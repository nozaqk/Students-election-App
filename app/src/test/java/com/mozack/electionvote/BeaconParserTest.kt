package com.mozack.electionvote

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BeaconParserTest {
    private fun bytes(vararg v: Int) = ByteArray(v.size) { v[it].toByte() }

    @Test fun parsesPayload() {
        // ver=1, beaconId=1, nonce=deadbeef, counter=7, mac=45c49bead11b97e7 (matches backend test vector)
        val p = bytes(1, 0, 0, 0, 1, 0xde, 0xad, 0xbe, 0xef, 0, 0, 0, 7, 0x45, 0xc4, 0x9b, 0xea, 0xd1, 0x1b, 0x97, 0xe7)
        val c = BeaconParser.parse(p)!!
        assertEquals(1L, c.beaconId); assertEquals("deadbeef", c.bootNonce); assertEquals(7L, c.counter); assertEquals("45c49bead11b97e7", c.mac)
    }

    @Test fun handlesUnsignedValues() {
        val p = bytes(1, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xfe, 1, 2, 3, 4, 5, 6, 7, 8)
        val c = BeaconParser.parse(p)!!
        assertEquals(4294967295L, c.beaconId); assertEquals(4294967294L, c.counter)
    }

    @Test fun rejectsBadInput() {
        assertNull(BeaconParser.parse(null))
        assertNull(BeaconParser.parse(ByteArray(20)))
        assertNull(BeaconParser.parse(bytes(2, *IntArray(20) { 0 })))
    }
}
