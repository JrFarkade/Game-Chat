import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/user.dart';
import 'signaling_service.dart';

enum MicState { on, muted, error }

class WebRtcService extends ChangeNotifier {
  final SignalingService _signaling;

  MediaStream? _localStream;
  RTCPeerConnection? _callsPc;
  String? _callsSessionId;
  String? _myCallsTrackName;

  // Remote streams mapped by peer ID
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, List<MediaStreamTrack>> _remoteAudioTracks = {};
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, UserPeer> _peers = {};

  MicState _micState = MicState.on;
  bool _isDeafened = false;
  bool _isPttEnabled = false;
  bool _isPttPressed = false;

  void _applyAudioTrackSettings(String? peerSocketId, MediaStreamTrack track) {
    if (track.kind != 'audio') return;
    try {
      final peer = peerSocketId != null ? _peers[peerSocketId] : null;
      final bool isLocallyMuted = peer?.isLocallyMuted ?? false;
      final bool shouldSilence = _isDeafened || isLocallyMuted;
      final double volume = shouldSilence ? 0.0 : (peer?.volume ?? 1.0);

      track.enabled = !shouldSilence;
      Helper.setVolume(volume, track);
    } catch (e) {
      print('[WebRTC] Error applying audio track settings: $e');
    }
  }

  void _applyAllRemoteAudioSettings() {
    for (final entry in _remoteAudioTracks.entries) {
      for (final track in entry.value) {
        _applyAudioTrackSettings(entry.key, track);
      }
    }
    for (final stream in _remoteStreams.values) {
      for (final track in stream.getAudioTracks()) {
        _applyAudioTrackSettings(null, track);
      }
    }
  }
  bool _isLocallySpeaking = false;
  String? _errorMessage;

  // Audio VoIP constraints
  bool _echoCancellation = true;
  bool _noiseSuppression = true;
  bool _autoGainControl = true;

  Timer? _statsTimer;
  StreamSubscription? _offerSub;
  StreamSubscription? _answerSub;
  StreamSubscription? _candidateSub;
  StreamSubscription? _userJoinedSub;
  StreamSubscription? _userLeftSub;
  StreamSubscription? _stateChangedSub;
  StreamSubscription? _speakingChangedSub;
  StreamSubscription? _callsTrackSub;

  WebRtcService(this._signaling) {
    _bindSignalingEvents();
  }

  MicState get micState => _micState;
  bool get isDeafened => _isDeafened;
  bool get isPttEnabled => _isPttEnabled;
  bool get isPttPressed => _isPttPressed;
  bool get isLocallySpeaking => _isLocallySpeaking;
  String? get errorMessage => _errorMessage;
  List<UserPeer> get peersList => _peers.values.toList();
  Map<String, UserPeer> get peers => _peers;

  bool get echoCancellation => _echoCancellation;
  bool get noiseSuppression => _noiseSuppression;
  bool get autoGainControl => _autoGainControl;

  void updateAudioSettings({
    bool? pttEnabled,
    bool? echoCancellation,
    bool? noiseSuppression,
    bool? autoGainControl,
  }) {
    if (pttEnabled != null) {
      _isPttEnabled = pttEnabled;
      _applyMicrophoneState();
    }
    if (echoCancellation != null) _echoCancellation = echoCancellation;
    if (noiseSuppression != null) _noiseSuppression = noiseSuppression;
    if (autoGainControl != null) _autoGainControl = autoGainControl;
    notifyListeners();
  }

