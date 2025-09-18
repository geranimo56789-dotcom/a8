import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:country_flags/country_flags.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'theme_notifier.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/results_service.dart';
import 'services/winners_service.dart';

// Allowed competitions: Top domestic leagues and inter-country European competitions
const Set<String> kAllowedLeagues = {
  // Top-5 domestic
  'Premier League', // England
  'Ligue 1', // France
  'Bundesliga', // Germany
  'Serie A', // Italy
  'La Liga', // Spain
  // Other notable European top flights (optional, can prune)
  'Eredivisie', // Netherlands
  'Primeira Liga', // Portugal
  'Süper Lig', // Türkiye
  'Scottish Premiership',
  // Inter-country European competitions
  'UEFA Champions League',
  'UEFA Europa League',
  'UEFA Europa Conference League',
  'UEFA European Championship',
  'UEFA Nations League',
  'UEFA Euro Qualifiers',
  'FIFA World Cup Qualifiers (UEFA)',
};

class LocaleNotifier extends ChangeNotifier {
  Locale? _locale;
  Locale? get locale => _locale;
  void setLanguageCode(String code) {
    _locale = Locale(code);
    notifyListeners();
  }
}

final localeNotifier = LocaleNotifier();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    // Reduce potential IndexedDB/persistence issues on web
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }
  // Load saved language (defaults to English)
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString('language_code') ?? 'en';
  localeNotifier.setLanguageCode(code);
  runApp(
    ChangeNotifierProvider(create: (_) => ThemeNotifier(), child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, notifier, child) => AnimatedBuilder(
        animation: localeNotifier,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx).t('app_title'),
          theme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: 'Arial',
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            fontFamily: 'Arial',
            brightness: Brightness.dark,
          ),
          themeMode: notifier.darkTheme ? ThemeMode.dark : ThemeMode.light,
          home: AuthGate(),
          debugShowCheckedModeBanner: false,
          locale: localeNotifier.locale,
          supportedLocales: const [Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizationsDelegate(),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (kAdminOverride) {
          return const AdminPanel();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Route admin to the secret admin panel
          if ((user.email ?? '').toLowerCase() == 'admin@gmail.com') {
            return AdminPanel();
          }
          return HomeScreen();
        }
        return SignInScreen();
      },
    );
  }
}

bool kAdminOverride = false;

class TeamAvatar extends StatelessWidget {
  final String teamCode;
  final Color color;

  const TeamAvatar({super.key, required this.teamCode, required this.color});

