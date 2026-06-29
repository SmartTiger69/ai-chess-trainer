import 'dart:async';
import 'dart:math';

import 'package:ai_chess_trainer_app/services/stockfish_engine.dart';
import 'package:ai_chess_trainer_app/services/stockfish_engine_base.dart';
import 'package:flutter/foundation.dart';

class StockfishAiMove {
  final String from;
  final String to;
  final String? promotion;

  const StockfishAiMove({required this.from, required this.to, this.promotion});

  Map<String, String> toMoveMap() {
    return <String, String>{
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion!,
    };
  }
}

class ChessAiService {
  final int botRating;

  StockfishEngine? _stockfish;
  StreamSubscription<String>? _stdoutSubscription;
  Completer<void>? _uciReadyCompleter;
  Completer<void>? _readyOkCompleter;
  Completer<String?>? _bestMoveCompleter;
  Future<void>? _initializing;
  Future<void> _requestQueue = Future<void>.value();
  bool _isDisposed = false;
  int? _configuredRating;
  bool _newGameSent = false;

  ChessAiService({required this.botRating});

  Future<void> initialize() {
    if (_isDisposed) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<StockfishAiMove?> bestMoveForFen(String fen) {
    final request = _requestQueue.then((_) => _bestMoveForFen(fen));
    _requestQueue = request.then<void>((_) {}, onError: (_) {});
    return request;
  }

  Future<void> _initialize() async {
    try {
      debugPrint('[stockfish] initializing engine');
      if (kIsWeb) {
        debugPrint(
          '[stockfish] web engine requires '
          'web/stockfish/stockfish-17.1-asm-341ff22.js',
        );
      }

      final stockfish = await createStockfishEngine().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException(
            'Stockfish startup timed out. On web, check the Stockfish worker asset.',
          );
        },
      );
      if (_isDisposed) {
        stockfish.dispose();
        return;
      }

      _stockfish = stockfish;
      _stdoutSubscription = stockfish.stdout.listen(
        _handleEngineLine,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[stockfish] stdout error: $error');
          debugPrintStack(stackTrace: stackTrace);
          _completePendingBestMove(null);
        },
      );

