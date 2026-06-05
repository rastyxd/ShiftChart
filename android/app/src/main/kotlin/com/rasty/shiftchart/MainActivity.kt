package com.rasty.shiftchart

import android.media.RingtoneManager
import android.media.Ringtone
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.rasty.shiftchart/ringtones"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRingtones" -> {
                    val ringtones = getRingtones()
                    result.success(ringtones)
                }
                "playRingtone" -> {
                    val uriString = call.argument<String>("uri")
                    playRingtone(uriString)
                    result.success(null)
                }
                "stopRingtone" -> {
                    stopRingtone()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private var currentRingtone: android.media.Ringtone? = null

    private fun getRingtones(): List<Map<String, String>> {
        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_NOTIFICATION)
        val cursor = manager.cursor
        val list = mutableListOf<Map<String, String>>()
        while (cursor.moveToNext()) {
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
            val uri = manager.getRingtoneUri(cursor.position).toString()
            list.add(mapOf("title" to title, "uri" to uri))
        }
        return list
    }

    private fun playRingtone(uriString: String?) {
        stopRingtone()
        if (uriString == null) return

        val uri: Uri = if (uriString.startsWith("content://")) {
            Uri.parse(uriString)
        } else {
            // It's a raw resource
            val resId = this.resources.getIdentifier(uriString, "raw", this.packageName)
            if (resId == 0) return
            Uri.parse("android.resource://" + this.packageName + "/" + resId)
        }

        currentRingtone = RingtoneManager.getRingtone(this, uri)
        currentRingtone?.play()
    }

    private fun stopRingtone() {
        currentRingtone?.stop()
        currentRingtone = null
    }

    override fun onPause() {
        super.onPause()
        stopRingtone()
    }
}