  @override
  Widget build(BuildContext context) {
    final safeCode = teamCode.trim().toLowerCase();
    final proper = _properNameFromCode(safeCode);

    // Build candidate asset paths (png/jpg, multiple naming conventions)
    final candidates = <String>[
      'assets/logos/clubs/$safeCode.png',
      'assets/logos/clubs/${safeCode.toUpperCase()}.png',
      'assets/logos/clubs/England__$proper.png',
      'assets/logos/clubs/$proper.png',
      'assets/logos/clubs/${proper.replaceAll(' ', '_')}.png',
      'assets/logos/clubs/$safeCode.jpg',
      'assets/logos/clubs/${safeCode.toUpperCase()}.jpg',
      'assets/logos/clubs/England__$proper.jpg',
      'assets/logos/clubs/$proper.jpg',
      'assets/logos/clubs/${proper.replaceAll(' ', '_')}.jpg',
    ];

    // Circular container with contained image so all logos fit nicely
    const double radius = 28;
    final double size = radius * 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: _buildAssetChain(candidates, size - 8, fallback: _initialsFallback(radius)),
      ),
    );
  }

  // Recursively tries candidate asset paths until one loads, otherwise shows fallback
  Widget _buildAssetChain(List<String> paths, double size, {required Widget fallback}) {
    if (paths.isEmpty) return fallback;
    final head = paths.first;
    final tail = paths.sublist(1);
    return Image.asset(
      head,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _buildAssetChain(tail, size, fallback: fallback),
    );
  }

  Widget _initialsFallback(double radius) {
    return Container(
      alignment: Alignment.center,
      color: color,
      child: Text(
        teamCode.isNotEmpty ? teamCode.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Map code to a reasonable English proper name fragment used in assets like England__Aston Villa.png
  String _properNameFromCode(String code) {
    switch (code) {
      case 'avl':
        return 'Aston Villa';
      case 'ars':
        return 'Arsenal';
      case 'bou':
        return 'Bournemouth';
      case 'bre':
        return 'Brentford';
      case 'bha':
        return 'Brighton & Hove Albion';
      case 'che':
        return 'Chelsea';
      case 'cry':
        return 'Crystal Palace';
      case 'eve':
        return 'Everton';
      case 'ful':
        return 'Fulham';
      case 'ips':
        return 'Ipswich Town';
      case 'lei':
        return 'Leicester City';
      case 'liv':
        return 'Liverpool';
      case 'mci':
        return 'Manchester City';
      case 'mun':
        return 'Manchester United';
      case 'new':
        return 'Newcastle United';
      case 'nfo':
        return 'Nottingham Forest';
      case 'sou':
        return 'Southampton';
      case 'tot':
        return 'Tottenham';
      case 'whu':
        return 'West Ham';
      case 'wol':
        return 'Wolves';
      // Common alternates seen in assets
      case 'tottenham':
        return 'Tottenham Hotspur';
      case 'westham':
        return 'West Ham United';
      case 'wolves':
        return 'Wolverhampton Wanderers';
      default:
        return code.toUpperCase();
    }
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  bool _loading = false;
  String? _error;
  final TextEditingController _dateController = TextEditingController();
  // Triplet A
  final TextEditingController _hourA = TextEditingController();
  final TextEditingController _homeA = TextEditingController();
  final TextEditingController _awayA = TextEditingController();
  // Triplet B
  final TextEditingController _hourB = TextEditingController();
  final TextEditingController _homeB = TextEditingController();
  final TextEditingController _awayB = TextEditingController();
  // Triplet C
  final TextEditingController _hourC = TextEditingController();
  final TextEditingController _homeC = TextEditingController();
  final TextEditingController _awayC = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
  _hourA.dispose();
  _homeA.dispose();
  _awayA.dispose();
  _hourB.dispose();
  _homeB.dispose();
  _awayB.dispose();
  _hourC.dispose();
  _homeC.dispose();
  _awayC.dispose();
    super.dispose();
  }

  Future<void> _submitMatch() async {
  if (_dateController.text.isEmpty ||
  _hourA.text.isEmpty || _homeA.text.isEmpty || _awayA.text.isEmpty ||
  _hourB.text.isEmpty || _homeB.text.isEmpty || _awayB.text.isEmpty ||
  _hourC.text.isEmpty || _homeC.text.isEmpty || _awayC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please fill date and all 3 matches')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final date = _dateController.text.trim();
  final hourA = _hourA.text.trim();
  final homeA = _homeA.text.trim();
  final awayA = _awayA.text.trim();
  final hourB = _hourB.text.trim();
  final homeB = _homeB.text.trim();
  final awayB = _awayB.text.trim();
  final hourC = _hourC.text.trim();
  final homeC = _homeC.text.trim();
  final awayC = _awayC.text.trim();

      // Build three match maps and write in a batch
      DateTime parseHour(String hhmm) => DateTime.parse('${date}T$hhmm:00Z');
    Map<String, dynamic> matchMap(String home, String away, String hhmm) {
        final id = '${date}_${home.replaceAll(' ', '_')}_${away.replaceAll(' ', '_')}'.toLowerCase();
        return {
          'id': id,
          'homeTeam': home,
          'awayTeam': away,
          'homeTeamCode': _teamCode(home),
          'awayTeamCode': _teamCode(away),
      'league': 'Premier League',
          'timeUtc': Timestamp.fromDate(parseHour(hhmm)),
          'time': hhmm,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'admin',
          'matchDate': date,
        };
      }

    final mA = matchMap(homeA, awayA, hourA);
    final mB = matchMap(homeB, awayB, hourB);
    final mC = matchMap(homeC, awayC, hourC);

      final batch = FirebaseFirestore.instance.batch();
      for (final m in [mA, mB, mC]) {
        final id = m['id'] as String;
        batch.set(FirebaseFirestore.instance.collection('matches').doc(id), Map.of(m)..remove('id'));
      }
      await batch.commit();

      _dateController.clear();
  _hourA.clear(); _homeA.clear(); _awayA.clear();
  _hourB.clear(); _homeB.clear(); _awayB.clear();
  _hourC.clear(); _homeC.clear(); _awayC.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added 3 matches for $date (UTC).'),
          duration: const Duration(seconds: 3),
        ),
      );

  // ignore: avoid_print
  print('DEBUG: Admin created 3 matches for date: $date');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding match: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // TEST HELPER: Seed today's three matches at 12:00, 15:30, 18:00 UTC
  Future<void> _seedTodaysTriplet() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      String fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final dateStr = fmt(todayUtc);

      DateTime at(String hhmm) => DateTime.parse('${dateStr}T$hhmm:00Z');
      Map<String, dynamic> m(String home, String away, DateTime t) {
        final id = '${dateStr}_${home.replaceAll(' ', '_')}_${away.replaceAll(' ', '_')}'.toLowerCase();
        return {
          'id': id,
          'homeTeam': home,
          'awayTeam': away,
          'homeTeamCode': _teamCode(home),
          'awayTeamCode': _teamCode(away),
          'league': 'Premier League',
          'timeUtc': Timestamp.fromDate(t),
          'time': DateFormat('HH:mm').format(t),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'admin',
          'matchDate': dateStr,
        };
      }

      final a = m('Arsenal', 'Manchester City', at('12:00'));
      final b = m('Chelsea', 'Liverpool', at('15:30'));
      final c = m('Newcastle United', 'West Ham United', at('18:00'));

      final batch = FirebaseFirestore.instance.batch();
      for (final mm in [a, b, c]) {
        final id = mm['id'] as String;
        batch.set(
          FirebaseFirestore.instance.collection('matches').doc(id),
          Map.of(mm)..remove('id'),
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seeded today's triplet in UTC")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // TEST HELPER: Mark today's three matches as completed with sample scores
  Future<void> _completeTodaysMatchesSampleScores() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final dayStart = DateTime.utc(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('timeUtc', isLessThan: Timestamp.fromDate(dayEnd))
          .orderBy('timeUtc')
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matches today to complete')),
        );
        setState(() => _loading = false);
        return;
      }

      // Assign scores in order: [1-0, 0-0, 2-1]
      final scores = const [
        {'home': 1, 'away': 0},
        {'home': 0, 'away': 0},
        {'home': 2, 'away': 1},
      ];
      final batch = FirebaseFirestore.instance.batch();
      for (var i = 0; i < snap.docs.length && i < scores.length; i++) {
        final doc = snap.docs[i];
        final sc = scores[i];
        batch.update(doc.reference, {
          'homeScore': sc['home'],
          'awayScore': sc['away'],
          'status': 'completed',
        });
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Today's matches marked completed with sample scores")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // TEST HELPER: Run the distributed winners job for today immediately
  Future<void> _runWinnersJobNow() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(now.year, now.month, now.day);
      final ws = WinnersService();
      final out = await ws.runDistributedDailyJobForDate(
        todayUtc,
        allowedLeagues: kAllowedLeagues,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Winners job: ${out.state}${out.winners != null ? ' winners=${out.winners}' : ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Admin: Export CSV with winners' emails grouped by date (UTC), over last 365 days
  Future<void> _exportWinnersCsv() async {
    setState(() => _loading = true);
    try {
      // First, try to fill in missing results for relevant competitions on yesterday and today
      try {
        final now = DateTime.now().toUtc();
        final todayUtc = DateTime.utc(now.year, now.month, now.day);
        final yestUtc = todayUtc.subtract(const Duration(days: 1));
        final rs = ResultsService();
        await rs.updateScoresForDate(yestUtc, allowedLeagues: kAllowedLeagues);
        await rs.updateScoresForDate(todayUtc, allowedLeagues: kAllowedLeagues);
      } catch (_) {
        // Swallow fetch errors to allow CSV to proceed with whatever data exists.
      }

      final now = DateTime.now().toUtc();
      final start = now.subtract(const Duration(days: 365));

      // Prefer precomputed archive built by the distributed job
      final archiveSnap = await FirebaseFirestore.instance
          .collection('winners_archive')
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(start))
          .get();

      final buffer = StringBuffer('date,email\n');
      if (archiveSnap.docs.isNotEmpty) {
        final items = archiveSnap.docs
            .map((d) => d.data())
            .where((m) => (m['winners'] as List?) != null)
            .toList();
        // Sort by date ascending
        items.sort((a, b) => (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString()));
        for (final m in items) {
          final date = (m['date'] ?? '').toString();
          final winners = (m['winners'] as List).cast<dynamic>().map((e) => e.toString()).toList()..sort();
          for (final w in winners) {
            buffer.writeln('$date,$w');
          }
        }
      } else {
        // Fallback: compute on the fly (legacy path)
        // Load matches with final scores in the last year
        final matchesSnap = await FirebaseFirestore.instance
            .collection('matches')
            .where('timeUtc', isGreaterThan: Timestamp.fromDate(start))
            .orderBy('timeUtc')
            .get();

        // dateStr -> matchId -> (homeScore, awayScore)
        final Map<String, Map<String, Map<String, int>>> resultsByDate = {};
        for (final doc in matchesSnap.docs) {
          final data = doc.data();
          final league = (data['league'] ?? '').toString();
          if (league.isEmpty || !kAllowedLeagues.contains(league)) continue; // restrict to allowed competitions
          final t = data['timeUtc'];
          if (t == null) continue;
          final dt = t is Timestamp ? t.toDate().toUtc() : (t as DateTime).toUtc();
          final hs = data['homeScore'];
          final as = data['awayScore'];
          if (hs == null || as == null) continue; // skip matches without final score
          final dateStr = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          resultsByDate.putIfAbsent(dateStr, () => {});
          resultsByDate[dateStr]![doc.id] = {
            'home': (hs as num).toInt(),
            'away': (as as num).toInt(),
          };
        }

        if (resultsByDate.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No finished matches found to compute winners.')),
          );
          setState(() => _loading = false);
          return;
        }

        // 2) Load all predictions collection group for the same timeframe
        final predsSnap = await FirebaseFirestore.instance
            .collectionGroup('predictions')
            .where('lockAt', isGreaterThan: Timestamp.fromDate(start))
            .get();

        // dateStr -> email -> correctCount
        final Map<String, Map<String, int>> correctByDateEmail = {};
        for (final doc in predsSnap.docs) {
          final data = doc.data();
          final lockAt = data['lockAt'];
          if (lockAt == null) continue;
          final d = lockAt is Timestamp ? lockAt.toDate().toUtc() : (lockAt as DateTime).toUtc();
          final dateStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final resForDate = resultsByDate[dateStr];
          if (resForDate == null) continue; // no results for that date yet
          final matchId = (data['matchId'] ?? '').toString();
          final predictedHome = (data['homeScore'] ?? 0) as num;
          final predictedAway = (data['awayScore'] ?? 0) as num;
          final actual = resForDate[matchId];
          if (actual == null) continue;
          final ok = predictedHome.toInt() == actual['home'] && predictedAway.toInt() == actual['away'];
          if (!ok) continue;
          final parent = doc.reference.parent.parent; // users/{uid}
          final uid = parent?.id ?? 'unknown';
          final email = (data['userEmail']?.toString().toLowerCase() ?? '').trim();
          final key = email.isNotEmpty ? email : 'uid:$uid';
          correctByDateEmail.putIfAbsent(dateStr, () => {});
          correctByDateEmail[dateStr]![key] = (correctByDateEmail[dateStr]![key] ?? 0) + 1;
        }

        // 3) Winners are emails with 3 correct predictions on that date
        final Map<String, Set<String>> winnersByDate = {};
        correctByDateEmail.forEach((date, map) {
          for (final entry in map.entries) {
            if (entry.value >= 3) {
              winnersByDate.putIfAbsent(date, () => <String>{});
              winnersByDate[date]!.add(entry.key);
            }
          }
        });

        // 4) Build CSV: date,email
        final dates = winnersByDate.keys.toList()..sort();
        for (final date in dates) {
          final emails = winnersByDate[date]?.toList();
          if (emails == null || emails.isEmpty) continue;
          emails.sort();
          for (final e in emails) {
            buffer.writeln('$date,$e');
          }
        }
      }

      final csv = buffer.toString();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Winners CSV'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: SelectableText(csv.isEmpty ? 'date,email\n' : csv),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (mounted) Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  String _teamCode(String name) {
    const map = {
      'Arsenal': 'ars',
      'Arsenal B': 'ars',
      'AFC Bournemouth': 'bou',
      'Aston Villa': 'avl',
      'Bournemouth': 'bou',
      'Brentford': 'bre',
      'Brighton & Hove Albion': 'bha',
      'Brighton': 'bha',
      'Chelsea': 'che',
      'Crystal Palace': 'cry',
      'Everton': 'eve',
      'Fulham': 'ful',
      'Ipswich Town': 'ips',
      'Leicester City': 'lei',
      'Liverpool': 'liv',
      'Manchester City': 'mci',
      'Manchester United': 'mun',
      'Newcastle United': 'new',
      'Nottingham Forest': 'nfo',
      'Southampton': 'sou',
      'Tottenham Hotspur': 'tot',
      'West Ham United': 'whu',
      'Wolverhampton Wanderers': 'wol',
    };

    final result = map[name] ??
        name
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w.substring(0, 1))
            .take(3)
            .join();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              kAdminOverride = false;
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  const Text(
                    'Add New Match',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date (YYYY-MM-DD)',
                      hintText: '2025-08-21',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  Text('Match A', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _matchRow(_homeA, _awayA, _hourA),
                  const SizedBox(height: 16),
                  Text('Match B', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _matchRow(_homeB, _awayB, _hourB),
                  const SizedBox(height: 16),
                  Text('Match C', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _matchRow(_homeC, _awayC, _hourC),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submitMatch,
                          child: const Text('Submit Match'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _exportWinnersCsv,
                          child: const Text('Export to CSV winning bets'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Test helpers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _loading ? null : _seedTodaysTriplet,
                        child: const Text("Seed today's 3 matches (UTC)"),
                      ),
                      ElevatedButton(
                        onPressed: _loading ? null : _completeTodaysMatchesSampleScores,
                        child: const Text("Set today's sample final scores"),
                      ),
                      ElevatedButton(
                        onPressed: _loading ? null : _runWinnersJobNow,
                        child: const Text('Run winners job now'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'UTC timezone',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _matchRow(TextEditingController home, TextEditingController away, TextEditingController hour) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: home,
            decoration: const InputDecoration(
              labelText: 'Team 1',
              hintText: 'Arsenal',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: TextField(
            controller: away,
            decoration: const InputDecoration(
              labelText: 'Team 2',
              hintText: 'Manchester City',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: hour,
            decoration: const InputDecoration(
              labelText: 'Hour (HH:MM)',
              hintText: '15:00',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorText;
  bool _isAutoLoggingIn = true;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadRememberedAndAutoLogin();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadRememberedAndAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remember_email');
    final password = prefs.getString('remember_password');

    if (email != null && password != null) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberMe = true;
        _isAutoLoggingIn = true;
      });

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        await prefs.remove('remember_password');
        setState(() {
          _isAutoLoggingIn = false;
          _errorText = AppLocalizations.of(context).t('auto_login_failed');
        });
      }
    } else {
      setState(() {
        _isAutoLoggingIn = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remember_email', _emailController.text.trim());
        await prefs.setString('remember_password', _passwordController.text);
      } else {
        await prefs.remove('remember_email');
        await prefs.remove('remember_password');
      }
    } on FirebaseAuthException catch (e) {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      if (email == 'admin@gmail.com' && password == '111111') {
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            await FirebaseAuth.instance.signInAnonymously();
          }
        } catch (_) {}
        if (!mounted) return;
        kAdminOverride = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminPanel()),
        );
        return;
      }
      if (e.code == 'user-not-found' &&
          email == 'admin@gmail.com' &&
          password == '111111') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          // After creating, sign in implicitly via auth state change
          final prefs = await SharedPreferences.getInstance();
          if (_rememberMe) {
            await prefs.setString('remember_email', email);
            await prefs.setString('remember_password', password);
          } else {
            await prefs.remove('remember_email');
            await prefs.remove('remember_password');
          }
        } on FirebaseAuthException catch (e2) {
          // If the email already exists, try to sign in (will surface wrong-password if mismatched)
          if (e2.code == 'email-already-in-use') {
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            } on FirebaseAuthException catch (e3) {
              _setAuthErrorFromCode(e3.code, fallbackMessage: e3.message);
            }
          } else {
            _setAuthErrorFromCode(e2.code, fallbackMessage: e2.message);
          }
        }
      } else {
        _setAuthErrorFromCode(e.code, fallbackMessage: e.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setAuthErrorFromCode(String code, {String? fallbackMessage}) {
    String key;
    switch (code) {
      case 'invalid-email':
        key = 'auth_invalid_email';
        break;
      case 'missing-password':
        key = 'auth_missing_password';
        break;
      case 'user-not-found':
        key = 'auth_user_not_found';
        break;
      case 'wrong-password':
        key = 'auth_wrong_password';
        break;
      case 'invalid-credential':
        // Newer Firebase returns this for wrong password/invalid credential
        key = 'auth_wrong_password';
        break;
      case 'user-disabled':
        key = 'auth_user_disabled';
        break;
      case 'too-many-requests':
        key = 'auth_too_many_requests';
        break;
      case 'network-request-failed':
        key = 'auth_network_error';
        break;
      case 'email-already-in-use':
        key = 'auth_email_in_use';
        break;
      case 'operation-not-allowed':
        key = 'auth_operation_not_allowed';
        break;
      default:
        key = 'auth_unknown_error';
    }
    setState(() {
      final base = AppLocalizations.of(context).t(key);
      _errorText = fallbackMessage != null && key == 'auth_unknown_error'
          ? '$base\n$fallbackMessage'
          : base;
    });
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remember_email', _emailController.text.trim());
      await prefs.setString(
        'remember_password',
        _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAutoLoggingIn) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).t('auto_signing_in')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[400],
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context).t('sign_in'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).t('email'),
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).t('password'),
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                      ),
                      Text(
                        AppLocalizations.of(context).t('remember_me'),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          if (_emailController.text.trim().isEmpty) return;
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: _emailController.text.trim(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                ).t('password_reset_email_sent'),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.of(context).t('forgot_password'),
                        ),
                      ),
                    ],
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text(AppLocalizations.of(context).t('sign_in'), style: const TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _register,
                    child: Text(
                      AppLocalizations.of(context).t('create_account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_appVersion != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Version: ${_appVersion!}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, int> _predictedHome = {};
  final Map<String, int> _predictedAway = {};

  List<Map<String, dynamic>> matches = [];
  bool _loadingMatches = true;
  Timer? _autoFetchTimer;
  final WinnersService _winnersService = WinnersService();

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _autoFetchTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMatches() async {
    setState(() {
      _loadingMatches = true;
    });
    await _loadMatches();
  }

  Future<void> _loadMatches() async {
    print('DEBUG: Loading matches...');
    
    // Create sample matches first as a fallback
    final now = DateTime.now().toUtc();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final tomorrowUtc = todayUtc.add(const Duration(days: 1));
    final yesterdayUtc = todayUtc.subtract(const Duration(days: 1));
    print('DEBUG: Today UTC base: $todayUtc');
    print('DEBUG: Tomorrow UTC base: $tomorrowUtc');
    
    final sampleMatches = [
      // Yesterday's completed triplet
      {
        'id': 'sample_past_eve_ful',
        'homeTeam': 'Everton',
        'awayTeam': 'Fulham',
        'homeTeamCode': 'eve',
        'awayTeamCode': 'ful',
        'league': 'Premier League',
        'timeUtc': yesterdayUtc.add(const Duration(hours: 14)),
        'homeScore': 2,
        'awayScore': 1,
        'status': 'completed',
      },
      {
        'id': 'sample_past_bre_bha',
        'homeTeam': 'Brentford',
  'awayTeam': 'Leicester City',
        'homeTeamCode': 'bre',
  'awayTeamCode': 'lei',
        'league': 'Premier League',
        'timeUtc': yesterdayUtc.add(const Duration(hours: 16)),
        'homeScore': 0,
        'awayScore': 0,
        'status': 'completed',
      },
      {
        'id': 'sample_past_tot_mun',
        'homeTeam': 'Tottenham Hotspur',
        'awayTeam': 'Manchester United',
        'homeTeamCode': 'tot',
        'awayTeamCode': 'mun',
        'league': 'Premier League',
        'timeUtc': yesterdayUtc.add(const Duration(hours: 18)),
        'homeScore': 3,
        'awayScore': 2,
        'status': 'completed',
      },
      // Today's triplet
      {
        'id': 'sample_ars_mci',
        'homeTeam': 'Arsenal',
        'awayTeam': 'Manchester City',
        'homeTeamCode': 'ars',
        'awayTeamCode': 'mci',
  'league': 'Premier League',
  'timeUtc': todayUtc.add(const Duration(hours: 12)),
      },
      {
        'id': 'sample_che_liv',
        'homeTeam': 'Chelsea',
        'awayTeam': 'Liverpool',
        'homeTeamCode': 'che',
        'awayTeamCode': 'liv',
        'league': 'Premier League',
        'timeUtc': todayUtc.add(const Duration(hours: 15, minutes: 30)),
      },
      {
        'id': 'sample_new_whu',
        'homeTeam': 'Newcastle United',
        'awayTeam': 'West Ham United',
        'homeTeamCode': 'new',
        'awayTeamCode': 'whu',
        'league': 'Premier League',
        'timeUtc': todayUtc.add(const Duration(hours: 18)),
      },
    ];
    
    try {
      // Query for matches from a few days ago to tomorrow to get both past and future matches
      final threeDaysAgoUtc = todayUtc.subtract(const Duration(days: 3));
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(threeDaysAgoUtc))
          .where('timeUtc', isLessThan: Timestamp.fromDate(tomorrowUtc))
          .orderBy('timeUtc')
          .get();
          
      List<Map<String, dynamic>> firestoreMatches = snapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList()
          .cast<Map<String, dynamic>>();

      print('DEBUG: Firestore matches (last 3 days + today): ${firestoreMatches.length}');
      
      // Use sample matches only if Firestore returned none (dev/demo fallback)
      if (firestoreMatches.isEmpty) {
        firestoreMatches.addAll(sampleMatches);
        print('DEBUG: Using sample matches fallback: ${firestoreMatches.length}');
      }

      // Sort all matches by time to ensure proper display order
      firestoreMatches.sort((a, b) {
        final dynamic aTime = a['timeUtc'];
        final dynamic bTime = b['timeUtc'];
        DateTime aDate, bDate;
        
        if (aTime is Timestamp) {
          aDate = aTime.toDate().toUtc();
        } else if (aTime is DateTime) {
          aDate = aTime.toUtc();
        } else {
          return 0;
        }
        
        if (bTime is Timestamp) {
          bDate = bTime.toDate().toUtc();
        } else if (bTime is DateTime) {
          bDate = bTime.toUtc();
        } else {
          return 0;
        }
        
        return aDate.compareTo(bDate);
      });

      setState(() {
        matches = firestoreMatches;
        _loadingMatches = false;
      });
      print('DEBUG: Matches loaded and sorted successfully: ${matches.length}');
  // Schedule automatic results fetch for today's matches (end of last match)
  // Best effort: runs once per UTC day, immediate if overdue.
  unawaited(_scheduleAutoResultsFetchForToday());
    } catch (e) {
      print('DEBUG: Error loading matches: $e');
      // Use sample matches as fallback
      final sortedSamples = List<Map<String, dynamic>>.from(sampleMatches);
      sortedSamples.sort((a, b) {
        final dynamic aTime = a['timeUtc'];
        final dynamic bTime = b['timeUtc'];
        if (aTime is DateTime && bTime is DateTime) {
          return aTime.compareTo(bTime);
        }
        return 0;
      });
      
      setState(() {
        matches = sortedSamples;
        _loadingMatches = false;
      });
      print('DEBUG: Using sorted sample matches as fallback: ${sortedSamples.length}');
      // Even with samples, attempt scheduling to keep behavior consistent in dev/demo
      unawaited(_scheduleAutoResultsFetchForToday());
    }
  }

  Future<void> _scheduleAutoResultsFetchForToday() async {
    try {
      _autoFetchTimer?.cancel();

      final todayMatches = _todaysMatches();
      if (todayMatches.isEmpty) {
        print('DEBUG: AutoFetch: No matches today, nothing to schedule.');
        return;
      }

      // Determine last kickoff time in UTC
      final dynamic lastT = todayMatches.last['timeUtc'];
      DateTime lastKickUtc;
      if (lastT is Timestamp) {
        lastKickUtc = lastT.toDate().toUtc();
      } else if (lastT is DateTime) {
        lastKickUtc = lastT.toUtc();
      } else {
        print('DEBUG: AutoFetch: Invalid timeUtc type for last match: $lastT');
        return;
      }

      // Schedule 3 hours after last kickoff to allow for extra time/overruns
      final scheduledAt = lastKickUtc.add(const Duration(hours: 3));
      final now = DateTime.now().toUtc();

  // We'll not use local SharedPreferences to gate; the distributed job itself
  // ensures idempotency and progress marking in Firestore.
  final todayUtcDate = DateTime.utc(now.year, now.month, now.day);

      if (!now.isBefore(scheduledAt)) {
        // Time passed; run immediately
        print('DEBUG: AutoFetch: Scheduled time passed, running now.');
        await _runAutoResultsFetch(todayUtcDate);
        return;
      }

      final delay = scheduledAt.difference(now);
      print('DEBUG: AutoFetch: Scheduling in ${delay.inMinutes} minutes at $scheduledAt');
      _autoFetchTimer = Timer(delay, () async {
        await _runAutoResultsFetch(todayUtcDate);
      });
    } catch (e) {
      print('DEBUG: AutoFetch: schedule error: $e');
    }
  }

  Future<void> _runAutoResultsFetch(DateTime todayUtcDate) async {
    try {
      // Run the distributed winners job for today; this will:
      // - update missing scores
      // - compute 3/3 winners
      // - archive to winners_archive and mark job status in winners_jobs
      final outcome = await _winnersService.runDistributedDailyJobForDate(
        todayUtcDate,
        allowedLeagues: kAllowedLeagues,
      );
      print('DEBUG: AutoFetch: Winners job outcome for ${outcome.date}: ${outcome.state} ${outcome.message ?? ''}');
      // Refresh to reflect updated scores
      if (mounted) {
        await _refreshMatches();
      }
    } catch (e) {
      print('DEBUG: AutoFetch: run error: $e');
    }
  }

  List<Map<String, dynamic>> _todaysMatches() {
    final now = DateTime.now().toUtc();
    print('DEBUG: Current time UTC: $now');
    print('DEBUG: Total matches loaded: ${matches.length}');
    
  final filtered = matches.where((m) {
      final dynamic t = m['timeUtc'];
      DateTime dt;
      if (t is Timestamp) {
        dt = t.toDate().toUtc();
      } else if (t is DateTime) {
        dt = t.toUtc();
      } else {
        print('DEBUG: Invalid time type for match ${m['id']}: $t');
        return false;
      }
      
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      print('DEBUG: Match ${m['id']} time: $dt, isToday: $isToday');
      return isToday;
    }).toList();
    
    // Deduplicate by id to avoid accidental duplicates
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final m in filtered) {
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        unique.add(m);
      }
    }

    // Sort by time ascending to match UI expectation
    unique.sort((a, b) {
      final at = a['timeUtc'];
      final bt = b['timeUtc'];
      DateTime ad = at is Timestamp ? at.toDate().toUtc() : (at as DateTime).toUtc();
      DateTime bd = bt is Timestamp ? bt.toDate().toUtc() : (bt as DateTime).toUtc();
      return ad.compareTo(bd);
    });

    print('DEBUG: Today\'s matches unique count: ${unique.length}');
    return unique.length > 3 ? unique.take(3).toList() : unique;
  }

  // _latestMatch() removed; replaced by _yesterdaysMatches()

  void _changePrediction(String matchId, String side, int delta) {
    setState(() {
      if (side == 'home') {
        _predictedHome[matchId] = (_predictedHome[matchId] ?? 0) + delta;
        if (_predictedHome[matchId]! < 0) _predictedHome[matchId] = 0;
      } else {
        _predictedAway[matchId] = (_predictedAway[matchId] ?? 0) + delta;
        if (_predictedAway[matchId]! < 0) _predictedAway[matchId] = 0;
      }
    });
  }

  Future<void> _submitPredictions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Always target the 3 matches of today
    final todayMatches = _todaysMatches();
    if (todayMatches.length != 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('no_more_match_to_predict'))),
      );
      return;
    }

    // Load existing predictions for these 3 matches to prefill and detect previous batchId
    final matchIds = todayMatches.map((m) => m['id'] as String).toList();
    final futures = matchIds.map((id) => FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('predictions')
        .doc(id)
        .get());
    final existingDocs = await Future.wait(futures);

    String? existingBatchId;
    Timestamp latestSubmit = Timestamp(0, 0);
    final Map<String, Map<String, dynamic>> existingById = {};
    for (final snap in existingDocs) {
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        existingById[snap.id] = data;
        final sa = data['submittedAt'];
        if (sa is Timestamp && sa.compareTo(latestSubmit) > 0) {
          latestSubmit = sa;
          existingBatchId = data['batchId']?.toString();
        }
      }
    }

    // Reuse previous batchId for the same triplet if present, else create a new one
  final String batchId = existingBatchId ?? DateTime.now().toUtc().millisecondsSinceEpoch.toString();

    // Build writes for all 3 matches (use new values if provided, else fallback to previous, else 0)
    final batch = FirebaseFirestore.instance.batch();
    int batchOrder = 0;
    for (final match in todayMatches) {
      final id = match['id'] as String;
      // Always write explicit values for all 3 matches; default to 0 when unchanged
      final int home = _predictedHome[id] ?? 0;
      final int away = _predictedAway[id] ?? 0;

      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .doc(id);

      batch.set(ref, {
        'matchId': id,
        'homeScore': home,
        'awayScore': away,
        'createdAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
        'batchId': batchId,
        'batchOrder': batchOrder,
        'lockAt': match['timeUtc'],
        'homeTeam': match['homeTeam'],
        'awayTeam': match['awayTeam'],
        'homeTeamCode': match['homeTeamCode'],
        'awayTeamCode': match['awayTeamCode'],
        'userId': user.uid,
        'userEmail': (user.email ?? '').toLowerCase(),
      }, SetOptions(merge: true));
      batchOrder++;
    }

    try {
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error committing batch: $e')),
      );
      return;
    }

    setState(() {
      _predictedHome.clear();
      _predictedAway.clear();
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PredictionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[400],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white, size: 30),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Image.asset(
          'assets/var6_logo.png',
          height: 48,
          errorBuilder: (context, error, stackTrace) => Text(
            AppLocalizations.of(context).t('image_not_found'),
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshMatches,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
    Text(
              AppLocalizations.of(
                context,
              ).t('place_your_predictions_for_todays_match_ups'),
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
            SizedBox(height: 8),
  Text(
              AppLocalizations.of(context).t('todays_matches'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
        color: Colors.blue,
              ),
            ),
    SizedBox(height: 2),
            _loadingMatches
                ? SizedBox(
  height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
        : _todaysMatches().isNotEmpty
        ? Column(
          children: _todaysMatches()
            .map((match) => _buildEditableMatchCard(match))
            .toList(),
          )
                : SizedBox(
  height: 50,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).t('no_more_match_to_predict'),
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  ),
  SizedBox(height: 6),
      SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
    padding: EdgeInsets.symmetric(vertical: 6),
                ),
        onPressed: _todaysMatches().length == 3 && _isBettingOpen() ? _submitPredictions : null,
                child: Text(
                  AppLocalizations.of(context).t('submit_prediction'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
      const SizedBox(height: 2),
            // Latest matches moved to bottom
      const SizedBox(height: 4),
            Text(
              'Latest matches',
              style: TextStyle(
        fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
      const SizedBox(height: 4),
            _loadingMatches
                ? Center(child: CircularProgressIndicator())
                : Builder(builder: (context) {
                    final list = _yesterdaysMatches();
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context).t('no_more_match_to_predict'),
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      );
                    }
                    return Column(
                      children: list.take(3).map((m) => _buildStyledMatchCard(m)).toList(),
                    );
                  }),
          ],
        ),
      ),
      ),
    );
  }

  // Yesterday's matches in UTC (ensures the section always shows recent results)
  List<Map<String, dynamic>> _yesterdaysMatches() {
    if (matches.isEmpty) return [];
    final now = DateTime.now().toUtc();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final yesterdayUtc = todayUtc.subtract(const Duration(days: 1));
  final list = matches.where((m) {
      final t = m['timeUtc'];
      DateTime dt;
      if (t is Timestamp) {
        dt = t.toDate().toUtc();
      } else if (t is DateTime) {
        dt = t.toUtc();
      } else {
        return false;
      }
      return dt.year == yesterdayUtc.year && dt.month == yesterdayUtc.month && dt.day == yesterdayUtc.day;
    }).toList();
    // Deduplicate by id
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final m in list) {
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        unique.add(m);
      }
    }
    // Sort by time ascending
    unique.sort((a, b) {
      final at = a['timeUtc'];
      final bt = b['timeUtc'];
      DateTime ad = at is Timestamp ? at.toDate().toUtc() : (at as DateTime).toUtc();
      DateTime bd = bt is Timestamp ? bt.toDate().toUtc() : (bt as DateTime).toUtc();
      return ad.compareTo(bd);
    });
    return unique.length > 3 ? unique.take(3).toList() : unique;
  }

  // Updated: Modern card with ribbon and big scores
  Widget _buildStyledMatchCard(Map<String, dynamic> match) {
    final String homeCode = match['homeTeamCode'] ?? 'H';
    final String awayCode = match['awayTeamCode'] ?? 'A';
    final dt = _matchLocalTime(match);
    final homeScore = (match['homeScore'] ?? 0).toString();
    final awayScore = (match['awayScore'] ?? 0).toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
      // Header (league label removed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
        const SizedBox.shrink(),
                if (dt != null) _dateRibbon(dt),
              ],
            ),
          ),
          // Main content (align with today's card)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Home
                Expanded(
                  child: Column(
                    children: [
                      TeamAvatar(teamCode: homeCode, color: Colors.blue),
            const SizedBox(height: 6),
                      Text(
                        (match['homeTeam'] ?? 'Home').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
                          color: Colors.blue,
              // letterSpacing removed to match today's card
                        ),
                      ),
                    ],
                  ),
                ),
                // Score block
                Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          homeScore,
                          style: TextStyle(
              fontSize: 36,
                            fontWeight: FontWeight.w900,
              color: Colors.blue[800],
                          ),
                        ),
            const SizedBox(width: 20),
            Text('v', style: TextStyle(fontSize: 24, color: Colors.blue[800], fontWeight: FontWeight.w900)),
            const SizedBox(width: 20),
                        Text(
                          awayScore,
                          style: TextStyle(
              fontSize: 36,
                            fontWeight: FontWeight.w900,
              color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
            const SizedBox(height: 2),
                  ],
                ),
                // Away
                Expanded(
                  child: Column(
                    children: [
                      TeamAvatar(teamCode: awayCode, color: Colors.red),
            const SizedBox(height: 6),
                      Text(
                        (match['awayTeam'] ?? 'Away').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
                          color: Colors.blue,
              // letterSpacing removed to match today's card
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer actions removed per design request
        ],
      ),
    );
  }

  // Updated: Modern editable card design similar to the reference image
  Widget _buildEditableMatchCard(Map<String, dynamic> match) {
    final String id = match['id'];
    final String homeCode = match['homeTeamCode'] ?? 'H';
    final String awayCode = match['awayTeamCode'] ?? 'A';
    final int home = _predictedHome[id] ?? 0;
    final int away = _predictedAway[id] ?? 0;
  final dt = _matchLocalTime(match);
  final bool bettingOpen = _isBettingOpen();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
      // Header with date/time (league label removed)
  Container(
            width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
        color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
        const SizedBox.shrink(),
                if (dt != null) _dateRibbon(dt),
              ],
            ),
          ),
          // Main content with teams and prediction controls
          Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                // Home team
                Expanded(
                  child: Column(
                    children: [
                      TeamAvatar(teamCode: homeCode, color: Colors.blue),
                      SizedBox(height: 6),
                      Text(
                        (match['homeTeam'] ?? 'Home').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // VS section
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AbsorbPointer(
                        absorbing: !bettingOpen,
                        child: Opacity(
                          opacity: bettingOpen ? 1.0 : 0.5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                          // Home vertical controls
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _changePrediction(id, 'home', 1),
                                child: Image.asset(
                                  'plus.png',
                                  width: 27,
                                  height: 27,
                                  errorBuilder: (context, error, stack) => Text('+', style: TextStyle(fontSize: 27, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$home',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _changePrediction(id, 'home', -1),
                                child: Image.asset(
                                  'minus.png',
                                  width: 33,
                                  height: 15,
                                  errorBuilder: (context, error, stack) => Text('-', style: TextStyle(fontSize: 27, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 20),
                          Text('v', style: TextStyle(fontSize: 24, color: Colors.blue[800], fontWeight: FontWeight.w900)),
                          const SizedBox(width: 20),

                          // Away vertical controls
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _changePrediction(id, 'away', 1),
                                child: Image.asset(
                                  'plus.png',
                                  width: 27,
                                  height: 27,
                                  errorBuilder: (context, error, stack) => Text('+', style: TextStyle(fontSize: 27, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$away',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _changePrediction(id, 'away', -1),
                                child: Image.asset(
                                  'minus.png',
                                  width: 33,
                                  height: 15,
                                  errorBuilder: (context, error, stack) => Text('-', style: TextStyle(fontSize: 27, color: Colors.blue[800], fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Away team
                Expanded(
                  child: Column(
                    children: [
                      TeamAvatar(teamCode: awayCode, color: Colors.red),
                      SizedBox(height: 6),
                      Text(
                        (match['awayTeam'] ?? 'Away').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer actions removed per design request
        ],
      ),
    );
  }

  // Footer helpers removed as footer is no longer used

  // Removed old _formatMatchDateTime helper; now using ribbon date/time UI

  // Helpers to render a date/time ribbon like the reference image
  DateTime? _matchLocalTime(Map<String, dynamic> match) {
    // Display times in UTC as they were entered/saved to avoid local TZ shifts
    final t = match['timeUtc'];
    if (t is Timestamp) return t.toDate().toUtc();
    if (t is DateTime) return t.toUtc();
    return null;
  }

  // Betting is open until the earliest of today's three matches starts (UTC).
  bool _isBettingOpen() {
    final today = _todaysMatches();
    if (today.isEmpty) return true; // nothing to bet on
    // Matches are already sorted ascending by time
    final dynamic t = today.first['timeUtc'];
    DateTime firstKick;
    if (t is Timestamp) {
      firstKick = t.toDate().toUtc();
    } else if (t is DateTime) {
      firstKick = t.toUtc();
    } else {
      return true;
    }
    final now = DateTime.now().toUtc();
    return now.isBefore(firstKick);
  }

  String _ordinalDay(int d) {
    if (d >= 11 && d <= 13) return '${d}TH';
    switch (d % 10) {
      case 1:
        return '${d}ST';
      case 2:
        return '${d}ND';
      case 3:
        return '${d}RD';
      default:
        return '${d}TH';
    }
  }

  String _formatRibbonDate(DateTime dt) {
    final dow = DateFormat('EEE').format(dt).toUpperCase();
    final month = DateFormat('MMM').format(dt).toUpperCase();
    final day = _ordinalDay(dt.day);
  // Year removed per request
  return '$dow $day $month';
  }

  String _formatRibbonTime(DateTime dt) {
  final minutes = dt.minute;
  final h = DateFormat('h').format(dt);
  final ampm = DateFormat('a').format(dt); // AM/PM
    if (minutes == 0) {
      return '$h$ampm';
    }
    final mm = DateFormat('mm').format(dt);
    return '$h:$mm$ampm';
  }

  Widget _dateRibbon(DateTime dt) {
    final dateText = _formatRibbonDate(dt);
    final timeText = _formatRibbonTime(dt);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[400],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dateText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        Positioned(
          right: -20,
          top: -16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[800],
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              timeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.lightBlue[400],
        child: Column(
          children: [
            Container(
              height: 100,
              padding: EdgeInsets.only(left: 16, top: 50),
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context).t('menu'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    Icons.home,
                    AppLocalizations.of(context).t('home'),
                    () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    Icons.flash_on,
                    AppLocalizations.of(context).t('check_predictions'),
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PredictionsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.settings,
                    AppLocalizations.of(context).t('settings'),
                    () {
                      Navigator.of(context).pop(); // Close the drawer
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.rule,
                    AppLocalizations.of(context).t('game_rules'),
                    () {
                      Navigator.of(context).pop(); // Close the drawer
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GameRulesScreen(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 40),
                  _buildDrawerItem(
                    Icons.logout,
                    AppLocalizations.of(context).t('log_out'),
                    () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('remember_email');
                      await prefs.remove('remember_password');

                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => AuthGate()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
    border: Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: ListTile(
    leading: Icon(icon, color: Colors.white, size: 28),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

class GameRulesScreen extends StatelessWidget {
  const GameRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).t('official_game_rules'),
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRuleText(
                      AppLocalizations.of(context).t('rules_intro_1'),
                    ),
                    SizedBox(height: 16),
                    _buildRuleText(
                      AppLocalizations.of(context).t('rules_intro_2'),
                    ),
                    SizedBox(height: 16),
                    _buildRuleText(
                      AppLocalizations.of(context).t('rules_intro_3'),
                    ),
                    SizedBox(height: 16),
                    _buildRuleText(
                      AppLocalizations.of(context).t('rules_intro_4'),
                    ),
                    SizedBox(height: 16),
                    _buildRuleText(
                      AppLocalizations.of(context).t('rules_prizes_intro'),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).t('prize1'),
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            AppLocalizations.of(context).t('prize2'),
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildRuleText(
                      AppLocalizations.of(context).t('rules_contact'),
                    ),
                    SizedBox(height: 30),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context).t('rules_disclaimer'),
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleText(String text) {
    return Text(text, style: TextStyle(fontSize: 16, height: 1.5));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('change_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).t('current_password')),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).t('new_password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).t('update')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: current.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(next.text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
  ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('password_updated'))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _changeLanguage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String selected = prefs.getString('language_code') ?? 'en';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setStateSB) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Wrap(
              children: [
                Text(
                  AppLocalizations.of(context).t('choose_language'),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlue),
                ),
                RadioListTile<String>(
                  value: 'en',
                  groupValue: selected,
                  onChanged: (v) => setStateSB(() => selected = v ?? 'en'),
                  title: Text(AppLocalizations.of(context).t('english'), style: TextStyle(color: Colors.lightBlue)),
                ),
                RadioListTile<String>(
                  value: 'fr',
                  groupValue: selected,
                  onChanged: (v) => setStateSB(() => selected = v ?? 'fr'),
                  title: Text(AppLocalizations.of(context).t('french'), style: TextStyle(color: Colors.lightBlue)),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      await prefs.setString('language_code', selected);
                      localeNotifier.setLanguageCode(selected);
                      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                    },
                    child: Text(AppLocalizations.of(context).t('save')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateEmail(BuildContext context) async {
    final currentPassword = TextEditingController();
    final newEmail = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('update_email')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newEmail,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).t('new_email')),
            ),
            TextField(
              controller: currentPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).t('current_password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).t('update')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updateEmail(newEmail.text.trim());
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
  ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('email_updated'))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final currentPassword = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('delete_account')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).t('irreversible_action')),
            TextField(
              controller: currentPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: AppLocalizations.of(context).t('confirm_password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).t('delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword.text,
      );
      await user.reauthenticateWithCredential(cred);
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final preds = await userRef.collection('predictions').get();
      for (final d in preds.docs) {
        await d.reference.delete();
      }
      await user.delete();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[400],
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/var6_logo.png',
          height: 56,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              AppLocalizations.of(context).t('image_not_found'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            );
          },
        ),
      ),
      body: Column(
        children: [
          _buildSettingsItem(
            Icons.image,
            AppLocalizations.of(context).t('test_teams_gallery'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeamsGalleryScreen()),
              );
            },
          ),
          _buildSettingsItem(
            Icons.vpn_key,
            AppLocalizations.of(context).t('change_password'),
            onTap: () => _changePassword(context),
          ),
          _buildSettingsItem(
            Icons.language,
            AppLocalizations.of(context).t('change_language'),
            onTap: () => _changeLanguage(context),
          ),
          _buildSettingsItem(
            Icons.email,
            AppLocalizations.of(context).t('update_email'),
            hasDropdown: true,
            onTap: () => _updateEmail(context),
          ),
          _buildSettingsItem(
            Icons.delete,
            AppLocalizations.of(context).t('delete_account'),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title, {
    bool hasDropdown = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24)),
        color: Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.lightBlue, size: 28),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            color: Colors.lightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: hasDropdown
            ? Icon(Icons.keyboard_arrow_down, color: Colors.lightBlue)
            : null,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
      ),
    );
  }
}

class TeamsGalleryScreen extends StatefulWidget {
  const TeamsGalleryScreen({super.key});

  @override
  State<TeamsGalleryScreen> createState() => _TeamsGalleryScreenState();
}

class _TeamsGalleryScreenState extends State<TeamsGalleryScreen> {
  late Future<List<String>> _pathsFuture;

  @override
  void initState() {
    super.initState();
    _pathsFuture = _loadClubAssets();
  }

  Future<List<String>> _loadClubAssets() async {
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> map = json.decode(manifest) as Map<String, dynamic>;
      final paths = map.keys
          .where((k) => k.startsWith('assets/logos/clubs/'))
          .toList()
        ..sort();
      return paths;
    } catch (_) {
      return const [];
    }
  }

  String _prettyName(String path) {
    final file = path.split('/').last;
    String name = file.replaceAll(
      RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false),
      '',
    );
    name = name.replaceAll('England__', '');
    name = name.replaceAll('_', ' ');
    // Capitalize words
    final parts = name.split(' ');
    name = parts.map((w) => w.isEmpty ? w : w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '')).join(' ');
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.blue),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Team Logos',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(text: 'Clubs'),
              Tab(text: 'Countries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Clubs grid
            FutureBuilder<List<String>>(
              future: _pathsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final paths = snap.data ?? const [];
                if (paths.isEmpty) {
                  return const Center(child: Text('No club assets found'));
                }
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: paths.length,
                    itemBuilder: (context, index) {
                      final p = paths[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: ClipOval(
                                child: Image.asset(
                                  p,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.red),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _prettyName(p),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // Countries flags grid
            _CountriesFlagsGrid(),
          ],
        ),
      ),
    );
  }
}

class _CountriesFlagsGrid extends StatelessWidget {
  _CountriesFlagsGrid();

  // ISO 3166-1 alpha2 for European countries commonly in UEFA competitions
  final List<Map<String, String>> countries = const [
    {'code': 'AL', 'name': 'Albania'},
    {'code': 'AD', 'name': 'Andorra'},
    {'code': 'AM', 'name': 'Armenia'},
    {'code': 'AT', 'name': 'Austria'},
    {'code': 'AZ', 'name': 'Azerbaijan'},
    {'code': 'BY', 'name': 'Belarus'},
    {'code': 'BE', 'name': 'Belgium'},
    {'code': 'BA', 'name': 'Bosnia & Herzegovina'},
    {'code': 'BG', 'name': 'Bulgaria'},
    {'code': 'HR', 'name': 'Croatia'},
    {'code': 'CY', 'name': 'Cyprus'},
    {'code': 'CZ', 'name': 'Czechia'},
    {'code': 'DK', 'name': 'Denmark'},
    {'code': 'EE', 'name': 'Estonia'},
    {'code': 'FI', 'name': 'Finland'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'GE', 'name': 'Georgia'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'GI', 'name': 'Gibraltar'},
    {'code': 'GR', 'name': 'Greece'},
    {'code': 'HU', 'name': 'Hungary'},
    {'code': 'IS', 'name': 'Iceland'},
    {'code': 'IE', 'name': 'Ireland'},
    {'code': 'IT', 'name': 'Italy'},
    {'code': 'KZ', 'name': 'Kazakhstan'},
    {'code': 'LV', 'name': 'Latvia'},
    {'code': 'LI', 'name': 'Liechtenstein'},
    {'code': 'LT', 'name': 'Lithuania'},
    {'code': 'LU', 'name': 'Luxembourg'},
    {'code': 'MT', 'name': 'Malta'},
    {'code': 'MD', 'name': 'Moldova'},
    {'code': 'MC', 'name': 'Monaco'},
    {'code': 'ME', 'name': 'Montenegro'},
    {'code': 'NL', 'name': 'Netherlands'},
    {'code': 'MK', 'name': 'North Macedonia'},
    {'code': 'NO', 'name': 'Norway'},
    {'code': 'PL', 'name': 'Poland'},
    {'code': 'PT', 'name': 'Portugal'},
    {'code': 'RO', 'name': 'Romania'},
    {'code': 'RU', 'name': 'Russia'},
    {'code': 'SM', 'name': 'San Marino'},
    {'code': 'RS', 'name': 'Serbia'},
    {'code': 'SK', 'name': 'Slovakia'},
    {'code': 'SI', 'name': 'Slovenia'},
    {'code': 'ES', 'name': 'Spain'},
    {'code': 'SE', 'name': 'Sweden'},
    {'code': 'CH', 'name': 'Switzerland'},
    {'code': 'TR', 'name': 'Türkiye'},
    {'code': 'UA', 'name': 'Ukraine'},
  {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'VA', 'name': 'Vatican City'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
        ),
        itemCount: countries.length,
        itemBuilder: (context, index) {
          final c = countries[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(builder: (context) {
                  // Normalize code to what the package expects
                  String code = c['code']!.toLowerCase();
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CountryFlag.fromCountryCode(
                      code,
                      width: 64,
                      height: 42,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  c['name']!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PredictionsScreen extends StatelessWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[400],
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/var6_logo.png',
          height: 80,
          errorBuilder: (context, error, stackTrace) {
            // ignore: avoid_print
            print('Header logo load failed: assets/var6_logo.png error=$error');
            return Text(
              AppLocalizations.of(context).t('image_not_found'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).t('check_submitted_predictions'),
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
            SizedBox(height: 8),
            Expanded(
              child: user == null
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context).t('not_signed_in'),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('predictions')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              AppLocalizations.of(context).t('no_predictions'),
                            ),
                          );
                        }

                        // Build groups by batchId if present; otherwise fallback to time-chunking
                        final docs = snapshot.data!.docs.toList();
                        final hasBatch = docs.any((d) => d.data().containsKey('batchId'));

                        late final List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> groups;
                        if (hasBatch) {
                          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> byBatch = {};
                          for (final d in docs) {
                            final bid = d.data()['batchId']?.toString() ?? 'legacy';
                            byBatch.putIfAbsent(bid, () => []).add(d);
                          }
                          // order groups by most recent submittedAt/createdAt desc
                          DateTime when(Map<String, dynamic> x) {
                            final sa = x['submittedAt'];
                            final ca = x['createdAt'];
                            if (sa is Timestamp) return sa.toDate().toUtc();
                            if (ca is Timestamp) return ca.toDate().toUtc();
                            return DateTime.fromMillisecondsSinceEpoch(0).toUtc();
                          }
                          final entries = byBatch.entries.toList()
                            ..sort((a, b) {
                              final aMax = a.value.map((d) => when(d.data())).fold<DateTime>(DateTime.fromMillisecondsSinceEpoch(0).toUtc(), (p, e) => e.isAfter(p) ? e : p);
                              final bMax = b.value.map((d) => when(d.data())).fold<DateTime>(DateTime.fromMillisecondsSinceEpoch(0).toUtc(), (p, e) => e.isAfter(p) ? e : p);
                              return bMax.compareTo(aMax);
                            });
                          groups = entries.map((e) {
                            final list = e.value;
                            list.sort((a, b) {
                              final ao = a.data()['batchOrder'];
                              final bo = b.data()['batchOrder'];
                              if (ao is int && bo is int) return ao.compareTo(bo);
                              final at = a.data()['lockAt'];
                              final bt = b.data()['lockAt'];
                              final ad = at is Timestamp ? at.toDate().toUtc() : DateTime.fromMillisecondsSinceEpoch(0).toUtc();
                              final bd = bt is Timestamp ? bt.toDate().toUtc() : DateTime.fromMillisecondsSinceEpoch(0).toUtc();
                              return ad.compareTo(bd);
                            });
                            return list;
                          }).toList();
                        } else {
                          // legacy: sort by time and chunk by 3
                          docs.sort((a, b) {
                            final at = a.data()['lockAt'];
                            final bt = b.data()['lockAt'];
                            final ad = at is Timestamp ? at.toDate().toUtc() : DateTime.fromMillisecondsSinceEpoch(0).toUtc();
                            final bd = bt is Timestamp ? bt.toDate().toUtc() : DateTime.fromMillisecondsSinceEpoch(0).toUtc();
                            return ad.compareTo(bd);
                          });
                          groups = <List<QueryDocumentSnapshot<Map<String, dynamic>>>>[];
                          for (var i = 0; i < docs.length; i += 3) {
                            groups.add(docs.sublist(i, (i + 3).clamp(0, docs.length)));
                          }
                        }

                        return ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, groupIndex) {
                            final group = groups[groupIndex];
                            // Show Edit only if this group's predictions are for today's UTC date
                            final nowUtc = DateTime.now().toUtc();
                            final todayUtcDate = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
                            bool isTodayGroup = true;
                            for (final doc in group) {
                              final ts = doc.data()['lockAt'];
                              if (ts is! Timestamp) { isTodayGroup = false; break; }
                              final d = ts.toDate().toUtc();
                              final dDate = DateTime.utc(d.year, d.month, d.day);
                              if (dDate != todayUtcDate) { isTodayGroup = false; break; }
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Blue header shows submit date and an Edit button
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlue[400],
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Builder(builder: (context) {
                                          // Use the first doc's submittedAt/createdAt as the group submit time
                                          final first = group.first.data();
                                          DateTime? ts;
                                          final sa = first['submittedAt'];
                                          final ca = first['createdAt'];
                                          if (sa is Timestamp) {
                                            ts = sa.toDate().toUtc();
                                          } else if (ca is Timestamp) ts = ca.toDate().toUtc();
                                          final label = ts != null
                                              ? DateFormat('EEE d MMM, HH:mm \'UTC\'').format(ts)
                                              : 'Submitted';
                                          return Text(
                                            label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                            ),
                                          );
                                        }),
                                        if (isTodayGroup)
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => HomeScreen()),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                            child: const Text('Edit'),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Inner list of 1..3 prediction rows
                                  ...group.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final p = entry.value.data();
                                    final String homeScore = '${p['homeScore']}';
                                    final String awayScore = '${p['awayScore']}';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: idx == 0 ? BorderSide.none : BorderSide(color: Colors.grey[200]!),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: _buildTeamColumn(
                                              p['homeTeamCode'] ?? 'H',
                                              p['homeTeam'] ?? 'Home',
                                              Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    homeScore,
                                                    style: TextStyle(
                                                      fontSize: 26,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text('v', style: TextStyle(fontSize: 24, color: Colors.blue[800], fontWeight: FontWeight.w900)),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    awayScore,
                                                    style: TextStyle(
                                                      fontSize: 26,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                                  const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Container(width: 14, height: 2, color: Colors.grey[400]),
                                                  const SizedBox(width: 32),
                                                  Container(width: 14, height: 2, color: Colors.grey[400]),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildTeamColumn(
                                              p['awayTeamCode'] ?? 'A',
                                              p['awayTeam'] ?? 'Away',
                                              Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String code, String name, Color color) {
    return Column(
      children: [
        TeamAvatar(teamCode: code, color: color),
  SizedBox(height: 4),
        Text(
          name.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
  // Score is shown centrally; omit per centered layout
      ],
    );
  }
}
