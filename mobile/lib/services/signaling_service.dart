import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../utils/constants.dart';

enum SignalingStatus { disconnected, connecting, connected, reconnecting, error }

class SignalingService extends ChangeNotifier {
  WebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  SignalingStatus _status = SignalingStatus.disconnected;
  String _serverUrl = AppConstants.defaultServerUrl;
  String? _currentRoomCode;
  String? _currentUsername;
  String? _socketId;
  bool _isHost = false;
  bool _isServerOnline = false;
  List<Map<String, dynamic>> _iceServers = List.from(AppConstants.defaultIceServers);

  Completer<List<UserPeer>>? _joinCompleter;

  // Stream controllers for real-time events
  final _onOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _onAnswerController = StreamController<Map<String, dynamic>>.broadcast();
  final _onCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  final _onUserJoinedController = StreamController<UserPeer>.broadcast();
  final _onUserLeftController = StreamController<String>.broadcast();
  final _onUserStateChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onUserSpeakingChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onSoundboardPlayedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onSoundboardSyncedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onCallsTrackUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _onKickedController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onOffer => _onOfferController.stream;
  Stream<Map<String, dynamic>> get onAnswer => _onAnswerController.stream;
  Stream<Map<String, dynamic>> get onCandidate => _onCandidateController.stream;
  Stream<UserPeer> get onUserJoined => _onUserJoinedController.stream;
  Stream<String> get onUserLeft => _onUserLeftController.stream;
  Stream<Map<String, dynamic>> get onUserStateChanged => _onUserStateChangedController.stream;
  Stream<Map<String, dynamic>> get onUserSpeakingChanged => _onUserSpeakingChangedController.stream;
  Stream<Map<String, dynamic>> get onSoundboardPlayed => _onSoundboardPlayedController.stream;
  Stream<Map<String, dynamic>> get onSoundboardSynced => _onSoundboardSyncedController.stream;
  Stream<Map<String, dynamic>> get onCallsTrackUpdated => _onCallsTrackUpdatedController.stream;
  Stream<String> get onKicked => _onKickedController.stream;

  SignalingStatus get status => _status;
  String get serverUrl => _serverUrl;
  String? get socketId => _socketId;
  String? get currentRoomCode => _currentRoomCode;
  bool get isHost => _isHost;
  bool get isConnected => _status == SignalingStatus.connected || (_isServerOnline && _currentRoomCode == null);
  List<Map<String, dynamic>> get iceServers => _iceServers;

