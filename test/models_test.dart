import 'package:election_student/api/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ElectionDetail parses nested positions and tolerates missing fields', () {
    final d = ElectionDetail.fromJson({
      'id': 'e1',
      'title': 'SRC Elections',
      'status': 'ACTIVE',
      'startAt': '2026-03-01T08:00:00.000Z',
      'requirePresence': true,
      'canVote': 'true',
      'ui': {'state': 'OPEN', 'headline': 'Voting open', 'body': 'Until 5pm'},
      'serverTime': '2026-03-01T09:00:00.000Z',
      'positions': [
        {
          'id': 'p1',
          'title': 'President',
          'maxSelections': 1,
          'allowAbstain': true,
          'candidates': [
            {'id': 'c1', 'name': 'Ama', 'number': 1, 'manifesto': 'Hi'},
            {'id': 'c2', 'name': 'Kofi', 'number': '2'},
          ],
        },
        {'id': 'p2', 'title': 'Senate', 'maxSelections': 0},
      ],
    });
    expect(d.isActive, isTrue);
    expect(d.requirePresence, isTrue);
    expect(d.canVote, isTrue);
    expect(d.hasVoted, isFalse);
    expect(d.startAt, DateTime.utc(2026, 3, 1, 8));
    expect(d.endAt, isNull);
    expect(d.description, '');
    expect(d.positions, hasLength(2));
    expect(d.positions.first.candidates.map((c) => c.number), [1, 2]);
    expect(d.positions.first.candidates.last.manifesto, '');
    expect(d.positions.last.maxSelections, 1, reason: 'a position always allows at least one choice');
    expect(d.positions.last.candidates, isEmpty);
  });

  test('Results computes vote share safely', () {
    final r = Results.fromJson({
      'id': 'e1',
      'title': 'T',
      'status': 'PUBLISHED',
      'turnout': 10,
      'results': [
        {
          'positionId': 'p1',
          'title': 'President',
          'totalVotes': 0,
          'candidates': [
            {'candidateId': 'c1', 'name': 'A', 'number': 1, 'votes': 0},
          ],
        },
        {
          'positionId': 'p2',
          'title': 'Secretary',
          'totalVotes': 8,
          'tie': true,
          'candidates': [
            {'candidateId': 'c2', 'name': 'B', 'number': 2, 'votes': 6, 'winner': true},
          ],
        },
      ],
    });
    expect(r.results.first.share(r.results.first.candidates.first), 0);
    expect(r.results.last.share(r.results.last.candidates.first), 0.75);
    expect(r.results.last.tie, isTrue);
    expect(r.publishedLabel, isNull);
  });

  test('PositionChoice serialises abstentions without candidates', () {
    expect(const PositionChoice(candidateIds: ['a'], abstain: true).toJson('p'), {
      'positionId': 'p',
      'candidateIds': <String>[],
      'abstain': true,
    });
    expect(const PositionChoice().complete, isFalse);
    expect(const PositionChoice(candidateIds: ['a']).complete, isTrue);
  });

  test('Me parses optional semester', () {
    final me = Me.fromJson({'indexNumber': 'UG1', 'fullName': 'Ama', 'department': 'CS', 'programme': 'BSc', 'level': 300});
    expect(me.semester, isNull);
    expect(me.level, 300);
  });
}
