import 'stockfish_engine_base.dart';
import 'stockfish_engine_native.dart'
    if (dart.library.html) 'stockfish_engine_web.dart';

Future<StockfishEngine> createStockfishEngine() =>
    createPlatformStockfishEngine();