  String _cleanUrl(String url) {
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      if (clean.contains('workers.dev') || clean.contains('trycloudflare.com')) {
        clean = 'https://$clean';
      } else {
        clean = 'http://$clean';
      }
    }
    return clean;
  }

  String _getWsUrl(String httpUrl, String roomCode) {
    final clean = _cleanUrl(httpUrl);
    String wsBase;
    if (clean.startsWith('https://')) {
      wsBase = clean.replaceFirst('https://', 'wss://');
    } else {
      wsBase = clean.replaceFirst('http://', 'ws://');
    }
    return '$wsBase/api/rooms/$roomCode/ws';
  }

  /// Verifies edge server status and loads remote ICE server configuration
  Future<bool> checkServerHealth([String? urlToTest]) async {
    final target = _cleanUrl(urlToTest ?? _serverUrl);
    try {
      final res = await http.get(Uri.parse('$target/health')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _isServerOnline = true;
        await _fetchIceServers(target);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('[Signaling] Server health check failed for $target: $e');
    }
    return false;
  }

  Future<void> _fetchIceServers(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/config/ice-servers');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['iceServers'] is List) {
          final List<dynamic> raw = data['iceServers'];
          _iceServers = raw.map((e) => Map<String, dynamic>.from(e)).toList();
          print('[Signaling] Loaded ${_iceServers.length} ICE servers from Cloudflare');
        }
      }
    } catch (e) {
      print('[Signaling] Using default STUN servers: $e');
      _iceServers = List.from(AppConstants.defaultIceServers);
    }
  }

  /// Initial connection setup on app launch
  void connect(String rawUrl) async {
    final cleanUrl = _cleanUrl(rawUrl);
    _serverUrl = cleanUrl;
    _status = SignalingStatus.connecting;
    notifyListeners();

    final ok = await checkServerHealth(cleanUrl);
    if (ok) {
      _status = SignalingStatus.connected;
    } else {
      _status = SignalingStatus.error;
    }
    notifyListeners();
  }

  /// Create a new room on Cloudflare Worker
  Future<String?> createRoomOnServer() async {
    try {
      final res = await http.post(Uri.parse('$_serverUrl/api/rooms')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['roomCode'] != null) {
          return data['roomCode'].toString();
        }
      }
    } catch (e) {
      print('[Signaling] Error creating room on Worker: $e');
    }
    return null;
  }

  /// Joins or creates a room via Durable Object WebSocket
  Future<List<UserPeer>> joinRoom(String roomCode, String username) async {
    _joinCompleter = Completer<List<UserPeer>>();
    _currentRoomCode = roomCode.toUpperCase().trim();
    _currentUsername = username;

    _status = SignalingStatus.connecting;
    notifyListeners();

    await _connectWebSocket();
    return _joinCompleter!.future;
  }

  Future<void> _connectWebSocket() async {
    if (_currentRoomCode == null) return;

    await _disconnectWebSocket();

    final wsEndpoint = _getWsUrl(_serverUrl, _currentRoomCode!);
    print('[Signaling] Connecting to Durable Object WebSocket: $wsEndpoint');

    try {
      _ws = await WebSocket.connect(wsEndpoint).timeout(const Duration(seconds: 8));
      _status = SignalingStatus.connected;
      notifyListeners();

      // Start ping heartbeat (keeps mobile carrier NAT port open)
      _startPingHeartbeat();

      // Send join-room payload
      final joinMsg = jsonEncode({
        'type': 'join-room',
        'roomCode': _currentRoomCode,
        'username': _currentUsername,
      });
      _ws!.add(joinMsg);

      _wsSub = _ws!.listen(
        _onMessageReceived,
        onError: (err) {
          print('[Signaling] WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          print('[Signaling] WebSocket closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      print('[Signaling] WebSocket connection failed: $e');
      _handleDisconnect();
      if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
        _joinCompleter!.completeError('Could not connect to room server: $e');
      }
    }
  }

  void _onMessageReceived(dynamic rawData) {
    if (rawData is! String) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(rawData);
    } catch (_) {
      return;
    }

    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'pong':
        break;

      case 'room-joined':
        final user = data['user'] != null ? UserPeer.fromJson(data['user']) : null;
        if (user != null) {
          _socketId = user.socketId;
          _isHost = data['isHost'] ?? user.isHost;
        }
        final List<UserPeer> peers = [];
        if (data['existingPeers'] is List) {
          for (final p in data['existingPeers']) {
            peers.add(UserPeer.fromJson(Map<String, dynamic>.from(p)));
          }
        }
        notifyListeners();
        if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
          _joinCompleter!.complete(peers);
        }
        break;

      case 'user-joined':
        if (data['user'] != null) {
          final peer = UserPeer.fromJson(Map<String, dynamic>.from(data['user']));
          _onUserJoinedController.add(peer);
        }
        break;

      case 'user-left':
        if (data['userId'] != null) {
          final userId = data['userId'].toString();
          if (data['newHost'] != null) {
            final newHost = UserPeer.fromJson(Map<String, dynamic>.from(data['newHost']));
            if (newHost.socketId == _socketId) {
              _isHost = true;
              notifyListeners();
            }
          }
          _onUserLeftController.add(userId);
        }
        break;

      case 'user-state-changed':
        _onUserStateChangedController.add(data);
        break;

      case 'user-speaking-changed':
        _onUserSpeakingChangedController.add(data);
        break;

      case 'offer':
        _onOfferController.add(data);
        break;

      case 'answer':
        _onAnswerController.add(data);
        break;

      case 'ice-candidate':
        _onCandidateController.add(data);
        break;

      case 'soundboard-played':
        _onSoundboardPlayedController.add(data);
        break;

      case 'soundboard-synced':
        _onSoundboardSyncedController.add(data);
        break;

      case 'calls-track-updated':
        _onCallsTrackUpdatedController.add(data);
        break;

      case 'kicked-from-room':
        final reason = data['reason']?.toString() ?? 'Kicked by host';
        _onKickedController.add(reason);
        break;

      case 'error':
        print('[Signaling] Server error message: ${data['message']}');
        break;
    }
  }

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_ws != null && _ws!.readyState == WebSocket.open) {
        _ws!.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    if (_currentRoomCode != null) {
      _status = SignalingStatus.reconnecting;
      notifyListeners();

      // Auto-reconnect backoff
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (_currentRoomCode != null) {
          print('[Signaling] Attempting to reconnect WebSocket to room $_currentRoomCode...');
          _connectWebSocket();
        }
      });
    } else {
      _status = SignalingStatus.disconnected;
      notifyListeners();
    }
  }

  Future<void> _disconnectWebSocket() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close(1000, 'Client disconnect');
    } catch (_) {}
    _ws = null;
  }

  void sendOffer(String targetUserId, Map<String, dynamic> sdp) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'offer',
        'targetUserId': targetUserId,
        'sdp': sdp,
      }));
    }
  }

  void sendAnswer(String targetUserId, Map<String, dynamic> sdp) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'answer',
        'targetUserId': targetUserId,
        'sdp': sdp,
      }));
    }
  }

  void sendIceCandidate(String targetUserId, Map<String, dynamic> candidate) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'ice-candidate',
        'targetUserId': targetUserId,
        'candidate': candidate,
      }));
    }
  }

  void sendStateChange({required bool isMuted, required bool isDeafened}) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'state-change',
        'isMuted': isMuted,
        'isDeafened': isDeafened,
      }));
    }
  }

  void sendSpeakingChange(bool isSpeaking) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'speaking-change',
        'isSpeaking': isSpeaking,
      }));
    }
  }

  void broadcastSoundboardPlay(String soundId, String soundName, {String? audioData, String? audioFormat}) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      final Map<String, dynamic> payload = {
        'type': 'soundboard-play',
        'soundId': soundId,
        'soundName': soundName,
      };
      if (audioData != null) payload['audioData'] = audioData;
      if (audioFormat != null) payload['audioFormat'] = audioFormat;
      _ws!.add(jsonEncode(payload));
    }
  }

  void broadcastSoundboardSync(String soundId, String soundName, String audioData, String audioFormat) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'soundboard-sync',
        'soundId': soundId,
        'soundName': soundName,
        'audioData': audioData,
        'audioFormat': audioFormat,
      }));
    }
  }

  void publishCallsTrack(String callsSessionId, String callsAudioTrackName) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'calls-track-published',
        'callsSessionId': callsSessionId,
        'callsAudioTrackName': callsAudioTrackName,
      }));
    }
  }

  void kickUser(String targetUserId) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      _ws!.add(jsonEncode({
        'type': 'kick-user',
        'targetUserId': targetUserId,
      }));
    }
  }

  void leaveRoom() {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      try {
        _ws!.add(jsonEncode({'type': 'leave-room'}));
      } catch (_) {}
    }
    _disconnectWebSocket();
    _currentRoomCode = null;
    _isHost = false;
    _status = _isServerOnline ? SignalingStatus.connected : SignalingStatus.disconnected;
    notifyListeners();
  }

  void disconnect() {
    leaveRoom();
    _isServerOnline = false;
    _status = SignalingStatus.disconnected;
    notifyListeners();
  }

  // =========================================================================
  // Cloudflare Realtime Calls Proxy REST Client Methods
  // =========================================================================

  Future<Map<String, dynamic>?> createCallsSession({Map<String, dynamic>? sessionDescription}) async {
    try {
      final uri = Uri.parse('$_serverUrl/api/calls/session/new');
      final body = sessionDescription != null ? jsonEncode({'sessionDescription': sessionDescription}) : jsonEncode({});
      final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print('[Signaling] Cloudflare Calls session create returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('[Signaling] Error creating Cloudflare Calls session: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> addCallsTracks(
    String sessionId, {
    required Map<String, dynamic> sessionDescription,
    required List<Map<String, dynamic>> tracks,
  }) async {
    try {
      final uri = Uri.parse('$_serverUrl/api/calls/session/$sessionId/tracks/new');
      final body = jsonEncode({
        'sessionDescription': sessionDescription,
        'tracks': tracks,
      });
      final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print('[Signaling] Cloudflare Calls addTracks returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('[Signaling] Error adding Cloudflare Calls tracks: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> pullCallsTracks(
    String sessionId, {
    required List<Map<String, dynamic>> tracks,
  }) async {
    try {
      final uri = Uri.parse('$_serverUrl/api/calls/session/$sessionId/tracks/new');
      final body = jsonEncode({'tracks': tracks});
      final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[Signaling] Error pulling Cloudflare Calls tracks: $e');
    }
    return null;
  }

  Future<void> closeCallsTracks(
    String sessionId, {
    required List<Map<String, dynamic>> tracks,
  }) async {
    try {
      final uri = Uri.parse('$_serverUrl/api/calls/session/$sessionId/tracks/close');
      final body = jsonEncode({'tracks': tracks});
      await http.put(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  @override
  void dispose() {
    _onOfferController.close();
    _onAnswerController.close();
    _onCandidateController.close();
    _onUserJoinedController.close();
    _onUserLeftController.close();
    _onUserStateChangedController.close();
    _onUserSpeakingChangedController.close();
    _onSoundboardPlayedController.close();
    _onSoundboardSyncedController.close();
    _onCallsTrackUpdatedController.close();
    _onKickedController.close();
    _disconnectWebSocket();
    super.dispose();
  }
}
