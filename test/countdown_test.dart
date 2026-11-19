import 'package:election_student/widgets/avatar.dart';
import 'package:election_student/widgets/countdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCountdown', () {
    test('pads hours, minutes and seconds', () {
      expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    });
    test('shows days only when non-zero', () {
      expect(formatCountdown(const Duration(days: 2, hours: 5)), '2d 05:00:00');
    });
    test('never goes negative', () {
      expect(formatCountdown(const Duration(seconds: -30)), '00:00:00');
    });
  });

  group('initialsOf', () {
    test('takes the first letter of up to two words', () {
      expect(initialsOf('Ama Serwaa Mensah'), 'AS');
      expect(initialsOf('kofi'), 'K');
      expect(initialsOf('  '), '');
    });
  });
}
