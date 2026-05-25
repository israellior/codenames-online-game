import 'dart:math';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/room_service.dart';
import '../services/board_service.dart';
import '../widgets/auth_card.dart';
import '../widgets/fade_slide_route.dart';
import '../theme/game_theme_provider.dart';
import '../theme/game_theme.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'game_board_screen.dart';
import 'home_screen.dart';
import '../game/game_state.dart';

enum LobbyEventType {
  join,
  leave,
  info,
}

class LobbyScreen extends StatefulWidget {
  final String? roomCode;
  final bool createNew;
  final bool autoLeave; // 👈 ADD

  const LobbyScreen({
    super.key,
    this.roomCode,
    this.createNew = false,
    this.autoLeave = false, // 👈 ADD
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String? roomCode;
  bool alreadyNavigated = false;
  bool _isLeaving = false;
  bool _showQr = false;

  bool _checkingMembership = false;
  bool _everSawMeInPlayers = false;

  List<Map<String, dynamic>>? _prevPlayers;
  final Queue<({String text, LobbyEventType type})> _snackQueue =
    Queue<({String text, LobbyEventType type})>();  
  bool _isShowingSnack = false;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    widget.createNew ? _createRoom() : roomCode = widget.roomCode;

        if (widget.autoLeave) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final roomRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomCode);

        final snap = await roomRef.get();
        if (!snap.exists) {
          _clearRoomAndGoHome();
          return;
        }

        final data = snap.data() as Map<String, dynamic>;
        final players =
            List<Map<String, dynamic>>.from(data['players']);
        final hostId = data['hostId'];

        await leaveRoom(roomRef, players, hostId);
      });
    }
  }



