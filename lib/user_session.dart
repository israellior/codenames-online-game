// lib/user_session.dart

/// For now: simple in-memory user session.
/// Later you can set these from a login / profile screen.
String currentUserId = "player_${DateTime.now().millisecondsSinceEpoch}";
String currentUsername = "Player";
//String? currentRoom123 = null;