import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final nowUtc = DateTime.now().toUtc();
  final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final dateStr = '${todayUtc.year.toString().padLeft(4, '0')}-${todayUtc.month.toString().padLeft(2, '0')}-${todayUtc.day.toString().padLeft(2, '0')}';
  final hour = '14:20';
  final id = '${dateStr}_sim_home_sim_away';

  String codeFor(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w.substring(0, 1))
      .take(3)
      .join();

  final docRef = FirebaseFirestore.instance.collection('matches').doc(id);
  await docRef.set({
    'homeTeam': 'Sim Home',
    'awayTeam': 'Sim Away',
    'homeTeamCode': codeFor('Sim Home'),
    'awayTeamCode': codeFor('Sim Away'),
    'league': 'Premier League',
    'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T$hour:00Z')),
    'time': hour,
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': 'admin',
    'matchDate': dateStr,
  });

  final get = await docRef.get();
  print('Wrote match ${get.id} exists=${get.exists} timeUtc=${get.data()!['timeUtc']}');
}
