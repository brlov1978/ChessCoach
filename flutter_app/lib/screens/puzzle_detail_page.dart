import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_app/models/puzzle_data.dart';
import 'package:flutter_app/utils/chess_board_utils.dart';
import 'package:flutter_app/widgets/chess_board_view.dart';
import 'package:flutter_app/widgets/info_chip.dart';

class PuzzleDetailPage extends StatefulWidget {
  const PuzzleDetailPage({
    super.key,
    required this.index,
    required this.puzzle,
    required this.onAttempt,
    this.starsCount = 0,
    this.facepalmCount = 0,
    this.sadCount = 0,
    this.scoreLabel = '0/0',
    this.initialResult,
    this.onNextPuzzle,
    this.onOpenSettings,
    this.puzzleCount = 0,
    this.isPreparingNext = false,
  });

  final int index;
  final PuzzleData puzzle;
  final void Function(bool isCorrect, String attemptedMove) onAttempt;
  final int starsCount;
  final int facepalmCount;
  final int sadCount;
  final String scoreLabel;
  final bool? initialResult;
  final VoidCallback? onNextPuzzle;
  final VoidCallback? onOpenSettings;
  final int puzzleCount;
  final bool isPreparingNext;

  @override
  State<PuzzleDetailPage> createState() => _PuzzleDetailPageState();
}

class _PuzzleDetailPageState extends State<PuzzleDetailPage> {
  bool _reveal = false;
  late String _currentFen;
  late bool _blackPerspective;
  String? _selectedSquare;
  String? _highlightSquare;
  bool? _lastResult;
  int _celebrationCount = 0;

  @override
  void initState() {
    super.initState();
    _resetPuzzle();
    _lastResult = widget.initialResult;
    if (_lastResult == true) {
      _celebrationCount = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PuzzleDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.index != widget.index ||
        oldWidget.puzzle.fen != widget.puzzle.fen ||
        oldWidget.puzzle.bestMoveUci != widget.puzzle.bestMoveUci) {
      _resetPuzzle();
    }
  }

  void _resetPuzzle() {
    _currentFen = widget.puzzle.fen;
    final parts = widget.puzzle.fen.split(' ');
    _blackPerspective = parts.length > 1 && parts[1] == 'b';
    _selectedSquare = null;
    _highlightSquare = null;
    _reveal = false;
    _lastResult = widget.initialResult == true ? true : null;
    _celebrationCount = widget.initialResult == true ? 1 : 0;
  }

  void _handleMoveAttempt(String fromSquare, String toSquare) {
    if (_lastResult != null) {
      return;
    }
    final expectedMove = widget.puzzle.bestMoveUci.toLowerCase();
    final attemptedMove = '$fromSquare$toSquare'.toLowerCase();
    final isCorrect = attemptedMove == expectedMove.substring(0, 4);

    widget.onAttempt(isCorrect, attemptedMove);

    setState(() {
      _highlightSquare = toSquare;
      _selectedSquare = null;
      _lastResult = isCorrect;

      if (isCorrect) {
        _currentFen = applyMoveToFen(_currentFen, expectedMove);
        _celebrationCount += 1;
      } else {
        _currentFen = widget.puzzle.fen;
      }
    });
  }

  void _handleSquareTap(String square) {
    if (_lastResult != null) {
      return;
    }

    final piece = pieceAtSquare(_currentFen, square);

    if (_selectedSquare == null) {
      if (piece.isNotEmpty && isSideToMovePiece(_currentFen, piece)) {
        setState(() {
          _selectedSquare = square;
          _highlightSquare = square;
        });
      } else {
        setState(() {});
      }
      return;
    }

    if (_selectedSquare == square) {
      setState(() {
        _selectedSquare = null;
        _highlightSquare = null;
      });
      return;
    }

    if (piece.isNotEmpty && isSideToMovePiece(_currentFen, piece)) {
      setState(() {
        _selectedSquare = square;
        _highlightSquare = square;
      });
      return;
    }

    _handleMoveAttempt(_selectedSquare!, square);
  }

