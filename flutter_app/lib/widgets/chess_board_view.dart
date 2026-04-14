import 'package:flutter/material.dart';

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

  static const Map<String, String> _pieceGlyphs = {
    'K': '♚',
    'Q': '♛',
    'R': '♜',
    'B': '♝',
    'N': '♞',
    'P': '♟',
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };

  Widget _buildPieceWidget(String piece, {double size = 34}) {
    if (piece.isEmpty) {
      return const SizedBox.shrink();
    }

    final isWhite = piece == piece.toUpperCase();
    final normalizedPiece = piece.toUpperCase();
    final sizeFactor = switch (normalizedPiece) {
      'P' => 0.92,
      'R' => 1.00,
      'N' => 1.03,
      'B' => 1.03,
      'Q' => 1.05,
      'K' => 1.06,
      _ => 1.0,
    };

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, size * 0.06),
          child: Text(
            _pieceGlyphs[piece] ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * sizeFactor,
              height: 1,
              color:
                  isWhite ? const Color(0xFFF8F8F6) : const Color(0xFF202020),
              shadows: [
                Shadow(
                  color: isWhite ? Colors.black45 : Colors.white38,
                  offset: const Offset(0.7, 0.8),
                  blurRadius: 1.0,
                ),
              ],
            ),
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
