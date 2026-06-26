class PuzzleData {
  const PuzzleData({
    required this.title,
    required this.fen,
    required this.bestMoveUci,
    required this.bestMoveSan,
    required this.actualMoveSan,
    required this.evaluationCp,
    required this.mateIn,
    required this.sourceUrl,
    required this.opening,
    required this.opponent,
    required this.playerColor,
    required this.reason,
    this.repeatCount,
    this.repeatExamples = const [],
  });

  final String title;
  final String fen;
  final String bestMoveUci;
  final String bestMoveSan;
  final String? actualMoveSan;
  final int evaluationCp;
  final int? mateIn;
  final String sourceUrl;
  final String opening;
  final String opponent;
  final String playerColor;
  final String reason;
  final int? repeatCount;
  final List<MistakeOccurrence> repeatExamples;

  factory PuzzleData.fromJson(Map<String, dynamic> json) {
    return PuzzleData(
      title: json['title']?.toString() ?? 'Puzzle',
      fen: json['fen']?.toString() ?? '8/8/8/8/8/8/8/8 w - - 0 1',
      bestMoveUci: json['best_move_uci']?.toString() ?? '',
      bestMoveSan: json['best_move_san']?.toString() ?? '',
      actualMoveSan: json['actual_move_san']?.toString(),
      evaluationCp: (json['evaluation_cp'] as num?)?.toInt() ?? 0,
      mateIn: (json['mate_in'] as num?)?.toInt(),
      sourceUrl: json['source_url']?.toString() ?? '',
      opening: json['opening']?.toString() ?? 'Unknown opening',
      opponent: json['opponent']?.toString() ?? 'Unknown',
      playerColor: json['player_color']?.toString() ?? 'White',
      reason: json['reason']?.toString() ?? '',
      repeatCount: (json['repeat_count'] as num?)?.toInt(),
      repeatExamples: (json['repeat_examples'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => MistakeOccurrence.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class MistakeOccurrence {
  const MistakeOccurrence({
    required this.url,
    required this.date,
    required this.format,
  });

  final String url;
  final String date;
  final String format;

  factory MistakeOccurrence.fromJson(Map<String, dynamic> json) {
    return MistakeOccurrence(
      url: json['url']?.toString() ?? '',
      date: json['date']?.toString() ?? 'Unknown date',
      format: json['format']?.toString() ?? 'unknown',
    );
  }
}
