import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sound_clip.dart';
import 'signaling_service.dart';

class AudioService extends ChangeNotifier {
  final SignalingService _signaling;
  final AudioPlayer _audioPlayer = AudioPlayer();

  double _soundboardVolume = 0.8;
  double _voiceVolume = 1.0;
  String? _currentlyPlayingId;

  // Built-in soundboard presets (28 sounds)
  final List<SoundClip> _presetClips = [
    SoundClip(id: 'vine_boom', name: 'VINE BOOM', assetPath: 'assets/sounds/vine_boom.mp3'),
    SoundClip(id: 'emotional_damage', name: 'EMOTIONAL DAMAGE', assetPath: 'assets/sounds/emotional_damage.mp3'),
    SoundClip(id: 'fbi_open_up', name: 'FBI OPEN UP!', assetPath: 'assets/sounds/fbi_open_up.mp3'),
    SoundClip(id: 'faaaah', name: 'FAAAAH', assetPath: 'assets/sounds/faaaah.mp3'),
    SoundClip(id: 'aayein', name: 'AAYEIN?!', assetPath: 'assets/sounds/aayein.mp3'),
    SoundClip(id: 'among_us', name: 'AMONG US', assetPath: 'assets/sounds/among_us.mp3'),
    SoundClip(id: 'anime_wow', name: 'ANIME WOW', assetPath: 'assets/sounds/anime_wow.mp3'),
    SoundClip(id: 'bing_chilling', name: 'BING CHILLING', assetPath: 'assets/sounds/bing_chilling.mp3'),
    SoundClip(id: 'dexter_surprise', name: 'SURPRISE MF', assetPath: 'assets/sounds/dexter_surprise.mp3'),
    SoundClip(id: 'directed_by_robert', name: 'DIRECTED BY ROBERT', assetPath: 'assets/sounds/directed_by_robert.mp3'),
    SoundClip(id: 'dun_dun_dun', name: 'DUN DUN DUN!', assetPath: 'assets/sounds/dun_dun_dun.mp3'),
    SoundClip(id: 'windows_error', name: 'WINDOWS ERROR', assetPath: 'assets/sounds/windows_error.mp3'),
    SoundClip(id: 'huh', name: 'HUH?!', assetPath: 'assets/sounds/huh.mp3'),
    SoundClip(id: 'jojo_pillar_men', name: 'JOJO AYAYAY', assetPath: 'assets/sounds/jojo_pillar_men.mp3'),
    SoundClip(id: 'rage_keyboard', name: 'RAGE KEYBOARD', assetPath: 'assets/sounds/rage_keyboard.mp3'),
    SoundClip(id: 'curb_credits', name: 'FINAL CREDITS', assetPath: 'assets/sounds/curb_credits.mp3'),
    SoundClip(id: 'bonk_meme', name: 'BONK!', assetPath: 'assets/sounds/bonk_meme.mp3'),
    SoundClip(id: 'meri_jung', name: 'MERI JUNG', assetPath: 'assets/sounds/meri_jung.mp3'),
    SoundClip(id: 'run_meme', name: 'RUN!', assetPath: 'assets/sounds/run_meme.mp3'),
    SoundClip(id: 'omae_wa_nani', name: 'OMAE WA NANI', assetPath: 'assets/sounds/omae_wa_nani.mp3'),
    SoundClip(id: 'wait_wait_wait', name: 'WAIT WAIT WAIT!', assetPath: 'assets/sounds/wait_wait_wait.mp3'),
    SoundClip(id: 'oh_my_god', name: 'OH MY GOD', assetPath: 'assets/sounds/oh_my_god.mp3'),
    SoundClip(id: 'spiderman_meme', name: 'SPIDERMAN', assetPath: 'assets/sounds/spiderman_meme.mp3'),
    SoundClip(id: 'subway_surfers_bass', name: 'SUBWAY SURFERS', assetPath: 'assets/sounds/subway_surfers_bass.mp3'),
    SoundClip(id: 'social_credit', name: 'SOCIAL CREDIT', assetPath: 'assets/sounds/social_credit.mp3'),
    SoundClip(id: 'tf2_nemesis', name: 'TF2 NEMESIS', assetPath: 'assets/sounds/tf2_nemesis.mp3'),
    SoundClip(id: 'lion_sleeps_tonight', name: 'A-WIMOWEH', assetPath: 'assets/sounds/lion_sleeps_tonight.mp3'),
    SoundClip(id: 'camera_snap', name: 'CAMERA SNAP 📸', assetPath: 'assets/sounds/camera_snap.mp3'),
  ];

  final List<SoundClip> _customClips = [];

