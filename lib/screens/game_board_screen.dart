
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../user_session.dart';
import '../game/game_state.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/bot_service.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import '../services/gemini_spymaster_client.dart';
import 'end_game_screen.dart';
import 'package:flutter/services.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'home_screen.dart';




class GameBoardScreen extends StatefulWidget {
  final String roomCode;



  const GameBoardScreen({super.key, required this.roomCode});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final TextEditingController _hintWordController = TextEditingController();
  final TextEditingController _hintNumberController = TextEditingController();

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  bool _navigatedToEnd = false;

  //bool _botIsThinking = false;

  // ───────────────────────── Board alerts ─────────────────────────
final Queue<({String text, Color? bg})> _snackQueue = Queue();
bool _isShowingSnack = false;
int? _lastBoardEventNonce;

void _handleBoardEvent(dynamic rawEvent) {
  if (rawEvent == null || rawEvent is! Map) return;

  final int? nonce = rawEvent['nonce'] is int ? rawEvent['nonce'] as int : null;
  if (nonce == null) return;

  // prevent repeating the same event on rebuilds
  if (_lastBoardEventNonce == nonce) return;
  _lastBoardEventNonce = nonce;

  final String text = (rawEvent['text'] ?? '').toString();
  if (text.isEmpty) return;

  Color? bg;
  if (rawEvent['bg'] != null) {
    switch (rawEvent['bg'].toString()) {
      case 'red':
        bg = Colors.redAccent;
        break;
      case 'blue':
        bg = Colors.blueAccent;
        break;
      case 'green':
        bg = Colors.green.shade600;
        break;
      case 'orange':
        bg = Colors.orange.shade700;
        break;
    }
  }

  _enqueueSnack(text, bg: bg);
}

String getWordsForRoom(Map<String, dynamic> roomData) {
  final lang = roomData['settings']?['language'] ?? 'en';
  return lang;
}

void _enqueueSnack(String text, {Color? bg}) {
  _snackQueue.add((text: text, bg: bg));
  _tryShowNextSnack();
}

void _tryShowNextSnack() {
  if (_isShowingSnack || _snackQueue.isEmpty || !mounted) return;

  _isShowingSnack = true;
  final item = _snackQueue.removeFirst();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(item.text),
            backgroundColor: item.bg,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        )
        .closed
        .then((_) {
      _isShowingSnack = false;
      _tryShowNextSnack();
    });
  });
}

  @override
  void dispose() {
    _hintWordController.dispose();
    _hintNumberController.dispose();
    super.dispose();
  }

Future<void> _startOrRestartGame(
  DocumentReference roomRef,
  Map<String, dynamic> roomData,
) async {
  // ✅ clear old history first
  await _clearHistory(roomRef);

  final lang = getWordsForRoom(roomData);
  final newState = GameState.newGame(lang);

  await roomRef.update({
    'state': 'in_game',
    'winner': null,
    'gameState': newState.toMap(),
    'botTurnLock': null,
    'currentTurnId': null,

    // optional but recommended:
    'statsProcessed': false,
  });
}



  Widget _withBackground(Widget child, Team? team) {
  return Stack(
    children: [
      _GameBackground(team: team),
      SafeArea(child: child),
    ],
  );
}

String _typeTag(Team t) {
  switch (t) {
    case Team.red:
      return 'R';
    case Team.blue:
      return 'B';
    case Team.neutral:
      return 'N';
    case Team.assassin:
      return '☠';
  }
}

Widget _buildWordCardTile({
  required CodeNameCard card,
  required bool isSpymaster,
  int? plannedTurn, // 👈 add
}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: card.revealed
        ? _revealedFace(card, key: ValueKey('rev_${card.word}'))
        : _hiddenFace(card,
            isSpymaster: isSpymaster,
            plannedTurn: plannedTurn,
            key: ValueKey('hid_${card.word}'),
          ),
  );
}

