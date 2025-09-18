import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'results_service.dart';

/// Distributed client-side daily winners job.
///
/// Coordination:
/// - Uses a Firestore lease document at winners_jobs/{YYYY-MM-DD} to ensure
///   only one client runs at a time. If a client dies mid-run, the lease
///   expires and another client can take over.
/// - Results (the winners list) are written to winners_archive/{YYYY-MM-DD}.
class WinnersService {
  WinnersService({FirebaseFirestore? firestore, ResultsService? resultsService})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _results = resultsService ?? ResultsService();

  final FirebaseFirestore _fs;
  final ResultsService _results;

  /// Attempt to run the winners job for the given UTC date.
  /// Safe to call many times across many clients; only the client that
  /// acquires the lease will perform work. Others will no-op.
  Future<JobOutcome> runDistributedDailyJobForDate(
    DateTime dateUtc, {
    required Set<String> allowedLeagues,
    String? ownerId,
    Duration leaseDuration = const Duration(minutes: 5),
  }) async {
    final day = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
    final key = _dateKey(day);
    final jobRef = _fs.collection('winners_jobs').doc(key);
    final now = DateTime.now().toUtc();
    final owner = ownerId ?? _deriveOwnerId();

    // Try to acquire or refresh a lease via transaction
    bool acquired = false;
    JobOutcome earlyOutcome = JobOutcome.noop(message: '');
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(jobRef);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();
        final leaseTs = data['leaseExpiresAt'];
        DateTime? leaseExpiry;
        if (leaseTs is Timestamp) leaseExpiry = leaseTs.toDate().toUtc();

        if (status == 'completed') {
          earlyOutcome = JobOutcome.alreadyCompleted(key);
          return;
        }
        if (status == 'running' && leaseExpiry != null && leaseExpiry.isAfter(now)) {
          earlyOutcome = JobOutcome.runningElsewhere(key);
          return;
        }
        // expired or pending -> take over
        final attempts = (data['attempts'] as int?) ?? 0;
        tx.set(jobRef, {
          'status': 'running',
          'leaseOwner': owner,
          'leaseExpiresAt': Timestamp.fromDate(now.add(leaseDuration)),
          'startedAt': data['startedAt'] ?? Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'attempts': attempts + 1,
          'date': key,
        }, SetOptions(merge: true));
        acquired = true;
      } else {
        tx.set(jobRef, {
          'status': 'running',
          'leaseOwner': owner,
          'leaseExpiresAt': Timestamp.fromDate(now.add(leaseDuration)),
          'startedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'attempts': 1,
          'date': key,
        });
        acquired = true;
      }
    });

    if (!acquired) {
      return earlyOutcome;
    }

    // We have the lease. Perform the job best-effort; always mark job doc.
    try {
      // 1) Ensure scores are updated for that day.
      await _results.updateScoresForDate(day, allowedLeagues: allowedLeagues);

      // 2) Load matches for the day and ensure we have at least 3 with scores.
      final dayStart = day;
      final dayEnd = dayStart.add(const Duration(days: 1));
      final matchesSnap = await _fs
          .collection('matches')
          .where('timeUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('timeUtc', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      // Build results map for allowed leagues
      final Map<String, Map<String, int>> resultsByMatchId = {};
      for (final d in matchesSnap.docs) {
        final data = d.data();
        final league = (data['league'] ?? '').toString();
        if (league.isEmpty || !allowedLeagues.contains(league)) continue;
        final hs = data['homeScore'];
        final as = data['awayScore'];
        if (hs is! num || as is! num) continue;
        resultsByMatchId[d.id] = {
          'home': hs.toInt(),
          'away': as.toInt(),
        };
      }

      if (resultsByMatchId.length < 3) {
        // Not all results in yet; leave job pending so another client can retry later.
        await jobRef.set({
          'status': 'pending',
          'pendingReason': 'results_incomplete',
          'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
          'leaseOwner': owner,
          'leaseExpiresAt': Timestamp.fromDate(DateTime.now().toUtc()),
        }, SetOptions(merge: true));
        return JobOutcome.pending(key, reason: 'results_incomplete');
      }

      // 3) Compute winners (3/3 exact) for that date across all users.
      final predsSnap = await _fs
          .collectionGroup('predictions')
          .where('lockAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('lockAt', isLessThan: Timestamp.fromDate(dayEnd))
          .get();

      final Map<String, int> correctByEmail = {};
      for (final doc in predsSnap.docs) {
        final data = doc.data();
        final matchId = (data['matchId'] ?? '').toString();
        final actual = resultsByMatchId[matchId];
        if (actual == null) continue; // only consider matches with final scores
        final predictedHome = (data['homeScore'] ?? 0) as num;
        final predictedAway = (data['awayScore'] ?? 0) as num;
        final ok = predictedHome.toInt() == actual['home'] && predictedAway.toInt() == actual['away'];
        if (!ok) continue;
        final email = (data['userEmail']?.toString().toLowerCase() ?? '').trim();
        final parent = doc.reference.parent.parent; // users/{uid}
        final uid = parent?.id ?? 'unknown';
        final keyEmail = email.isNotEmpty ? email : 'uid:$uid';
        correctByEmail[keyEmail] = (correctByEmail[keyEmail] ?? 0) + 1;
      }

      final Set<String> winners = <String>{};
      for (final e in correctByEmail.entries) {
        if (e.value >= 3) winners.add(e.key);
      }

      // 4) Write archive doc
      final archiveRef = _fs.collection('winners_archive').doc(key);
      final winnerList = winners.toList()..sort();
      await archiveRef.set({
        'date': key,
        'winners': winnerList,
        'winnerCount': winnerList.length,
        'matchCount': resultsByMatchId.length,
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'source': 'client',
      }, SetOptions(merge: true));

      // 5) Mark job as completed
      await jobRef.set({
        'status': 'completed',
        'finishedAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'leaseOwner': owner,
        'leaseExpiresAt': Timestamp.fromDate(DateTime.now().toUtc()),
        'winnerCount': winnerList.length,
      }, SetOptions(merge: true));

      return JobOutcome.completed(key, winners: winnerList.length);
    } catch (e) {
      await jobRef.set({
        'status': 'pending',
        'pendingReason': 'error',
        'lastError': e.toString(),
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      }, SetOptions(merge: true));
      return JobOutcome.failed(key, error: e.toString());
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _deriveOwnerId() {
    final u = FirebaseAuth.instance.currentUser;
    final uid = u?.uid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return uid != null ? 'uid:$uid@$ts' : 'anon@$ts';
  }
}

class JobOutcome {
  final String date;
  final String state; // completed | pending | running | noop
  final String? message;
  final int? winners;
  final String? error;

  const JobOutcome._(this.date, this.state, {this.message, this.winners, this.error});

  factory JobOutcome.completed(String date, {required int winners}) =>
      JobOutcome._(date, 'completed', winners: winners);
  factory JobOutcome.pending(String date, {String? reason}) =>
      JobOutcome._(date, 'pending', message: reason);
  factory JobOutcome.runningElsewhere(String date) =>
      JobOutcome._(date, 'running', message: 'another client holds lease');
  factory JobOutcome.alreadyCompleted(String date) =>
      JobOutcome._(date, 'noop', message: 'already completed');
  factory JobOutcome.noop({required String message}) =>
      JobOutcome._('', 'noop', message: message);
  factory JobOutcome.failed(String date, {required String error}) =>
      JobOutcome._(date, 'pending', error: error);
}
