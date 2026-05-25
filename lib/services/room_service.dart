import 'dart:math';

class RoomService {
  static String generateRoomCode([int length = 3]) {
    const chars = '0123456789';
    final rand = Random();

    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}