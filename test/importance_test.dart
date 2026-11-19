import 'package:election_student/api/models.dart';
import 'package:election_student/state/importance.dart';
import 'package:flutter_test/flutter_test.dart';

ElectionSummary _e(String id, String status) => ElectionSummary.fromJson({'id': id, 'title': id, 'status': status});

void main() {
  test('byImportance puts open voting first and withdrawn last', () {
    final sorted = byImportance([
      _e('pub', 'PUBLISHED'),
      _e('dead', 'DEACTIVATED'),
      _e('sched', 'SCHEDULED'),
      _e('active', 'ACTIVE'),
      _e('ended', 'ENDED'),
      _e('paused', 'PAUSED'),
    ]);
    expect(sorted.map((e) => e.id), ['active', 'paused', 'sched', 'ended', 'pub', 'dead']);
  });

  test('byImportance is stable within the same status', () {
    final sorted = byImportance([_e('a', 'ENDED'), _e('b', 'COUNTING'), _e('c', 'VERIFIED'), _e('d', 'FINALIZED')]);
    expect(sorted.map((e) => e.id), ['a', 'b', 'c', 'd']);
  });

  test('unknown statuses go to the end', () {
    final sorted = byImportance([_e('x', 'MYSTERY'), _e('y', 'DEACTIVATED')]);
    expect(sorted.map((e) => e.id), ['y', 'x']);
    expect(rankOf('MYSTERY'), 9);
  });
}
