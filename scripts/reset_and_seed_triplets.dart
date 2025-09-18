// Run with: flutter run -d chrome -t scripts/reset_and_seed_triplets.dart
// Purges all matches and all users' predictions, then seeds 3 yesterday and 3 today matches.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final fs = FirebaseFirestore.instance;

  // 1) Delete all predictions for all users
  final users = await fs.collection('users').get();
  for (final u in users.docs) {
    final preds = await fs.collection('users').doc(u.id).collection('predictions').get();
    for (final p in preds.docs) {
      await p.reference.delete();
    }
  }

  // 2) Delete all matches
  final matches = await fs.collection('matches').get();
  for (final m in matches.docs) {
    await m.reference.delete();
  }

  // 3) Seed 3 yesterday + 3 today
  final now = DateTime.now().toUtc();
  final todayUtc = DateTime.utc(now.year, now.month, now.day);
  final yesterdayUtc = todayUtc.subtract(const Duration(days: 1));

  List<Map<String, dynamic>> seeds = [
    // Yesterday
    {
      'id': '${yesterdayUtc.toIso8601String().substring(0,10)}_eve_ful',
      'homeTeam': 'Everton', 'awayTeam': 'Fulham', 'homeTeamCode': 'eve', 'awayTeamCode': 'ful',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(yesterdayUtc.add(const Duration(hours: 14))),
      'status': 'completed', 'homeScore': 2, 'awayScore': 1, 'matchDate': _d(yesterdayUtc), 'time': '14:00',
    },
    {
  'id': '${yesterdayUtc.toIso8601String().substring(0,10)}_bre_lei',
  'homeTeam': 'Brentford', 'awayTeam': 'Leicester City', 'homeTeamCode': 'bre', 'awayTeamCode': 'lei',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(yesterdayUtc.add(const Duration(hours: 16))),
      'status': 'completed', 'homeScore': 0, 'awayScore': 0, 'matchDate': _d(yesterdayUtc), 'time': '16:00',
    },
    {
      'id': '${yesterdayUtc.toIso8601String().substring(0,10)}_tot_mun',
      'homeTeam': 'Tottenham Hotspur', 'awayTeam': 'Manchester United', 'homeTeamCode': 'tot', 'awayTeamCode': 'mun',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(yesterdayUtc.add(const Duration(hours: 18))),
      'status': 'completed', 'homeScore': 3, 'awayScore': 2, 'matchDate': _d(yesterdayUtc), 'time': '18:00',
    },
    // Today
    {
      'id': '${todayUtc.toIso8601String().substring(0,10)}_ars_mci',
      'homeTeam': 'Arsenal', 'awayTeam': 'Manchester City', 'homeTeamCode': 'ars', 'awayTeamCode': 'mci',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(todayUtc.add(const Duration(hours: 12))),
      'matchDate': _d(todayUtc), 'time': '12:00',
    },
    {
      'id': '${todayUtc.toIso8601String().substring(0,10)}_che_liv',
      'homeTeam': 'Chelsea', 'awayTeam': 'Liverpool', 'homeTeamCode': 'che', 'awayTeamCode': 'liv',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(todayUtc.add(const Duration(hours: 15, minutes: 30))),
      'matchDate': _d(todayUtc), 'time': '15:30',
    },
    {
      'id': '${todayUtc.toIso8601String().substring(0,10)}_new_whu',
      'homeTeam': 'Newcastle United', 'awayTeam': 'West Ham United', 'homeTeamCode': 'new', 'awayTeamCode': 'whu',
      'league': 'Premier League',
      'timeUtc': Timestamp.fromDate(todayUtc.add(const Duration(hours: 18))),
      'matchDate': _d(todayUtc), 'time': '18:00',
    },
  ];

  final batch = fs.batch();
  for (final m in seeds) {
    final id = m['id'] as String;
    batch.set(fs.collection('matches').doc(id), Map.of(m)..remove('id'));
  }
  await batch.commit();

  // ignore: avoid_print
  print('Reset complete. Seeded 3 yesterday matches and 3 today matches.');
}

String _d(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