Widget _hiddenFace(
  CodeNameCard card, {
  required bool isSpymaster,
  required Key key,
  int? plannedTurn, // 👈 add
}) {
  final accent = _teamColor(card.team);
  final borderColor =
      isSpymaster ? accent.withOpacity(0.95) : Colors.white.withOpacity(0.18);
  final borderWidth = isSpymaster ? 2.4 : 1.2;

  return Container(
    key: key,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor, width: borderWidth),
    ),
    padding: const EdgeInsets.all(6),
    child: Stack(
      children: [
        // 🔹 subtle spymaster tint
        if (isSpymaster)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

            if (isSpymaster && plannedTurn != null)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Text(
                    plannedTurn.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      height: 1.0,
                    ),
                  ),
                ),
              ),

        Column(
          children: [

            // 🔹 FIXED-HEIGHT HEADER (badge lives here)
            SizedBox(
              height: isSpymaster ? 22 : 0,
              child: isSpymaster
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _typeTag(card.team),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11, // 🔻 slightly smaller
                            height: 1.0,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),

            // 🔹 WORD AREA (guaranteed space)
            Expanded(
              child: Center(
                child: AutoSizeText(
                  card.word,
                  maxLines: 1, // ❗ still one line
                  minFontSize: 6, // ⭐ allow aggressive shrink
                  maxFontSize: 14,
                  stepGranularity: 0.5,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.0, // ⭐ critical: no extra vertical space
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


Widget _revealedFace(CodeNameCard card, {required Key key}) {
  final bg = _teamColor(card.team);

  return Container(
    key: key,
    decoration: BoxDecoration(
      color: bg.withOpacity(0.95),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.18)),
    ),
    padding: const EdgeInsets.all(6),
    child: Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Icon(
            _teamIcon(card.team),
            size: 18,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        Center(
          child: AutoSizeText(
            card.word,
            maxLines: 1,
            minFontSize: 9,
            maxFontSize: 14,
            stepGranularity: 0.5,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: card.team == Team.neutral
                  ? Colors.black87
                  : Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
      ],
    ),
  );
}

Color _teamColor(Team t) {
  switch (t) {
    case Team.red:
      return const Color(0xFFB71C1C);
    case Team.blue:
      return const Color(0xFF0D47A1);
    case Team.neutral:
      return const Color(0xFFE0E0E0);
    case Team.assassin:
      return const Color(0xFF111111);
  }
}

IconData _teamIcon(Team t) {
  switch (t) {
    case Team.red:
    case Team.blue:
      return Icons.person;
    case Team.neutral:
      return Icons.circle_outlined;
    case Team.assassin:
      return Icons.close;
  }
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


  @override
  Widget build(BuildContext context) {
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        title: Text("Game Board - ${widget.roomCode}",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
         ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => _openHistoryBottomSheet(context, roomRef),
          ),
          
          // StreamBuilder<DocumentSnapshot>(
          //   stream: roomRef.snapshots(),
          //   builder: (context, snapshot) {
          //     if (!snapshot.hasData || snapshot.data!.data() == null) {
          //       return const SizedBox.shrink();
          //     }
          //     final data = snapshot.data!.data() as Map<String, dynamic>;
          //     final String hostId = data['hostId'];
          //     final players =
          //         List<Map<String, dynamic>>.from(data['players'] ?? []);
          //     final me = players.firstWhere(
          //       (p) => p['id'] == uid,
          //       orElse: () => {},
          //     );

          //     final bool isHost =
          //         hostId == uid || me['isHost'] == true;
          //     if (!isHost) return const SizedBox.shrink();

          //     return IconButton(
          //       icon: const Icon(Icons.play_arrow),
          //       onPressed: () => _startOrRestartGame(roomRef,data),
          //     );
          //   },
          // ),
          
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: roomRef.snapshots(),
        builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _withBackground(
            const Center(child: CircularProgressIndicator()),
            null,
          );
        }

        final rawData = snapshot.data!.data();
        if (rawData == null) {
          return _withBackground(
            const Center(child: Text('Room not found')),
            null,
          );
        }

          final data = rawData as Map<String, dynamic>;
          _handleBoardEvent(data['lastBoardEvent']);
          final String hostId = data['hostId'];
          final bool isHost = hostId == uid;

          if (data['state'] == 'game_over' && !_navigatedToEnd) {
            _navigatedToEnd = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EndGameScreen(roomCode: widget.roomCode),
                ),
              );
            });
          }

          final dynamic rawPlayers = data['players'];
          final List<Map<String, dynamic>> players = rawPlayers is List
              ? List<Map<String, dynamic>>.from(rawPlayers)
              : const [];

          final me = players.firstWhere(
            (p) => p['id'] == uid,
            orElse: () => {"role": "operative"},
          );
          final String myName = me['name'] ?? 'Unknown';
          final String myTeamStr = me['team'] ?? 'red'; // "red" / "blue"

          final String myRole = me["role"]; // "spymaster" or "operative"
          final bool isSpymaster = myRole == "spymaster";

          Team? myTeam;
          if (myTeamStr == "red") {
            myTeam = Team.red;
          } else if (myTeamStr == "blue") {
            myTeam = Team.blue;
          } else {
            myTeam = null; // לא משויך / צופה
          }

          if (!data.containsKey('gameState') || data['gameState'] == null) {
            return _withBackground(
              DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'There is no active game yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isHost ? () => _startOrRestartGame(roomRef,data) : null,
                        child: const Text('Start Game'),
                      ),
                  if (!isHost)
                    const Text(
                      'Only the Host can start or reset the game',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                   ],
                  ),
               ),
              ),
              myTeam,
            );
          }

          final gameStateMap =
              Map<String, dynamic>.from(data['gameState'] as Map);
          final gameState = GameState.fromMap(gameStateMap);


          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;

            // Only host finalizes stats
            if (gameState.isGameOver &&
                data['state'] == 'game_over' &&
                data['statsProcessed'] != true &&
                data['hostId'] == uid) {

              final winner = teamToString(gameState.winnerTeam!);

              // 🔒 LOCK FIRST
              await roomRef.update({'statsProcessed': true});

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
          });



          // 👇 trigger bot (if exists) to act as operative
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeSpymasterBotAct(roomRef, players, gameState);
            _maybeBotAct(roomRef, players, gameState); // operative
          });
          // האם זה התור של הקבוצה שלי
          final bool isMyTeamTurn =
              myTeam != null && myTeam == gameState.currentTeam;
          final String currentTeamNameHe =
              gameState.currentTeam == Team.red ? 'Red' : 'Blue';
          final bool isOperative = myRole == "operative";

