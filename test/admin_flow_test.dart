import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// This test simulates the admin creating a match and verifies it is persisted
/// and then appears in the Today’s Matches query shape used by HomeScreen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin flow -> Firestore -> Client today list', () {
    late FakeFirebaseFirestore fake;
    setUp(() async {
      fake = FakeFirebaseFirestore();
    });

    test('admin creates match and it exists in Firestore', () async {
      final nowUtc = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final hour = '15:45';
      final dateStr = '${todayUtc.year.toString().padLeft(4, '0')}-${todayUtc.month.toString().padLeft(2, '0')}-${todayUtc.day.toString().padLeft(2, '0')}';
      final id = '${dateStr}_test_home_test_away';

      // Simulate AdminPanel._teamCode behavior in a simple way
      String codeFor(String name) {
        final s = name.toLowerCase();
        return s.substring(0, s.length >= 3 ? 3 : s.length);
      }

  final docRef = fake.collection('matches').doc(id);

      // Write (admin submit)
      await docRef.set({
        'homeTeam': 'Test Home',
        'awayTeam': 'Test Away',
        'homeTeamCode': codeFor('Test Home'),
        'awayTeamCode': codeFor('Test Away'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T$hour:00Z')),
        'time': hour,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
        'matchDate': dateStr,
      });

      // Verify existence
      final written = await docRef.get();
      expect(written.exists, true);
      expect(written.data()!['homeTeam'], 'Test Home');
      expect(written.data()!['awayTeam'], 'Test Away');
    });

    test('client todaysMatches returns exactly 3', () async {
      final nowUtc = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final dateStr = '${todayUtc.year.toString().padLeft(4, '0')}-${todayUtc.month.toString().padLeft(2, '0')}-${todayUtc.day.toString().padLeft(2, '0')}';

      String codeFor(String name) {
        final s = name.toLowerCase();
        return s.substring(0, s.length >= 3 ? 3 : s.length);
      }

      // Seed today's triplet
      await fake.collection('matches').doc('${dateStr}_a_b').set({
        'homeTeam': 'Test Home',
        'awayTeam': 'Test Away',
        'homeTeamCode': codeFor('Test Home'),
        'awayTeamCode': codeFor('Test Away'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T13:00:00Z')),
        'time': '13:00',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
        'matchDate': dateStr,
      });
      await fake.collection('matches').doc('${dateStr}_c_d').set({
        'homeTeam': 'C', 'awayTeam': 'D', 'homeTeamCode': codeFor('C'), 'awayTeamCode': codeFor('D'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T15:30:00Z')),
        'time': '15:30', 'createdAt': FieldValue.serverTimestamp(), 'createdBy': 'admin', 'matchDate': dateStr,
      });
      await fake.collection('matches').doc('${dateStr}_e_f').set({
        'homeTeam': 'E', 'awayTeam': 'F', 'homeTeamCode': codeFor('E'), 'awayTeamCode': codeFor('F'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T18:00:00Z')),
        'time': '18:00', 'createdAt': FieldValue.serverTimestamp(), 'createdBy': 'admin', 'matchDate': dateStr,
      });

      final tomorrowUtc = todayUtc.add(const Duration(days: 1));

      // Query similar to HomeScreen (subset for today only)
  final snap = await fake
          .collection('matches')
          .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(todayUtc))
          .where('timeUtc', isLessThan: Timestamp.fromDate(tomorrowUtc))
          .orderBy('timeUtc')
          .get();

      expect(snap.docs.length, 3);
    });

    test('yesterdaysMatches returns exactly 3', () async {
      final nowUtc = DateTime.now().toUtc();
      final todayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final yesterdayUtc = todayUtc.subtract(const Duration(days: 1));
      final dateStr = '${yesterdayUtc.year.toString().padLeft(4, '0')}-${yesterdayUtc.month.toString().padLeft(2, '0')}-${yesterdayUtc.day.toString().padLeft(2, '0')}';

      String codeFor(String name) {
        final s = name.toLowerCase();
        return s.substring(0, s.length >= 3 ? 3 : s.length);
      }
      await fake.collection('matches').doc('${dateStr}_g_h').set({
        'homeTeam': 'G', 'awayTeam': 'H', 'homeTeamCode': codeFor('G'), 'awayTeamCode': codeFor('H'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T14:00:00Z')),
        'time': '14:00', 'createdAt': FieldValue.serverTimestamp(), 'createdBy': 'admin', 'matchDate': dateStr,
      });
      await fake.collection('matches').doc('${dateStr}_i_j').set({
        'homeTeam': 'I', 'awayTeam': 'J', 'homeTeamCode': codeFor('I'), 'awayTeamCode': codeFor('J'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T16:00:00Z')),
        'time': '16:00', 'createdAt': FieldValue.serverTimestamp(), 'createdBy': 'admin', 'matchDate': dateStr,
      });
      await fake.collection('matches').doc('${dateStr}_k_l').set({
        'homeTeam': 'K', 'awayTeam': 'L', 'homeTeamCode': codeFor('K'), 'awayTeamCode': codeFor('L'),
        'league': 'Premier League',
        'timeUtc': Timestamp.fromDate(DateTime.parse('${dateStr}T18:00:00Z')),
        'time': '18:00', 'createdAt': FieldValue.serverTimestamp(), 'createdBy': 'admin', 'matchDate': dateStr,
      });

      final snap = await fake
          .collection('matches')
          .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayUtc))
          .where('timeUtc', isLessThan: Timestamp.fromDate(todayUtc))
          .orderBy('timeUtc')
          .get();

      expect(snap.docs.length, 3);
    });
  });
}
