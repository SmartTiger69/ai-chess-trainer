import 'dart:math';

import 'package:ai_chess_trainer_app/widgets/chess_board_widget.dart';
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chess Trainer',
      theme: ThemeData.dark(),
      home: const ChessScreen(),
    );
  }
}

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  chess.Chess game = chess.Chess();

  String gameStatus = "White to move";

  bool isAiThinking = false;

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

  Map<String, String> moveMapFromVerboseMove(Map move) {
    return <String, String>{
      'from': move['from'] as String,
      'to': move['to'] as String,
      if (move['promotion'] != null)
        'promotion': pieceTypeCode(move['promotion']),
    };
  }

  String pieceTypeCode(Object pieceType) {
    if (pieceType is chess.PieceType) return pieceType.name;
    return pieceType.toString().toLowerCase();
  }

  Future<void> makeAiMove() async {
    if (game.game_over) return;

    if (game.turn != chess.Color.BLACK) return;

    setState(() {
      isAiThinking = true;

      gameStatus = "AI Thinking...";
    });

    await Future.delayed(const Duration(seconds: 1));

    final moves = game.moves({'verbose': true}).cast<Map>();

    if (moves.isEmpty) return;

    final random = Random();

    final aiMove = moveMapFromVerboseMove(moves[random.nextInt(moves.length)]);

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

    if (!game.game_over && game.turn == chess.Color.BLACK && !isAiThinking) {
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
    setState(() {
      game = chess.Chess();

      gameStatus = "White to move";

      isAiThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,

        title: const Text(
          "AI Chess Trainer",

          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.deepPurple,

                borderRadius: BorderRadius.circular(16),
              ),

              child: Column(
                children: [
                  const Text(
                    "Game Status",

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(gameStatus, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ChessBoardWidget(
                key: ValueKey(game.fen),

                game: game,

                whiteAtBottom: true,

                isInteractive:
                    !isAiThinking &&
                    !game.game_over &&
                    game.turn == chess.Color.WHITE,

                onMove: handleMove,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),

                onPressed: resetGame,

                child: const Text("Reset Game", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
