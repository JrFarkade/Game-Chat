import 'dart:math';

class RoomCodeGen {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // exclude 0, O, 1, I to avoid typos
  static final _rnd = Random();

  /// Generates a clean 5-character room code (e.g. "X7K92")
  static String generate([int length = 5]) {
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length)),
      ),
    );
  }
}
