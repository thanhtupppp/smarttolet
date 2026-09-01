import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'controllers/kiosk_controller.dart';
import 'screens/kiosk_home_screen.dart';
import 'services/settings_service.dart';
import 'theme/kiosk_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request Camera Permission on startup
  try {
    await Permission.camera.request();
  } catch (_) {}

  // Fullscreen Kiosk Mode configuration
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final settingsService = await SettingsService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => KioskController(settingsService),
        ),
      ],
      child: const SmartToiletKioskApp(),
    ),
  );
}

class SmartToiletKioskApp extends StatelessWidget {
  const SmartToiletKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Toilet Kiosk',
      debugShowCheckedModeBanner: false,
      theme: KioskTheme.darkTheme,
      home: const KioskHomeScreen(),
    );
  }
}
