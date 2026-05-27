import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chess.dart accepts all pawn promotion piece codes', () {
    const promotionCodes = ['q', 'r', 'b', 'n'];

    for (final promotion in promotionCodes) {
      final game = chess.Chess.fromFEN('8/P7/8/8/8/8/8/k6K w - - 0 1');

      final moveWasMade = game.move({
        'from': 'a7',
        'to': 'a8',
        'promotion': promotion,
      });

      expect(moveWasMade, isTrue, reason: 'promotion $promotion should move');
      expect(game.get('a8')?.type.name, promotion);
    }
  });
}