void _openPlayerEditor(
  BuildContext context,
  Map<String, dynamic> player,
  DocumentReference roomRef,
  List<Map<String, dynamic>> allPlayers,
) {
  bool isBot(Map<String, dynamic> p) =>
      (p['id'] as String).startsWith('bot_');

  bool hasOperativeBotInTeam(
    String team,
    String currentBotId,
    List<Map<String, dynamic>> players,
  ) {
    return players.any((p) {
      return isBot(p) &&
          p['id'] != currentBotId &&
          p['team'] == team &&
          p['role'] == 'operative';
    });
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player['name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // ───────── TEAM ─────────
            const Text("Team", style: TextStyle(color: Colors.white70)),
            Wrap(
              spacing: 8,
              children: ['red', 'blue', 'none'].map((team) {
                return ChoiceChip(
                  label: Text(team.toUpperCase()),
                  selected: player['team'] == team,
                  onSelected: (_) async {
                    final teamTarget = team;

                    await updatePlayer(
                      player['id'],
                      (p) => {...p, 'team': team, 'ready': false},
                      allPlayers,
                      roomRef,
                    );

                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // ───────── ROLE ─────────
            const Text("Role", style: TextStyle(color: Colors.white70)),
            Wrap(
              spacing: 8,
              children: ['spymaster', 'operative'].map((role) {
                return ChoiceChip(
                  label: Text(role.toUpperCase()),
                  selected: player['role'] == role,
                  onSelected: (_) async {
                    final bot = isBot(player);
                    final team = player['team'];

                    // 🚫 Switching TO operative must obey bot rule
                    if (bot &&
                        role == 'operative' &&
                        team != 'none') {
                      final conflict = hasOperativeBotInTeam(
                        team,
                        player['id'],
                        allPlayers,
                      );

                      if (conflict) {
                        _showLobbySnack(
                          "Only one operative bot allowed per team",
                          type: LobbyEventType.info,
                        );
                        return;
                      }
                    }

                    await updatePlayer(
                      player['id'],
                      (p) => {...p, 'role': role, 'ready': false},
                      allPlayers,
                      roomRef,
                    );

                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}



List<Widget> _buildTeamSection({
  required String title,
  required Color color,
  required List<Map<String, dynamic>> players,
  required bool isHost,
  required DocumentReference roomRef,
  required List<Map<String, dynamic>> allPlayers,
}) {
  if (players.isEmpty) return [];

  return [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
    ...players.map(
      (p) => _PlayerTile(
        player: p,
        isHost: isHost,
        isMe: p['id'] == uid,
        //onToggleReady: () => toggleReady(allPlayers, roomRef),
        //onSet: (fn) => updatePlayer(p['id'], fn, allPlayers, roomRef),
        onKick: () async {
          final ok = await _confirmAction(
            title: "Kick player?",
            message: "Are you sure you want to remove ${p['name']} from the room?",
            confirmText: "Kick",
          );

          if (!ok) return;

          await kickPlayer(p['id'], roomRef, allPlayers);
        },
        onEdit: () => _openPlayerEditor(context,p,roomRef,allPlayers,),
      ),
    ),
  ];
}

GameTheme resolveRoomTheme({
  required List<Map<String, dynamic>> players,
  required String uid,
}) {
  final me = players.firstWhere(
    (p) => p['id'] == uid,
    orElse: () => {},
  );

  switch (me['team']) {
    case 'red':
      return GameTheme.red();
    case 'blue':
      return GameTheme.blue();
    default:
      // ✅ unassigned / spectator → neutral UI
      return GameTheme.defaultView();
  }
}

bool hasMixedOperatives(List<Map<String, dynamic>> team) {
  final hasHuman = team.any((p) =>
      !(p['id'] as String).startsWith('bot_') &&
      p['role'] == 'operative');

  final hasBot = team.any((p) =>
      (p['id'] as String).startsWith('bot_') &&
      p['role'] == 'operative');

  return hasHuman && hasBot;
}


bool canStartGame(List<Map<String, dynamic>> players) {
  // Rule 1: total players
  if (players.length < 4) return false;

  final red = players.where((p) => p['team'] == 'red').toList();
  final blue = players.where((p) => p['team'] == 'blue').toList();

  // Rule 2 & 3: team sizes
  if (red.length < 2 || blue.length < 2) return false;

  // Rule 4 & 5: exactly one spymaster per team
  final redSpymasters =
      red.where((p) => p['role'] == 'spymaster').length;
  final blueSpymasters =
      blue.where((p) => p['role'] == 'spymaster').length;

  if (redSpymasters != 1 || blueSpymasters != 1) return false;

  if (hasMixedOperatives(red)) return false;
  if (hasMixedOperatives(blue)) return false;


  return true;
}

Future<void> _verifyMembershipOrRepair(DocumentReference roomRef) async {
  if (_checkingMembership || alreadyNavigated || !mounted) return;
  _checkingMembership = true;

  try {
    // Force SERVER truth (not cache)
    final snap = await roomRef.get(const GetOptions(source: Source.server));
    if (!snap.exists) {
      await _clearRoomAndGoHome();
      return;
    }

    final data = snap.data() as Map<String, dynamic>;
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
    final inRoom = players.any((p) => p['id'] == uid);

    if (inRoom) {
      // ✅ Repair: you ARE in the room, so currentRoom must be this code
      final code = snap.id;
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"currentRoom": code});

      // Don’t navigate away
      return;
    }

    // ✅ Server confirms you're not in the room → now it's safe to clear
    await _clearRoomAndGoHome();
  } finally {
    _checkingMembership = false;
  }
}


Future<void> kickPlayer(
  String playerId,
  DocumentReference roomRef,
  List<Map<String, dynamic>> players,
) async {
  // Remove the kicked player
  final updated = players.where((p) => p['id'] != playerId).toList();

  // Helper: identify humans
  bool isHuman(Map<String, dynamic> p) =>
      !(p['id'] as String).startsWith('bot_');

  // Count remaining humans
  final remainingHumans = updated.where(isHuman).toList();

  // 🧹 Delete room ONLY if no humans remain
  if (remainingHumans.isEmpty) {
    await roomRef.delete();

    // Clean kicked user's session if human
    if (!playerId.startsWith('bot_')) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(playerId)
          .update({"currentRoom": null});
    }

    // Navigate only if *I* was kicked
    if (playerId == uid && mounted) {
      Navigator.pushReplacement(
        context,
        FadeSlideRoute(
          page: const HomeScreen(),
        ),
      );
    }

    return;
  }

  // ✅ Otherwise: just update players (NO host logic here)
  await roomRef.update({"players": updated});

  // Clean kicked user's session if human
  if (!playerId.startsWith('bot_')) {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(playerId)
        .update({"currentRoom": null});
  }

  // Navigate only if *I* was kicked
  if (playerId == uid && mounted) {
    Navigator.pushReplacement(
      context,
      FadeSlideRoute(
        page: const HomeScreen(),
      ),
    );
  }
}

Future<void> autoBalanceTeams(
  List<Map<String, dynamic>> players, // unused
  DocumentReference roomRef,
) async {
  await _txUpdatePlayers(roomRef, (curr) {
    if (curr.length < 2) return curr;

    bool isBot(Map<String, dynamic> p) => (p['id'] as String).startsWith('bot_');

    final random = Random();
    final shuffled = [...curr]..shuffle(random);

    final half = (shuffled.length / 2).ceil();
    final redTeam = shuffled.take(half).toList();
    final blueTeam = shuffled.skip(half).toList();
    if (redTeam.isEmpty || blueTeam.isEmpty) return curr;

    final redSpymaster = redTeam[random.nextInt(redTeam.length)]['id'];
    final blueSpymaster = blueTeam[random.nextInt(blueTeam.length)]['id'];

    bool redBotOperativeUsed = false;
    bool blueBotOperativeUsed = false;

    return curr.map((p) {
      final u = {...p};

      final inRed = redTeam.any((x) => x['id'] == p['id']);
      final inBlue = blueTeam.any((x) => x['id'] == p['id']);

      if (inRed) {
        u['team'] = 'red';
        if (p['id'] == redSpymaster) {
          u['role'] = 'spymaster';
        } else if (isBot(p)) {
          if (!redBotOperativeUsed) {
            u['role'] = 'operative';
            redBotOperativeUsed = true;
          } else {
            u['role'] = 'spymaster';
          }
        } else {
          u['role'] = 'operative';
        }
      }

      if (inBlue) {
        u['team'] = 'blue';
        if (p['id'] == blueSpymaster) {
          u['role'] = 'spymaster';
        } else if (isBot(p)) {
          if (!blueBotOperativeUsed) {
            u['role'] = 'operative';
            blueBotOperativeUsed = true;
          } else {
            u['role'] = 'spymaster';
          }
        } else {
          u['role'] = 'operative';
        }
      }

      u['ready'] = false;
      return u;
    }).toList();
  });
}



  // ───────────────────────── ROOM CREATION ─────────────────────────

  Future<void> _createRoom() async {
    final code = RoomService.generateRoomCode();
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(code);
    final username = await _getUsername(uid);


    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .update({"currentRoom": code});

    await roomRef.set({
      'createdAt': Timestamp.now(),
      'state': 'lobby',
      'hostId': uid,
      'settings': {
        'turnTime': null,
        'language': 'he',
        'selectedPackIds': ['classic_easy_he'],
      },
      'players': [
        {
          'id': uid,
          'name': username, // ✅ Firestore username
          'isHost': true,
          'role': 'spymaster',
          'team': 'red',
          'ready': false,
        }
      ],
    });

    setState(() => roomCode = code);
  }

  // ───────────────────────── ACTIONS ─────────────────────────

Future<void> _txUpdatePlayers(
  DocumentReference roomRef,
  List<Map<String, dynamic>> Function(List<Map<String, dynamic>> curr) mutate,
) async {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(roomRef);
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final currPlayers =
        List<Map<String, dynamic>>.from((data['players'] ?? const []) as List);

    final next = mutate(currPlayers);

    tx.update(roomRef, {'players': next});
  });
}


Future<String> _getUsername(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  final data = doc.data();
  return data?['username'] ?? 'Player';
}

Future<void> toggleReady(
  List<Map<String, dynamic>> players, // unused
  DocumentReference roomRef,
) async {
  await _txUpdatePlayers(roomRef, (curr) {
    return curr.map((p) {
      if (p['id'] == uid) {
        return {...p, 'ready': !(p['ready'] ?? false)};
      }
      return p;
    }).toList();
  });
}


Future<void> addBot(
  List<Map<String, dynamic>> players, // unused
  DocumentReference roomRef,
) async {
  await _txUpdatePlayers(roomRef, (curr) {
    final bots = curr.where((p) => (p['id'] as String).startsWith('bot_')).toList();
    if (bots.length >= 3) {
      _showLobbySnack("Maximum of 3 bots allowed", type: LobbyEventType.info);
      return curr;
    }

    final botId = "bot_${Random().nextInt(9999)}";
    return [
      ...curr,
      {
        'id': botId,
        'name': '🤖 Bot',
        'isHost': false,
        'role': 'operative',
        'team': 'none',
        'ready': false,
      }
    ];
  });
}


bool canAssignBotToTeam({
  required String botId,
  required String team,
  required List<Map<String, dynamic>> players,
}) {
  return players.where((p) {
    final isBot = (p['id'] as String).startsWith('bot_');
    final sameTeam = p['team'] == team;
    final operative = p['role'] == 'operative';
    final notSameBot = p['id'] != botId;

    return isBot && sameTeam && operative && notSameBot;
  }).isEmpty;
}

Future<void> updatePlayer(
  String playerId,
  Map<String, dynamic> Function(Map<String, dynamic>) fn,
  List<Map<String, dynamic>> players, // (unused now, keep signature if you want)
  DocumentReference roomRef,
) async {
  await _txUpdatePlayers(roomRef, (curr) {
    return curr.map((p) {
      if (p['id'] == playerId) return fn(p);
      return p;
    }).toList();
  });
}

Future<void> _clearHistory(DocumentReference roomRef) async {
  const int batchSize = 200;

  while (true) {
    final snap = await roomRef
        .collection('history')
        .limit(batchSize)
        .get(const GetOptions(source: Source.server)); // 👈 important

    if (snap.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    if (snap.docs.length < batchSize) break;
  }
}


Future<void> startGame(
  String lang,
  List<String> selectedPackIds,
  DocumentReference roomRef,
) async {
  await _clearHistory(roomRef);
  await _clearSpymasterPlan(roomRef);

  final newState = GameState.newGame(
    lang,
    selectedPackIds: selectedPackIds,
  );

  await roomRef.update({
    'state': 'in_game',
    'winner': null,
    'gameState': newState.toMap(),
    'botTurnLock': null,
    'currentTurnId': null,
    'statsProcessed': false,
  });
}



Future<void> updatePlayerRelationStats({
  required String ownerUid,
  required String otherUid,
  required bool sameTeam,
  required bool ownerWon,
}) async {
  final ref =
      FirebaseFirestore.instance.collection('users').doc(ownerUid);

  final String basePath =
      sameTeam ? 'recentPlayers.$otherUid.together'
               : 'recentPlayers.$otherUid.against';

  await ref.update({
    '$basePath.games': FieldValue.increment(1),
    '$basePath.wins':
        ownerWon ? FieldValue.increment(1) : FieldValue.increment(0),
    '$basePath.losses':
        !ownerWon ? FieldValue.increment(1) : FieldValue.increment(0),
  });
}

Future<void> _clearSpymasterPlan(DocumentReference roomRef) async {
  for (final team in ['red', 'blue']) {
    final targets = await roomRef.collection('spymasterPlan').doc(team).collection('targets').get();
    final clues = await roomRef.collection('spymasterPlan').doc(team).collection('clues').get();

    final batch = FirebaseFirestore.instance.batch();
    for (final d in targets.docs) batch.delete(d.reference);
    for (final d in clues.docs) batch.delete(d.reference);
    await batch.commit();
  }
}

Future<void> _clearPlayerChat(DocumentReference roomRef) async {
  const int batchSize = 200;

  while (true) {
    final snap = await roomRef
        .collection('playerChat')
        .limit(batchSize)
        .get(const GetOptions(source: Source.server));

    if (snap.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    if (snap.docs.length < batchSize) break;
  }
}

/// Call this before deleting the room doc
Future<void> _deleteRoomFully(DocumentReference roomRef) async {
  // Delete subcollections first
  await _clearHistory(roomRef);
  await _clearPlayerChat(roomRef);
  await _clearSpymasterPlan(roomRef);

  // Now delete the room doc itself
  await roomRef.delete();
}


Future<void> leaveRoom(
  DocumentReference roomRef,
  List<Map<String, dynamic>> players,
  String hostId,
) async {
  if (_isLeaving) return;
  _isLeaving = true;
  if (mounted) setState(() {});

  final uid = FirebaseAuth.instance.currentUser!.uid;

  final snap = await roomRef.get();
  if (!snap.exists) {
    _clearRoomAndGoHome();
    return;
  }

  final data = snap.data() as Map<String, dynamic>;
  final String state = data['state'] ?? 'lobby';

  final me = players.firstWhere(
    (p) => p['id'] == uid,
    orElse: () => {},
  );

  // Remaining players
  final remaining = players.where((p) => p['id'] != uid).toList();
  final remainingHumans =
      remaining.where((p) => !(p['id'] as String).startsWith('bot_')).toList();

  final bool hostIsLastHuman =
      state == 'in_game' && uid == hostId && remainingHumans.isEmpty;

  // ─────────────────────────────
  // 🔴 HOST IS LAST HUMAN → PROCESS STATS
  // ─────────────────────────────
  if (hostIsLastHuman && me.isNotEmpty) {
    final String myTeam = (me['team'] ?? 'red').toString();
    final String winner = myTeam == 'red' ? 'blue' : 'red';

    final rawGameState = data['gameState'];
    if (rawGameState is Map) {
      final gs = Map<String, dynamic>.from(rawGameState);
      gs['isGameOver'] = true;
      gs['winnerTeam'] = winner;
      await roomRef.update({'gameState': gs});
    }

    for (final p in players) {
      final String playerId = p['id'];
      if (playerId.startsWith('bot_')) continue;

      final bool playerWon = p['team'] == winner;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(playerId)
          .update({
        'gamesPlayed': FieldValue.increment(1),
        'wins': playerWon ? FieldValue.increment(1) : FieldValue.increment(0),
        'losses': !playerWon ? FieldValue.increment(1) : FieldValue.increment(0),
      });

      for (final other in players) {
        if (other['id'] == playerId) continue;
        if (other['id'].startsWith('bot_')) continue;

        await updatePlayerRelationStats(
          ownerUid: playerId,
          otherUid: other['id'],
          sameTeam: other['team'] == p['team'],
          ownerWon: playerWon,
        );
      }
    }
    await _deleteRoomFully(roomRef);
    //await roomRef.delete();
    _clearRoomAndGoHome();
    return;
  }

  // ─────────────────────────────
  // 🟡 BUILD FINAL PLAYERS LIST
  // ─────────────────────────────
  List<Map<String, dynamic>> updatedPlayers = remaining;

  final bool hostLeft = uid == hostId;

  // ─────────────────────────────
  // 🔴 HOST LEAVES → REASSIGN (LOBBY + GAME)
  // ─────────────────────────────
  if (hostLeft && remainingHumans.isNotEmpty) {
    final newHost = remainingHumans.first;

    updatedPlayers = remaining.map((p) {
      if (p['id'] == newHost['id']) {
        return {
          ...p,
          'isHost': true,
          if (state == 'in_game') 'role': 'spymaster',
        };
      }
      return {...p, 'isHost': false};
    }).toList();

    await roomRef.update({'hostId': newHost['id']});
  }

  // ─────────────────────────────
  // 🔴 IN-GAME → FORCE GAME OVER
  // ─────────────────────────────
  if (state == 'in_game' && me.isNotEmpty) {
    final String myTeam = (me['team'] ?? 'red').toString();
    final String winner = myTeam == 'red' ? 'blue' : 'red';

    final rawGameState = data['gameState'];
    if (rawGameState is Map) {
      final Map<String, dynamic> gs = Map<String, dynamic>.from(rawGameState);
      gs['isGameOver'] = true;
      gs['winnerTeam'] = winner;
      gs['waitingForHint'] = false;
      gs['remainingGuesses'] = 0;

      await roomRef.update({
        'state': 'game_over', // ✅ ADD THIS
        'winner': winner,     // optional but consistent
        'gameState': gs,
        'lastBoardEvent': {
          'nonce': DateTime.now().millisecondsSinceEpoch,
          'text': '${me['name']} left the game — $winner team wins!',
          'bg': winner,
        },
      });
      // ✅ STATS ARE DONE HERE
      /*await _processStatsOnce(
        roomRef: roomRef,
        players: players,
        winner: winner,
      );*/
    }
  }

  // ─────────────────────────────
  // REMOVE USER SESSION
  // ─────────────────────────────
  await FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .update({"currentRoom": null});

  // 🧹 Cleanup
  if (updatedPlayers.isEmpty ||
      updatedPlayers.where((p) => !(p['id'] as String).startsWith('bot_')).isEmpty) {
    await roomRef.delete();
    _clearRoomAndGoHome();
    return;
  }

  // ✅ SINGLE FINAL WRITE
  await roomRef.update({'players': updatedPlayers});

  _clearRoomAndGoHome();
}

Future<void> _processStatsOnce({
  required DocumentReference roomRef,
  required List<Map<String, dynamic>> players,
  required String winner,
}) async {
  final snap = await roomRef.get();
  if (!snap.exists) return;

  final data = snap.data() as Map<String, dynamic>;

  if (data['statsProcessed'] == true) return;

  // 🔒 lock immediately
  await roomRef.update({'statsProcessed': true});

  // 2️⃣ Update stats
  for (final p in players) {
    final String playerId = p['id'];
    if (playerId.startsWith('bot_')) continue;

    final bool playerWon = p['team'] == winner;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(playerId)
        .update({
          'gamesPlayed': FieldValue.increment(1),
          'wins': playerWon ? FieldValue.increment(1) : FieldValue.increment(0),
          'losses': !playerWon ? FieldValue.increment(1) : FieldValue.increment(0),
        });

    for (final other in players) {
      if (other['id'] == playerId) continue;
      if (other['id'].startsWith('bot_')) continue;

      await updatePlayerRelationStats(
        ownerUid: playerId,
        otherUid: other['id'],
        sameTeam: other['team'] == p['team'],
        ownerWon: playerWon,
      );
    }
  }
}


/*Future<void> leaveRoom(
  DocumentReference roomRef,
  List<Map<String, dynamic>> players,
  String hostId,
) async {
  if (_isLeaving) return;
  _isLeaving = true;
  if (mounted) setState(() {});

  final uid = FirebaseAuth.instance.currentUser!.uid;

  final snap = await roomRef.get();
  if (!snap.exists) {
    _clearRoomAndGoHome();
    return;
  }

  final data = snap.data() as Map<String, dynamic>;
  final String state = data['state'] ?? 'lobby';

  final me = players.firstWhere(
    (p) => p['id'] == uid,
    orElse: () => {},
  );

  // Remaining players (before removal)
  final remaining = players.where((p) => p['id'] != uid).toList();

  final remainingHumans =
      remaining.where((p) => !(p['id'] as String).startsWith('bot_')).toList();

  final bool hostIsLastHuman =
    state == 'in_game' &&
    uid == hostId &&
    remainingHumans.isEmpty;

    // ─────────────────────────────
// 🔴 HOST IS LAST HUMAN → PROCESS STATS NOW
// ─────────────────────────────
if (hostIsLastHuman && me.isNotEmpty) {
  final String myTeam = (me['team'] ?? 'red').toString();
  final String winner = myTeam == 'red' ? 'blue' : 'red';

  // 1️⃣ Mark gameState as finished (for consistency)
  final rawGameState = data['gameState'];
  if (rawGameState is Map) {
    final gs = Map<String, dynamic>.from(rawGameState);
    gs['isGameOver'] = true;
    gs['winnerTeam'] = winner;

    await roomRef.update({
      'gameState': gs,
    });
  }

  // 2️⃣ RUN STATS HERE (host-only fallback)
  for (final p in players) {
    final String playerId = p['id'];
    if (playerId.startsWith('bot_')) continue;

    final bool playerWon = p['team'] == winner;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(playerId)
        .update({
          'gamesPlayed': FieldValue.increment(1),
          'wins': playerWon
              ? FieldValue.increment(1)
              : FieldValue.increment(0),
          'losses': !playerWon
              ? FieldValue.increment(1)
              : FieldValue.increment(0),
        });


    for (final other in players) {
      if (other['id'] == playerId) continue;
      if (other['id'].startsWith('bot_')) continue;

      await updatePlayerRelationStats(
        ownerUid: playerId,
        otherUid: other['id'],
        sameTeam: other['team'] == p['team'],
        ownerWon: playerWon,
      );
    }
  }

  // 3️⃣ Delete room (no humans remain)
  await roomRef.delete();
  _clearRoomAndGoHome();
  return;
}


  // ─────────────────────────────
  // 🔴 HOST LEAVES MID-GAME → REASSIGN HOST FIRST
  // ─────────────────────────────
  if (state == 'in_game' && uid == hostId && remainingHumans.isNotEmpty) {
    final newHost = remainingHumans.first;

    await roomRef.update({
      'hostId': newHost['id'],
      'players': players.map((p) {
        if (p['id'] == newHost['id']) {
          return {
            ...p,
            'isHost': true,
            'role': 'spymaster',//////////////////////////////////////////////////////////////////////////////
          };
        }
        if (p['id'] == uid) {
          return {
            ...p,
            'isHost': false,
          };
        }
        return p;
      }).toList(),
    });
  }

  // ─────────────────────────────
  // 🔴 IN-GAME → FORCE GAME OVER (via gameState only)
  // ─────────────────────────────
  if (state == 'in_game' && me.isNotEmpty) {
    final String myTeam = (me['team'] ?? 'red').toString();
    final String winner = myTeam == 'red' ? 'blue' : 'red';

    final rawGameState = data['gameState'];

    if (rawGameState is Map) {
      final Map<String, dynamic> gs =
          Map<String, dynamic>.from(rawGameState);

      gs['isGameOver'] = true;
      gs['winnerTeam'] = winner;
      gs['waitingForHint'] = false;
      gs['remainingGuesses'] = 0;

      await roomRef.update({
        'gameState': gs,
        'lastBoardEvent': {
          'nonce': DateTime.now().millisecondsSinceEpoch,
          'text': '${me['name']} left the game — $winner team wins!',
          'bg': winner,
        },
      });
    }
  }

  // ─────────────────────────────
  // REMOVE USER SESSION
  // ─────────────────────────────
  await FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .update({"currentRoom": null});

  final hasHumanPlayers = remainingHumans.isNotEmpty;

  // 🧹 Cleanup
  if (remaining.isEmpty || !hasHumanPlayers) {
    await roomRef.delete();
    _clearRoomAndGoHome();
    return;
  }

  // Remove player from list
  await roomRef.update({'players': remaining});

  _clearRoomAndGoHome();
}*/


Future<void> _clearRoomAndGoHome({bool clearCurrentRoom = true}) async {
  if (alreadyNavigated) return;
  alreadyNavigated = true;

  if (clearCurrentRoom) {
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .update({"currentRoom": null});
    } catch (_) {}
  }

  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
}


  List<Map<String, dynamic>> sortTeamWithSpymasterFirst(
  List<Map<String, dynamic>> team,
) {
  final spymaster =
      team.where((p) => p['role'] == 'spymaster').toList();
  final others =
      team.where((p) => p['role'] != 'spymaster').toList();

  return [...spymaster, ...others];
}

Future<bool> _confirmAction({
  required String title,
  required String message,
  String confirmText = "Yes",
  String cancelText = "Cancel",
  Color confirmColor = Colors.redAccent,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return result ?? false;
}

void _handleLobbyChanges(List<Map<String, dynamic>> players) {
  if (_prevPlayers == null) {
    _prevPlayers = players;
    return;
  }

  final prev = {for (var p in _prevPlayers!) p['id']: p};
  final curr = {for (var p in players) p['id']: p};

  final prevHost =
      _prevPlayers!.firstWhere((p) => p['isHost'] == true, orElse: () => {});
  final currHost =
      players.firstWhere((p) => p['isHost'] == true, orElse: () => {});

  // ───────── PLAYER JOINED ─────────
  for (final id in curr.keys) {
    if (!prev.containsKey(id)) {
      _showLobbySnack(
        id == uid
            ? "You joined the room"
            : "${curr[id]!['name']} joined the room",
        type: LobbyEventType.join,
      );
    }
  }

  // ───────── PLAYER LEFT (NEUTRAL & CORRECT) ─────────
  for (final id in prev.keys) {
    if (!curr.containsKey(id)) {
      final name = prev[id]!['name'];

      _showLobbySnack(
        id == uid
            ? "You are no longer in the room"
            : "$name left the room",
        type: LobbyEventType.leave,
      );
    }
  }

  // ───────── HOST CHANGED ─────────
  if (prevHost['id'] != currHost['id'] && currHost.isNotEmpty) {
    _showLobbySnack(
      currHost['id'] == uid
          ? "You are the host now"
          : "${currHost['name']} is the host now",
      type: LobbyEventType.info,
    );
  }

  // ───────── ROLE / TEAM CHANGES (ONLY FOR ME) ─────────
  if (prev.containsKey(uid) && curr.containsKey(uid)) {
    final before = prev[uid]!;
    final after = curr[uid]!;

    if (before['team'] != after['team']) {
      _showLobbySnack(
        "Host changed your team to ${after['team']}",
        type: LobbyEventType.info,
      );
    }

    if (before['role'] != after['role']) {
      _showLobbySnack(
        "Host changed your role to ${after['role']}",
        type: LobbyEventType.info,
      );
    }
  }

  _prevPlayers = players;
}



void _showLobbySnack(
  String text, {
  LobbyEventType type = LobbyEventType.info,
}) {
  _snackQueue.add((text: text, type: type));
  _tryShowNextSnack();
}


void _tryShowNextSnack() {
  if (_isShowingSnack || _snackQueue.isEmpty || !mounted) return;

  _isShowingSnack = true;
  final item = _snackQueue.removeFirst();

  Color? bg;
  switch (item.type) {
    case LobbyEventType.join:
      bg = Colors.green.shade600;
      break;
    case LobbyEventType.leave:
      bg = Colors.redAccent;
      break;
    case LobbyEventType.info:
      bg = null; // default
      break;
  }

  ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text(item.text),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      )
      .closed
      .then((_) {
        _isShowingSnack = false;
        _tryShowNextSnack();
      });
}




  // ───────────────────────── UI ─────────────────────────

@override
Widget build(BuildContext context) {

  if (roomCode == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  final roomRef =
      FirebaseFirestore.instance.collection('rooms').doc(roomCode);

  return Scaffold(
    body: Stack(
      children: [

        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    FadeSlideRoute(page: const HomeScreen()),
                  );
                },
              ),
            ),
          ),
        ),

        // ✅ NO `return` HERE
        SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: roomRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.data!.exists) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _clearRoomAndGoHome();
                });
                return const SizedBox.shrink();
              }

              final data =
                  snapshot.data!.data() as Map<String, dynamic>;
              final players =
                  List<Map<String, dynamic>>.from(data['players']);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleLobbyChanges(players);
              });

              final effectiveTheme = resolveRoomTheme(
                players: players,
                uid: uid,
              );

              final isStillInRoom = players.any((p) => p['id'] == uid);
              if (isStillInRoom) _everSawMeInPlayers = true;

              if (!isStillInRoom) {
                // 🔥 IMPORTANT: do NOT clear immediately.
                // If snapshot is from cache OR we never saw ourselves yet -> verify with server.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _verifyMembershipOrRepair(roomRef);
                });

                return const SizedBox.shrink();
              }

              final hostId = data['hostId'];
              final isHost = uid == hostId;

              // ✅ TEAM SPLIT (CORRECT SCOPE)
              final unassigned =
                  players.where((p) => p['team'] == 'none').toList();
              final redTeam = sortTeamWithSpymasterFirst(
                players.where((p) => p['team'] == 'red').toList(),
              );

              final blueTeam = sortTeamWithSpymasterFirst(
                players.where((p) => p['team'] == 'blue').toList(),
              );

              if (data['state'] == 'in_game') {
                if (_isLeaving || alreadyNavigated) {
                  // בזמן יציאה/ניווט – לא להקפיץ למסך המשחק
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _isLeaving || alreadyNavigated) return;
                    alreadyNavigated = true;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameBoardScreen(roomCode: roomCode!),
                      ),
                    );
                  });
                }
              }

              return GameThemeProvider(
                theme: effectiveTheme,
                child: Stack(
                  children: [
                    _Background(colors: effectiveTheme.background),

                    SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔝 TOP BAR (now in flow)
                                _LobbyTopBar(
                                  logoAsset: effectiveTheme.logoAsset,
                                  textColor: effectiveTheme.textPrimary,
                                  onBack: () {
                                    Navigator.pushReplacement(
                                      context,
                                      FadeSlideRoute(
                                        page: const HomeScreen(),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 20),

                                // 🧊 LOBBY CARD
                                AuthCard(
                                  title: "Lobby • $roomCode",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // 🔳 QR TOGGLE BUTTON
                                      OutlinedButton.icon(
                                        icon: Icon(_showQr ? Icons.close : Icons.qr_code),
                                        label: Text(_showQr ? "Hide QR code" : "Show QR code"),
                                        onPressed: () {
                                          setState(() => _showQr = !_showQr);
                                        },
                                      ),

                                      const SizedBox(height: 12),

                                      // 📦 ANIMATED QR
                                      AnimatedCrossFade(
                                        duration: const Duration(milliseconds: 250),
                                        crossFadeState: _showQr
                                            ? CrossFadeState.showSecond
                                            : CrossFadeState.showFirst,
                                        firstChild: const SizedBox.shrink(),
                                        secondChild: Center(
                                          child: _RoomQrCard(roomCode: roomCode!),
                                        ),
                                      ),


                                      ..._buildTeamSection(
                                        title: "Unassigned",
                                        color: Colors.white70,
                                        players: unassigned,
                                        isHost: isHost,
                                        roomRef: roomRef,
                                        allPlayers: players,
                                      ),

                                      ..._buildTeamSection(
                                        title: "🔴 Red Team",
                                        color: Colors.redAccent,
                                        players: redTeam,
                                        isHost: isHost,
                                        roomRef: roomRef,
                                        allPlayers: players,
                                      ),

                                      ..._buildTeamSection(
                                        title: "🔵 Blue Team",
                                        color: Colors.lightBlueAccent,
                                        players: blueTeam,
                                        isHost: isHost,
                                        roomRef: roomRef,
                                        allPlayers: players,
                                      ),

                                      const SizedBox(height: 16),
                                      if (isHost) ...[
                                        const SizedBox(height: 16),

                                        const Text(
                                          "Game Settings",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),


                                        const SizedBox(height: 12),

                                        // 🌍 Language
                                        DropdownButtonFormField<String>(
                                          value: data['settings']?['language'] ?? 'en',
                                          dropdownColor: const Color(0xFF1C1C1E),
                                          style: const TextStyle(color: Colors.white),
                                          iconEnabledColor: Colors.white70,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'en',
                                              child: Text("English", style: TextStyle(color: Colors.white)),
                                            ),
                                            DropdownMenuItem(
                                              value: 'he',
                                              child: Text("Hebrew", style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                          onChanged: (v) {
                                              if (v == null) return;
                                              roomRef.update({
                                                'settings.language': v,
                                                'settings.selectedPackIds': ['classic_easy_$v'],
                                              });
                                          },
                                          decoration: InputDecoration(
                                            labelText: "Word language",
                                            labelStyle: const TextStyle(color: Colors.white70),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white30),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 12),

Builder(
  builder: (context) {
    final String lang = (data['settings']?['language'] ?? 'en') as String;

    final List<String> selectedPackIds = List<String>.from(
      (data['settings']?['selectedPackIds'] ?? []) as List,
    );

    final packsForLang = wordPacks.where((p) => p.lang == lang).toList();

    return ExpansionTile(
      title: const Text("Word packs", style: TextStyle(color: Colors.white)),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white70,
      children: [
        for (final p in packsForLang)
          CheckboxListTile(
            value: selectedPackIds.contains(p.id),
            title: Text(p.name, style: const TextStyle(color: Colors.white)),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (checked) async {
              final next = [...selectedPackIds];

              if (checked == true) {
                if (!next.contains(p.id)) next.add(p.id);
              } else {
                next.remove(p.id);
                if (next.isEmpty) next.add('classic_easy_$lang');
              }

              await roomRef.update({'settings.selectedPackIds': next});
            },
          ),
      ],
    );
  },
),



                                      const SizedBox(height: 20),

                                      if (isHost)
                                        ElevatedButton(
                                          onPressed: canStartGame(players)
                                            ? () => startGame(
                                              data['settings']?['language'] ?? 'en',
                                              List<String>.from((data['settings']?['selectedPackIds'] ?? []) as List),
                                              roomRef,
                                            )
                                            : null,
                                          child: const Text("Start Game"),
                                        ),

                                      OutlinedButton(
                                        onPressed: () async {
                                          final ok = await _confirmAction(
                                            title: "Leave room?",
                                            message: "Are you sure you want to leave this room?",
                                            confirmText: "Leave",
                                          );

                                          if (!ok) return;

                                          await leaveRoom(roomRef, players, hostId);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        child: const Text("Leave Room"),
                                      ),


                                      if (isHost)
                                        ElevatedButton.icon(
                                          onPressed: players.length >= 2
                                              ? () =>
                                                  autoBalanceTeams(players, roomRef)
                                              : null,
                                          icon: const Icon(Icons.balance),
                                          label:
                                              const Text("Auto-Balance Teams"),
                                        ),

                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              );

            },
          ),
        ),
      ],
    ),
  );
}

}

/* ───────────────────────── PLAYER TILE ───────────────────────── */

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isHost;
  final bool isMe;
  //final VoidCallback onToggleReady;
  final VoidCallback onKick;
  final VoidCallback onEdit; // 👈 NEW

  const _PlayerTile({
    required this.player,
    required this.isHost,
    required this.isMe,
    //required this.onToggleReady,
    required this.onKick,
    required this.onEdit,
  });

  Color get teamColor {
    switch (player['team']) {
      case 'red':
        return Colors.redAccent;
      case 'blue':
        return Colors.lightBlueAccent;
      default:
        return Colors.grey;
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⭐ HOST + AVATAR
            Column(
              children: [
                if (player['isHost'] == true)
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(height: 4),
                _PlayerAvatar(
                  playerId: player['id'],
                  teamColor: teamColor,
                ),
              ],
            ),

            const SizedBox(width: 12),

            // 🧠 NAME + ROLE (flexible area)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME (wraps naturally, no overflow)
                  Text(
                    player['name'] ?? 'Player',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ROLE CHIP
                  Chip(
                    label: Text(
                      player['role'],
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.black26,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 🎮 ACTIONS
            Column(
              children: [
                /*if (isMe)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      player['ready'] == true
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: player['ready'] == true
                          ? Colors.green
                          : Colors.redAccent,
                    ),
                    onPressed: onToggleReady,
                  ),*/

                if (isHost)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit, color: Colors.white70),
                    onPressed: onEdit,
                  ),

                if (isHost && !isMe)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.person_remove,
                        color: Colors.redAccent),
                    onPressed: onKick,
                  ),
              ],
            ),
          ],
        ),
      ),

    );
  }
  
}
class _PlayerAvatar extends StatelessWidget {
  final String playerId;
  final Color teamColor;