// ✅ REPLACE your old `return StreamBuilder<DocumentSnapshot>(stream: planStream, ...)`
// with this FULL block (includes: top bar + hint UI + board + chat button)

final Stream<QuerySnapshot> targetsStream =
    (isSpymaster && (myTeamStr == 'red' || myTeamStr == 'blue'))
        ? _targetsCol(roomRef, myTeamStr).snapshots()
        : const Stream<QuerySnapshot>.empty();

return StreamBuilder<QuerySnapshot>(
  stream: targetsStream,
  builder: (context, targetsSnap) {
    // docId -> turn
    final Map<String, int> plannedTurnByKey = {};
    for (final d in targetsSnap.data?.docs ?? []) {
      final m = d.data() as Map<String, dynamic>;
      final t = (m['turn'] as num?)?.toInt();
      if (t != null) plannedTurnByKey[d.id] = t;
    }

    return _withBackground(
      DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          children: [
            _buildTopBar(
              roomRef: roomRef,
              gameState: gameState,
              myTeam: myTeam,
              isSpymaster: isSpymaster,
              canEndTurn: !gameState.isGameOver &&
                  !gameState.waitingForHint &&
                  (myRole == "operative") &&
                  (myTeam != null) &&
                  (myTeam == gameState.currentTeam) &&
                  (gameState.remainingGuesses > 0),
              onEndTurn: () async {
                gameState.endTurnEarly();

                await _addHistoryEvent(
                  roomRef,
                  type: 'end_turn',
                  team: myTeam == Team.red ? 'red' : 'blue',
                  byId: uid,
                  byName: myName,
                );

                await roomRef.update({'gameState': gameState.toMap()});
              },
            ),

            const SizedBox(height: 8),

            // ───────────────────────── HINT UI (UNCHANGED) ─────────────────────────
            if (!gameState.isGameOver && gameState.waitingForHint) ...[
              if (isSpymaster && isMyTeamTurn) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hintWordController,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Clue Word',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _hintNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.allow(RegExp(r'[1-9]')),
                          ],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            labelText: 'Number',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white54),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: _glassButtonStyle(myTeam),
                        onPressed: () async {
                          final word = _hintWordController.text.trim();
                          final numStr = _hintNumberController.text.trim();
                          final num = int.tryParse(numStr);

                          if (word.isEmpty || num == null || num <= 0) return;

                          gameState.setHint(word, num);

                          final turnId =
                              DateTime.now().millisecondsSinceEpoch.toString();

                          await roomRef.update({
                            'gameState': gameState.toMap(),
                            'currentTurnId': turnId,
                          });

                          await _addHistoryEvent(
                            roomRef,
                            type: 'hint',
                            team: myTeamStr,
                            byId: uid,
                            byName: myName,
                            extra: {
                              'turnId': turnId,
                              'word': word,
                              'number': num,
                            },
                          );

                          _hintWordController.clear();
                          _hintNumberController.clear();
                        },
                        child: const Text('Submit Clue'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                Text(
                  isMyTeamTurn
                      ? 'Waiting for your Spymaster’s clue...'
                      : 'Waiting for $currentTeamNameHe team to finish...',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ],

            // ───────────────────────── BOARD (FIXED) ─────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: gameState.board.length,
                  itemBuilder: (context, index) {
                    final card = gameState.board[index];

                    final keyWord = _wordKey(card.word);
                    final plannedTurn =
                        isSpymaster ? plannedTurnByKey[keyWord] : null;

                    return GestureDetector(
                      onTap: () async {
                        // ✅ Spymaster planning tap (before operative checks)
                        if (isSpymaster &&
                            !gameState.isGameOver &&
                            !card.revealed &&
                            (myTeamStr == 'red' || myTeamStr == 'blue')) {
                          await _cyclePlannedTurnForWordV2(
                            roomRef: roomRef,
                            team: myTeamStr,
                            word: card.word,
                            maxTurn: 6,
                          );
                          return;
                        }

                        // only operative of current team can guess
                        if (!isOperative ||
                            isSpymaster ||
                            gameState.isGameOver ||
                            gameState.waitingForHint ||
                            myTeam == null ||
                            myTeam != gameState.currentTeam) {
                          return;
                        }

                        if (card.revealed) return;

                        final clickingTeam = gameState.currentTeam;
                        final clickedWord = card.word;
                        final clickedCardTeam = card.team;

                        final bool isCorrect = clickedCardTeam == clickingTeam;
                        final bool isAssassin = clickedCardTeam == Team.assassin;

                        final teamName = clickingTeam == Team.red
                            ? "Red team"
                            : "Blue team";
                        final resultText = isAssassin
                            ? "clicked the assassin — game over!"
                            : (isCorrect
                                ? "made a correct guess!"
                                : "made a wrong guess!");

                        final String clickingTeamStr =
                            clickingTeam == Team.red ? 'red' : 'blue';

                        final String result = isAssassin
                            ? 'assassin'
                            : (isCorrect ? 'correct' : 'wrong');

                        final String turnId =
                            (data['currentTurnId'] ?? '').toString();

                        await _addHistoryEvent(
                          roomRef,
                          type: 'play',
                          team: clickingTeamStr,
                          byId: uid,
                          byName: myName,
                          extra: {
                            'turnId': turnId,
                            'word': clickedWord,
                            'result': result,
                            'cardTeam': teamToString(clickedCardTeam),
                          },
                        );

                        final snackText =
                            '$teamName clicked "$clickedWord" and $resultText';
                        final snackBg = isAssassin
                            ? 'red'
                            : (isCorrect
                                ? (clickingTeam == Team.red ? 'red' : 'blue')
                                : 'orange');

                        gameState.revealCard(index);

                        await roomRef.update({
                          'gameState': gameState.toMap(),
                          'lastBoardEvent': {
                            'nonce': DateTime.now().millisecondsSinceEpoch,
                            'text': snackText,
                            'bg': snackBg,
                          },
                        });

                        if (gameState.isGameOver) {
                          final winner = teamToString(gameState.winnerTeam!);
                          await roomRef.update({
                            'state': 'game_over',
                            'winner': winner,
                          });
                        }
                      },
                      child: _buildWordCardTile(
                        card: card,
                        isSpymaster: isSpymaster,
                        plannedTurn: plannedTurn,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ───────────────────────── CHAT BUTTON (UNCHANGED) ─────────────────────────
            GestureDetector(
              onTap: () {
                _openChatBottomSheet(
                  context,
                  roomRef,
                  uid,
                  myName,
                  myTeamStr,
                  isSpymaster,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: _glassChipDecoration(myTeam),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chat',
                      style: TextStyle(color: Colors.white),
                    ),
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      myTeam,
    );
  },
);


      },
    ),
  );
}

Future<void> _cyclePlannedTurnForWordV2({
  required DocumentReference roomRef,
  required String team, // 'red'/'blue'
  required String word,
  required int maxTurn,
}) async {
  final key = _wordKey(word);
  final doc = _targetsCol(roomRef, team).doc(key);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(doc);

    final int? current = snap.exists
        ? (snap.data() as Map<String, dynamic>)['turn'] as int?
        : null;

    final int? next = (current == null) ? 1 : (current >= maxTurn ? null : current + 1);

    if (next == null) {
      tx.delete(doc);
    } else {
      tx.set(doc, {
        'turn': next,
        'word': word, // original for display
        'updatedAt': FieldValue.serverTimestamp(),
        'authorId': FirebaseAuth.instance.currentUser!.uid,
      }, SetOptions(merge: true));
    }
  });
}




  // ---------- BOT OPERATIVE LOGIC ----------

