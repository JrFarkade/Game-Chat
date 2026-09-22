package com.gamechat.talk

import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.gamechat.talk/foreground_service"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceService" -> {
                    val roomCode = call.argument<String>("roomCode") ?: "Active"
                    val username = call.argument<String>("username") ?: "Player"
                    startVoiceForegroundService(roomCode, username)
                    result.success(true)
                }
                "stopVoiceService" -> {
                    stopVoiceForegroundService()
                    result.success(true)
                }
                "updateRoomInfo" -> {
                    val roomCode = call.argument<String>("roomCode") ?: "Active"
                    updateServiceRoomInfo(roomCode)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startVoiceForegroundService(roomCode: String, username: String) {
        val intent = Intent(this, VoiceForegroundService::class.java).apply {
            action = VoiceForegroundService.ACTION_START
            putExtra(VoiceForegroundService.EXTRA_ROOM_CODE, roomCode)
            putExtra(VoiceForegroundService.EXTRA_USERNAME, username)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopVoiceForegroundService() {
        val intent = Intent(this, VoiceForegroundService::class.java).apply {
            action = VoiceForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun updateServiceRoomInfo(roomCode: String) {
        val intent = Intent(this, VoiceForegroundService::class.java).apply {
            action = VoiceForegroundService.ACTION_UPDATE_ROOM
            putExtra(VoiceForegroundService.EXTRA_ROOM_CODE, roomCode)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
