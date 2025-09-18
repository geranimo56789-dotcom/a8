import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/firebase_options.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Get Firestore instance
  final firestore = FirebaseFirestore.instance;

  // Sample matches data
  final matches = [
    {
      'homeTeam': 'Manchester United',
      'awayTeam': 'Arsenal',
      'homeScore': 2,
      'awayScore': 1,
      'time': '20:45',
      'date': 'Today',
      'league': 'Premier League',
      'homeTeamCode': 'MUN',
      'awayTeamCode': 'ARS',
      'timeUtc': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 1, hours: 20, minutes: 45)),
      ),
    },
    {
      'homeTeam': 'Chelsea',
      'awayTeam': 'Liverpool',
      'homeScore': 1,
      'awayScore': 1,
      'time': '22:00',
      'date': 'Today',
      'league': 'Premier League',
      'homeTeamCode': 'CHE',
      'awayTeamCode': 'LIV',
      'timeUtc': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 1, hours: 22, minutes: 0)),
      ),
    },
    {
      'homeTeam': 'Barcelona',
      'awayTeam': 'Real Madrid',
      'homeScore': 3,
      'awayScore': 2,
      'time': '21:30',
      'date': 'Tomorrow',
      'league': 'La Liga',
      'homeTeamCode': 'BAR',
      'awayTeamCode': 'RMA',
      'timeUtc': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 2, hours: 21, minutes: 30)),
      ),
    },
    {
      'homeTeam': 'Bayern Munich',
      'awayTeam': 'Borussia Dortmund',
      'homeScore': 2,
      'awayScore': 0,
      'time': '20:30',
      'date': 'Tomorrow',
      'league': 'Bundesliga',
      'homeTeamCode': 'BAY',
      'awayTeamCode': 'BVB',
      'timeUtc': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 2, hours: 20, minutes: 30)),
      ),
    },
    {
      'homeTeam': 'PSG',
      'awayTeam': 'Marseille',
      'homeScore': 4,
      'awayScore': 1,
      'time': '21:00',
      'date': 'Today',
      'league': 'Ligue 1',
      'homeTeamCode': 'PSG',
      'awayTeamCode': 'MAR',
      'timeUtc': Timestamp.fromDate(
        DateTime.now().add(Duration(days: 1, hours: 21, minutes: 0)),
      ),
    },
  ];

  try {
    // Add matches to Firestore
    for (final match in matches) {
      await firestore.collection('matches').add(match);
      print('Added match: ${match['homeTeam']} vs ${match['awayTeam']}');
    }

    print('\n✅ Successfully seeded Firestore with ${matches.length} matches!');
    print('\nMatches added:');
    for (final match in matches) {
      final timeUtc = (match['timeUtc'] as Timestamp).toDate();
      print(
        '- ${match['homeTeam']} vs ${match['awayTeam']} (${match['league']}) - ${timeUtc.toString()}',
      );
    }
  } catch (e) {
    print('❌ Error seeding Firestore: $e');
  }

  // Exit
  exit(0);
}
