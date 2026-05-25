import 'package:cloud_functions/cloud_functions.dart';

class GeminiSpymasterClient {
  static Future<Map<String, dynamic>> generateHint({
    required String team,
    required List<Map<String, dynamic>> board, // FULL board with teams
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('generateSpymasterHint');

      final res = await callable.call({
        "team": team,
        "board": board,
      });

      final data = Map<String, dynamic>.from(res.data);
      if (data['word'] is String && data['number'] is int) {
        return data;
      }
    } catch (_) {}

    // Safe fallback
    return {"word": "random", "number": 1};
  }
}
