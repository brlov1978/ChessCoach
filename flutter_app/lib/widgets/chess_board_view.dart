import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_app/utils/chess_board_utils.dart';

class ChessBoardView extends StatelessWidget {
  const ChessBoardView({
    super.key,
    required this.fen,
    required this.onSquareTap,
    required this.onMoveAttempt,
    this.selectedSquare,
    this.highlightSquare,
  });

  final String fen;
  final ValueChanged<String> onSquareTap;
  final void Function(String fromSquare, String toSquare) onMoveAttempt;
  final String? selectedSquare;
  final String? highlightSquare;

  static const Map<String, String> _pieceAssets = {
    'k': 'assets/pieces/king.svg',
    'q': 'assets/pieces/queen.svg',
    'r': 'assets/pieces/rook.svg',
    'b': 'assets/pieces/bishop.svg',
    'n': 'assets/pieces/knight.svg',
    'p': 'assets/pieces/pawn.svg',
  };

  Widget _buildPieceWidget(String piece, {double size = 34}) {
    if (piece.isEmpty) {
      return const SizedBox.shrink();
    }

    final isWhite = piece == piece.toUpperCase();
    final normalizedPiece = piece.toLowerCase();
    final sizeFactor = switch (normalizedPiece) {
      'p' => 0.82,
      'r' => 0.92,
      'n' => 0.96,
      'b' => 0.96,
      'q' => 0.99,
      'k' => 1.00,
      _ => 0.94,
    };

    final pieceAsset = _pieceAssets[normalizedPiece]!;
    final frontColor =
        isWhite ? const Color(0xFFFDFBF6) : const Color(0xFF1F1F1F);
    final outlineColor =
        isWhite ? const Color(0xFF3A342E) : const Color(0xFFE8E2D8);
    final pieceSize = size * sizeFactor;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, size * 0.04),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                pieceAsset,
                width: pieceSize * 1.08,
                height: pieceSize * 1.08,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(outlineColor, BlendMode.srcIn),
              ),
              SvgPicture.asset(
                pieceAsset,
                width: pieceSize,
                height: pieceSize,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(frontColor, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = expandFenBoard(fen);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D1B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4A4743), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: List.generate(8, (row) {
            return Expanded(
              child: Row(
                children: List.generate(8, (column) {
                  final square =
                      '${String.fromCharCode(97 + column)}${8 - row}';
                  final piece = rows[row][column];
                  final isLight = (row + column).isEven;
                  final isSelected = selectedSquare == square;
                  final isHighlighted = highlightSquare == square;
                  final isDraggablePiece =
                      piece.isNotEmpty && isSideToMovePiece(fen, piece);

                  return Expanded(
                    child: DragTarget<String>(
                      onWillAccept: (fromSquare) =>
                          fromSquare != null && fromSquare != square,
                      onAccept: (fromSquare) =>
                          onMoveAttempt(fromSquare, square),
                      builder: (context, candidateData, rejectedData) {
                        final isDropCandidate = candidateData.isNotEmpty;
                        final pieceWidget = Center(
                          child: _buildPieceWidget(piece, size: 42),
                        );

                        return GestureDetector(
                          onTap: () => onSquareTap(square),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFBACA44)
                                  : isHighlighted || isDropCandidate
                                      ? const Color(0xFFF6F669)
                                      : isLight
                                          ? const Color(0xFFEEEED2)
                                          : const Color(0xFF769656),
                              border: Border.all(
                                color: isSelected ||
                                        isHighlighted ||
                                        isDropCandidate
                                    ? const Color(0xCC1F1D1B)
                                    : Colors.transparent,
                                width: isSelected ||
                                        isHighlighted ||
                                        isDropCandidate
                                    ? 1.5
                                    : 0,
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (column == 0)
                                  Positioned(
                                    left: 4,
                                    top: 2,
                                    child: Text(
                                      '${8 - row}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isLight
                                            ? const Color(0xFF769656)
                                            : const Color(0xFFEFEFE0),
                                      ),
                                    ),
                                  ),
                                if (row == 7)
                                  Positioned(
                                    right: 4,
                                    bottom: 2,
                                    child: Text(
                                      String.fromCharCode(97 + column),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isLight
                                            ? const Color(0xFF769656)
                                            : const Color(0xFFEFEFE0),
                                      ),
                                    ),
                                  ),
                                Center(
                                  child: isDraggablePiece
                                      ? Draggable<String>(
                                          data: square,
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: SizedBox(
                                              width: 56,
                                              height: 56,
                                              child: _buildPieceWidget(piece,
                                                  size: 50),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(
                                            opacity: 0.25,
                                            child: pieceWidget,
                                          ),
                                          child: pieceWidget,
                                        )
                                      : pieceWidget,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}
