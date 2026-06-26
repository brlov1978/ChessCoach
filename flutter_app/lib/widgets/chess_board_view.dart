import 'package:flutter/material.dart';

import 'package:flutter_app/utils/chess_board_utils.dart';

class ChessBoardView extends StatelessWidget {
  const ChessBoardView({
    super.key,
    required this.fen,
    required this.onSquareTap,
    required this.onMoveAttempt,
    this.blackPerspective,
    this.selectedSquare,
    this.highlightSquare,
  });

  final String fen;
  final ValueChanged<String> onSquareTap;
  final void Function(String fromSquare, String toSquare) onMoveAttempt;
  final bool? blackPerspective;
  final String? selectedSquare;
  final String? highlightSquare;

  static const Map<String, String> _solidPieceGlyphs = {
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };

  static const List<Offset> _outlineOffsets = [
    Offset(-1.4, 0),
    Offset(1.4, 0),
    Offset(0, -1.4),
    Offset(0, 1.4),
    Offset(-1.0, -1.0),
    Offset(1.0, -1.0),
    Offset(-1.0, 1.0),
    Offset(1.0, 1.0),
  ];

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

    final glyph = _solidPieceGlyphs[normalizedPiece] ?? '';
    final frontColor = isWhite ? const Color(0xFFF6F6F6) : const Color(0xFF111111);
    final pieceSize = size * sizeFactor * 1.15;
    final fontSize = pieceSize * 0.9;
    final verticalOffset = size * 0.02 + (normalizedPiece == 'p' ? 0 : 5);

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isWhite)
                ..._outlineOffsets.map(
                  (offset) => Transform.translate(
                    offset: offset,
                    child: Text(
                      glyph,
                      style: TextStyle(
                        fontSize: fontSize,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101010),
                      ),
                    ),
                  ),
                ),
              Text(
                glyph,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: frontColor,
                ),
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
    final parts = fen.split(' ');
    final isBlackToMove = blackPerspective ?? (parts.length > 1 && parts[1] == 'b');

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
                  final boardRow = isBlackToMove ? 7 - row : row;
                  final boardColumn = isBlackToMove ? 7 - column : column;
                  final square =
                    '${String.fromCharCode(97 + boardColumn)}${8 - boardRow}';
                  final piece = rows[boardRow][boardColumn];
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
                                      square.substring(1),
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
                                      square[0],
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