      await _sendUci();
      await _configureStrength();
      await _waitUntilReady();
      await _sendNewGame();
      await _waitUntilReady();
      debugPrint('[stockfish] initialized');
    } catch (error, stackTrace) {
      _initializing = null;
      debugPrint('[stockfish] initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<StockfishAiMove?> _bestMoveForFen(String fen) async {
    if (_isDisposed) return null;

    await initialize();
    if (_isDisposed) return null;

    await _configureStrength();
    await _waitUntilReady();
    await _sendNewGame();
    await _waitUntilReady();

    final stockfish = _stockfish;
    if (stockfish == null) return null;

    final completer = Completer<String?>();
    _bestMoveCompleter = completer;

    final settings = _settingsForRating(botRating);
    _sendCommand('position fen $fen');
    _sendCommand('go movetime ${settings.moveTimeMs}');

    final searchTimeoutMs = max(settings.moveTimeMs + 3000, 5000);
    final uciMove = await _waitForBestMove(
      completer,
      Duration(milliseconds: searchTimeoutMs),
    );

    final parsedMove = _parseUciMove(uciMove);
    debugPrint(
      '[stockfish] parsed bestmove: '
      '${parsedMove == null ? 'null' : parsedMove.toMoveMap()}',
    );
    return parsedMove;
  }

  Future<void> _sendUci() async {
    final stockfish = _stockfish;
    if (stockfish == null) return;

    final completer = Completer<void>();
    _uciReadyCompleter = completer;
    _sendCommand('uci');

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[stockfish] uci handshake timed out');
        if (identical(_uciReadyCompleter, completer)) {
          _uciReadyCompleter = null;
        }
      },
    );
  }

  Future<void> _configureStrength() async {
    final stockfish = _stockfish;
    if (stockfish == null || _configuredRating == botRating) return;

    final settings = _settingsForRating(botRating);
    _sendCommand('setoption name Skill Level value ${settings.skillLevel}');
    _sendCommand('setoption name Threads value 1');
    _sendCommand('setoption name Hash value 16');
    _configuredRating = botRating;
  }

  Future<void> _sendNewGame() async {
    final stockfish = _stockfish;
    if (stockfish == null || _newGameSent) return;

    _sendCommand('ucinewgame');
    _newGameSent = true;
  }

  Future<void> _waitUntilReady() async {
    final stockfish = _stockfish;
    if (stockfish == null) return;

    final completer = Completer<void>();
    _readyOkCompleter = completer;
    _sendCommand('isready');

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[stockfish] ready check timed out');
        if (identical(_readyOkCompleter, completer)) {
          _readyOkCompleter = null;
        }
      },
    );
  }

  void _handleEngineLine(String rawLine) {
    for (final line in rawLine.split('\n').map((line) => line.trim())) {
      _handleSingleEngineLine(line);
    }
  }

  void _handleSingleEngineLine(String line) {
    if (line.isEmpty) return;
    debugPrint('[stockfish] << $line');

    if (line == 'uciok') {
      _complete(_uciReadyCompleter);
      _uciReadyCompleter = null;
      return;
    }

    if (line == 'readyok') {
      _complete(_readyOkCompleter);
      _readyOkCompleter = null;
      return;
    }

    if (line.startsWith('bestmove ')) {
      final parts = line.split(RegExp(r'\s+'));
      final move = parts.length >= 2 ? parts[1] : null;
      debugPrint('[stockfish] bestmove received: $move');
      if (_bestMoveCompleter?.isCompleted == false) {
        _bestMoveCompleter!.complete(move == '(none)' ? null : move);
      }
      _bestMoveCompleter = null;
    }
  }

  Future<String?> _waitForBestMove(
    Completer<String?> completer,
    Duration timeout,
  ) async {
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      debugPrint(
        '[stockfish] bestmove timed out after ${timeout.inMilliseconds}ms',
      );
      if (identical(_bestMoveCompleter, completer)) {
        _sendCommand('stop');
      }

      try {
        return await completer.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        debugPrint('[stockfish] bestmove did not arrive after stop');
        if (identical(_bestMoveCompleter, completer)) {
          _bestMoveCompleter = null;
        }
        return null;
      }
    }
  }

  void _sendCommand(String command) {
    final stockfish = _stockfish;
    if (stockfish == null || _isDisposed) return;

    debugPrint('[stockfish] >> $command');
    stockfish.send(command);
  }

  void _completePendingBestMove(String? move) {
    if (_bestMoveCompleter?.isCompleted == false) {
      _bestMoveCompleter!.complete(move);
    }
    _bestMoveCompleter = null;
  }

  void _complete(Completer<void>? completer) {
    if (completer?.isCompleted == false) {
      completer!.complete();
    }
  }

  StockfishAiMove? _parseUciMove(String? uciMove) {
    if (uciMove == null || uciMove.length < 4) return null;

    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promotion = uciMove.length >= 5 ? uciMove.substring(4, 5) : null;

    if (!_isSquare(from) || !_isSquare(to)) return null;

    return StockfishAiMove(from: from, to: to, promotion: promotion);
  }

  bool _isSquare(String value) {
    if (value.length != 2) return false;

    final file = value.codeUnitAt(0);
    final rank = value.codeUnitAt(1);
    return file >= 'a'.codeUnitAt(0) &&
        file <= 'h'.codeUnitAt(0) &&
        rank >= '1'.codeUnitAt(0) &&
        rank <= '8'.codeUnitAt(0);
  }

  _StockfishStrengthSettings _settingsForRating(int rating) {
    if (rating <= 200) {
      return const _StockfishStrengthSettings(skillLevel: 0, moveTimeMs: 80);
    }
    if (rating <= 400) {
      return const _StockfishStrengthSettings(skillLevel: 2, moveTimeMs: 120);
    }
    if (rating <= 600) {
      return const _StockfishStrengthSettings(skillLevel: 4, moveTimeMs: 180);
    }
    if (rating <= 900) {
      return const _StockfishStrengthSettings(skillLevel: 7, moveTimeMs: 260);
    }
    return const _StockfishStrengthSettings(skillLevel: 10, moveTimeMs: 380);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _completePendingBestMove(null);
    _uciReadyCompleter = null;
    _readyOkCompleter = null;
    _bestMoveCompleter = null;
    await _stdoutSubscription?.cancel();
    _stdoutSubscription = null;
    _stockfish?.dispose();
    _stockfish = null;
  }
}

class _StockfishStrengthSettings {
  final int skillLevel;
  final int moveTimeMs;

  const _StockfishStrengthSettings({
    required this.skillLevel,
    required this.moveTimeMs,
  });
}
