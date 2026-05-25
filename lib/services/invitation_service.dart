import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvitationService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  Future<Map<String, dynamic>> _myUser() async {
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data() ?? {});
  }

  /// Send an invite to `toUid` for `roomCode`
Future<void> sendInvite({
  required String toUid,
  required String roomCode,
  String? message,
}) async {
  if (toUid == uid) return;

  final room = roomCode.trim().toUpperCase();

  final fromSnap = await _db.collection('users').doc(uid).get();
  final fromData = fromSnap.data() ?? {};
  final fromName = (fromData['username'] ?? 'Player') as String;

  final toUserRef = _db.collection('users').doc(toUid);
  final inviteRef = toUserRef.collection('invites').doc(room); // ✅ unique per (toUid, room)
  final roomRef = _db.collection('rooms').doc(room);

  await _db.runTransaction((tx) async {
    // 1) verify receiver exists & check their currentRoom
    final toSnap = await tx.get(toUserRef);
    if (!toSnap.exists) {
      throw Exception("User does not exist.");
    }

    final toData = toSnap.data() ?? {};
    final toCurrentRoom = (toData['currentRoom'] as String?)?.toUpperCase();

    if (toCurrentRoom != null && toCurrentRoom == room) {
      throw Exception("That user is already in this room.");
    }

    // 2) verify room exists (optional but recommended)
    final roomSnap = await tx.get(roomRef);
    if (!roomSnap.exists) {
      throw Exception("Room does not exist.");
    }

    // 3) enforce ONE invite per (user, room)
    final existing = await tx.get(inviteRef);

    if (existing.exists) {
      final ex = existing.data() ?? {};
      final status = (ex['status'] ?? 'pending').toString();

      if (status == 'pending') {
        // Just refresh it (no duplicate)
        tx.update(inviteRef, {
          'fromUid': uid,
          'fromName': fromName,
          'updatedAt': FieldValue.serverTimestamp(),
          'message': message ?? (ex['message'] ?? ''),
        });
        return;
      }

      // If accepted/declined/expired → overwrite to new pending
      tx.set(inviteRef, {
        'roomCode': room,
        'fromUid': uid,
        'fromName': fromName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'message': message ?? '',
      });
      return;
    }

    // 4) create new invite
    tx.set(inviteRef, {
      'roomCode': room,
      'fromUid': uid,
      'fromName': fromName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'message': message ?? '',
    });
  });
}


  /// Decline an invite (recipient action)
  Future<void> declineInvite({
    required String toUid,
    required String inviteId,
  }) async {
    if (toUid != uid) return;

    final ref = _db.collection('users').doc(uid).collection('invites').doc(inviteId);
    await ref.update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept invite:
  /// 1) verify room exists
  /// 2) add player to room.players
  /// 3) set users/{uid}.currentRoom
  /// 4) mark invite accepted
  ///
  /// Uses a transaction to reduce race conditions.
Future<String?> acceptInvite({
  required String inviteId,
}) async {
  final userRef = _db.collection('users').doc(uid);
  final inviteRef = userRef.collection('invites').doc(inviteId);

  return _db.runTransaction<String?>((tx) async {
    final userSnap = await tx.get(userRef);
    final inviteSnap = await tx.get(inviteRef);

    if (!inviteSnap.exists) return null;

    final invite = (inviteSnap.data() ?? {}) as Map<String, dynamic>;
    final status = (invite['status'] ?? '') as String;

    // Only accept pending
    if (status != 'pending') return null;

    final String roomCode = (invite['roomCode'] ?? '') as String;
    if (roomCode.isEmpty) {
      tx.update(inviteRef, {'status': 'declined'});
      return null;
    }

    final String? currentRoom = (userSnap.data()?['currentRoom'] as String?);

    // ✅ If already in THIS room → treat as success (idempotent)
    if (currentRoom != null && currentRoom.toUpperCase() == roomCode.toUpperCase()) {
      tx.update(inviteRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return roomCode;
    }

    // ✅ If already in ANOTHER room → block
    if (currentRoom != null && currentRoom.isNotEmpty) {
      tx.update(inviteRef, {'status': 'declined'});
      return null;
    }

    final roomRef = _db.collection('rooms').doc(roomCode);
    final roomSnap = await tx.get(roomRef);

    if (!roomSnap.exists) {
      tx.update(inviteRef, {'status': 'declined'});
      return null;
    }

    final myName = (userSnap.data()?['username'] ?? 'Player') as String;

    final playerMap = {
      'id': uid,
      'name': myName,
      'isHost': false,
      'role': 'operative',
      'ready': false,
      'team': 'none',
    };

    // ✅ Atomic add (won’t overwrite other updates)
    tx.update(roomRef, {
      'players': FieldValue.arrayUnion([playerMap]),
    });

    // ✅ Set currentRoom
    tx.update(userRef, {'currentRoom': roomCode});

    // ✅ Mark accepted
    tx.update(inviteRef, {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    return roomCode;
  });
}

}