  const _PlayerAvatar({
    required this.playerId,
    required this.teamColor,
  });

  bool get isBot => playerId.startsWith('bot_');

  @override
  Widget build(BuildContext context) {
    if (isBot) {
      return CircleAvatar(
        backgroundColor: teamColor,
        child: const Text("🤖"),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(playerId)
          .snapshots(),
      builder: (context, snapshot) {
        ImageProvider? image;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;

          if (data['photoUrl'] != null) {
            image = NetworkImage(data['photoUrl']);
          } else if (data['avatarId'] != null) {
            image = AssetImage(
              'assets/avatars/${data['avatarId']}.png',
            );
          }
        }

        return Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: image,
              child: image == null
                  ? const Icon(Icons.person, color: Colors.white70)
                  : null,
            ),
            Positioned(
              bottom: -1,
              right: -1,
              child: CircleAvatar(
                radius: 7,
                backgroundColor: teamColor,
              ),
            ),
          ],
        );
      },
    );
  }
}



/* ───────────────────────── BACKGROUND ───────────────────────── */

class _Background extends StatelessWidget {
  final List<Color> colors;

  const _Background({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _RoomQrCard extends StatelessWidget {
  final String roomCode;

  const _RoomQrCard({required this.roomCode});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          "Scan to join",
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: roomCode,
            size: 180,
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _LobbyTopBar extends StatelessWidget {
  final String logoAsset;
  final Color textColor;
  final VoidCallback onBack;

  const _LobbyTopBar({
    required this.logoAsset,
    required this.textColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),

        Expanded(
          child: Center(
            child: Image.asset(
              logoAsset,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Spacer to balance back button
        const SizedBox(width: 48),
      ],
    );
  }
}