  AudioService(this._signaling) {
    _loadCustomClips();
    _listenToSignalingSoundboard();
    _audioPlayer.onPlayerComplete.listen((_) {
      _currentlyPlayingId = null;
      notifyListeners();
    });
  }

  double get soundboardVolume => _soundboardVolume;
  double get voiceVolume => _voiceVolume;
  String? get currentlyPlayingId => _currentlyPlayingId;
  List<SoundClip> get presetClips => _presetClips;
  List<SoundClip> get customClips => _customClips;
  List<SoundClip> get allClips => [..._presetClips, ..._customClips];

  void setSoundboardVolume(double volume) {
    _soundboardVolume = volume.clamp(0.0, 1.0);
    _audioPlayer.setVolume(_soundboardVolume);
    notifyListeners();
  }

  void setVoiceVolume(double volume) {
    _voiceVolume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  void _listenToSignalingSoundboard() {
    _signaling.onSoundboardPlayed.listen((data) {
      final soundId = data['soundId'] as String?;
      final senderSocketId = (data['senderSocketId'] ?? data['senderId']) as String?;

      // Don't replay if we were the sender (we already played it immediately for zero delay)
      if (senderSocketId == _signaling.socketId) return;

      if (soundId != null) {
        _playClipByIdLocally(soundId);
      }
    });
  }

  /// Triggers sound: plays locally AND sends to everyone in room via WebRTC signaling
  Future<void> playAndBroadcast(SoundClip clip) async {
    _currentlyPlayingId = clip.id;
    notifyListeners();

    // Broadcast to room
    _signaling.broadcastSoundboardPlay(clip.id, clip.name);

    // Play locally
    await _playClipLocally(clip);
  }

  Future<void> _playClipLocally(SoundClip clip) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_soundboardVolume);

      if (clip.isCustom && clip.filePath != null) {
        await _audioPlayer.play(DeviceFileSource(clip.filePath!));
      } else if (clip.assetPath != null) {
        await _audioPlayer.play(AssetSource(clip.assetPath!.replaceFirst('assets/', '')));
      }
    } catch (e) {
      print('[AudioService] Error playing sound ${clip.name}: $e');
      _currentlyPlayingId = null;
      notifyListeners();
    }
  }

  Future<void> _playClipByIdLocally(String soundId) async {
    final clip = allClips.firstWhere(
      (c) => c.id == soundId,
      orElse: () => _presetClips.first,
    );
    await _playClipLocally(clip);
  }

  Future<void> stopCurrentSound() async {
    await _audioPlayer.stop();
    _currentlyPlayingId = null;
    notifyListeners();
  }

  // --- Custom Sounds Management ---

  Future<void> _loadCustomClips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('gamechat_custom_sounds');
      if (savedJson != null) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        _customClips.clear();
        for (final item in decoded) {
          final clip = SoundClip.fromJson(Map<String, dynamic>.from(item));
          if (clip.filePath != null && File(clip.filePath!).existsSync()) {
            _customClips.add(clip);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      print('[AudioService] Error loading custom sounds: $e');
    }
  }

  Future<void> _saveCustomClips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customClips.map((c) => c.toJson()).toList();
      await prefs.setString('gamechat_custom_sounds', jsonEncode(list));
    } catch (e) {
      print('[AudioService] Error saving custom sounds: $e');
    }
  }

  /// Pick an audio file (mp3, wav, ogg) from phone storage and save it locally
  Future<bool> pickAndAddCustomSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        final sourceFile = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final ext = result.files.single.extension ?? 'wav';
        final cleanName = result.files.single.name.replaceAll('.$ext', '');
        final targetPath = '${appDir.path}/custom_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await sourceFile.copy(targetPath);

        final newClip = SoundClip(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: cleanName.length > 12 ? cleanName.substring(0, 12) : cleanName,
          filePath: targetPath,
          isCustom: true,
        );

        _customClips.add(newClip);
        await _saveCustomClips();
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('[AudioService] Error picking sound: $e');
    }
    return false;
  }

  Future<void> renameCustomSound(String id, String newName) async {
    final index = _customClips.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = _customClips[index];
      _customClips[index] = SoundClip(
        id: old.id,
        name: newName,
        filePath: old.filePath,
        isCustom: true,
      );
      await _saveCustomClips();
      notifyListeners();
    }
  }

  Future<void> deleteCustomSound(String id) async {
    final index = _customClips.indexWhere((c) => c.id == id);
    if (index != -1) {
      final clip = _customClips[index];
      if (clip.filePath != null) {
        try {
          final file = File(clip.filePath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
      _customClips.removeAt(index);
      await _saveCustomClips();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
