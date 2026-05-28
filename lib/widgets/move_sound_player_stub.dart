import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class BoardSoundPlayer {
  const BoardSoundPlayer._();

  static void prime() {}

  static void play({required bool capture}) {
    debugPrint('[sound:platform] play requested capture=$capture');
    SystemSound.play(capture ? SystemSoundType.alert : SystemSoundType.click);
  }
}
