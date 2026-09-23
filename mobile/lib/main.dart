import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/signaling_service.dart';
import 'services/webrtc_service.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark status bar / navigation bar for gaming aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const GameChatApp());
}

class GameChatApp extends StatelessWidget {
  const GameChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SignalingService>(
          create: (_) => SignalingService(),
        ),
        ChangeNotifierProxyProvider<SignalingService, WebRtcService>(
          create: (ctx) => WebRtcService(ctx.read<SignalingService>()),
          update: (ctx, signaling, previous) => previous ?? WebRtcService(signaling),
        ),
        ChangeNotifierProxyProvider2<SignalingService, WebRtcService, AudioService>(
          create: (ctx) => AudioService(ctx.read<SignalingService>(), ctx.read<WebRtcService>()),
          update: (ctx, signaling, webrtc, previous) =>
              (previous ?? AudioService(signaling, webrtc))..updateWebRtc(webrtc),
        ),
      ],
      child: MaterialApp(
        title: 'GameChat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.primary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.primaryHover,
            surface: AppColors.surface,
            error: AppColors.redMuted,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          fontFamily: 'sans-serif',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
