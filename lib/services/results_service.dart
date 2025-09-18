import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Simple results fetcher wired for football-data.org free API.
/// Requires an API key passed at build/run time:
///   --dart-define=FOOTBALL_DATA_API_KEY=your_key
/// Only pulls competitions whitelisted below to match European top flights
/// and inter-country competitions.
class ResultsService {
  ResultsService({FirebaseFirestore? firestore, ResultsProvider? provider})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _provider = provider ?? FootballDataProvider();

  final FirebaseFirestore _fs;
  final ResultsProvider _provider;

  /// Updates scores for all matches on [dateUtc] that don't yet have final scores.
  /// Returns the number of matches updated.
  Future<int> updateScoresForDate(
    DateTime dateUtc, {
    Set<String>? allowedLeagues,
  }) async {
    final dayStart = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Load our matches for that UTC day
    final snap = await _fs
        .collection('matches')
        .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('timeUtc', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    if (snap.docs.isEmpty) return 0;

    final results = await _provider.fetchResultsForDate(dayStart, dayEnd);
    if (results.isEmpty) return 0;

    int updated = 0;
    final batch = _fs.batch();

    for (final d in snap.docs) {
      final data = d.data();
      final league = (data['league'] ?? '').toString();
      if (allowedLeagues != null && allowedLeagues.isNotEmpty && !allowedLeagues.contains(league)) {
        continue;
      }
      final dynamic t = data['timeUtc'];
      final dt = t is Timestamp ? t.toDate().toUtc() : (t as DateTime).toUtc();
      final home = (data['homeTeam'] ?? '').toString();
      final away = (data['awayTeam'] ?? '').toString();
      final hasScores = data['homeScore'] != null && data['awayScore'] != null;
      if (hasScores) continue; // already completed

      final match = _matchResult(results, dt, home, away);
      if (match == null) continue;

      batch.update(d.reference, {
        'homeScore': match.homeScore,
        'awayScore': match.awayScore,
        'status': 'completed',
      });
      updated++;
    }

    if (updated > 0) {
      await batch.commit();
    }
    return updated;
  }

  MatchResult? _matchResult(List<MatchResult> results, DateTime dt, String home, String away) {
    final targetDay = DateTime.utc(dt.year, dt.month, dt.day);
    final nh = _norm(home);
    final na = _norm(away);

    MatchResult? best;
    int bestScore = -1;
    for (final r in results) {
      final rDay = DateTime.utc(r.utcTime.year, r.utcTime.month, r.utcTime.day);
      if (rDay != targetDay) continue;

      final rh = _norm(r.homeTeam);
      final ra = _norm(r.awayTeam);

      int score = 0;
      if (rh == nh) score += 2;
      else if (rh.contains(nh) || nh.contains(rh)) score += 1;
      if (ra == na) score += 2;
      else if (ra.contains(na) || na.contains(ra)) score += 1;

      // small time proximity bonus (within 3h)
      final dtDiff = (r.utcTime.difference(dt)).inMinutes.abs();
      if (dtDiff <= 180) score += 1;

      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    // require decent confidence
    if (bestScore >= 3) return best;
    return null;
  }

  String _norm(String s) {
    final x = s
        .toLowerCase()
        .replaceAll(RegExp(r'fc|cf|afc|sc|ac|bc|u\d+'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // common aliases
    return x
        .replaceAll('manchester utd', 'manchester united')
        .replaceAll('man utd', 'manchester united')
        .replaceAll('man city', 'manchester city')
        .replaceAll('real madrid cf', 'real madrid')
        .replaceAll('inter milano', 'inter')
        .replaceAll('atl madrid', 'atletico madrid')
        .replaceAll('newcastle', 'newcastle united');
  }
}

abstract class ResultsProvider {
  Future<List<MatchResult>> fetchResultsForDate(DateTime fromUtc, DateTime toUtc);
}

class FootballDataProvider implements ResultsProvider {
  FootballDataProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Minimal whitelist of top European top-flight competitions and inter-country.
  // Easily extendable.
  static const List<String> competitions = [
    // Top-5 leagues
    'PL', // Premier League (England)
    'FL1', // Ligue 1 (France)
    'BL1', // Bundesliga (Germany)
    'SA', // Serie A (Italy)
    'PD', // La Liga (Spain)
    // Not top-5 but common
    'DED', // Eredivisie (Netherlands)
    'PPL', // Primeira Liga (Portugal)
    'TUR', // Süper Lig (Türkiye) – code alias varies
    'CHA', // Scottish Premiership (approx; subject to API code)
    // Inter-country competitions
    'EC', // UEFA European Championship
    'CL', // UEFA Champions League
    'EL', // UEFA Europa League
    'ECL', // UEFA Europa Conference League
    'WC-QUAL', // World Cup Qualifiers (broad; API specific)
    'FRIENDLY', // Friendlies (broad; API specific)
  ];

  // API key: uses --dart-define if provided, else falls back to embedded key below.
  static const String _envApiKey = String.fromEnvironment('FOOTBALL_DATA_API_KEY');
  static const String _embeddedApiKey = '6b4e882798e04de1b8f5ba8d46cad565';
  static String get _apiKey => _envApiKey.isNotEmpty ? _envApiKey : _embeddedApiKey;

  @override
  Future<List<MatchResult>> fetchResultsForDate(DateTime fromUtc, DateTime toUtc) async {
    if (_apiKey.isEmpty) {
      // Without a key we cannot call football-data.org.
      return [];
    }
    final dateFrom = _fmtDate(fromUtc);
    final dateTo = _fmtDate(toUtc.subtract(const Duration(seconds: 1)));
    final comps = competitions.join(',');
    final uri = Uri.parse('https://api.football-data.org/v4/matches?dateFrom=$dateFrom&dateTo=$dateTo&competitions=$comps');

    final resp = await _client.get(
      uri,
      headers: {'X-Auth-Token': _apiKey},
    );
    if (resp.statusCode != 200) {
      return [];
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final matches = (body['matches'] as List?) ?? const [];
    final List<MatchResult> out = [];
    for (final m in matches) {
      final status = (m['status'] ?? '').toString();
      if (status != 'FINISHED') continue;
      final utc = DateTime.tryParse((m['utcDate'] ?? '').toString())?.toUtc();
      if (utc == null) continue;
      final home = (m['homeTeam']?['name'] ?? '').toString();
      final away = (m['awayTeam']?['name'] ?? '').toString();
      final score = m['score'] as Map<String, dynamic>?;
      final full = score?['fullTime'] as Map<String, dynamic>?;
      final hs = (full?['home'] ?? 0) as int? ?? 0;
      final as_ = (full?['away'] ?? 0) as int? ?? 0;
      out.add(MatchResult(
        utcTime: utc,
        homeTeam: home,
        awayTeam: away,
        homeScore: hs,
        awayScore: as_,
      ));
    }
    return out;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class MatchResult {
  MatchResult({
    required this.utcTime,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
  });

  final DateTime utcTime;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
}
