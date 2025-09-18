// Run with: flutter run -d chrome -t scripts/simulate_triplet_today.dart
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

  final seeds = [
    {
      'id': '${todayUtc.toIso8601String().substring(0,10)}_ars_mci',
      'homeTeam': 'Arsenal', 'awayTeam': 'Manchester City', 'homeTeamCode': 'ars', 'awayTeamCode': 'mci',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(todayUtc.add(const Duration(hours: 12))),
      'matchDate': '${todayUtc.year}-${todayUtc.month.toString().padLeft(2,'0')}-${todayUtc.day.toString().padLeft(2,'0')}', 'time': '12:00',
    },
    {
      'id': '${todayUtc.toIso8601String().substring(0,10)}_che_liv',
      'homeTeam': 'Chelsea', 'awayTeam': 'Liverpool', 'homeTeamCode': 'che', 'awayTeamCode': 'liv',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(todayUtc.add(const Duration(hours: 15, minutes: 30))),
      'matchDate': '${todayUtc.year}-${todayUtc.month.toString().padLeft(2,'0')}-${todayUtc.day.toString().padLeft(2,'0')}', 'time': '15:30',
    },
    {
      'id': '${todayUtc.toIso8601String().substring(0,10)}_new_whu',
      'homeTeam': 'Newcastle United', 'awayTeam': 'West Ham United', 'homeTeamCode': 'new', 'awayTeamCode': 'whu',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(todayUtc.add(const Duration(hours: 18))),
      'matchDate': '${todayUtc.year}-${todayUtc.month.toString().padLeft(2,'0')}-${todayUtc.day.toString().padLeft(2,'0')}', 'time': '18:00',
    },
  ];

  // Clear any other today docs
  final snap = await fs.collection('matches')
    .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(todayUtc))
    .where('timeUtc', isLessThan: Timestamp.fromDate(todayUtc.add(const Duration(days: 1))))
    .get();
  for (final d in snap.docs) { await d.reference.delete(); }

  final batch = fs.batch();
  for (final m in seeds) {
    final id = m['id'] as String;
    batch.set(fs.collection('matches').doc(id), Map.of(m)..remove('id'));
  }
  await batch.commit();

  // ignore: avoid_print
  print('Seeded 3 matches for today.');
}
