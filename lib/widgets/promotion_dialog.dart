import 'package:flutter/material.dart';

class PromotionDialog extends StatelessWidget {
  final bool isWhite;

  const PromotionDialog({super.key, required this.isWhite});

  static const _pieces = <_PromotionOption>[
    _PromotionOption('q', 'Queen'),
    _PromotionOption('r', 'Rook'),
    _PromotionOption('b', 'Bishop'),
    _PromotionOption('n', 'Knight'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorPrefix = isWhite ? 'w' : 'b';
    debugPrint('[promotion] dialog opening for ${isWhite ? 'white' : 'black'}');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: const Color(0xFF202124),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Promote pawn',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final piece in _pieces)
                    _PromotionTile(
                      piece: piece,
                      assetPath: 'assets/pieces/$colorPrefix${piece.code}.png',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionOption {
  final String code;
  final String label;

  const _PromotionOption(this.code, this.label);
}

class _PromotionTile extends StatelessWidget {
  final _PromotionOption piece;
  final String assetPath;

  const _PromotionTile({required this.piece, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: piece.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            debugPrint('[promotion] selected ${piece.label} (${piece.code})');
            Navigator.of(context).pop(piece.code);
          },
          child: SizedBox(
            width: 72,
            height: 86,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    assetPath,
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    piece.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
