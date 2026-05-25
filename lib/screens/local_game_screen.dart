/*import 'package:flutter/material.dart';
import '../game/game_state.dart';

const List<String> demoWords = [
  "חתול",
  "כלב",
  "שולחן",
  "מחשב",
  "כדור",
  "ספר",
  "אור",
  "ים",
  "טלפון",
  "חלון",
  "דלת",
  "יד",
  "רגל",
  "שמיים",
  "כיסא",
  "חול",
  "ענן",
  "אוטו",
  "עץ",
  "כביש",
  "גשר",
  "שוקולד",
  "שעון",
  "עיפרון",
  "גיטרה",
];

class LocalGameScreen extends StatefulWidget {
  const LocalGameScreen({super.key});

  @override
  State<LocalGameScreen> createState() => _LocalGameScreenState();
}

class _LocalGameScreenState extends State<LocalGameScreen> {
  late GameState gameState;

  late TextEditingController _hintWordController;
  late TextEditingController _hintNumberController;
  Role _currentRole = Role.spymaster; 


    Color _teamColor(Team team) {
    switch (team) {
      case Team.red:
        return Colors.redAccent;
      case Team.blue:
        return Colors.blueAccent;
      case Team.neutral:
        return Colors.brown;
      case Team.assassin:
        return Colors.black;
    }
  }

  @override
  void initState() {
    super.initState();
    gameState = GameState.newGame(demoWords);
    _hintWordController = TextEditingController();
    _hintNumberController = TextEditingController();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Codenames'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),

          // מצב תצוגה: מנהיג / שחקן
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentRole == Role.spymaster
                    ? 'תצוגת מנהיג'
                    : 'תצוגת שחקן',
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentRole = _currentRole == Role.spymaster
                        ? Role.operative
                        : Role.spymaster;
                  });
                },
                child: Text(
                  _currentRole == Role.spymaster
                      ? 'עבור לתצוגת שחקן'
                      : 'עבור לתצוגת מנהיג',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // שורת סטטוס רמז
          Text(
            gameState.waitingForHint
                ? 'מחכים לרמז מה-${gameState.currentTeam == Team.red ? "אדומים" : "כחולים"}'
                : 'רמז: "${gameState.currentHintWord}" (${gameState.currentHintNumber}) | ניחושים נשארו: ${gameState.remainingGuesses}',
          ),

          const SizedBox(height: 8),

          // תור / מנצח
          Text(
            gameState.isGameOver
                ? 'Game Over! Winner: ${gameState.winnerTeam == Team.red ? "Red" : "Blue"}'
                : 'Turn: ${gameState.currentTeam == Team.red ? "Red" : "Blue"}',
          ),

          const SizedBox(height: 8),
          Text('Red remaining: ${gameState.redRemaining}'),
          Text('Blue remaining: ${gameState.blueRemaining}'),
          const SizedBox(height: 8),

          // אזור "תן רמז" – רק כשהמשחק חי ומחכים לרמז
          if (!gameState.isGameOver && gameState.waitingForHint) ...[
            if (_currentRole == Role.spymaster) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _hintWordController,
                        decoration: const InputDecoration(
                          labelText: 'מילת רמז',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: _hintNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'מס\'',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final word = _hintWordController.text.trim();
                        final numStr = _hintNumberController.text.trim();
                        final num = int.tryParse(numStr);

                        if (word.isEmpty || num == null || num <= 0) {
                          return;
                        }

                        setState(() {
                          gameState.setHint(word, num);
                        });

                        _hintWordController.clear();
                        _hintNumberController.clear();
                      },
                      child: const Text('תן רמז'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const Text(
                'מחכים לרמז מהמנהל...',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ],

          // כפתור משחק חדש
          ElevatedButton(
            onPressed: () {
              setState(() {
                gameState = GameState.newGame(demoWords);
              });
            },
            child: const Text('New Game'),
          ),

          const SizedBox(height: 8),

          // לוח המשחק
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                itemCount: gameState.board.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final card = gameState.board[index];

                  Color backgroundColor;
                  if (card.revealed) {
                    backgroundColor = _teamColor(card.team);
                  } else {
                    if (_currentRole == Role.spymaster) {
                      backgroundColor = _teamColor(card.team);
                    } else {
                      backgroundColor = Colors.white;
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      // מנהיג / מצב בלי רמז / סוף משחק – לא מנחשים
                      if (_currentRole == Role.spymaster ||
                          gameState.isGameOver ||
                          gameState.waitingForHint) {
                        return;
                      }

                      setState(() {
                        gameState.revealCard(index);
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(width: 1),
                        color: backgroundColor,
                      ),
                      child: Text(
                        card.word,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hintWordController.dispose();
    _hintNumberController.dispose();
    super.dispose();
  }
}
*/
