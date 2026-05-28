// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class BoardSoundPlayer {
  static final String _moveSoundUri = _buildSoundUri(
    // Crisp, premium "wooden tick" (short transient + tight body).
    durationMs: 46,
    bodyFrequencies: const [820, 1320, 2080, 3120],
    knockFrequency: 360,
    amplitude: 0.20,
    seed: 17,
  );
  static final String _captureSoundUri = _buildSoundUri(
    // Slightly deeper + sharper than move (more body, slightly longer).
    durationMs: 70,
    bodyFrequencies: const [540, 860, 1280, 1780],
    knockFrequency: 230,
    amplitude: 0.23,
    seed: 43,
  );
  static bool _primed = false;

  const BoardSoundPlayer._();

  static void prime() {
    if (_primed) return;

    _primed = true;
    debugPrint('[sound:web] prime requested');
    final audio = html.AudioElement(_moveSoundUri)
      ..volume = 0
      ..muted = true;
    audio
        .play()
        .then((_) {
          audio.pause();
          debugPrint('[sound:web] prime completed');
        })
        .catchError((error) {
          debugPrint('[sound:web] prime blocked/failed: $error');
        });
  }

  static void play({required bool capture}) {
    debugPrint('[sound:web] play requested capture=$capture');
    final audio = html.AudioElement(capture ? _captureSoundUri : _moveSoundUri)
      ..volume = capture ? 0.205 : 0.172;
    audio
        .play()
        .then((_) {
          debugPrint('[sound:web] playback started capture=$capture');
        })
        .catchError((error) {
          debugPrint('[sound:web] playback blocked/failed: $error');
        });
  }

  static String _buildSoundUri({
    required int durationMs,
    required List<double> bodyFrequencies,
    required double knockFrequency,
    required double amplitude,
    required int seed,
  }) {
    const sampleRate = 44100;
    const headerLength = 44;
    const bytesPerSample = 2;
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final dataLength = sampleCount * bytesPerSample;
    final bytes = Uint8List(headerLength + dataLength);
    final data = ByteData.sublistView(bytes);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
    data.setUint16(32, bytesPerSample, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, dataLength, Endian.little);

    var noiseState = seed;
    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final progress = i / sampleCount;
      // Fast attack + snappy decay to feel like wood contact.
      final attack = math.min(1.0, progress * 85);
      final bodyEnvelope = attack * math.pow(1 - progress, 3.7).toDouble();
      final clickEnvelope = math.pow(1 - progress, 22).toDouble();
      final knockEnvelope = attack * math.pow(1 - progress, 6.1).toDouble();

      noiseState = (noiseState * 1664525 + 1013904223) & 0x7fffffff;
      final noise = ((noiseState / 0x7fffffff) * 2) - 1;

      // Tight click + reduced noise floor.
      var wave = noise * clickEnvelope * 0.36;

      for (var j = 0; j < bodyFrequencies.length; j++) {
        final weight = 0.34 / (j + 1);
        final detune = 1 + (j * 0.005);
        wave +=
            math.sin(2 * math.pi * bodyFrequencies[j] * detune * t) *
            bodyEnvelope *
            weight;
      }

      wave += math.sin(2 * math.pi * knockFrequency * t) * knockEnvelope * 0.62;
      wave = _softClip(wave * 1.7);

      final sample = (wave * amplitude * 32767).clamp(-32768, 32767).round();
      data.setInt16(headerLength + (i * bytesPerSample), sample, Endian.little);
    }

    return 'data:audio/wav;base64,${base64Encode(bytes)}';
  }

  static double _softClip(double sample) {
    return sample / (1 + sample.abs());
  }
}
