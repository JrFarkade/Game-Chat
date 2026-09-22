import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0E1117);
  static const Color surface = Color(0xFF161B26);
  static const Color card = Color(0xFF212836);
  static const Color cardBorder = Color(0xFF2F384C);
  
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryHover = Color(0xFF651FFF);
  static const Color primaryGlow = Color(0x667C4DFF);

  static const Color greenActive = Color(0xFF00E676);
  static const Color greenGlow = Color(0x5500E676);
  
  static const Color redMuted = Color(0xFFFF5252);
  static const Color redGlow = Color(0x55FF5252);

  static const Color yellowWarning = Color(0xFFFFD600);
  
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

class AppConstants {
  // Default Cloudflare Worker URL (production edge backend)
  // Can be customized or overridden in Settings for local development
  static const String defaultServerUrl = 'https://game-chat.jrfarkade.workers.dev';
  static const String devLocalServerUrl = 'http://10.0.2.2:8787';

  // Cloudflare Anycast STUN + Google public STUN servers for WebRTC NAT traversal
  static const List<Map<String, dynamic>> defaultIceServers = [
    {'urls': 'stun:stun.cloudflare.com:3478'},
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
  ];

  static const String prefsUsernameKey = 'gamechat_saved_username';
  static const String prefsServerUrlKey = 'gamechat_server_url';
  static const String prefsPttEnabledKey = 'gamechat_ptt_enabled';
  static const String prefsEchoCancellationKey = 'gamechat_echo_cancel';
  static const String prefsNoiseSuppressionKey = 'gamechat_noise_suppress';
  static const String prefsAgcKey = 'gamechat_auto_gain';
}
