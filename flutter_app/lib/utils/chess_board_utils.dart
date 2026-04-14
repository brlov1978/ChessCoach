List<List<String>> expandFenBoard(String fen) {
  final placement = fen.split(' ').first;
  return placement.split('/').map((row) {
    final cells = <String>[];
    for (final char in row.split('')) {
      final count = int.tryParse(char);
      if (count != null) {
        for (var i = 0; i < count; i++) {
          cells.add('');
        }
      } else {
        cells.add(char);
      }
    }
    return cells;
  }).toList();
}

String compressFenBoard(List<List<String>> board) {
  return board.map((row) {
    final buffer = StringBuffer();
    var emptyCount = 0;

    for (final piece in row) {
      if (piece.isEmpty) {
        emptyCount++;
      } else {
        if (emptyCount > 0) {
          buffer.write(emptyCount);
          emptyCount = 0;
        }
        buffer.write(piece);
      }
    }

    if (emptyCount > 0) {
      buffer.write(emptyCount);
    }

    return buffer.toString();
  }).join('/');
}

int fileToColumn(String square) => square.codeUnitAt(0) - 97;

int rankToRow(String square) => 8 - int.parse(square.substring(1));

String pieceAtSquare(String fen, String square) {
  final board = expandFenBoard(fen);
  return board[rankToRow(square)][fileToColumn(square)];
}

bool isSideToMovePiece(String fen, String piece) {
  final parts = fen.split(' ');
  final turn = parts.length > 1 ? parts[1] : 'w';
  return turn == 'w' ? piece == piece.toUpperCase() : piece == piece.toLowerCase();
}

String applyMoveToFen(String fen, String uci) {
  if (uci.length < 4) {
    return fen;
  }

  final parts = fen.split(' ');
  while (parts.length < 6) {
    parts.add(parts.length == 1 ? 'w' : '-');
  }

  final board = expandFenBoard(fen);
  final from = uci.substring(0, 2);
  final to = uci.substring(2, 4);
  final fromRow = rankToRow(from);
  final fromColumn = fileToColumn(from);
  final toRow = rankToRow(to);
  final toColumn = fileToColumn(to);
  final piece = board[fromRow][fromColumn];

  if (piece.isEmpty) {
    return fen;
  }

  board[fromRow][fromColumn] = '';
  var pieceToPlace = piece;

  if (uci.length > 4) {
    final promoted = uci[4];
    pieceToPlace = piece == piece.toUpperCase() ? promoted.toUpperCase() : promoted.toLowerCase();
  }

  if (piece.toLowerCase() == 'k') {
    if (from == 'e1' && to == 'g1') {
      board[7][7] = '';
      board[7][5] = 'R';
    } else if (from == 'e1' && to == 'c1') {
      board[7][0] = '';
      board[7][3] = 'R';
    } else if (from == 'e8' && to == 'g8') {
      board[0][7] = '';
      board[0][5] = 'r';
    } else if (from == 'e8' && to == 'c8') {
      board[0][0] = '';
      board[0][3] = 'r';
    }
  }

  board[toRow][toColumn] = pieceToPlace;
  parts[0] = compressFenBoard(board);
  parts[1] = parts[1] == 'w' ? 'b' : 'w';

  return parts.take(6).join(' ');
}