  void _bindSignalingEvents() {
    _offerSub = _signaling.onOffer.listen(_handleOffer);
    _answerSub = _signaling.onAnswer.listen(_handleAnswer);
    _candidateSub = _signaling.onCandidate.listen(_handleCandidate);
    _userJoinedSub = _signaling.onUserJoined.listen(_handleUserJoined);
    _userLeftSub = _signaling.onUserLeft.listen(_handleUserLeft);

    _stateChangedSub = _signaling.onUserStateChanged.listen((data) {
      final userId = data['userId']?.toString();
      if (userId != null && _peers.containsKey(userId)) {
        if (data['isMuted'] != null) _peers[userId]!.isMuted = data['isMuted'] as bool;
        if (data['isDeafened'] != null) _peers[userId]!.isDeafened = data['isDeafened'] as bool;
        notifyListeners();
      }
    });

    _speakingChangedSub = _signaling.onUserSpeakingChanged.listen((data) {
      final userId = data['userId']?.toString();
      if (userId != null && _peers.containsKey(userId)) {
        _peers[userId]!.isSpeaking = data['isSpeaking'] == true;
        notifyListeners();
      }
    });

    _callsTrackSub = _signaling.onCallsTrackUpdated.listen((data) {
      final userId = data['userId']?.toString();
      final sessId = data['callsSessionId']?.toString();
      final trackName = data['callsAudioTrackName']?.toString();
      if (userId != null && sessId != null && trackName != null) {
        if (_peers.containsKey(userId)) {
          _peers[userId]!.callsSessionId = sessId;
          _peers[userId]!.callsAudioTrackName = trackName;
        }
        _pullRemoteCallsTrack(userId, sessId, trackName);
      }
    });
  }

  /// Initializes the local microphone stream and connects to Cloudflare Realtime Calls
  Future<void> initLocalStreamAndJoin(List<UserPeer> existingPeers) async {
    await _createLocalStream();

    _peers.clear();
    for (final peer in existingPeers) {
      _peers[peer.socketId] = peer;
    }
    notifyListeners();

    // 1. Try connecting to Cloudflare Realtime Calls SFU
    final callsSuccess = await _initCloudflareCalls(existingPeers);

    // 2. If Calls is not configured on the Worker (e.g. initial dev mode), fallback to direct P2P mesh
    if (!callsSuccess) {
      print('[WebRTC] Cloudflare Calls SFU not available, falling back to direct P2P mesh');
      for (final peer in existingPeers) {
        await _createPeerConnectionFor(peer.socketId, isInitiator: true);
      }
    }

    _startAudioActivityMonitoring();
  }

  /// Establishes session and publishes mic track to Cloudflare Realtime Calls
  Future<bool> _initCloudflareCalls(List<UserPeer> existingPeers) async {
    try {
      final sessionData = await _signaling.createCallsSession();
      if (sessionData == null || sessionData['sessionId'] == null) {
        return false;
      }

      _callsSessionId = sessionData['sessionId'].toString();
      print('[WebRTC] Cloudflare Calls session created: $_callsSessionId');

      final Map<String, dynamic> rtcConfig = {
        'iceServers': _signaling.iceServers,
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
      };

      _callsPc = await createPeerConnection(rtcConfig);

      // Handle incoming remote audio tracks from SFU
      _callsPc!.onTrack = (event) {
        if (event.track.kind == 'audio') {
          print('[WebRTC] Received remote audio track from Cloudflare Calls');
          _remoteAudioTracks.putIfAbsent('_calls_sfu', () => []).add(event.track);
          if (event.streams.isNotEmpty) {
            final stream = event.streams[0];
            // Assign to any pending peer without stream
            for (final p in _peers.values) {
              if (!_remoteStreams.containsKey(p.socketId)) {
                _remoteStreams[p.socketId] = stream;
                break;
              }
            }
          }
          _applyAudioTrackSettings(null, event.track);
        }
      };

      // Add local microphone track
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          await _callsPc!.addTrack(track, _localStream!);
        }
      }

      // Generate local SDP offer to publish track
      final offer = await _callsPc!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _callsPc!.setLocalDescription(offer);

      _myCallsTrackName = 'audio-${_signaling.socketId ?? DateTime.now().millisecondsSinceEpoch}';

      // Register track on Cloudflare Calls
      final trackResult = await _signaling.addCallsTracks(
        _callsSessionId!,
        sessionDescription: {'type': offer.type, 'sdp': offer.sdp},
        tracks: [
          {
            'location': 'local',
            'trackName': _myCallsTrackName,
          }
        ],
      );

