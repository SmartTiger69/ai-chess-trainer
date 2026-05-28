import 'package:chess/chess.dart' as chess;
import 'package:ai_chess_trainer_app/widgets/move_sound_player.dart';
import 'package:ai_chess_trainer_app/widgets/promotion_dialog.dart';
import 'package:flutter/material.dart';

typedef ChessMoveCallback = Future<void> Function(Map<String, String> move);

class ChessBoardWidget extends StatefulWidget {
  final chess.Chess game;
  final ChessMoveCallback onMove;
  final bool isInteractive;
  final bool whiteAtBottom;
  final chess.Color userColor;

  const ChessBoardWidget({
    super.key,
    required this.game,
    required this.onMove,
    this.isInteractive = true,
    this.whiteAtBottom = true,
    required this.userColor,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  static const List<String> _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  static const Color _lightSquare = Color(0xFFEEEED2);
  static const Color _darkSquare = Color(0xFF769656);
  static const Color _selectedHighlightColor = Color(0x70F4F06A);
  static const Color _lastMoveHighlightColor = Color(0x66E7E864);
  static const Color _moveDotColor = Color(0x55333A2C);
  static const Color _lightCoordinateColor = Color(0xCC769656);
  static const Color _darkCoordinateColor = Color(0xCCEEEED2);
  static const Color _captureGlowColor = Color(0x44F8F3A2);

  String? _selectedSquare;
  Set<String> _legalDestinationSquares = <String>{};
  String? _lastSoundFen;
  String? _lastCaptureLogFen;
  String? _lastImmediateSoundMoveSignature;

  @override
  void didUpdateWidget(covariant ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.fen != widget.game.fen) {
      _selectedSquare = null;
      _legalDestinationSquares = <String>{};
      _playMoveSoundIfNeeded();
    }
  }

  Future<void> _handleSquareTap(String square) async {
    if (!widget.isInteractive) return;

    BoardSoundPlayer.prime();
    final selectedSquare = _selectedSquare;
    if (selectedSquare != null && _legalDestinationSquares.contains(square)) {
      final move = await _buildMove(selectedSquare, square);
      _clearSelection();
      if (move != null) {
        _playPendingMoveSound(move);
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

    BoardSoundPlayer.prime();
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
      _playPendingMoveSound(move);
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
      if (moves.first['captured'] != null)
        'captured': _pieceTypeCode(moves.first['captured']!),
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
      if (move['captured'] != null)
        'captured': _pieceTypeCode(move['captured']),
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

    final file = _fileForColumn(column);
    final rank = _rankForRow(row);
    return '$file$rank';
  }

  String _fileForColumn(int column) {
    return widget.whiteAtBottom ? _files[column] : _files[7 - column];
  }

  int _rankForRow(int row) {
    return widget.whiteAtBottom ? 8 - row : row + 1;
  }

  bool _isLightSquare(int index) {
    final row = index ~/ 8;
    final column = index % 8;
    return (row + column).isEven;
  }

  Color _squareColor(int index) {
    return _isLightSquare(index) ? _lightSquare : _darkSquare;
  }

  Color _coordinateColor(int index) {
    return _isLightSquare(index) ? _lightCoordinateColor : _darkCoordinateColor;
  }

  Set<String> _lastMoveSquares() {
    if (widget.game.history.isEmpty) return const <String>{};

    final move = widget.game.history.last.move;
    return <String>{move.fromAlgebraic, move.toAlgebraic};
  }

  _CaptureFeedback? _lastCaptureFeedback() {
    if (widget.game.history.isEmpty) return null;

    final move = widget.game.history.last.move;
    final capturedType = move.captured;
    if (capturedType == null) return null;

    final capturedColor = move.color == chess.Color.WHITE
        ? chess.Color.BLACK
        : chess.Color.WHITE;

    return _CaptureFeedback(
      square: move.toAlgebraic,
      assetPath: _pieceAssetPath(chess.Piece(capturedType, capturedColor))!,
      animationKey: '${widget.game.fen}:${move.toAlgebraic}',
    );
  }

  bool _lastMoveWasCapture() {
    return widget.game.history.isNotEmpty &&
        widget.game.history.last.move.captured != null;
  }

  void _playMoveSoundIfNeeded() {
    if (widget.game.history.isEmpty || _lastSoundFen == widget.game.fen) {
      return;
    }

    final lastMove = widget.game.history.last.move;
    final lastMoveSignature =
        '${lastMove.fromAlgebraic}->${lastMove.toAlgebraic}';
    _lastSoundFen = widget.game.fen;
    if (_lastImmediateSoundMoveSignature == lastMoveSignature) {
      debugPrint('[sound] post-move sound skipped after immediate playback');
      _lastImmediateSoundMoveSignature = null;
      return;
    }

    final isCapture = _lastMoveWasCapture();
    debugPrint(
      '[sound] post-move ${isCapture ? 'capture' : 'move'} sound for '
      '$lastMoveSignature',
    );
    BoardSoundPlayer.play(capture: isCapture);
  }

  void _playPendingMoveSound(Map<String, String> move) {
    final isCapture = move['captured'] != null;
    _lastImmediateSoundMoveSignature = '${move['from']}->${move['to']}';
    debugPrint(
      '[sound] immediate ${isCapture ? 'capture' : 'move'} sound for '
      '${move['from']}->${move['to']}',
    );
    BoardSoundPlayer.play(capture: isCapture);
  }

  List<String> _capturedPieceAssets(chess.Color color) {
    final assets = <String>[];

    for (final state in widget.game.history) {
      final capturedType = state.move.captured;
      if (capturedType == null) continue;

      final capturedColor = state.move.color == chess.Color.WHITE
          ? chess.Color.BLACK
          : chess.Color.WHITE;
      if (capturedColor != color) continue;

      assets.add(_pieceAssetPath(chess.Piece(capturedType, capturedColor))!);
    }

    assets.sort((a, b) => _pieceSortValue(a).compareTo(_pieceSortValue(b)));
    return assets;
  }

  int _pieceSortValue(String assetPath) {
    final code = assetPath.split('/').last.substring(1, 2);
    switch (code) {
      case 'q':
        return 0;
      case 'r':
        return 1;
      case 'b':
        return 2;
      case 'n':
        return 3;
      case 'p':
        return 4;
      default:
        return 5;
    }
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
    final lastMoveSquares = _lastMoveSquares();
    final captureFeedback = _lastCaptureFeedback();
    final capturedWhitePieces = _capturedPieceAssets(chess.Color.WHITE);
    final capturedBlackPieces = _capturedPieceAssets(chess.Color.BLACK);
    _debugLogCapturedPieces(capturedWhitePieces, capturedBlackPieces);

    final topPlayerColor = widget.whiteAtBottom ? chess.Color.BLACK : chess.Color.WHITE;
    final bottomPlayerColor = topPlayerColor == chess.Color.WHITE
        ? chess.Color.BLACK
        : chess.Color.WHITE;
    final topName = topPlayerColor == widget.userColor ? 'User' : 'Bot';
    final bottomName = bottomPlayerColor == widget.userColor ? 'User' : 'Bot';

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _PlayerHeader(
            name: topName,
            assetPaths: widget.whiteAtBottom
                ? capturedWhitePieces
                : capturedBlackPieces,
            materialAdvantage: widget.whiteAtBottom
                ? _materialAdvantageFor(chess.Color.BLACK)
                : _materialAdvantageFor(chess.Color.WHITE),
            avatarAssetPath: _pieceAssetPath(
              chess.Piece(chess.PieceType.KING, topPlayerColor),
            )!,
          ),
          const SizedBox(height: 8),
          Expanded(
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      final row = index ~/ 8;
                      final column = index % 8;
                      final square = _squareName(index);
                      final piece = widget.game.get(square);
                      final pieceAssetPath = _pieceAssetPath(piece);
                      final isLegalDestination = _legalDestinationSquares
                          .contains(square);
                      final isSelected = _selectedSquare == square;
                      final squareCaptureFeedback =
                          captureFeedback?.square == square
                          ? captureFeedback
                          : null;

                      return _BoardSquare(
                        key: ValueKey(square),
                        color: _squareColor(index),
                        pieceAssetPath: pieceAssetPath,
                        square: square,
                        isSelected: isSelected,
                        isLastMoveSquare: lastMoveSquares.contains(square),
                        showMoveDot: isLegalDestination && piece == null,
                        moveDotColor: _moveDotColor,
                        selectedHighlightColor: _selectedHighlightColor,
                        lastMoveHighlightColor: _lastMoveHighlightColor,
                        captureGlowColor: _captureGlowColor,
                        captureFeedback: squareCaptureFeedback,
                        rankLabel: column == 0 ? '${_rankForRow(row)}' : null,
                        fileLabel: row == 7 ? _fileForColumn(column) : null,
                        coordinateColor: _coordinateColor(index),
                        isDraggable: widget.isInteractive && piece != null,
                        onDragStarted: () => _handleDragStarted(square),
                        onDragCanceled: _handleDragCanceled,
                        onCanAcceptDrop: (from) =>
                            _canDropOnSquare(from, square),
                        onAcceptDrop: (from) => _handlePieceDrop(from, square),
                        onTap: () => _handleSquareTap(square),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _PlayerHeader(
            name: bottomName,
            assetPaths: widget.whiteAtBottom
                ? capturedBlackPieces
                : capturedWhitePieces,
            materialAdvantage: widget.whiteAtBottom
                ? _materialAdvantageFor(chess.Color.WHITE)
                : _materialAdvantageFor(chess.Color.BLACK),
            avatarAssetPath: _pieceAssetPath(
              chess.Piece(chess.PieceType.KING, bottomPlayerColor),
            )!,
          ),
        ],
      ),
    );
  }

  void _debugLogCapturedPieces(
    List<String> capturedWhitePieces,
    List<String> capturedBlackPieces,
  ) {
    if (_lastCaptureLogFen == widget.game.fen) return;

    _lastCaptureLogFen = widget.game.fen;
    debugPrint(
      '[capture-tray] white captured=${capturedWhitePieces.length}, '
      'black captured=${capturedBlackPieces.length}, '
      'history=${widget.game.history.length}',
    );
  }

  int _materialAdvantageFor(chess.Color playerColor) {
    final capturedWhiteValue = _capturedMaterialValue(chess.Color.WHITE);
    final capturedBlackValue = _capturedMaterialValue(chess.Color.BLACK);
    final advantage = playerColor == chess.Color.WHITE
        ? capturedBlackValue - capturedWhiteValue
        : capturedWhiteValue - capturedBlackValue;

    return advantage > 0 ? advantage : 0;
  }

  int _capturedMaterialValue(chess.Color capturedColor) {
    var value = 0;

    for (final state in widget.game.history) {
      final capturedType = state.move.captured;
      if (capturedType == null) continue;

      final color = state.move.color == chess.Color.WHITE
          ? chess.Color.BLACK
          : chess.Color.WHITE;
      if (color != capturedColor) continue;

      value += _pieceMaterialValue(capturedType);
    }

    return value;
  }

  int _pieceMaterialValue(chess.PieceType pieceType) {
    switch (pieceType) {
      case chess.PieceType.PAWN:
        return 1;
      case chess.PieceType.KNIGHT:
      case chess.PieceType.BISHOP:
        return 3;
      case chess.PieceType.ROOK:
        return 5;
      case chess.PieceType.QUEEN:
        return 9;
      case chess.PieceType.KING:
        return 0;
      default:
        return 0;
    }
  }
}

class _CaptureFeedback {
  final String square;
  final String assetPath;
  final String animationKey;

  const _CaptureFeedback({
    required this.square,
    required this.assetPath,
    required this.animationKey,
  });
}

class _BoardSquare extends StatelessWidget {
  final Color color;
  final String? pieceAssetPath;
  final String square;
  final bool isSelected;
  final bool isLastMoveSquare;
  final bool showMoveDot;
  final Color moveDotColor;
  final Color selectedHighlightColor;
  final Color lastMoveHighlightColor;
  final Color captureGlowColor;
  final _CaptureFeedback? captureFeedback;
  final String? rankLabel;
  final String? fileLabel;
  final Color coordinateColor;
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
    required this.isLastMoveSquare,
    required this.showMoveDot,
    required this.moveDotColor,
    required this.selectedHighlightColor,
    required this.lastMoveHighlightColor,
    required this.captureGlowColor,
    required this.captureFeedback,
    required this.rankLabel,
    required this.fileLabel,
    required this.coordinateColor,
    required this.isDraggable,
    required this.onDragStarted,
    required this.onDragCanceled,
    required this.onCanAcceptDrop,
    required this.onAcceptDrop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DragTarget<Map<String, String>>(
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
                  final captureFeedback = this.captureFeedback;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isLastMoveSquare)
                        _SquareHighlight(color: lastMoveHighlightColor),
                      if (isSelected)
                        _SquareHighlight(color: selectedHighlightColor),
                      if (captureFeedback != null)
                        _CaptureGlow(
                          key: ValueKey('${captureFeedback.animationKey}:glow'),
                          color: captureGlowColor,
                        ),
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
                      if (captureFeedback != null)
                        _CapturedPieceFade(
                          key: ValueKey(captureFeedback.animationKey),
                          assetPath: captureFeedback.assetPath,
                          square: square,
                        ),
                      if (rankLabel != null)
                        _BoardCoordinate(
                          label: rankLabel!,
                          color: coordinateColor,
                          alignment: Alignment.topLeft,
                        ),
                      if (fileLabel != null)
                        _BoardCoordinate(
                          label: fileLabel!,
                          color: coordinateColor,
                          alignment: Alignment.bottomRight,
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final String name;
  final List<String> assetPaths;
  final int materialAdvantage;
  final String avatarAssetPath;

  const _PlayerHeader({
    required this.name,
    required this.assetPaths,
    required this.materialAdvantage,
    required this.avatarAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: RepaintBoundary(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PlayerAvatar(assetPath: avatarAssetPath, name: name),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF5F5F2),
                      fontSize: 14,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CapturedPiecesInline(
                        assetPaths: assetPaths,
                        materialAdvantage: materialAdvantage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final String assetPath;
  final String name;

  const _PlayerAvatar({required this.assetPath, required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF3E3B36),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0x22FFFFFF), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Opacity(
            opacity: 0.9,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: '$name avatar chess king',
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapturedPiecesInline extends StatelessWidget {
  final List<String> assetPaths;
  final int materialAdvantage;

  const _CapturedPiecesInline({
    required this.assetPaths,
    required this.materialAdvantage,
  });

  @override
  Widget build(BuildContext context) {
    final hasAdvantage = materialAdvantage > 0;

    return SizedBox(
      height: 13,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (assetPaths.isNotEmpty)
            SizedBox(
              width: (assetPaths.length * 6 + 10).toDouble().clamp(14, 128),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < assetPaths.length; index++)
                    Positioned(
                      left: index * 6,
                      top: -2.5,
                      child: SizedBox.square(
                        dimension: 13,
                        child: Opacity(
                          opacity: 0.78,
                          child: Image.asset(
                            assetPaths[index],
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (hasAdvantage) ...[
            SizedBox(width: assetPaths.isEmpty ? 0 : 4),
            Opacity(
              opacity: 0.62,
              child: Text(
                '+$materialAdvantage',
                maxLines: 1,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: const TextStyle(
                  color: Color(0xFFD8D8D2),
                  fontSize: 11.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SquareHighlight extends StatelessWidget {
  final Color color;

  const _SquareHighlight({required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(decoration: BoxDecoration(color: color)),
      ),
    );
  }
}

class _CaptureGlow extends StatelessWidget {
  final Color color;

  const _CaptureGlow({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: const Color(0x99F4F06A), width: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CapturedPieceFade extends StatelessWidget {
  final String assetPath;
  final String square;

  const _CapturedPieceFade({
    super.key,
    required this.assetPath,
    required this.square,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1, end: 0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value * 0.38,
              child: Transform.scale(
                scale: 0.82 + (value * 0.18),
                child: child,
              ),
            );
          },
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            semanticLabel: '$square captured chess piece',
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

class _BoardCoordinate extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment alignment;

  const _BoardCoordinate({
    required this.label,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isBottom = alignment.y > 0;

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isBottom ? 0 : 3,
              isBottom ? 0 : 2,
              isBottom ? 3 : 0,
              isBottom ? 1 : 0,
            ),
            child: Text(
              label,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
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
      animateSelection: true,
    );

    if (!isDraggable) return piece;

    return Draggable<Map<String, String>>(
      data: <String, String>{'from': square},
      dragAnchorStrategy: childDragAnchorStrategy,
      rootOverlay: true,
      maxSimultaneousDrags: 1,
      onDraggableCanceled: (_, __) => onDragCanceled(),
      feedback: SizedBox.square(
        dimension: squareSize,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: Transform.scale(
              scale: 1.035,
              child: _PieceImage(
                assetPath: assetPath,
                square: square,
                isSelected: false,
                animateSelection: false,
              ),
            ),
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
  final bool animateSelection;

  const _PieceImage({
    required this.assetPath,
    required this.square,
    required this.isSelected,
    required this.animateSelection,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: '$square chess piece',
      gaplessPlayback: true,
    );

    return FractionallySizedBox(
      widthFactor: 1,
      heightFactor: 1,
      child: RepaintBoundary(
        child: animateSelection
            ? AnimatedScale(
                scale: isSelected ? 1.025 : 1,
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOutCubic,
                child: image,
              )
            : image,
      ),
    );
  }
}
