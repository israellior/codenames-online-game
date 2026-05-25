import 'package:flutter/material.dart';
import 'game_theme.dart';

class GameThemeProvider extends InheritedWidget {
  final GameTheme theme;

  const GameThemeProvider({
    super.key,
    required this.theme,
    required Widget child,
  }) : super(child: child);

  static GameTheme of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<GameThemeProvider>();
    assert(provider != null, 'GameThemeProvider not found');
    return provider!.theme;
  }

  @override
  bool updateShouldNotify(GameThemeProvider oldWidget) {
    return oldWidget.theme != theme;
  }
}
