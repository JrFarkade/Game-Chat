import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class UserTile extends StatelessWidget {
  final UserPeer user;
  final bool isSelf;
  final bool isHostOfRoom;
  final VoidCallback onLocalMuteToggle;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onKickUser;

  const UserTile({
    Key? key,
    required this.user,
    this.isSelf = false,
    this.isHostOfRoom = false,
    required this.onLocalMuteToggle,
    required this.onVolumeChanged,
    this.onKickUser,
  }) : super(key: key);

  void _showUserControlSheet(BuildContext context) {
    if (isSelf) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              user.isHost ? 'Room Host' : 'Member',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'User Volume',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(user.volume * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: user.volume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.cardBorder,
                    onChanged: (val) {
                      setSheetState(() => user.volume = val);
                      onVolumeChanged(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: user.isLocallyMuted ? AppColors.greenActive : AppColors.card,
                        foregroundColor: user.isLocallyMuted ? Colors.black : AppColors.redMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: user.isLocallyMuted ? AppColors.greenActive : AppColors.cardBorder,
                          ),
                        ),
                      ),
                      icon: Icon(user.isLocallyMuted ? Icons.volume_up : Icons.volume_off),
                      label: Text(
                        user.isLocallyMuted ? 'UNMUTE FOR ME' : 'MUTE FOR ME',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        onLocalMuteToggle();
                        setSheetState(() {});
                      },
                    ),
                  ),
                  if (isHostOfRoom && onKickUser != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.redMuted,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.person_remove),
                        label: const Text('KICK FROM ROOM'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onKickUser!();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSpeakingRing = user.isSpeaking && !user.isMuted;

    return InkWell(
      onTap: () => _showUserControlSheet(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSpeakingRing ? AppColors.greenActive : AppColors.cardBorder,
            width: hasSpeakingRing ? 2 : 1,
          ),
          boxShadow: hasSpeakingRing
              ? [
                  BoxShadow(
                    color: AppColors.greenGlow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                    border: Border.all(
                      color: hasSpeakingRing ? AppColors.greenActive : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user.isMuted ? AppColors.redMuted : AppColors.greenActive,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Username and Tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.username + (isSelf ? ' (You)' : ''),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isHost) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'HOST',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasSpeakingRing
                        ? '🔊 SPEAKING'
                        : user.isMuted
                            ? 'Muted'
                            : 'Connected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasSpeakingRing ? FontWeight.bold : FontWeight.normal,
                      color: hasSpeakingRing
                          ? AppColors.greenActive
                          : user.isMuted
                              ? AppColors.redMuted
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Icons on right
            if (user.isLocallyMuted)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.volume_off, color: AppColors.redMuted, size: 20),
              ),
            Icon(
              user.isMuted ? Icons.mic_off : Icons.mic,
              color: user.isMuted ? AppColors.redMuted : AppColors.greenActive,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
