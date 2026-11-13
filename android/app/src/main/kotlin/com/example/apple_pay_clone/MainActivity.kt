package com.example.apple_pay_clone

import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.wallet.pay/native"
    private var nfcAdapter: NfcAdapter? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // تفعيل حماية الشاشة ومنع التصوير أو التسجيل (FLAG_SECURE)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "activateHceToken" -> {
                    val token = call.argument<String>("token")
                    MyHostApduService.activePaymentToken = token
                    MyHostApduService.tokenExpiryMillis = System.currentTimeMillis() + 45_000L
                    result.success(true)
                }
                "deactivateHceToken" -> {
                    MyHostApduService.activePaymentToken = null
                    result.success(true)
                }
                "startMerchantReader" -> {
                    enableReaderMode()
                    result.success(true)
                }
                "stopMerchantReader" -> {
                    nfcAdapter?.disableReaderMode(this)
                    result.success(true)
                }
                "isNfcAvailable" -> {
                    result.success(nfcAdapter != null && nfcAdapter!!.isEnabled)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun enableReaderMode() {
        val flags = NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
        nfcAdapter?.enableReaderMode(this, { tag: Tag ->
            try {
                val isoDep = IsoDep.get(tag)
                isoDep?.connect()
                val selectApdu = byteArrayOf(
                    0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(),
                    0x07.toByte(), 0xF0.toByte(), 0x01.toByte(), 0x02.toByte(),
                    0x03.toByte(), 0x04.toByte(), 0x05.toByte(), 0x06.toByte(), 0x00.toByte()
                )
                val response = isoDep.transceive(selectApdu)
                isoDep.close()

                if (response.size > 2 &&
                    response[response.size - 2] == 0x90.toByte() &&
                    response[response.size - 1] == 0x00.toByte()
                ) {
                    val tokenBytes = response.copyOfRange(0, response.size - 2)
                    val token = String(tokenBytes, StandardCharsets.UTF_8)
                    runOnUiThread {
                        methodChannel?.invokeMethod("onNfcTokenReceived", token)
                    }
                }
            } catch (_: Exception) {
            }
        }, flags, null)
    }
}
