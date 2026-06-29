import 'dart:async';
import 'dart:math';

import 'package:ai_chess_trainer_app/services/chess_ai_service.dart';
import 'package:ai_chess_trainer_app/widgets/chess_board_widget.dart';
import 'package:ai_chess_trainer_app/widgets/move_sound_player.dart';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;

void main() {
  runApp(const MyApp());
}

enum PlayerSideChoice { white, black, random }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chess Trainer',
      theme: ThemeData.dark(),
      home: const NewGameSetupScreen(),
    );
  }
}

class _BotDifficulty {
  final String name;
  final int rating;

  const _BotDifficulty(this.name, this.rating);
}

class NewGameSetupScreen extends StatefulWidget {
  const NewGameSetupScreen({super.key});

  @override
  State<NewGameSetupScreen> createState() => _NewGameSetupScreenState();
}

class _NewGameSetupScreenState extends State<NewGameSetupScreen> {
  static const _bots = <_BotDifficulty>[
    _BotDifficulty('New to Chess', 200),
    _BotDifficulty('Beginner', 400),
    _BotDifficulty('Novice', 600),
    _BotDifficulty('Intermediate', 900),
    _BotDifficulty('Intermediate II', 1200),
  ];

  PlayerSideChoice _side = PlayerSideChoice.random;
  _BotDifficulty _bot = _bots[1];

  chess.Color _resolvedUserColor() {
    final resolved = _side == PlayerSideChoice.random
        ? (Random().nextBool()
              ? PlayerSideChoice.white
              : PlayerSideChoice.black)
        : _side;
    return resolved == PlayerSideChoice.white
        ? chess.Color.WHITE
        : chess.Color.BLACK;
  }

