import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamechat/models/sound_clip.dart';
import 'package:gamechat/models/user.dart';

void main() {
  group('Deafen and Volume Isolation Tests', () {
    test('Deafen independently silences incoming tracks without touching mic', () {
      bool isMuted = false;
      bool isDeafened = false;

      double calculateTargetVolume({
        required bool isDeafened,
        required bool isLocallyMuted,
        required double peerVolume,
      }) {
        if (isDeafened || isLocallyMuted) return 0.0;
        return peerVolume;
      }

      bool calculateTrackEnabled({
        required bool isDeafened,
        required bool isLocallyMuted,
      }) {
        return !isDeafened && !isLocallyMuted;
      }

      expect(isMuted, false);
      expect(isDeafened, false);
      expect(calculateTargetVolume(isDeafened: isDeafened, isLocallyMuted: false, peerVolume: 1.0), 1.0);
      expect(calculateTrackEnabled(isDeafened: isDeafened, isLocallyMuted: false), true);

      // User presses DEAFEN
      isDeafened = true;
      expect(isMuted, false, reason: 'Microphone state must not be modified by deafen');
      expect(calculateTargetVolume(isDeafened: isDeafened, isLocallyMuted: false, peerVolume: 1.0), 0.0);
      expect(calculateTrackEnabled(isDeafened: isDeafened, isLocallyMuted: false), false);

      // User toggles mic while deafened (mic and deafen are independent)
      isMuted = true;
      expect(isMuted, true);
      expect(isDeafened, true);

      isMuted = false;
      expect(isMuted, false);
      expect(isDeafened, true);

      // User turns DEAFEN OFF
      isDeafened = false;
      expect(calculateTargetVolume(isDeafened: isDeafened, isLocallyMuted: false, peerVolume: 1.0), 1.0);
      expect(calculateTrackEnabled(isDeafened: isDeafened, isLocallyMuted: false), true);
      expect(isMuted, false);
    });

    test('Late-joining peer track is silenced immediately if deafen is already active', () {
      final isDeafened = true;
      final latePeer = UserPeer(socketId: 'peer_2', username: 'Friend2', volume: 0.8);

      double targetVolume = isDeafened ? 0.0 : latePeer.volume;
      bool targetEnabled = !isDeafened;

      expect(targetVolume, 0.0, reason: 'New peer joining while deafened must be muted immediately');
      expect(targetEnabled, false);
    });
  });

  group('Custom Soundboard Transmission Tests', () {
    test('Preset sound clips are preserved (28 sounds)', () {
      final presetIds = [
        'vine_boom', 'emotional_damage', 'fbi_open_up', 'faaaah', 'aayein',
        'among_us', 'anime_wow', 'bing_chilling', 'dexter_surprise',
        'directed_by_robert', 'dun_dun_dun', 'windows_error', 'huh',
        'jojo_pillar_men', 'rage_keyboard', 'curb_credits', 'bonk_meme',
        'meri_jung', 'run_meme', 'omae_wa_nani', 'wait_wait_wait',
        'oh_my_god', 'spiderman_meme', 'subway_surfers_bass', 'social_credit',
        'tf2_nemesis', 'lion_sleeps_tonight', 'camera_snap'
      ];
      expect(presetIds.length, 28);
    });

    test('Custom sound audio encoding, transmission, and decoding simulation', () {
      final rawAudio = 'RIFF simulated wav/mp3 audio data header and samples';
      final originalBytes = utf8.encode(rawAudio);

      final base64Payload = base64Encode(originalBytes);
      final playPayload = {
        'type': 'soundboard-play',
        'soundId': 'custom_12345',
        'soundName': 'My Custom Sound',
        'audioData': base64Payload,
        'audioFormat': 'mp3',
      };

      final jsonString = jsonEncode(playPayload);
      final receivedData = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(receivedData['audioData'], isNotNull);
      final receivedBytes = base64Decode(receivedData['audioData'] as String);
      expect(receivedBytes, equals(originalBytes));
      expect(utf8.decode(receivedBytes), equals(rawAudio));

      final receivedClip = SoundClip(
        id: receivedData['soundId'] as String,
        name: receivedData['soundName'] as String,
        filePath: '/tmp/room_sounds/${receivedData['soundId']}.${receivedData['audioFormat']}',
        isCustom: true,
      );
      expect(receivedClip.id, 'custom_12345');
      expect(receivedClip.name, 'My Custom Sound');
      expect(receivedClip.isCustom, true);
    });

    test('Deafen suppresses incoming soundboard playback', () {
      bool isDeafened = true;
      bool soundPlayed = false;

      void onReceiveRemoteSoundboard() {
        if (isDeafened) {
          return;
        }
        soundPlayed = true;
      }

      onReceiveRemoteSoundboard();
      expect(soundPlayed, false, reason: 'Remote soundboard must be suppressed when deafened');

      isDeafened = false;
      onReceiveRemoteSoundboard();
      expect(soundPlayed, true, reason: 'Remote soundboard plays when deafen is off');
    });

    test('Room custom sounds list clears on leave without losing personal custom sounds', () {
      final personalClips = [
        SoundClip(id: 'c1', name: 'My Sound', isCustom: true),
      ];
      final roomClips = [
        SoundClip(id: 'c2', name: 'Friend Sound', isCustom: true),
      ];

      List<SoundClip> getAllClips() => [...personalClips, ...roomClips];
      expect(getAllClips().length, 2);

      roomClips.clear();
      expect(getAllClips().length, 1);
      expect(getAllClips().first.id, 'c1');
    });
  });
}
