import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import 'game_board_screen.dart';
import 'home_screen.dart';
import '../game/game_state.dart';


class EndGameScreen extends StatefulWidget {
  final String roomCode;
  const EndGameScreen({super.key, required this.roomCode});

  @override
  State<EndGameScreen> createState() => _EndGameScreenState();
}

class _EndGameScreenState extends State<EndGameScreen>
    with SingleTickerProviderStateMixin {
  late final DocumentReference roomRef;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _teamColor(String winner) {
    switch (winner) {
      case 'red':
        return Colors.redAccent;
      case 'blue':
        return Colors.lightBlueAccent;
      default:
        return Colors.grey;
    }
  }

  String _winnerText(String winner) {
    switch (winner) {
      case 'red':
        return 'Red Team Wins!';
      case 'blue':
        return 'Blue Team Wins!';
      default:
        return 'Game Is Over!';
    }
  }

  Future<void> _backToLobby(List<Map<String, dynamic>> players) async {
    // איפוס מינימלי וחזרה ללובי
    final resetPlayers = players
        .map((p) => {
              ...p,
              'ready': false,
            })
        .toList();

    await roomRef.update({
      'state': 'lobby',
      'winner': null,
      'gameState': null,
      'players': resetPlayers,
    });
  }

Future<void> _leaveRoom() async {
  await FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .update({"currentRoom": null});

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(roomRef);
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final hostId = data['hostId'] as String?;
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

    if (uid == hostId) {
      tx.update(roomRef, {
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final remaining = players.where((p) => p['id'] != uid).toList();

    final hasHuman = remaining.any(
      (p) => !(p['id'] as String).startsWith('bot_'),
    );

    if (!hasHuman) {
      tx.update(roomRef, {
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'players': remaining,
      });
    } else {
      tx.update(roomRef, {'players': remaining});
    }
  });

  if (!mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (_) => false,
  );
}

bool canStartGame(List<Map<String, dynamic>> players) {
  // Only players that are actually assigned to a team
  final activePlayers =
      players.where((p) => p['team'] == 'red' || p['team'] == 'blue').toList();

  // Rule 1: total players
  if (activePlayers.length < 4) return false;

  final red = activePlayers.where((p) => p['team'] == 'red').toList();
  final blue = activePlayers.where((p) => p['team'] == 'blue').toList();

  // Rule 2 & 3: team sizes
  if (red.length < 2 || blue.length < 2) return false;

  // Rule 4 & 5: exactly one spymaster per team
  final redSpymasters =
      red.where((p) => p['role'] == 'spymaster').length;
  final blueSpymasters =
      blue.where((p) => p['role'] == 'spymaster').length;

  if (redSpymasters != 1 || blueSpymasters != 1) return false;

  return true;
}

Future<void> _clearHistory(DocumentReference roomRef) async {
  const int batchSize = 200;

  while (true) {
    final snap = await roomRef
        .collection('history')
        .limit(batchSize)
        .get(const GetOptions(source: Source.server)); // ✅ avoid cache

    if (snap.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    if (snap.docs.length < batchSize) break;
  }
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


Future<void> _startNewGame() async {
  final snap = await roomRef.get(const GetOptions(source: Source.server));
  if (!snap.exists) return;

  final data = snap.data() as Map<String, dynamic>;
  final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

  // 🔒 BACKEND GUARD
  if (!canStartGame(players)) return;

  // ✅ 1) clear old history BEFORE starting
  await _clearHistory(roomRef);
  await _clearSpymasterPlan(roomRef); // ✅ also reset plan on restart


  // ✅ 2) clear any old turn lock / turn id as well (prevents weird bot repeats)
  final String lang = data['settings']?['language'] ?? 'en';
  final newState = GameState.newGame(lang);

  await roomRef.update({
    'state': 'in_game',
    'winner': null,
    'statsProcessed': false,
    'lastBoardEvent': null,
    'botTurnLock': null,
    'currentTurnId': null,
    'gameState': newState.toMap(),
  });
}




  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: roomRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Room לא קיים")),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
        final hostId = data['hostId'];
        final isHost = uid == hostId;
        final bool canStart = canStartGame(players);


        final winner = (data['winner'] ?? '') as String;

        final status = data['status'];
        if (status == 'closed') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await FirebaseFirestore.instance
                .collection("users")
                .doc(uid)
                .update({"currentRoom": null});

            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          });
        }

        if (data['state'] == 'in_game') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GameBoardScreen(roomCode: widget.roomCode),
              ),
            );
          });
        }

        // ניווט אוטומטי חזרה ללובי אם ה-state השתנה
              if (data['state'] == 'lobby') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LobbyScreen(roomCode: widget.roomCode),
                    ),
                  );
                });
              }
        

        final bg = _teamColor(winner);

        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            color: bg,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 80, color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            _winnerText(winner),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Great game👏",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _AnimatedStats(uid: uid),


                          // Host decides what happens next
                          if (isHost) ...[
                            SizedBox(
                              width: 260,
                              child: ElevatedButton(
                                onPressed: () => _backToLobby(players),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Back to Lobby"),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 260,
                              child: OutlinedButton(
                                onPressed: canStart ? _startNewGame : null, // 🔒 gated
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: canStart ? Colors.white : Colors.white38,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Start New Game"),
                              ),
                            ),

                          ] else ...[
                            // Non-host players
                            const Text(
                              "Waiting for the host to decide what’s next…",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: 260,
                              child: OutlinedButton(
                                onPressed: _leaveRoom,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Leave Room"),
                              ),
                            ),
                          ]

                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedStats extends StatefulWidget {
  final String uid;
  const _AnimatedStats({required this.uid});

  @override
  State<_AnimatedStats> createState() => _AnimatedStatsState();
}

class _AnimatedStatsState extends State<_AnimatedStats>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.data() == null) {
          return const SizedBox.shrink();
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final wins = data['wins'] ?? 0;
        final losses = data['losses'] ?? 0;
        final games = data['gamesPlayed'] ?? 0;
        final winRate =
            games == 0 ? 0 : ((wins / games) * 100).round();

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _ctrl,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CountStat(label: "Wins", value: wins, ctrl: _ctrl),
                  _CountStat(label: "Losses", value: losses, ctrl: _ctrl),
                  _CountStat(label: "Games", value: games, ctrl: _ctrl),
                  _CountStat(label: "Win %", value: winRate, ctrl: _ctrl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountStat extends StatelessWidget {
  final String label;
  final int value;
  final AnimationController ctrl;

  const _CountStat({
    required this.label,
    required this.value,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final animation = IntTween(begin: 0, end: value).animate(
      CurvedAnimation(
        parent: ctrl,
        curve: Curves.easeOutQuart,
      ),
    );

    return Column(
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) {
            return Text(
              animation.value.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

