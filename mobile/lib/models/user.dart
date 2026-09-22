class UserPeer {
  final String socketId; // Unique participant connection ID
  String username;
  bool isHost;
  bool isMuted;
  bool isDeafened;
  bool isSpeaking;
  String? callsSessionId;
  String? callsAudioTrackName;

  // Local user settings for this specific peer
  double volume; // 0.0 to 1.0 (local volume slider)
  bool isLocallyMuted;

  UserPeer({
    required this.socketId,
    required this.username,
    this.isHost = false,
    this.isMuted = false,
    this.isDeafened = false,
    this.isSpeaking = false,
    this.callsSessionId,
    this.callsAudioTrackName,
    this.volume = 1.0,
    this.isLocallyMuted = false,
  });

  factory UserPeer.fromJson(Map<String, dynamic> json) {
    return UserPeer(
      socketId: (json['socketId'] ?? json['id'] ?? '').toString(),
      username: json['username'] ?? 'Player',
      isHost: json['isHost'] ?? false,
      isMuted: json['isMuted'] ?? false,
      isDeafened: json['isDeafened'] ?? false,
      isSpeaking: json['isSpeaking'] ?? false,
      callsSessionId: json['callsSessionId'],
      callsAudioTrackName: json['callsAudioTrackName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'socketId': socketId,
      'username': username,
      'isHost': isHost,
      'isMuted': isMuted,
      'isDeafened': isDeafened,
      'isSpeaking': isSpeaking,
      'callsSessionId': callsSessionId,
      'callsAudioTrackName': callsAudioTrackName,
    };
  }
}

