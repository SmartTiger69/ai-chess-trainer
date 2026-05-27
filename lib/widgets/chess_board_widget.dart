import 'package:chess/chess.dart' as chess;
import 'package:ai_chess_trainer_app/widgets/promotion_dialog.dart';
import 'package:flutter/material.dart';

typedef ChessMoveCallback = Future<void> Function(Map<String, String> move);

class ChessBoardWidget extends StatefulWidget {
  final chess.Chess game;
  final ChessMoveCallback onMove;
  final bool isInteractive;
  final bool whiteAtBottom;

  const ChessBoardWidget({
    super.key,
    required this.game,
    required this.onMove,
    this.isInteractive = true,
    this.whiteAtBottom = true,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  static const List<String> _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const Color _lightSquare = Color(0xFFEEEED2);
  static const Color _darkSquare = Color(0xFF769656);
  static const Color _selectedColor = Color(0xDDF6F669);
  static const Color _moveDotColor = Color(0x55333A2C);

  String? _selectedSquare;
  Set<String> _legalDestinationSquares = <String>{};

  @override
  void didUpdateWidget(covariant ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.fen != widget.game.fen) {
      _selectedSquare = null;
      _legalDestinationSquares = <String>{};
    }
  }

  Future<void> _handleSquareTap(String square) async {
    if (!widget.isInteractive) return;

    final selectedSquare = _selectedSquare;
    if (selectedSquare != null && _legalDestinationSquares.contains(square)) {
      final move = await _buildMove(selectedSquare, square);
      _clearSelection();
      if (move != null) {
        await widget.onMove(move);
      }
      return;
    }

    final piece = widget.game.get(square);
    if (piece != null && piece.color == widget.game.turn) {
      if (selectedSquare == square) {
        _clearSelection();
        return;
      }

      _selectSquare(square);
      return;
    }

    _clearSelection();
  }

  void _handleDragStarted(String square) {
    if (!widget.isInteractive) return;
    _selectSquare(square);
  }

  void _handleDragCanceled() {
    _clearSelection();
  }

  bool _canDropOnSquare(String? from, String to) {
    return widget.isInteractive &&
        from != null &&
        from != to &&
        _findMove(from, to) != null;
  }

  Future<void> _handlePieceDrop(String from, String to) async {
    if (!widget.isInteractive) return;

    final move = await _buildMove(from, to);
    _clearSelection();
    if (move != null) {
      await widget.onMove(move);
    }
  }

  void _selectSquare(String square) {
    if (_selectedSquare == square) return;

    setState(() {
      _selectedSquare = square;
      _legalDestinationSquares = _legalMovesFrom(
        square,
      ).map((move) => move['to']!).toSet();
    });
  }

  void _clearSelection() {
    if (_selectedSquare == null && _legalDestinationSquares.isEmpty) return;

    setState(() {
      _selectedSquare = null;
      _legalDestinationSquares = <String>{};
    });
  }

  List<Map<String, String>> _legalMovesFrom(String square) {
    return widget.game
        .moves({'verbose': true, 'square': square})
        .cast<Map>()
        .map(_stringMoveMap)
        .toList();
  }

  Map<String, String>? _findMove(String from, String to) {
    final moves = _legalMovesFrom(from).where((move) => move['to'] == to);
    if (moves.isEmpty) return null;

    return moves.first;
  }

  Future<Map<String, String>?> _buildMove(String from, String to) async {
    final moves = _legalMovesFrom(from).where((move) => move['to'] == to);
    if (moves.isEmpty) return null;

    final piece = widget.game.get(from);
    if (piece == null || !_isPawnPromotion(piece, to)) return moves.first;

    final promotionMoves = moves.where((move) => move['promotion'] != null);
    debugPrint(
      '[promotion] ${piece.color == chess.Color.WHITE ? 'white' : 'black'} '
      'pawn reached last rank: $from -> $to',
    );
    debugPrint(
      '[promotion] legal promotion codes: '
      '${promotionMoves.map((move) => move['promotion']).join(', ')}',
    );

    final normalizedPromotion = await _selectPromotion(piece);
    if (normalizedPromotion == null) return null;

    final legalPromotionCodes = promotionMoves
        .map((move) => move['promotion'])
        .whereType<String>()
        .toSet();
    if (legalPromotionCodes.isNotEmpty &&
        !legalPromotionCodes.contains(normalizedPromotion)) {
      debugPrint('[promotion] illegal promotion ignored: $normalizedPromotion');
      return null;
    }

    final move = <String, String>{
      'from': from,
      'to': to,
      'promotion': normalizedPromotion,
    };
    debugPrint('[promotion] move payload prepared: $move');
    return move;
  }

  bool _isPawnPromotion(chess.Piece piece, String to) {
    if (piece.type != chess.PieceType.PAWN) return false;

    final targetRank = to.length == 2 ? to[1] : '';
    return (piece.color == chess.Color.WHITE && targetRank == '8') ||
        (piece.color == chess.Color.BLACK && targetRank == '1');
  }

  Future<String?> _selectPromotion(chess.Piece piece) async {
    debugPrint('[promotion] opening dialog');

    final promotion = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PromotionDialog(isWhite: piece.color == chess.Color.WHITE),
    );

    debugPrint('[promotion] dialog returned: $promotion');

    if (!mounted || promotion == null) return null;

    final normalizedPromotion = promotion.toLowerCase();
    if (!const {'q', 'r', 'b', 'n'}.contains(normalizedPromotion)) {
      debugPrint('[promotion] invalid promotion ignored: $promotion');
      return null;
    }

    return normalizedPromotion;
  }

