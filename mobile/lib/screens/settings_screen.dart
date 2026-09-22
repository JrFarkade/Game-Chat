import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedServer = prefs.getString(AppConstants.prefsServerUrlKey) ?? AppConstants.defaultServerUrl;
    _serverController.text = savedServer;
  }

  Future<void> _saveServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final newUrl = _serverController.text.trim();
    if (newUrl.isNotEmpty) {
      await prefs.setString(AppConstants.prefsServerUrlKey, newUrl);
      if (mounted) {
        context.read<SignalingService>().connect(newUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server URL updated and reconnecting...')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final webrtc = context.watch<WebRtcService>();
    final audio = context.watch<AudioService>();
    final signaling = context.watch<SignalingService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Voice Settings
          _buildSectionHeader('VOICE & MICROPHONE'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: AppColors.primary,
                  title: const Text('Push To Talk (PTT)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Hold button to transmit audio', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  value: webrtc.isPttEnabled,
                  onChanged: (val) async {
                    webrtc.updateAudioSettings(pttEnabled: val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(AppConstants.prefsPttEnabledKey, val);
                  },
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                SwitchListTile(
                  activeColor: AppColors.primary,
                  title: const Text('Echo Cancellation', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Prevents game speaker feedback into mic', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  value: webrtc.echoCancellation,
                  onChanged: (val) {
                    webrtc.updateAudioSettings(echoCancellation: val);
                  },
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                SwitchListTile(
                  activeColor: AppColors.primary,
                  title: const Text('Noise Suppression', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Filters out background noise and fans', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  value: webrtc.noiseSuppression,
                  onChanged: (val) {
                    webrtc.updateAudioSettings(noiseSuppression: val);
                  },
                ),
                const Divider(color: AppColors.cardBorder, height: 1),
                SwitchListTile(
                  activeColor: AppColors.primary,
                  title: const Text('Automatic Gain Control', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Normalizes microphone volume', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  value: webrtc.autoGainControl,
                  onChanged: (val) {
                    webrtc.updateAudioSettings(autoGainControl: val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Audio Volumes
          _buildSectionHeader('VOLUME LEVELS'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Voice Volume', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${(audio.voiceVolume * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: audio.voiceVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.cardBorder,
                  onChanged: (val) => audio.setVoiceVolume(val),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Soundboard Volume', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${(audio.soundboardVolume * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: audio.soundboardVolume,
                  min: 0.0,
                  max: 1.0,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.cardBorder,
                  onChanged: (val) => audio.setSoundboardVolume(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Signaling Server & Network
          _buildSectionHeader('SERVER & NETWORK CONNECTION'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cloudflare Backend URL',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.card,
                    hintText: 'https://your-worker.workers.dev',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, color: AppColors.greenActive),
                      onPressed: _saveServerUrl,
                      tooltip: 'Save URL',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Quick Environment Switchers
                Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.cloud_done, size: 14, color: AppColors.greenActive),
                        label: const Text('Cloudflare Edge', style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.cardBorder),
                        onPressed: () {
                          _serverController.text = AppConstants.defaultServerUrl;
                          _saveServerUrl();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.developer_mode, size: 14, color: AppColors.yellowWarning),
                        label: const Text('Local Wrangler', style: TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.cardBorder),
                        onPressed: () {
                          _serverController.text = AppConstants.devLocalServerUrl;
                          _saveServerUrl();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Status: ${signaling.isConnected ? "🟢 Connected to Cloudflare Edge" : "🔴 Disconnected"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: signaling.isConnected ? AppColors.greenActive : AppColors.redMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('TEST & RECONNECT'),
                    onPressed: _isTestingConnection
                        ? null
                        : () async {
                            setState(() => _isTestingConnection = true);
                            final ok = await signaling.checkServerHealth(_serverController.text.trim());
                            if (mounted) {
                              setState(() => _isTestingConnection = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Connected to Cloudflare Backend!' : 'Could not reach backend URL'),
                                  backgroundColor: ok ? AppColors.greenActive : AppColors.redMuted,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
