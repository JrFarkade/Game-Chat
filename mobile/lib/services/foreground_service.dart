import 'dart:io';
import 'package:flutter/services.dart';

/// Service that interacts with the native Android Kotlin VoiceForegroundService.
/// Keeps the microphone and real-time audio pipeline alive when GameChat is minimized
/// and the user is playing another mobile game.
class ForegroundService {
  static const MethodChannel _channel = MethodChannel('com.gamechat.talk/foreground_service');
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// Starts the Android native foreground service with sticky notification
  static Future<void> start({
    required String roomCode,
    required String username,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startVoiceService', {
        'roomCode': roomCode,
        'username': username,
      });
      _isRunning = true;
    } catch (e) {
      print('[ForegroundService] Error starting service: $e');
    }
  }

  /// Stops the Android native foreground service and releases wake/wifi locks
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopVoiceService');
      _isRunning = false;
    } catch (e) {
      print('[ForegroundService] Error stopping service: $e');
    }
  }

  /// Updates current room code shown in notification
  static Future<void> updateRoom(String roomCode) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateRoomInfo', {
        'roomCode': roomCode,
      });
    } catch (e) {
      print('[ForegroundService] Error updating room: $e');
    }
  }
}