      if (trackResult != null && trackResult['sessionDescription'] != null) {
        final answerSdp = trackResult['sessionDescription']['sdp'] as String?;
        final answerType = trackResult['sessionDescription']['type'] as String? ?? 'answer';
        if (answerSdp != null) {
          await _callsPc!.setRemoteDescription(RTCSessionDescription(answerSdp, answerType));
          print('[WebRTC] Cloudflare Calls track successfully published');

          // Broadcast track info to the room via Durable Object
          _signaling.publishCallsTrack(_callsSessionId!, _myCallsTrackName!);

          // Pull tracks for any existing peers
          for (final peer in existingPeers) {
            if (peer.callsSessionId != null && peer.callsAudioTrackName != null) {
              await _pullRemoteCallsTrack(peer.socketId, peer.callsSessionId!, peer.callsAudioTrackName!);
            }
          }

          return true;
        }
      }
    } catch (e) {
      print('[WebRTC] Error initializing Cloudflare Calls: $e');
    }
    return false;
  }

  /// Pulls a remote participant's audio track from Cloudflare Calls SFU
  Future<void> _pullRemoteCallsTrack(String peerId, String remoteSessionId, String remoteTrackName) async {
    if (_callsSessionId == null || _callsPc == null) return;
    try {
      print('[WebRTC] Pulling remote track $remoteTrackName from session $remoteSessionId for peer $peerId');
      final pullResult = await _signaling.pullCallsTracks(
        _callsSessionId!,
        tracks: [
          {
            'location': 'remote',
            'sessionId': remoteSessionId,
            'trackName': remoteTrackName,
          }
        ],
      );

      if (pullResult != null && pullResult['sessionDescription'] != null) {
        final sdp = pullResult['sessionDescription']['sdp'] as String?;
        final type = pullResult['sessionDescription']['type'] as String? ?? 'offer';
        if (sdp != null) {
          await _callsPc!.setRemoteDescription(RTCSessionDescription(sdp, type));
          final answer = await _callsPc!.createAnswer();
          await _callsPc!.setLocalDescription(answer);
        }
      }
    } catch (e) {
      print('[WebRTC] Error pulling remote Calls track: $e');
    }
  }

  /// Captures local microphone audio with low latency and VoIP constraints
  Future<bool> _createLocalStream() async {
    try {
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': _echoCancellation,
          'noiseSuppression': _noiseSuppression,
          'autoGainControl': _autoGainControl,
          'sampleRate': 48000,
          'channelCount': 1,
          'latency': 0.01,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        audioTracks.first.onEnded = () {
          print('[WebRTC] Microphone hardware stream stopped!');
          _micState = MicState.error;
          _errorMessage = 'Microphone hardware stream stopped';
          notifyListeners();
        };
      }

      _micState = MicState.on;
      _errorMessage = null;
      _applyMicrophoneState();
      notifyListeners();
      return true;
    } catch (e) {
      print('[WebRTC] Error initializing microphone: $e');
      _micState = MicState.error;
      _errorMessage = 'Could not access microphone: $e';
      notifyListeners();
      return false;
    }
  }

  /// Hot-replaces microphone track across active connections
  Future<bool> reconnectMicrophone() async {
    print('[WebRTC] Reconnecting microphone track...');
    final success = await _createLocalStream();
    if (!success || _localStream == null) return false;

    final newTrack = _localStream!.getAudioTracks().isNotEmpty ? _localStream!.getAudioTracks().first : null;
    if (newTrack == null) return false;

    // Replace track on Cloudflare Calls connection
    if (_callsPc != null) {
      try {
        final senders = await _callsPc!.getSenders();
        for (final s in senders) {
          if (s.track?.kind == 'audio') {
            await s.replaceTrack(newTrack);
          }
        }
      } catch (e) {
        print('[WebRTC] Error replacing track on Calls PC: $e');
      }
    }

    // Replace track on P2P connections if any active
    for (final pc in _peerConnections.values) {
      try {
        final senders = await pc.getSenders();
        for (final s in senders) {
          if (s.track?.kind == 'audio') {
            await s.replaceTrack(newTrack);
          }
        }
      } catch (_) {}
    }

    _applyMicrophoneState();
    notifyListeners();
    return true;
  }

  /// P2P RTCPeerConnection establishment with Anycast STUN
  Future<RTCPeerConnection> _createPeerConnectionFor(String peerSocketId, {required bool isInitiator}) async {
    final Map<String, dynamic> configuration = {
      'iceServers': _signaling.iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
    };

    final pc = await createPeerConnection(configuration);
    _peerConnections[peerSocketId] = pc;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _signaling.sendIceCandidate(peerSocketId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'audio') {
        _remoteAudioTracks.putIfAbsent(peerSocketId, () => []).add(event.track);
        if (event.streams.isNotEmpty) {
          _remoteStreams[peerSocketId] = event.streams[0];
        }
        _applyAudioTrackSettings(peerSocketId, event.track);
        notifyListeners();
      }
    };

    if (isInitiator) {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await pc.setLocalDescription(offer);
      _signaling.sendOffer(peerSocketId, {
        'type': offer.type,
        'sdp': offer.sdp,
      });
    }

    return pc;
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    final senderSocketId = (data['senderSocketId'] ?? data['senderId'] ?? data['userId']) as String?;
    final sdpMap = data['sdp'] as Map<String, dynamic>?;
    if (senderSocketId == null || sdpMap == null) return;

    final pc = await _createPeerConnectionFor(senderSocketId, isInitiator: false);
    final description = RTCSessionDescription(sdpMap['sdp'] as String, sdpMap['type'] as String);
    await pc.setRemoteDescription(description);

    final answer = await pc.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });
    await pc.setLocalDescription(answer);

    _signaling.sendAnswer(senderSocketId, {
      'type': answer.type,
      'sdp': answer.sdp,
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    final senderSocketId = (data['senderSocketId'] ?? data['senderId'] ?? data['userId']) as String?;
    final sdpMap = data['sdp'] as Map<String, dynamic>?;
    if (senderSocketId == null || sdpMap == null) return;

    final pc = _peerConnections[senderSocketId];
    if (pc != null) {
      final description = RTCSessionDescription(sdpMap['sdp'] as String, sdpMap['type'] as String);
      await pc.setRemoteDescription(description);
    }
  }

  Future<void> _handleCandidate(Map<String, dynamic> data) async {
    final senderSocketId = (data['senderSocketId'] ?? data['senderId'] ?? data['userId']) as String?;
    final candData = data['candidate'] as Map<String, dynamic>?;
    if (senderSocketId == null || candData == null) return;

    final candidate = RTCIceCandidate(
      candData['candidate'] as String?,
      candData['sdpMid'] as String?,
      candData['sdpMLineIndex'] as int?,
    );

    final pc = _peerConnections[senderSocketId];
    if (pc != null) {
      await pc.addCandidate(candidate);
    }
  }

  Future<void> _handleUserJoined(UserPeer peer) async {
    _peers[peer.socketId] = peer;
    notifyListeners();

    if (peer.callsSessionId != null && peer.callsAudioTrackName != null) {
      await _pullRemoteCallsTrack(peer.socketId, peer.callsSessionId!, peer.callsAudioTrackName!);
    } else if (_callsPc == null) {
      // In P2P mode, initiator creates peer connection with the joining user
      await _createPeerConnectionFor(peer.socketId, isInitiator: true);
    }
  }

  void _handleUserLeft(String socketId) {
    _peers.remove(socketId);
    _closePeerConnection(socketId);
    _remoteAudioTracks.remove(socketId);
    notifyListeners();
  }

  void _closePeerConnection(String socketId) {
    if (_peerConnections.containsKey(socketId)) {
      _peerConnections[socketId]?.close();
      _peerConnections.remove(socketId);
    }
    if (_remoteStreams.containsKey(socketId)) {
      _remoteStreams[socketId]?.dispose();
      _remoteStreams.remove(socketId);
    }
  }

  void toggleMute() {
    if (_micState == MicState.muted) {
      _micState = MicState.on;
    } else if (_micState == MicState.on) {
      _micState = MicState.muted;
    }
    _applyMicrophoneState();
    _signaling.sendStateChange(isMuted: _micState == MicState.muted, isDeafened: _isDeafened);
    notifyListeners();
  }

  void toggleDeafen() {
    _isDeafened = !_isDeafened;
    _applyAllRemoteAudioSettings();
    _signaling.sendStateChange(isMuted: _micState == MicState.muted, isDeafened: _isDeafened);
    notifyListeners();
  }

  void setPttPressed(bool pressed) {
    if (!_isPttEnabled) return;
    _isPttPressed = pressed;
    _applyMicrophoneState();
    notifyListeners();
  }

  void _applyMicrophoneState() {
    if (_localStream == null) return;
    final tracks = _localStream!.getAudioTracks();
    if (tracks.isEmpty) return;

    bool shouldEnable = false;
    if (_micState == MicState.on) {
      if (_isPttEnabled) {
        shouldEnable = _isPttPressed;
      } else {
        shouldEnable = true;
      }
    }
    tracks.first.enabled = shouldEnable;
  }

  void toggleLocalMuteForPeer(String socketId) {
    final peer = _peers[socketId];
    if (peer == null) return;

    peer.isLocallyMuted = !peer.isLocallyMuted;
    final tracks = _remoteAudioTracks[socketId];
    if (tracks != null) {
      for (final track in tracks) {
        _applyAudioTrackSettings(socketId, track);
      }
    }
    final stream = _remoteStreams[socketId];
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        _applyAudioTrackSettings(socketId, track);
      }
    }
    notifyListeners();
  }

  void setPeerVolume(String socketId, double volume) {
    final peer = _peers[socketId];
    if (peer == null) return;
    peer.volume = volume;
    final tracks = _remoteAudioTracks[socketId];
    if (tracks != null) {
      for (final track in tracks) {
        _applyAudioTrackSettings(socketId, track);
      }
    }
    final stream = _remoteStreams[socketId];
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        _applyAudioTrackSettings(socketId, track);
      }
    }
    notifyListeners();
  }

  void _startAudioActivityMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (_micState != MicState.on || (_isPttEnabled && !_isPttPressed)) {
        if (_isLocallySpeaking) {
          _isLocallySpeaking = false;
          _signaling.sendSpeakingChange(false);
          notifyListeners();
        }
        return;
      }

      bool speaking = false;
      if (_callsPc != null) {
        try {
          final stats = await _callsPc!.getStats();
          for (final report in stats) {
            if (report.type == 'outbound-rtp' && report.values['kind'] == 'audio') {
              final bytes = int.tryParse(report.values['bytesSent']?.toString() ?? '0') ?? 0;
              if (bytes > 0) {
                speaking = true;
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (!speaking) {
        for (final pc in _peerConnections.values) {
          try {
            final stats = await pc.getStats();
            for (final report in stats) {
              if (report.type == 'outbound-rtp' && report.values['kind'] == 'audio') {
                final bytes = int.tryParse(report.values['bytesSent']?.toString() ?? '0') ?? 0;
                if (bytes > 0) {
                  speaking = true;
                  break;
                }
              }
            }
          } catch (_) {}
        }
      }

      if (speaking != _isLocallySpeaking) {
        _isLocallySpeaking = speaking;
        _signaling.sendSpeakingChange(speaking);
        notifyListeners();
      }
    });
  }

  Future<void> leaveAndCleanUp() async {
    _statsTimer?.cancel();

    if (_callsSessionId != null && _myCallsTrackName != null) {
      _signaling.closeCallsTracks(_callsSessionId!, tracks: [{'trackName': _myCallsTrackName!}]);
    }

    if (_callsPc != null) {
      await _callsPc!.close();
      _callsPc = null;
    }
    _callsSessionId = null;
    _myCallsTrackName = null;

    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();

    for (final stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    _peers.clear();
    _remoteAudioTracks.clear();
    _isDeafened = false;
    _micState = MicState.on;
    _isLocallySpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    _answerSub?.cancel();
    _candidateSub?.cancel();
    _userJoinedSub?.cancel();
    _userLeftSub?.cancel();
    _stateChangedSub?.cancel();
    _speakingChangedSub?.cancel();
    _callsTrackSub?.cancel();
    leaveAndCleanUp();
    super.dispose();
  }
}