  Map<String, String> _stringMoveMap(Map move) {
    return <String, String>{
      'from': move['from'] as String,
      'to': move['to'] as String,
      if (move['promotion'] != null)
        'promotion': _pieceTypeCode(move['promotion']),
    };
  }

  String _pieceTypeCode(Object pieceType) {
    if (pieceType is chess.PieceType) return pieceType.name;
    return pieceType.toString().toLowerCase();
  }

  String _squareName(int index) {
    final row = index ~/ 8;
    final column = index % 8;

    final file = widget.whiteAtBottom ? _files[column] : _files[7 - column];
    final rank = widget.whiteAtBottom ? 8 - row : row + 1;
    return '$file$rank';
  }

  Color _squareColor(int index, String square) {
    final row = index ~/ 8;
    final column = index % 8;
    final baseColor = (row + column).isEven ? _lightSquare : _darkSquare;

    if (_selectedSquare == square) return _selectedColor;

    return baseColor;
  }

  String? _pieceAssetPath(chess.Piece? piece) {
    if (piece == null) return null;

    final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    return 'assets/pieces/$colorPrefix${_pieceAssetName(piece.type)}.png';
  }

  String _pieceAssetName(chess.PieceType pieceType) {
    switch (pieceType) {
      case chess.PieceType.PAWN:
        return 'p';
      case chess.PieceType.KNIGHT:
        return 'n';
      case chess.PieceType.BISHOP:
        return 'b';
      case chess.PieceType.ROOK:
        return 'r';
      case chess.PieceType.QUEEN:
        return 'q';
      case chess.PieceType.KING:
        return 'k';
      default:
        return 'p';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                offset: Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              itemBuilder: (context, index) {
                final square = _squareName(index);
                final piece = widget.game.get(square);
                final pieceAssetPath = _pieceAssetPath(piece);
                final isLegalDestination = _legalDestinationSquares.contains(
                  square,
                );
                final isSelected = _selectedSquare == square;

                return _BoardSquare(
                  key: ValueKey(square),
                  color: _squareColor(index, square),
                  pieceAssetPath: pieceAssetPath,
                  square: square,
                  isSelected: isSelected,
                  showMoveDot: isLegalDestination && piece == null,
                  moveDotColor: _moveDotColor,
                  isDraggable: widget.isInteractive && piece != null,
                  onDragStarted: () => _handleDragStarted(square),
                  onDragCanceled: _handleDragCanceled,
                  onCanAcceptDrop: (from) => _canDropOnSquare(from, square),
                  onAcceptDrop: (from) => _handlePieceDrop(from, square),
                  onTap: () => _handleSquareTap(square),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardSquare extends StatelessWidget {
  final Color color;
  final String? pieceAssetPath;
  final String square;
  final bool isSelected;
  final bool showMoveDot;
  final Color moveDotColor;
  final bool isDraggable;
  final VoidCallback onDragStarted;
  final VoidCallback onDragCanceled;
  final bool Function(String? from) onCanAcceptDrop;
  final void Function(String from) onAcceptDrop;
  final VoidCallback onTap;

  const _BoardSquare({
    super.key,
    required this.color,
    required this.pieceAssetPath,
    required this.square,
    required this.isSelected,
    required this.showMoveDot,
    required this.moveDotColor,
    required this.isDraggable,
    required this.onDragStarted,
    required this.onDragCanceled,
    required this.onCanAcceptDrop,
    required this.onAcceptDrop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, String>>(
      onWillAcceptWithDetails: (details) =>
          onCanAcceptDrop(details.data['from']),
      onAcceptWithDetails: (details) => onAcceptDrop(details.data['from']!),
      builder: (context, _, __) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final squareSize = constraints.biggest.shortestSide;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (showMoveDot)
                      FractionallySizedBox(
                        widthFactor: 0.24,
                        heightFactor: 0.24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: moveDotColor,
                          ),
                        ),
                      ),
                    if (pieceAssetPath != null)
                      _DraggablePiece(
                        assetPath: pieceAssetPath!,
                        square: square,
                        squareSize: squareSize,
                        isSelected: isSelected,
                        isDraggable: isDraggable,
                        onDragStarted: onDragStarted,
                        onDragCanceled: onDragCanceled,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DraggablePiece extends StatelessWidget {
  final String assetPath;
  final String square;
  final double squareSize;
  final bool isSelected;
  final bool isDraggable;
  final VoidCallback onDragStarted;
  final VoidCallback onDragCanceled;

  const _DraggablePiece({
    required this.assetPath,
    required this.square,
    required this.squareSize,
    required this.isSelected,
    required this.isDraggable,
    required this.onDragStarted,
    required this.onDragCanceled,
  });

  @override
  Widget build(BuildContext context) {
    final piece = _PieceImage(
      assetPath: assetPath,
      square: square,
      isSelected: isSelected,
    );

    if (!isDraggable) return piece;

    return Draggable<Map<String, String>>(
      data: <String, String>{'from': square},
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDraggableCanceled: (_, __) => onDragCanceled(),
      feedback: SizedBox.square(
        dimension: squareSize,
        child: IgnorePointer(
          child: _PieceImage(
            assetPath: assetPath,
            square: square,
            isSelected: true,
          ),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      onDragStarted: onDragStarted,
      child: piece,
    );
  }
}

class _PieceImage extends StatelessWidget {
  final String assetPath;
  final String square;
  final bool isSelected;

  const _PieceImage({
    required this.assetPath,
    required this.square,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.04 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: FractionallySizedBox(
        widthFactor: 1,
        heightFactor: 1,
        child: RepaintBoundary(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            semanticLabel: '$square chess piece',
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
