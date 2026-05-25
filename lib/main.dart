import 'package:codename_app/screens/home_screen.dart';
import 'package:codename_app/theme/game_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
//import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/local_game_screen.dart';
import 'app_root.dart';
import 'package:codename_app/theme/game_theme.dart';
import 'package:codename_app/theme/game_theme_provider.dart';




Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    GameThemeProvider(
      theme: GameTheme.defaultView(), // 👈 default theme
      child: const CodenameApp(),
    ),
  );
}

class CodenameApp extends StatelessWidget {
  const CodenameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codename App',
      debugShowCheckedModeBanner: false, 
      home: const AppRoot(),
    );
  }
}