Future<void> _maybeBotAct(
  DocumentReference roomRef,
  List<Map<String, dynamic>> players,
  GameState gameState,
) async {
  // ------------------------------
  // STOP CONDITIONS
  // ------------------------------
  if (gameState.waitingForHint ||
      gameState.isGameOver ||
      gameState.remainingGuesses <= 0) {
    return;
  }

  // ------------------------------
  // FIND OPERATIVE BOT FOR TURN
  // ------------------------------
  final bot = players.firstWhere(
    (p) =>
        p['id'].toString().startsWith('bot_') &&
        p['role'] == 'operative' &&
        p['team'] ==
            (gameState.currentTeam == Team.red ? 'red' : 'blue'),
    orElse: () => {},
  );

  if (bot.isEmpty) return;

// ------------------------------
// ACQUIRE TURN LOCK (TRANSACTION)
// ------------------------------
try {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw 'ROOM_MISSING';
    }

    final data = snap.data() as Map<String, dynamic>;

    if (data['botTurnLock'] != null) {
      throw 'LOCKED';
    }

    tx.update(roomRef, {
      'botTurnLock': {
        'team': bot['team'],
        'phase': 'operative',
      }
    });
  });
} catch (_) {
  // Someone else got the lock → silently abort
  return;
}


  try {
    // ------------------------------
    // VALIDATE HINT
    // ------------------------------
    final hintWord = gameState.currentHintWord;
    final hintNumber = gameState.currentHintNumber;

    if (hintWord == null || hintNumber == null) return;

    // ------------------------------
    // SIMULATE THINKING
    // ------------------------------
    await Future.delayed(const Duration(seconds: 5));

    // ------------------------------
    // PREPARE BOARD FOR GEMINI
    // ------------------------------
    final boardPayload = gameState.board
        .map((c) => {
              'word': c.word,
              'team': teamToString(c.team),
              'revealed': c.revealed,
            })
        .toList();

    int chosenIndex;

    try {
      chosenIndex = await GeminiBotClient.pickMove(
        team: bot['team'],
        hintWord: hintWord,
        hintNumber: hintNumber,
        remainingGuesses: gameState.remainingGuesses,
        board: boardPayload,
      );
    } catch (_) {
      return;
    }

    // ------------------------------
    // VALIDATE MOVE
    // ------------------------------
    if (chosenIndex < 0 ||
        chosenIndex >= gameState.board.length ||
        gameState.board[chosenIndex].revealed) {
      chosenIndex =
          gameState.board.indexWhere((c) => !c.revealed);
    }

    if (chosenIndex == -1) return;

    // ------------------------------
    // APPLY MOVE
    // ------------------------------
    final clickingTeam = gameState.currentTeam;
    final clickedCard = gameState.board[chosenIndex];

    final bool isCorrect = clickedCard.team == clickingTeam;
    final bool isAssassin = clickedCard.team == Team.assassin;

    final snackText =
        '${bot['team'] == 'red' ? 'Red' : 'Blue'} team (BOT) clicked "${clickedCard.word}"';

    final snackBg = isAssassin
        ? 'red'
        : (isCorrect
            ? (clickingTeam == Team.red ? 'red' : 'blue')
            : 'orange');

    gameState.revealCard(chosenIndex);

    await roomRef.update({
      'gameState': gameState.toMap(),
      'lastBoardEvent': {
        'nonce': DateTime.now().millisecondsSinceEpoch,
        'text': snackText,
        'bg': snackBg,
      },
    });

    // ------------------------------
    // FINALIZE GAME
    // ------------------------------
    if (gameState.isGameOver) {
      await roomRef.update({
        'state': 'game_over',
        'winner': teamToString(gameState.winnerTeam!),
      });
    }
  } finally {
    // 🔓 ALWAYS RELEASE LOCK
    await roomRef.update({'botTurnLock': null});
  }
}



