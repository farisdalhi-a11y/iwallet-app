package com.example.apple_pay_clone

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import java.nio.charset.StandardCharsets

class MyHostApduService : HostApduService() {

    companion object {
        // رمز الدفع المؤقت المشفر (يُفعل فقط بعد البصمة لمدة 45 ثانية)
        var activePaymentToken: String? = null
        var tokenExpiryMillis: Long = 0L

        private val SELECT_APDU_HEADER = byteArrayOf(
            0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(),
            0x07.toByte(), 0xF0.toByte(), 0x01.toByte(), 0x02.toByte(),
            0x03.toByte(), 0x04.toByte(), 0x05.toByte(), 0x06.toByte()
        )
        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val SW_SECURITY_ERROR = byteArrayOf(0x69.toByte(), 0x82.toByte())
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return SW_SECURITY_ERROR

        val isSelectAid = commandApdu.size >= SELECT_APDU_HEADER.size &&
                SELECT_APDU_HEADER.indices.all { commandApdu[it] == SELECT_APDU_HEADER[it] }

        if (isSelectAid) {
            val token = activePaymentToken
            if (token != null && System.currentTimeMillis() < tokenExpiryMillis) {
                // مسح الرمز فوراً بعد الإرسال لمنع إعادة الاستخدام (Replay Attack)
                activePaymentToken = null
                val payload = token.toByteArray(StandardCharsets.UTF_8)
                return payload + SW_OK
            }
        }
        return SW_SECURITY_ERROR
    }

    override fun onDeactivated(reason: Int) {
        activePaymentToken = null
    }
}
