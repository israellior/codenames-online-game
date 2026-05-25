import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';

class GeminiBotClient {
  static Future<int> pickMove({
    required String team,
    required String hintWord,
    required int hintNumber,
    required int remainingGuesses,
    required List<Map<String, dynamic>> board, // FULL board locally
  }) async {
    final unrevealed = <int>[];
    for (int i = 0; i < board.length; i++) {
      if (board[i]['revealed'] == false) {
        unrevealed.add(i);
      }
    }
    if (unrevealed.isEmpty) return -1;

    // 🚫 Strip team info before sending
    final operativeBoard = board
        .map((c) => {
              "word": c["word"],
              "revealed": c["revealed"],
            })
        .toList();

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('pickOperativeMove');

      final res = await callable.call({
        "hintWord": hintWord,
        "hintNumber": hintNumber,
        "remainingGuesses": remainingGuesses,
        "board": operativeBoard,
      });

      final raw = res.data["index"];
      final idx = raw is int ? raw : int.tryParse(raw.toString());

      if (idx != null &&
          idx >= 0 &&
          idx < board.length &&
          board[idx]['revealed'] == false) {
        return idx;
      }
    } catch (_) {}

    // 🎯 Smart fallback (semantic blindness → neutral bias)
    final safe = unrevealed.where((i) {
      final t = board[i]['team'];
      return t == team || t == 'neutral';
    }).toList();

    final r = Random();
    return safe.isNotEmpty
        ? safe[r.nextInt(safe.length)]
        : unrevealed[r.nextInt(unrevealed.length)];
  }
}