Future<void> _maybeSpymasterBotAct(
  DocumentReference roomRef,
  List<Map<String, dynamic>> players,
  GameState gameState,
) async {
  // ------------------------------
  // STOP CONDITIONS
  // ------------------------------
  if (!gameState.waitingForHint || gameState.isGameOver) return;

  // ------------------------------
  // FIND SPYMASTER BOT
  // ------------------------------
  final bot = players.firstWhere(
    (p) =>
        p['id'].toString().startsWith('bot_') &&
        p['role'] == 'spymaster' &&
        p['team'] ==
            (gameState.currentTeam == Team.red ? 'red' : 'blue'),
    orElse: () => {},
  );

  if (bot.isEmpty) return;

try {
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(roomRef);
    if (!snap.exists) {
      throw 'ROOM_MISSING';
    }

    final data = snap.data() as Map<String, dynamic>;

    if (data['botTurnLock'] != null) {
      throw 'LOCKED';
    }

    tx.update(roomRef, {
      'botTurnLock': {
        'team': bot['team'],
        'phase': 'spymaster',
      }
    });
  });
} catch (_) {
  return;
}


  try {
    // ------------------------------
    // PREPARE BOARD
    // ------------------------------
    final boardPayload = gameState.board
        .map((c) => {
              'word': c.word,
              'team': teamToString(c.team),
              'revealed': c.revealed,
            })
        .toList();

    final hint = await GeminiSpymasterClient.generateHint(
      team: bot['team'],
      board: boardPayload,
    );

    gameState.setHint(hint['word'], hint['number']);

    await roomRef.update({
      'gameState': gameState.toMap(),
    });
  } finally {
    // 🔓 RELEASE LOCK
    await roomRef.update({'botTurnLock': null});
  }
}

  // ---------- COLORS / CHAT UI ----------

  Color getCardColor(CodeNameCard card, bool isSpymaster) {
    if (card.revealed) {
      return teamColor(card.team);
    }

    if (isSpymaster) {
      return teamColor(card.team).withOpacity(0.45);
    }

    return Colors.grey[300]!;
  }

  Color teamColor(Team team) {
    switch (team) {
      case Team.red:
        return Colors.red;
      case Team.blue:
        return Colors.blue;
      case Team.neutral:
        return Colors.brown;
      case Team.assassin:
        return Colors.black;
    }
  }

  Color _accentColor(Team? team) {
  if (team == Team.red) return Colors.redAccent;
  if (team == Team.blue) return Colors.lightBlueAccent;
  return Colors.white;
}

ButtonStyle _glassButtonStyle(Team? team) {
  final accent = _accentColor(team);
  return ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(0.12),
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: accent.withOpacity(0.35)),
    ),
  );
}

BoxDecoration _glassChipDecoration(Team? team) {
  final accent = _accentColor(team);
  return BoxDecoration(
    color: Colors.white.withOpacity(0.12),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: accent.withOpacity(0.35)),
  );
}

