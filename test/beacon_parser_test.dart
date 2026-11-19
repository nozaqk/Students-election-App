import 'package:election_student/native/beacon_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeaconParser', () {
    test('parses the ESP32 payload', () {
      // ver=1, beaconId=1, nonce=deadbeef, counter=7, mac=45c49bead11b97e7 (matches backend test vector)
      final p = [1, 0, 0, 0, 1, 0xde, 0xad, 0xbe, 0xef, 0, 0, 0, 7, 0x45, 0xc4, 0x9b, 0xea, 0xd1, 0x1b, 0x97, 0xe7];
      final c = BeaconParser.parse(p);
      expect(c, isNotNull);
      expect(c!.beaconId, 1);
      expect(c.bootNonce, 'deadbeef');
      expect(c.counter, 7);
      expect(c.mac, '45c49bead11b97e7');
      expect(c.toJson(), {'beaconId': 1, 'bootNonce': 'deadbeef', 'counter': 7, 'mac': '45c49bead11b97e7'});
    });

    test('handles unsigned 32-bit values', () {
      final p = [1, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xfe, 1, 2, 3, 4, 5, 6, 7, 8];
      final c = BeaconParser.parse(p)!;
      expect(c.beaconId, 4294967295);
      expect(c.counter, 4294967294);
      expect(c.bootNonce, '00000000');
      expect(c.mac, '0102030405060708');
    });

    test('rejects bad input', () {
      expect(BeaconParser.parse(null), isNull);
      expect(BeaconParser.parse(List<int>.filled(20, 0)), isNull);
      expect(BeaconParser.parse(List<int>.filled(22, 0)), isNull);
      expect(BeaconParser.parse([2, ...List<int>.filled(20, 0)]), isNull);
    });

    test('claims compare by value', () {
      const a = BeaconClaim(beaconId: 1, bootNonce: 'aa', counter: 2, mac: 'bb');
      const b = BeaconClaim(beaconId: 1, bootNonce: 'aa', counter: 2, mac: 'bb');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
