import 'package:flutter_stockfish_plugin/stockfish.dart' as stockfish_plugin;

import 'stockfish_engine_base.dart';

Future<StockfishEngine> createPlatformStockfishEngine() async {
  final engine = NativeStockfishEngine();
  await engine.initialize();
  return engine;
}

class NativeStockfishEngine implements StockfishEngine {
  stockfish_plugin.Stockfish? _stockfish;

  @override
  Stream<String> get stdout => _stockfish!.stdout;

  @override
  Future<void> initialize() async {
    _stockfish = await stockfish_plugin.stockfishAsync();
  }

  @override
  void send(String command) {
    _stockfish?.stdin = command;
  }

  @override
  void dispose() {
    _stockfish?.dispose();
    _stockfish = null;
  }
}