Widget _buildTopBar({
  required DocumentReference roomRef,
  required GameState gameState,
  required Team? myTeam,
  required bool isSpymaster,
  required bool canEndTurn,
  required Future<void> Function() onEndTurn,
}) {

  final bool isMyTeamTurn = myTeam != null && myTeam == gameState.currentTeam;

  final String myTeamHe = myTeam == null
      ? 'לא משויך'
      : (myTeam == Team.red ? 'Red' : 'Blue');

  final String currentTeamHe =
      gameState.currentTeam == Team.red ? 'Red' : 'Blue';

  final Color accent = _accentColor(myTeam);
  final String hintLine = gameState.waitingForHint
      ? 'Waiting for a clue from the $currentTeamHe team'
      : 'Clue: "${gameState.currentHintWord ?? ""}" (${gameState.currentHintNumber ?? 0}) • Guesses: ${gameState.remainingGuesses}';

  final String titleLine = gameState.isGameOver
      ? 'Game Over • ${gameState.winnerTeam == Team.red ? "Red" : "Blue"}'
      : 'Turn : $currentTeamHe';

  final actions = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _pill(text: isSpymaster ? 'Spymaster' : 'Operative', team: myTeam),

      // 🔹 SPYMASTER PLAN BUTTON (HERE!)
      if (isSpymaster && (myTeam == Team.red || myTeam == Team.blue)) ...[
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Spymaster Plan',
          icon: const Icon(Icons.view_list, color: Colors.white),
          onPressed: () => _openPlanBottomSheet(
            context: context,
            roomRef: roomRef,
            team: myTeam == Team.red ? 'red' : 'blue',
            gameState: gameState,
            maxTurn: 6,
          ),
        ),
      ],
      if (canEndTurn) ...[
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () async => await onEndTurn(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.12),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withOpacity(0.16)),
            ),
          ),
          icon: const Icon(Icons.skip_next, size: 18),
          label: const Text(
            'End turn',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ],
  );

  return Directionality(
    textDirection: TextDirection.ltr,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.35)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;

            final content = Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _pill(text: 'My Team: $myTeamHe', team: myTeam),
                          const SizedBox(width: 10),
                          if (!gameState.isGameOver)
                            _pill(
                              text: isMyTeamTurn ? 'Our turn' : 'Not our turn',
                              team: myTeam,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _pill(
                            text: 'Red left: ${gameState.redRemaining}',
                            team: Team.red,
                          ),
                          const SizedBox(width: 10),
                          _pill(
                            text: 'Blue left: ${gameState.blueRemaining}',
                            team: Team.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      hintLine,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(alignment: Alignment.centerRight, child: actions),
                  const SizedBox(height: 8),
                  content,
                ],
              );
            }

            return Stack(
              children: [
                content,
                Positioned(right: 0, top: 0, child: actions),
              ],
            );
          },
        ),
      ),
    ),
  );
}


