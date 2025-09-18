// Run with: flutter run -d chrome -t scripts/simulate_triplet_yesterday.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final fs = FirebaseFirestore.instance;

  final now = DateTime.now().toUtc();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  final yesterdayUtc = todayUtc.subtract(const Duration(days: 1));

  final seeds = [
    {
      'id': '${yesterdayUtc.toIso8601String().substring(0,10)}_eve_ful',
      'homeTeam': 'Everton', 'awayTeam': 'Fulham', 'homeTeamCode': 'eve', 'awayTeamCode': 'ful',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(yesterdayUtc.add(const Duration(hours: 14))),
      'status': 'completed', 'homeScore': 2, 'awayScore': 1, 'matchDate': '${yesterdayUtc.year}-${yesterdayUtc.month.toString().padLeft(2,'0')}-${yesterdayUtc.day.toString().padLeft(2,'0')}', 'time': '14:00',
    },
    {
  'id': '${yesterdayUtc.toIso8601String().substring(0,10)}_bre_lei',
  'homeTeam': 'Brentford', 'awayTeam': 'Leicester City', 'homeTeamCode': 'bre', 'awayTeamCode': 'lei',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(yesterdayUtc.add(const Duration(hours: 16))),
      'status': 'completed', 'homeScore': 0, 'awayScore': 0, 'matchDate': '${yesterdayUtc.year}-${yesterdayUtc.month.toString().padLeft(2,'0')}-${yesterdayUtc.day.toString().padLeft(2,'0')}', 'time': '16:00',
    },
    {
      'id': '${yesterdayUtc.toIso8601String().substring(0,10)}_tot_mun',
      'homeTeam': 'Tottenham Hotspur', 'awayTeam': 'Manchester United', 'homeTeamCode': 'tot', 'awayTeamCode': 'mun',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(yesterdayUtc.add(const Duration(hours: 18))),
      'status': 'completed', 'homeScore': 3, 'awayScore': 2, 'matchDate': '${yesterdayUtc.year}-${yesterdayUtc.month.toString().padLeft(2,'0')}-${yesterdayUtc.day.toString().padLeft(2,'0')}', 'time': '18:00',
    },
  ];

  // Clear any other yesterday docs
  final snap = await fs.collection('matches')
    .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayUtc))
    .where('timeUtc', isLessThan: Timestamp.fromDate(todayUtc))
    .get();
  for (final d in snap.docs) { await d.reference.delete(); }

  final batch = fs.batch();
  for (final m in seeds) {
    final id = m['id'] as String;
    batch.set(fs.collection('matches').doc(id), Map.of(m)..remove('id'));
  }
  await batch.commit();

  // ignore: avoid_print
  print('Seeded 3 matches for yesterday.');
}
