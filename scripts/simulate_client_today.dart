import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final nowUtc = DateTime.now().toUtc();
  final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
  final tomorrowUtc = todayUtc.add(const Duration(days: 1));

  final snap = await FirebaseFirestore.instance
      .collection('matches')
      .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(todayUtc))
      .where('timeUtc', isLessThan: Timestamp.fromDate(tomorrowUtc))
      .orderBy('timeUtc')
      .get();

  print('Today matches count: ${snap.docs.length}');
  for (final d in snap.docs) {
    final data = d.data();
    print(' - ${d.id}: ${data['homeTeam']} vs ${data['awayTeam']} at ${data['timeUtc']}');
  }
}
