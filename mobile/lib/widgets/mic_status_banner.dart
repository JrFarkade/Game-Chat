import 'package:flutter/material.dart';
import '../services/webrtc_service.dart';
import '../utils/constants.dart';

class MicStatusBanner extends StatelessWidget {
  final MicState micState;
  final bool isSpeaking;
  final String? errorMessage;
  final VoidCallback onReconnect;

  const MicStatusBanner({
    Key? key,
    required this.micState,
    required this.isSpeaking,
    this.errorMessage,
    required this.onReconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (micState == MicState.error) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.redMuted.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.redMuted, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.redMuted, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Microphone Connection Problem',
                    style: TextStyle(
                      color: AppColors.redMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.redMuted,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onReconnect,
              child: const Text(
                'RECONNECT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }

    // Normal or muted status badge
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (micState == MicState.muted) {
      badgeColor = AppColors.redMuted;
      badgeIcon = Icons.mic_off;
      badgeText = 'Microphone MUTED';
    } else if (isSpeaking) {
      badgeColor = AppColors.greenActive;
      badgeIcon = Icons.record_voice_over;
      badgeText = 'Transmitting Voice';
    } else {
      badgeColor = AppColors.textSecondary;
      badgeIcon = Icons.mic;
      badgeText = 'Microphone ON (Ready)';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 16),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
