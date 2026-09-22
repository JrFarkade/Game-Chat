import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sound_clip.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/sound_button.dart';

class SoundboardScreen extends StatelessWidget {
  const SoundboardScreen({Key? key}) : super(key: key);

  void _showRenameDialog(BuildContext context, SoundClip clip) {
    final controller = TextEditingController(text: clip.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename Sound', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('SAVE'),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context.read<AudioService>().renameCustomSound(clip.id, newName);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.surround_sound, color: AppColors.primary),
            SizedBox(width: 10),
            Text('SOUNDBOARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          if (audio.currentlyPlayingId != null)
            TextButton.icon(
              icon: const Icon(Icons.stop, color: AppColors.redMuted),
              label: const Text('STOP', style: TextStyle(color: AppColors.redMuted, fontWeight: FontWeight.bold)),
              onPressed: () => audio.stopCurrentSound(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Volume Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(Icons.volume_up, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Volume',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Expanded(
                  child: Slider(
                    value: audio.soundboardVolume,
                    min: 0.0,
                    max: 1.0,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.cardBorder,
                    onChanged: (val) => audio.setSoundboardVolume(val),
                  ),
                ),
                Text(
                  '${(audio.soundboardVolume * 100).toInt()}%',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),

          // Soundboard Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: audio.allClips.length + 1, // +1 for the Add Sound tile
              itemBuilder: (context, index) {
                if (index < audio.allClips.length) {
                  final clip = audio.allClips[index];
                  final isPlaying = audio.currentlyPlayingId == clip.id;

                  return SoundButton(
                    clip: clip,
                    isPlaying: isPlaying,
                    onPlay: () => audio.playAndBroadcast(clip),
                    onStop: () => audio.stopCurrentSound(),
                    onRename: clip.isCustom ? () => _showRenameDialog(context, clip) : null,
                    onDelete: clip.isCustom ? () => audio.deleteCustomSound(clip.id) : null,
                  );
                }

                // Add Custom Sound Tile
                return InkWell(
                  onTap: () async {
                    final success = await audio.pickAndAddCustomSound();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Custom sound added successfully!')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: AppColors.primary, size: 36),
                        SizedBox(height: 8),
                        Text(
                          '+ ADD SOUND',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'MP3, WAV, OGG',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
