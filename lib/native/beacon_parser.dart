/// A polling-node beacon as seen by the phone.
///
/// The app does NOT verify the beacon: it holds no key. It relays the fields to the backend,
/// which checks the MAC, the boot nonce and the counter before issuing a voting authorisation.
class BeaconClaim {
  const BeaconClaim({
    required this.beaconId,
    required this.bootNonce,
    required this.counter,
    required this.mac,
  });

  final int beaconId;
  final String bootNonce;
  final int counter;
  final String mac;

  Map<String, dynamic> toJson() => {
        'beaconId': beaconId,
        'bootNonce': bootNonce,
        'counter': counter,
        'mac': mac,
      };

  @override
  bool operator ==(Object other) =>
      other is BeaconClaim &&
      other.beaconId == beaconId &&
      other.bootNonce == bootNonce &&
      other.counter == counter &&
      other.mac == mac;

  @override
  int get hashCode => Object.hash(beaconId, bootNonce, counter, mac);

  @override
  String toString() => 'BeaconClaim(#$beaconId nonce=$bootNonce counter=$counter)';
}

/// Parses the ESP32-C3 beacon payload (manufacturer data after the 2-byte company id):
///
/// `ver(1)=1 | beaconId(4,BE) | bootNonce(4) | counter(4,BE) | mac(8)`
abstract class BeaconParser {
  /// Bluetooth SIG "test" company identifier used by the polling nodes.
  static const int companyId = 0xFFFF;
  static const int payloadLength = 21;
  static const int version = 1;

  static BeaconClaim? parse(List<int>? data) {
    if (data == null || data.length != payloadLength || (data[0] & 0xFF) != version) return null;

    int u32(int off) =>
        ((data[off] & 0xFF) << 24) |
        ((data[off + 1] & 0xFF) << 16) |
        ((data[off + 2] & 0xFF) << 8) |
        (data[off + 3] & 0xFF);

    String hex(int from, int len) => [
          for (var i = from; i < from + len; i++) (data[i] & 0xFF).toRadixString(16).padLeft(2, '0'),
        ].join();

    return BeaconClaim(
      beaconId: u32(1),
      bootNonce: hex(5, 4),
      counter: u32(9),
      mac: hex(13, 8),
    );
  }
}
