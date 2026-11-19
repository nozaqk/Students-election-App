import 'package:election_student/api/models.dart';
import 'package:election_student/theme/app_theme.dart';
import 'package:election_student/widgets/common.dart';
import 'package:election_student/widgets/election_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('ElectionCard shows Vote Now for a votable election', (tester) async {
    final e = ElectionSummary.fromJson({
      'id': 'e1',
      'title': 'SRC Elections',
      'status': 'ACTIVE',
      'canVote': true,
      'ui': {'state': 'OPEN', 'headline': 'Voting is open', 'body': 'Closes at 5pm'},
    });
    var opened = 0;
    await tester.pumpWidget(_wrap(ElectionCard(election: e, skew: Duration.zero, onOpen: () => opened++)));
    expect(find.text('SRC Elections'), findsOneWidget);
    expect(find.text('VOTING OPEN'), findsOneWidget);
    expect(find.text('Voting is open'), findsOneWidget);
    expect(find.text('Vote Now'), findsOneWidget);
    await tester.tap(find.text('Vote Now'));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ElectionCard shows a countdown and the voted notice', (tester) async {
    final e = ElectionSummary.fromJson({
      'id': 'e2',
      'title': 'Hall Elections',
      'status': 'SCHEDULED',
      'hasVoted': true,
      'startAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'ui': {'state': 'SOON', 'headline': 'Opens soon', 'body': ''},
    });
    await tester.pumpWidget(_wrap(ElectionCard(election: e, skew: Duration.zero, onOpen: () {})));
    expect(find.text('Voting opens in'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^01:5\d:\d\d$')), findsOneWidget);
    expect(find.text('✓ You have voted in this election.'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.text('SCHEDULED'), findsOneWidget);
    // Dispose the card so its ticking countdown timer is cancelled.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('AppButton is disabled while busy', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(AppButton('Go', busy: true, onPressed: () => taps++)));
    await tester.tap(find.text('Go'));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
