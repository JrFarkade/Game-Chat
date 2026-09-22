import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/foreground_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../utils/constants.dart';
import '../utils/room_code_gen.dart';
import 'join_room_screen.dart';
import 'settings_screen.dart';
import 'voice_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _requestRequiredPermissions();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(AppConstants.prefsUsernameKey);
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
    } else {
      _usernameController.text = 'Player_${(100 + (DateTime.now().millisecondsSinceEpoch % 900))}';
    }

    final savedServer = prefs.getString(AppConstants.prefsServerUrlKey) ?? AppConstants.defaultServerUrl;
    if (mounted) {
      context.read<SignalingService>().connect(savedServer);
    }
  }

  Future<void> _requestRequiredPermissions() async {
    // Request microphone and notification permissions upfront
    await [
      Permission.microphone,
      Permission.notification,
    ].request();
  }

  Future<void> _saveUsername(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefsUsernameKey, name.trim());
  }

  Future<void> _createRoom() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    // Check mic permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final res = await Permission.microphone.request();
      if (!res.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required for voice chat')),
        );
        return;
      }
    }

    final signaling = context.read<SignalingService>();
    if (!signaling.isConnected) {
      _showServerConfigDialog();
      return;
    }

    setState(() => _isLoading = true);
    await _saveUsername(username);

    final serverCode = await signaling.createRoomOnServer();
    final roomCode = serverCode ?? RoomCodeGen.generate();
    final webrtc = context.read<WebRtcService>();

    try {
      final existingPeers = await signaling.joinRoom(roomCode, username);
      await webrtc.initLocalStreamAndJoin(existingPeers);

      // Start Android native Foreground Service for gaming in background
      await ForegroundService.start(roomCode: roomCode, username: username);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceRoomScreen(roomCode: roomCode, username: username),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating room: $e')),
        );
      }
    }
  }

  void _showServerConfigDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString(AppConstants.prefsServerUrlKey) ?? AppConstants.defaultServerUrl;
    final controller = TextEditingController(text: currentUrl);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Server Connection', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Cloudflare Worker URL (e.g. https://your-worker.workers.dev) or local development server.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                hintText: 'https://game-chat.jrfarkade.workers.dev',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('CONNECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                final p = await SharedPreferences.getInstance();
                await p.setString(AppConstants.prefsServerUrlKey, newUrl);
                if (mounted) {
                  context.read<SignalingService>().connect(newUrl);
                }
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
    final signaling = context.watch<SignalingService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text(
              'GAME CHAT',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0),
            ),
          ],
        ),
        actions: [
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Gaming Icon Header
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 25,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.headset_mic, size: 48, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // Username input
              const Text(
                'ENTER USERNAME',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _usernameController,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: 'e.g. Sahil',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Create Room Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                  shadowColor: AppColors.primaryGlow,
                ),
                onPressed: _isLoading ? null : _createRoom,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'CREATE ROOM',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
              ),
              const SizedBox(height: 14),

              // Join Room Button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final username = _usernameController.text.trim();
                  if (username.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a username first')),
                    );
                    return;
                  }
                  if (!signaling.isConnected) {
                    _showServerConfigDialog();
                    return;
                  }
                  _saveUsername(username);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JoinRoomScreen(username: username),
                    ),
                  );
                },
                child: const Text(
                  'JOIN ROOM',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ),
              const Spacer(),

              // Tappable Server connection indicator
              Center(
                child: InkWell(
                  onTap: _showServerConfigDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: signaling.isConnected ? AppColors.greenActive.withValues(alpha: 0.5) : AppColors.redMuted.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: signaling.isConnected ? AppColors.greenActive : AppColors.redMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          signaling.isConnected
                              ? 'Server: Connected'
                              : 'Server: Offline (Tap to Configure)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: signaling.isConnected ? AppColors.greenActive : AppColors.redMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

