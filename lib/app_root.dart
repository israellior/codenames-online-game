import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/game_theme.dart';
import 'theme/game_theme_provider.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (!authSnap.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoginScreen(),
          );
        }

        final uid = authSnap.data!.uid;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final data = userSnap.data!.data() as Map<String, dynamic>?;

            final profileCompleted = data?['profileCompleted'] == true;
            final view = data?['gameView']; // 👈 NO default here

            GameTheme theme;
            switch (view) {
              case 'red':
                theme = GameTheme.red();
                break;
              case 'blue':
                theme = GameTheme.blue();
                break;
              default:
                theme = GameTheme.defaultView();} // 👈 neutral

            return GameThemeProvider(
              theme: theme,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
              home: profileCompleted
                  ? const HomeScreen()
                  : const LoginScreen(initialStep: AuthStep.completeProfile),

              ),
            );
          },
        );

      },
    );
  }
}

