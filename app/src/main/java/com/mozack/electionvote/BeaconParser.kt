package com.mozack.electionvote

/**
 * Parses the ESP32-C3 beacon payload (manufacturer data after the 2-byte company id):
 *   ver(1)=1 | beaconId(4,BE) | bootNonce(4) | counter(4,BE) | mac(8)
 * The app does NOT verify the MAC: it holds no key. It relays the fields to the backend, which does.
 */
data class BeaconClaim(val beaconId: Long, val bootNonce: String, val counter: Long, val mac: String) {
    fun toJson(): String =
        """{"beaconId":$beaconId,"bootNonce":"$bootNonce","counter":$counter,"mac":"$mac"}"""
}

object BeaconParser {
    const val COMPANY_ID = 0xFFFF
    const val PAYLOAD_LEN = 21

    fun parse(data: ByteArray?): BeaconClaim? {
        if (data == null || data.size != PAYLOAD_LEN || data[0].toInt() != 1) return null
        fun u32(off: Int): Long =
            ((data[off].toLong() and 0xFF) shl 24) or ((data[off + 1].toLong() and 0xFF) shl 16) or
                ((data[off + 2].toLong() and 0xFF) shl 8) or (data[off + 3].toLong() and 0xFF)
        fun hex(from: Int, len: Int) = (from until from + len).joinToString("") { "%02x".format(data[it]) }
        return BeaconClaim(beaconId = u32(1), bootNonce = hex(5, 4), counter = u32(9), mac = hex(13, 8))
    }
}