  Widget _buildHeaderSnapshot(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF262421),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4A4743)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training snapshot',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SnapshotPill(
                    label: 'Puzzles',
                    value: '${widget.puzzleCount}',
                    icon: Icons.grid_view_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SnapshotPill(
                    label: 'Stars',
                    value: '${widget.starsCount}',
                    icon: Icons.star_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SnapshotPill(
                    label: 'Facepalms',
                    value: '${widget.facepalmCount}',
                    icon: Icons.sentiment_dissatisfied_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SnapshotPill(
                    label: 'Sad',
                    value: '${widget.sadCount}',
                    icon: Icons.sentiment_very_dissatisfied_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SnapshotPill(
                    label: 'Score',
                    value: widget.scoreLabel,
                    icon: Icons.emoji_events_rounded,
                  ),
                  const SizedBox(width: 8),
                  _SnapshotPill(
                    label: 'Next',
                    value: widget.isPreparingNext ? 'Loading' : 'Ready',
                    icon: widget.isPreparingNext ? Icons.hourglass_bottom_rounded : Icons.check_circle_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelebrationCard() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_celebrationCount),
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: Transform.scale(scale: value, child: child),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F3A27),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF59A96A)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331E8E3E),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration, color: Color(0xFFFFD54F)),
                SizedBox(width: 8),
                Text(
                  'Nice solve!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.auto_awesome, color: Color(0xFFFFD54F)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'You found the best move. Ready for the next puzzle?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onNextPuzzle,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next puzzle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTryAgainCard() {
    return TweenAnimationBuilder<double>(
      key: ValueKey('retry-$_lastResult-$_currentFen'),
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF4A1F1F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB95C5C)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33B95C5C),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close_rounded, color: Color(0xFFFFC9C9)),
                SizedBox(width: 8),
                Text(
                  'Not quite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.refresh_rounded, color: Color(0xFFFFC9C9)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'That move was not the best one. Reset the board and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(_resetPuzzle),
              icon: const Icon(Icons.replay),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatDetailsCard() {
    final repeats = widget.puzzle.repeatExamples;
    if (repeats.isEmpty) {
      return const SizedBox.shrink();
    }

    final repeatCount = widget.puzzle.repeatCount ?? repeats.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF22201D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4743)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: const Color(0xFFBFD97B),
        collapsedIconColor: const Color(0xFFBFD97B),
        title: Text(
          'You repeated this mistake $repeatCount times',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Tap to view game occurrences',
          style: TextStyle(color: Colors.white70),
        ),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: repeats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
            ),
            itemBuilder: (context, index) {
              final item = repeats[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1816),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3E3A36)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.format.toUpperCase()} • ${item.date}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.tryParse(item.url);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: const Text(
                        'Open game',
                        style: TextStyle(
                          color: Color(0xFF8BC0FF),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const SizedBox.shrink(),
          leadingWidth: 0,
          title: const Text('Your move'),
          toolbarHeight: 60,
          actions: [
            if (widget.onOpenSettings != null)
              IconButton(
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(78),
            child: _buildHeaderSnapshot(context),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = constraints.maxWidth < 640 ? (constraints.maxWidth - 84).clamp(260.0, 560.0).toDouble() : 520.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        puzzle.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Drag a piece to solve the puzzle. Tapping also works.',
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: boardSize + 72,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _EvalBar(
                                evaluationCp: puzzle.evaluationCp,
                                mateIn: puzzle.mateIn,
                                height: boardSize,
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: boardSize,
                                height: boardSize,
                                child: ChessBoardView(
                                  fen: _currentFen,
                                  blackPerspective: _blackPerspective,
                                  selectedSquare: _selectedSquare,
                                  highlightSquare: _highlightSquare,
                                  onSquareTap: _handleSquareTap,
                                  onMoveAttempt: _handleMoveAttempt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_lastResult == true) ...[
                        const SizedBox(height: 16),
                        _buildCelebrationCard(),
                      ] else if (_lastResult == false) ...[
                        const SizedBox(height: 16),
                        _buildTryAgainCard(),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          InfoChip(label: 'Opening', value: puzzle.opening),
                          InfoChip(label: 'Opponent', value: puzzle.opponent),
                          InfoChip(label: 'Side', value: puzzle.playerColor),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(puzzle.reason),
                      if (puzzle.repeatExamples.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildRepeatDetailsCard(),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => setState(() => _reveal = !_reveal),
                            child: Text(
                              _reveal ? 'Hide solution' : 'Reveal solution',
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(_resetPuzzle),
                            child: const Text('Reset board'),
                          ),
                        ],
                      ),
                      if (_reveal || _lastResult == true) ...[
                        const SizedBox(height: 8),
                        Text('Best move: ${puzzle.bestMoveSan}'),
                        if (puzzle.actualMoveSan != null)
                          Text(
                            'Move played in the game: ${puzzle.actualMoveSan}',
                          ),
                        if (puzzle.sourceUrl.isNotEmpty) SelectableText('Source game: ${puzzle.sourceUrl}'),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SnapshotPill extends StatelessWidget {
  const _SnapshotPill({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D1B),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF4A4743)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFBFD97B)),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFBFD97B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvalBar extends StatelessWidget {
  const _EvalBar({
    required this.evaluationCp,
    required this.mateIn,
    required this.height,
  });

  final int evaluationCp;
  final int? mateIn;
  final double height;

  @override
  Widget build(BuildContext context) {
    final whiteShare = mateIn != null ? (evaluationCp >= 0 ? 0.96 : 0.04) : (((evaluationCp.clamp(-900, 900)) + 900) / 1800).toDouble();
    final whiteFlex = (whiteShare * 100).round().clamp(4, 96);
    final blackFlex = 100 - whiteFlex;
    final label = mateIn != null ? 'M$mateIn' : '${evaluationCp >= 0 ? '+' : ''}${(evaluationCp / 100).toStringAsFixed(1)}';

    return SizedBox(
      width: 56,
      height: height,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC2C2A28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF4A4743)),
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF4A4743), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Column(
                  children: [
                    Expanded(
                      flex: blackFlex,
                      child: Container(color: const Color(0xFF1F1F1F)),
                    ),
                    Expanded(
                      flex: whiteFlex,
                      child: Container(color: const Color(0xFFF4F1EA)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
