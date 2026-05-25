import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final CollectionReference _users =
      FirebaseFirestore.instance.collection('users');

  /// Ensures Firestore user document exists.
  /// Returns true if user was newly created.
  static Future<bool> ensureUserDoc(User user) async {
    final ref = _users.doc(user.uid);
    final doc = await ref.get();

    if (doc.exists) return false;

    await ref.set({
      'uid': user.uid,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'email': user.email,
      'phone': user.phoneNumber,
      'username': null,
      'profileCompleted': false,
      'createdAt': Timestamp.now(),
      'currentRoom': null,
      'gameView': "default",
          // 🔹 GAME STATS
      'wins': 0,
      'losses': 0,
      'gamesPlayed': 0
    });

    return true;
  }

  static Future<void> updateStats({
  required String uid,
  required bool won,
}) async {
  final ref = _users.doc(uid);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;

    final wins = data['wins'] ?? 0;
    final losses = data['losses'] ?? 0;
    final games = data['gamesPlayed'] ?? 0;

    tx.update(ref, {
      'wins': won ? wins + 1 : wins,
      'losses': !won ? losses + 1 : losses,
      'gamesPlayed': games + 1,
    });
  });
}

}

