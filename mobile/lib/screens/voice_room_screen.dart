import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/foreground_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../utils/constants.dart';
import '../widgets/mic_status_banner.dart';
import '../widgets/ptt_button.dart';
import '../widgets/user_tile.dart';
import 'settings_screen.dart';
import 'soundboard_screen.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomCode;
  final String username;

  const VoiceRoomScreen({
    Key? key,
    required this.roomCode,
    required this.username,
  }) : super(key: key);

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  @override
  void initState() {
    super.initState();
    final signaling = context.read<SignalingService>();
    signaling.onKicked.listen((reason) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You were kicked: $reason')),
        );
        _leaveRoom();
      }
    });
  }

  void _copyRoomCode() {
    final serverUrl = context.read<SignalingService>().serverUrl;
    final inviteText = '🎮 GameChat Voice Room\nRoom Code: ${widget.roomCode}\nServer: $serverUrl';
    Clipboard.setData(ClipboardData(text: inviteText));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code & Server URL copied to clipboard!\nShare this with your friends.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    await ForegroundService.stop();
    if (mounted) {
      context.read<WebRtcService>().leaveAndCleanUp();
      context.read<SignalingService>().leaveRoom();
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signaling = context.watch<SignalingService>();
    final webrtc = context.watch<WebRtcService>();

    final selfUser = UserPeer(
      socketId: signaling.socketId ?? '',
      username: widget.username,
      isHost: signaling.isHost,
      isMuted: webrtc.micState == MicState.muted,
      isDeafened: webrtc.isDeafened,
      isSpeaking: webrtc.isLocallySpeaking,
    );

    final otherPeers = webrtc.peersList;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Leave Voice Room?', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
              'Leaving will disconnect your voice chat and stop the background service.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                child: const Text('STAY', style: TextStyle(color: AppColors.textSecondary)),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.redMuted),
                child: const Text('LEAVE', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );

        if (shouldLeave == true) {
          await _leaveRoom();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Leave Voice Room?', style: TextStyle(color: AppColors.textPrimary)),
                      content: const Text('Do you want to disconnect from this room?'),
                      actions: [
                        TextButton(
                          child: const Text('CANCEL'),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.redMuted),
                          child: const Text('LEAVE'),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  ) ==
                  true) {
                await _leaveRoom();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('ROOM ', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  Text(
                    widget.roomCode,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ],
              ),
              Text(
                '${otherPeers.length + 1} participant${otherPeers.isEmpty ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy, color: AppColors.primary),
              tooltip: 'Copy room code',
              onPressed: _copyRoomCode,
            ),
            IconButton(
              icon: const Icon(Icons.surround_sound, color: AppColors.greenActive),
              tooltip: 'Soundboard',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SoundboardScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: AppColors.textSecondary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Microphone Status Banner (handles error and reconnect)
            MicStatusBanner(
              micState: webrtc.micState,
              isSpeaking: webrtc.isLocallySpeaking,
              errorMessage: webrtc.errorMessage,
              onReconnect: () => webrtc.reconnectMicrophone(),
            ),

            // Connected Users List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Self user
                  UserTile(
                    user: selfUser,
                    isSelf: true,
                    isHostOfRoom: signaling.isHost,
                    onLocalMuteToggle: () {},
                    onVolumeChanged: (_) {},
                  ),
                  const Divider(color: AppColors.cardBorder, indent: 20, endIndent: 20),

                  // Remote peers
                  if (otherPeers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.group_add, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text(
                              'Waiting for friends to join...',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Share the room code above with your friends',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...otherPeers.map(
                      (peer) => UserTile(
                        user: peer,
                        isSelf: false,
                        isHostOfRoom: signaling.isHost,
                        onLocalMuteToggle: () => webrtc.toggleLocalMuteForPeer(peer.socketId),
                        onVolumeChanged: (vol) => webrtc.setPeerVolume(peer.socketId, vol),
                        onKickUser: () => signaling.kickUser(peer.socketId),
                      ),
                    ),
                ],
              ),
            ),

            // Push-To-Talk Button or Open Mic Status
            if (webrtc.isPttEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: PttButton(
                  isPressed: webrtc.isPttPressed,
                  onStateChanged: (pressed) => webrtc.setPttPressed(pressed),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        webrtc.micState == MicState.on ? Icons.mic : Icons.mic_off,
                        color: webrtc.micState == MicState.on ? AppColors.greenActive : AppColors.redMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        webrtc.micState == MicState.on ? 'Open Mic Active' : 'Microphone Muted',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Tactical Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute Button
                    _ControlButton(
                      icon: webrtc.micState == MicState.muted ? Icons.mic_off : Icons.mic,
                      label: webrtc.micState == MicState.muted ? 'UNMUTE' : 'MUTE',
                      isActive: webrtc.micState == MicState.muted,
                      activeColor: AppColors.redMuted,
                      onTap: () => webrtc.toggleMute(),
                    ),

                    // Deafen / Undeafen Speaker Button
                    _ControlButton(
                      icon: webrtc.isDeafened ? Icons.volume_off : Icons.volume_up,
                      label: webrtc.isDeafened ? 'UNDEAFEN' : 'DEAFEN',
                      isActive: webrtc.isDeafened,
                      activeColor: AppColors.redMuted,
                      onTap: () => webrtc.toggleDeafen(),
                    ),

                    // Quick Soundboard Button
                    _ControlButton(
                      icon: Icons.surround_sound,
                      label: 'SOUNDS',
                      isActive: false,
                      activeColor: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SoundboardScreen()),
                        );
                      },
                    ),

                    // Leave Call Button
                    _ControlButton(
                      icon: Icons.call_end,
                      label: 'LEAVE',
                      isActive: true,
                      activeColor: AppColors.redMuted,
                      onTap: _leaveRoom,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ControlButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor.withOpacity(0.2) : AppColors.card,
                border: Border.all(
                  color: isActive ? activeColor : AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? activeColor : AppColors.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
