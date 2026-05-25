import 'dart:math';

class BoardService {
  static final List<String> sampleWords = [
    "APPLE", "BRIDGE", "CAT", "DRAGON", "EAGLE",
    "FOREST", "GOLD", "HOUSE", "ISLAND", "JOKER",
    "KING", "LION", "MONEY", "NINJA", "OCEAN",
    "PILOT", "QUEEN", "RAIN", "SNAKE", "TIGER",
    "UMBRELLA", "VIRUS", "WATER", "XENON", "YELLOW",
    "ZEBRA", "DOCTOR", "MOUNTAIN", "STAR", "RIVER",
    "CASTLE", "ROBOT", "LIGHT", "SPACE", "LASER",
    "MAGIC", "TRAIN", "CLOUD", "CHESS"
  ];

  /// Generate a random board of 25 cards
  static List<Map<String, dynamic>> generateBoard() {
    final rand = Random();

    // Shuffle words and pick 25
    final words = List<String>.from(sampleWords);
    words.shuffle(rand);
    final selectedWords = words.take(25).toList();

    // Prepare roles
    List<String> roles = [
      ...List.filled(9, "red"),
      ...List.filled(8, "blue"),
      ...List.filled(7, "neutral"),
      "assassin"
    ];

    roles.shuffle(rand);

    // Combine into card objects
    List<Map<String, dynamic>> board = [];
    for (int i = 0; i < 25; i++) {
      board.add({
        "word": selectedWords[i],
        "role": roles[i],
        "revealed": false,
      });
    }

    return board;
  }
}