  void _startGame() {
    // Prime audio within a user gesture to allow AI-first moves (Play as Black).
    BoardSoundPlayer.prime();

    final userColor = _resolvedUserColor();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            ChessScreen(userColor: userColor, botRating: _bot.rating),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget sideIcon({
      required PlayerSideChoice value,
      required Widget child,
      required String label,
    }) {
      final selected = _side == value;
      return Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _side = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF2D2E34)
                  : const Color(0xFF1D1E22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0x33FFFFFF)
                    : const Color(0x1AFFFFFF),
                width: 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: selected
                    ? const Color(0xFFEFEFEF)
                    : const Color(0xFFC9C9C9),
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: 18,
                  color: selected
                      ? const Color(0xFFEFEFEF)
                      : const Color(0xFFC9C9C9),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F12),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "AI Chess Trainer",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    sideIcon(
                      value: PlayerSideChoice.white,
                      label: 'Play as White',
                      child: Opacity(
                        opacity: _side == PlayerSideChoice.white ? 1 : 0.82,
                        child: Image.asset(
                          'assets/pieces/wk.png',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    sideIcon(
                      value: PlayerSideChoice.random,
                      label: 'Random',
                      child: const Icon(Icons.casino_outlined),
                    ),
                    const SizedBox(width: 10),
                    sideIcon(
                      value: PlayerSideChoice.black,
                      label: 'Play as Black',
                      child: Opacity(
                        opacity: _side == PlayerSideChoice.black ? 1 : 0.82,
                        child: Image.asset(
                          'assets/pieces/bk.png',
                          width: 18,
                          height: 18,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16171B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x18FFFFFF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Choose Opponent',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Text(
                        '${_bot.rating}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFBDBDBD),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF101115),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x18FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: _bots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final bot = _bots[index];
                          final selected = bot.rating == _bot.rating;

                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _bot = bot),
                            hoverColor: const Color(0x14FFFFFF),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                12,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF1F2025)
                                    : const Color(0xFF17181D),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0x33FFFFFF)
                                      : const Color(0x14FFFFFF),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bot.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.1,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${bot.rating}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: const Color(0xFFA8A8A8),
                                                height: 1.1,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF3C7D2A)
                                          : const Color(0xFF222329),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0x554AE05D)
                                            : const Color(0x22FFFFFF),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 14,
                                      color: selected
                                          ? const Color(0xFFF2FFF0)
                                          : const Color(0x00000000),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3C7D2A),
                          foregroundColor: const Color(0xFFF2FFF0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ).merge(
                          ButtonStyle(
                            overlayColor: WidgetStateProperty.all(
                              const Color(0x2237FF63),
                            ),
                          ),
                        ),
                    onPressed: _startGame,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded),
                        const SizedBox(width: 6),
                        Text(
                          'Play',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: const Color(0xFFF2FFF0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChessScreen extends StatefulWidget {
  final chess.Color userColor;
  final int botRating;

  const ChessScreen({
    super.key,
    required this.userColor,
    required this.botRating,
  });

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  chess.Chess game = chess.Chess();
  late final ChessAiService _aiService;

  String gameStatus = "White to move";

  bool isAiThinking = false;

  chess.Color get _aiColor => widget.userColor == chess.Color.WHITE
      ? chess.Color.BLACK
      : chess.Color.WHITE;

  String currentGameStatus() {
    if (game.in_checkmate) {
      return game.turn == chess.Color.WHITE
          ? "Black Wins by Checkmate"
          : "White Wins by Checkmate";
    } else if (game.in_draw) {
      return "Draw";
    } else if (game.in_check) {
      return game.turn == chess.Color.WHITE
          ? "White is in Check"
          : "Black is in Check";
    }

    return game.turn == chess.Color.WHITE ? "White to move" : "Black to move";
  }

  @override
  void initState() {
    super.initState();
    _aiService = ChessAiService(botRating: widget.botRating);
    unawaited(
      _aiService.initialize().catchError((Object error, StackTrace stackTrace) {
        debugPrint('[stockfish] warmup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!game.game_over && game.turn == _aiColor) {
        makeAiMove();
      }
    });
  }

  @override
  void dispose() {
    unawaited(_aiService.dispose());
    super.dispose();
  }

  Future<void> makeAiMove() async {
    if (game.game_over) return;

    if (game.turn != _aiColor) return;

    setState(() {
      isAiThinking = true;

      gameStatus = "AI Thinking...";
    });

    await Future.delayed(const Duration(seconds: 1));

    Map<String, String>? aiMove;
    try {
      aiMove = (await _aiService.bestMoveForFen(game.fen))?.toMoveMap();
    } catch (error, stackTrace) {
      debugPrint('[stockfish] move request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted) return;
    if (aiMove == null) {
      setState(() {
        gameStatus = currentGameStatus();
        isAiThinking = false;
      });
      return;
    }

    logPromotionMoveStart(aiMove);
    debugPrint('[move] final game.move() payload: $aiMove');
    final aiMoveWasMade = game.move(aiMove);
    debugPrint('[move] game.move() returned: $aiMoveWasMade');
    if (aiMoveWasMade) {
      logPromotedPieceIfNeeded(aiMove);
    }

    setState(() {
      gameStatus = currentGameStatus();
      isAiThinking = false;
    });
  }

  Future<void> handleMove(Map<String, String> move) async {
    logPromotionMoveStart(move);
    debugPrint('[move] final game.move() payload: $move');
    final moveWasMade = game.move(move);
    debugPrint('[move] game.move() returned: $moveWasMade');

    if (!moveWasMade) return;

    logPromotedPieceIfNeeded(move);

    setState(() {
      gameStatus = currentGameStatus();
    });

    if (!game.game_over && game.turn == _aiColor && !isAiThinking) {
      await makeAiMove();
    }
  }

  void logPromotionMoveStart(Map<String, String> move) {
    final promotion = move['promotion'];
    if (promotion == null) return;

    debugPrint(
      '[promotion] pawn reaching last rank at execution: '
      '${move['from']} -> ${move['to']} as $promotion',
    );
  }

  void logPromotedPieceIfNeeded(Map<String, String> move) {
    final promotion = move['promotion'];
    if (promotion == null) return;

    final to = move['to'];
    final promotedPiece = to == null ? null : game.get(to);
    debugPrint(
      '[promotion] board after move: $to contains '
      '${promotedPiece?.color == chess.Color.WHITE ? 'white' : 'black'} '
      '${promotedPiece?.type.name}; expected $promotion',
    );
  }

  void resetGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NewGameSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final whiteAtBottom = widget.userColor == chess.Color.WHITE;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F12),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "AI Chess Trainer",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFFEFEFEF),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFA8A8A8)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: Text(
                gameStatus,
                style: const TextStyle(
                  color: Color(0xFFEFEFEF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ChessBoardWidget(
                  game: game,
                  whiteAtBottom: whiteAtBottom,
                  userColor: widget.userColor,
                  isInteractive:
                      !isAiThinking &&
                      !game.game_over &&
                      game.turn == widget.userColor,
                  onMove: handleMove,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFA8A8A8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: resetGame,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                "New Game",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