Widget _pill({required String text, required Team? team}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: _glassChipDecoration(team),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

void _openChatBottomSheet(
  BuildContext context,
  DocumentReference roomRef,
  String uid,
  String myName,
  String myTeamStr,
  bool isSpymaster,
) {
  final TextEditingController controller = TextEditingController();
  final Team? team =
      myTeamStr == 'red' ? Team.red : (myTeamStr == 'blue' ? Team.blue : null);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.40,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Messages list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: roomRef
                      .collection('playerChat')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Chat error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'There are no messages yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>;

                        final String senderName =
                            data['senderName'] ?? 'Unknown';
                        final String text = data['text'] ?? '';
                        final String msgTeam = data['team'] ?? 'red';

                        final Color nameColor =
                            msgTeam == 'red' ? Colors.red : Colors.blue;

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$senderName: ',
                                style: TextStyle(
                                  color: nameColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Input row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 6.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSpymaster) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              style:
                                  const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle:
                                    TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          Container(
                            decoration: _glassChipDecoration(team),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                final text =
                                    controller.text.trim();
                                if (text.isEmpty) return;

                                await roomRef
                                    .collection('playerChat')
                                    .add({
                                  'senderId': uid,
                                  'senderName': myName,
                                  'team': myTeamStr,
                                  'text': text,
                                  'timestamp':
                                      FieldValue.serverTimestamp(),
                                });

                                controller.clear();
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Spymasters cannot send messages',
                          style:
                              TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _wordKey(String w) {
  final normalized = w
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Firestore doc IDs cannot contain '/', but can contain almost everything else.
  // Use base64Url of UTF-8 to avoid collisions & language issues.
  final bytes = utf8.encode(normalized);
  return base64UrlEncode(bytes);
}





void _openPlanBottomSheet({
  required BuildContext context,
  required DocumentReference roomRef,
  required String team, // 'red' / 'blue'
  required GameState gameState,
  required int maxTurn,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _SpymasterPlanSheet(
      roomRef: roomRef,
      team: team,
      gameState: gameState,
      maxTurn: maxTurn,
    ),
  );
}





void _openHistoryBottomSheet(BuildContext context, DocumentReference roomRef) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: roomRef
                      .collection('history')
                      .orderBy('ts', descending: true)
                      .limit(200)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'History error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No history yet',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final raw = snapshot.data!.docs
                        .map((d) => d.data() as Map<String, dynamic>)
                        .toList();

                    // ---- group by turnId
                    final Map<String, Map<String, dynamic>> hintByTurn = {};
                    final Map<String, List<Map<String, dynamic>>> playsByTurn = {};

                    for (final m in raw) {
                      final type = (m['type'] ?? '').toString();
                      final turnId = (m['turnId'] ?? '').toString();
                      if (turnId.isEmpty) continue;

                      if (type == 'hint') {
                        hintByTurn[turnId] = m;
                      } else if (type == 'play') {
                        (playsByTurn[turnId] ??= []).add(m);
                      }
                    }

                    // only turns that have a clue (hint)
                    final turnIds = hintByTurn.keys.toList();

                    // newest clue on top (fallback: sort by turnId)
                    turnIds.sort((a, b) {
                      final ta = hintByTurn[a]?['ts'];
                      final tb = hintByTurn[b]?['ts'];
                      if (ta is Timestamp && tb is Timestamp) {
                        return tb.toDate().compareTo(ta.toDate());
                      }
                      return b.compareTo(a);
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: turnIds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final turnId = turnIds[i];
                        final hint = hintByTurn[turnId]!;
                        final plays = playsByTurn[turnId] ?? [];

                        plays.sort((a, b) {
                          final ta = a['ts'];
                          final tb = b['ts'];
                          if (ta is Timestamp && tb is Timestamp) {
                            return ta.toDate().compareTo(tb.toDate()); // oldest -> newest
                          }
                          return 0;
                        });

                        final team = (hint['team'] ?? '').toString(); // red/blue
                        final teamColor = team == 'red'
                            ? Colors.redAccent
                            : team == 'blue'
                                ? Colors.lightBlueAccent
                                : Colors.white70;

                        final clueWord = (hint['word'] ?? '').toString();
                        final clueNum = (hint['number'] ?? '').toString();

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: (color) Turn i (red/blue): clue: "" (number)
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Turn ${turnIds.length - i} (${team.toUpperCase()}): Clue: "$clueWord" ($clueNum)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Guesses under the clue
                              if (plays.isEmpty)
                                const Text('No guesses yet', style: TextStyle(color: Colors.white70))
                              else
                                ...List.generate(plays.length, (gi) {
                                  final p = plays[gi];
                                  final w = (p['word'] ?? '').toString();
                                  final r = (p['result'] ?? '').toString(); // correct/wrong/assassin

                                  final rText = r == 'correct'
                                      ? 'Correct'
                                      : r == 'wrong'
                                          ? 'Wrong'
                                          : r == 'assassin'
                                              ? 'ASSASSIN'
                                              : r;

                                  final rColor = r == 'correct'
                                      ? Colors.greenAccent
                                      : r == 'wrong'
                                          ? Colors.orangeAccent
                                          : Colors.redAccent;

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        Text('Guess ${gi + 1}: ', style: const TextStyle(color: Colors.white70)),
                                        Expanded(
                                          child: Text(
                                            w,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(rText, style: TextStyle(color: rColor, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        );
                      },
                    );

                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}




Future<void> _clearHistory(DocumentReference roomRef) async {
  const int batchSize = 200;

  while (true) {
    final snap = await roomRef
        .collection('history')
        .limit(batchSize)
        .get();

    if (snap.docs.isEmpty) break;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    // If we got less than batchSize, we’re done
    if (snap.docs.length < batchSize) break;
  }
}


Future<void> _addHistoryEvent(
  DocumentReference roomRef, {
  required String type, // 'hint' | 'play' | 'end_turn'
  required String team, // 'red'/'blue'
  required String byId,
  required String byName,
  Map<String, dynamic>? extra,
}) async {
  await roomRef.collection('history').add({
    'type': type,
    'team': team,
    'byId': byId,
    'byName': byName,
    'ts': FieldValue.serverTimestamp(),
    ...?extra,
  });
}


}

class _GameBackground extends StatelessWidget {
  final Team? team;
  const _GameBackground({required this.team});

  @override
  Widget build(BuildContext context) {
    final colors = team == Team.red
        ? const [Color(0xFF2A0B0B), Color(0xFF5C1616), Color(0xFF0F2027)]
        : team == Team.blue
            ? const [Color(0xFF071425), Color(0xFF0F2F57), Color(0xFF0F2027)]
            : const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)];

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







class _SpymasterPlanSheet extends StatefulWidget {
  final DocumentReference roomRef;
  final String team;
  final GameState gameState;
  final int maxTurn;

  const _SpymasterPlanSheet({
    required this.roomRef,
    required this.team,
    required this.gameState,
    required this.maxTurn,
  });

  @override
  State<_SpymasterPlanSheet> createState() => _SpymasterPlanSheetState();
}

class _SpymasterPlanSheetState extends State<_SpymasterPlanSheet> {
  int selectedTurn = 1;

  late TextEditingController clueCtrl;
  String _lastLoadedValue = '';
  bool _dirty = false; // user edited but didn't save yet  late final TextEditingController clueCtrl;


@override
void initState() {
  super.initState();
  clueCtrl = TextEditingController();
  clueCtrl.addListener(() {
    _dirty = (clueCtrl.text != _lastLoadedValue);
  });
}

@override
void dispose() {
  clueCtrl.dispose();
  super.dispose();
}

void _ensureEditorValue(String firestoreValue) {
  // If user has unsaved edits, don't overwrite
  if (_dirty) return;

  if (_lastLoadedValue != firestoreValue) {
    _lastLoadedValue = firestoreValue;
    clueCtrl.value = TextEditingValue(
      text: firestoreValue,
      selection: TextSelection.collapsed(offset: firestoreValue.length),
    );
  }
}

Future<void> _removeWordFromPlanV2({
  required DocumentReference roomRef,
  required String team,
  required String wordKey,
}) async {
  await _targetsCol(roomRef, team).doc(wordKey).delete();
}





  List<String> _wordsForTurn(Map<String, dynamic> targetsByWord, int turn) {
  final result = <String>[];
  targetsByWord.forEach((word, t) {
    final int? asInt = (t as num?)?.toInt();
    if (asInt == turn) result.add(word.toString());
  });
  result.sort();
  return result;
}

Future<void> _setDraftClueForTurnV2({
  required DocumentReference roomRef,
  required String team,
  required int turn,
  required String clueWord,
}) async {
  final doc = _cluesCol(roomRef, team).doc(turn.toString());
  final uid = FirebaseAuth.instance.currentUser!.uid;

  if (clueWord.trim().isEmpty) {
    await doc.delete();
  } else {
    await doc.set({
      'word': clueWord.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'authorId': uid,
    }, SetOptions(merge: true));
  }
}



@override
Widget build(BuildContext context) {
  final targetsStream = _targetsCol(widget.roomRef, widget.team).snapshots();

  final clueDocStream = _cluesCol(widget.roomRef, widget.team)
      .doc(selectedTurn.toString())
      .snapshots();

  return StreamBuilder<QuerySnapshot>(
    stream: targetsStream,
    builder: (context, targetsSnap) {
      final allTargets = (targetsSnap.data?.docs ?? [])
          .map((d) => {
                'id': d.id,
                ...(d.data() as Map<String, dynamic>),
              })
          .toList();

      final wordsInTurn = allTargets
          .where((x) => (x['turn'] as num?)?.toInt() == selectedTurn)
          .map((x) => {
                'id': x['id'].toString(),
                'word': (x['word'] ?? x['id']).toString(),
              })
          .toList()
        ..sort((a, b) => a['word']!.compareTo(b['word']!));

      return StreamBuilder<DocumentSnapshot>(
        stream: clueDocStream,
        builder: (context, clueSnap) {
          final clueData = clueSnap.data?.data() as Map<String, dynamic>?;
          final firestoreValue = (clueData?['word'] ?? '').toString();
          _ensureEditorValue(firestoreValue);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Spymaster Plan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    // Turn selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: List.generate(widget.maxTurn, (i) {
                          final t = i + 1;
                          final isSel = t == selectedTurn;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: isSel,
                              label: Text('Turn $t'),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                              selectedColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              onSelected: (_) {
                                setState(() {
                                  selectedTurn = t;
                                  _dirty = false;
                                  _lastLoadedValue = '';
                                });
                              },
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Draft clue
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: clueCtrl,
                              style: const TextStyle(color: Colors.white),
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Planned clue (optional)',
                                labelStyle: const TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.white.withOpacity(0.16)),
                              ),
                            ),
                            onPressed: () async {
                              final v = clueCtrl.text.trim();

                              await _setDraftClueForTurnV2(
                                roomRef: widget.roomRef,
                                team: widget.team,
                                turn: selectedTurn,
                                clueWord: v,
                              );

                              _lastLoadedValue = v;
                              _dirty = false;

                              if (mounted) FocusScope.of(context).unfocus();
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: wordsInTurn.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No words in this turn yet.\nTap cards on the board to assign them.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: wordsInTurn.length,
                                  separatorBuilder: (_, __) =>
                                      Divider(color: Colors.white.withOpacity(0.10)),
                                  itemBuilder: (_, i) {
                                    final w = wordsInTurn[i]['word']!;
                                    final id = wordsInTurn[i]['id']!;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            w,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove',
                                          icon: const Icon(Icons.close, color: Colors.white70),
                                          onPressed: () => _removeWordFromPlanV2(
                                            roomRef: widget.roomRef,
                                            team: widget.team,
                                            wordKey: id,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

}
DocumentReference _teamPlanDoc(DocumentReference roomRef, String team) {
  return roomRef.collection('spymasterPlan').doc(team);
}

CollectionReference _targetsCol(DocumentReference roomRef, String team) {
  return _teamPlanDoc(roomRef, team).collection('targets');
}

CollectionReference _cluesCol(DocumentReference roomRef, String team) {
  return _teamPlanDoc(roomRef, team).collection('clues');
}