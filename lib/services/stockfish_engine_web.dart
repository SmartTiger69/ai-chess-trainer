// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'stockfish_engine_base.dart';

const _stockfishWorkerPath = 'stockfish/stockfish-17.1-asm-341ff22.js';

Future<StockfishEngine> createPlatformStockfishEngine() async {
  final engine = WebStockfishEngine();
  await engine.initialize();
  return engine;
}

class WebStockfishEngine implements StockfishEngine {
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();

  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  StreamSubscription<html.Event>? _errorSubscription;

  @override
  Stream<String> get stdout => _stdoutController.stream;

  @override
  Future<void> initialize() async {
    final worker = html.Worker(_stockfishWorkerPath);
    _worker = worker;

    _messageSubscription = worker.onMessage.listen((event) {
      final data = event.data;
      if (data == null) return;
      _stdoutController.add(data.toString());
    });

    _errorSubscription = worker.onError.listen((event) {
      _stdoutController.addError('Stockfish worker failed: $event');
    });
  }

  @override
  void send(String command) {
    _worker?.postMessage(command);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _errorSubscription?.cancel();
    _errorSubscription = null;
    _worker?.terminate();
    _worker = null;
    _stdoutController.close();
  }
}
