import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/puzzle_data.dart';
import 'package:flutter_app/screens/puzzle_detail_page.dart';
import 'package:flutter_app/screens/settings_page.dart';
import 'package:flutter_app/widgets/chess_board_view.dart';

void main() {
  testWidgets('Chess Coach opens directly into training flow', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessCoachApp());

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.textContaining('Preparing your first puzzle'), findsOneWidget);
    expect(find.textContaining('Ready to train'), findsNothing);
    expect(find.text('Create puzzles'), findsNothing);
  });

  testWidgets('Settings page renders analysis options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(
          initialSettings: TrainingSettings(
            backendUrl: 'http://127.0.0.1:8000',
            username: 'brlov1978',
            monthsBack: 12,
            maxGames: 500,
            analysisDepth: 10,
            mistakeThresholdCp: 90,
          ),
        ),
      ),
    );

    expect(find.textContaining('How far back to scan'), findsOneWidget);
    expect(find.textContaining('Max games to scan per run'), findsOneWidget);
    expect(find.textContaining('Mistake threshold'), findsOneWidget);
  });

  testWidgets('Puzzle detail screen supports drag solving', (WidgetTester tester) async {
    const puzzle = PuzzleData(
      title: 'Find the best move for White',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 1,
          puzzle: puzzle,
          onAttempt: (_, __) {},
        ),
      ),
    );

    expect(find.textContaining('Drag'), findsWidgets);
  });

  testWidgets('Puzzle detail hides app bar back button', (WidgetTester tester) async {
    const puzzle = PuzzleData(
      title: 'Find the best move for White',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PuzzleDetailPage(
                        index: 1,
                        puzzle: puzzle,
                        onAttempt: (_, __) {},
                      ),
                    ),
                  );
                },
                child: const Text('Open puzzle'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open puzzle'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('Puzzle detail shows celebration controls after solve', (WidgetTester tester) async {
    const puzzle = PuzzleData(
      title: 'Find the best move for White',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 1,
          puzzle: puzzle,
          initialResult: true,
          onAttempt: (_, __) {},
        ),
      ),
    );

    expect(find.text('Nice solve!'), findsOneWidget);
    expect(find.text('Next puzzle'), findsOneWidget);
  });

  testWidgets('Puzzle detail shows retry card after wrong answer', (WidgetTester tester) async {
    const puzzle = PuzzleData(
      title: 'Find the best move for White',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 1,
          puzzle: puzzle,
          initialResult: false,
          onAttempt: (_, __) {},
        ),
      ),
    );

    expect(find.text('Try again'), findsWidgets);
  });

  testWidgets('Wrong move resets board to original position', (WidgetTester tester) async {
    const puzzle = PuzzleData(
      title: 'Find the best move for White',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 1,
          puzzle: puzzle,
          onAttempt: (_, __) {},
        ),
      ),
    );

    final boardBefore = tester.widget<ChessBoardView>(find.byType(ChessBoardView));
    expect(boardBefore.fen, puzzle.fen);

    boardBefore.onMoveAttempt('a2', 'a3');
    await tester.pump();

    final boardAfter = tester.widget<ChessBoardView>(find.byType(ChessBoardView));
    expect(boardAfter.fen, puzzle.fen);
    expect(find.text('Try again'), findsWidgets);
  });

  testWidgets('Puzzle detail resets transient state when puzzle changes', (WidgetTester tester) async {
    const puzzleOne = PuzzleData(
      title: 'Puzzle One',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com/1',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    const puzzleTwo = PuzzleData(
      title: 'Puzzle Two',
      fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQ1RK1 w kq - 4 5',
      bestMoveUci: 'c4f7',
      bestMoveSan: 'Bxf7+',
      actualMoveSan: 'Bxf7+',
      evaluationCp: 310,
      mateIn: null,
      sourceUrl: 'https://example.com/2',
      opening: 'Italian Game',
      opponent: 'Other Opponent',
      playerColor: 'White',
      reason: 'A different tactic appears here.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 1,
          puzzle: puzzleOne,
          initialResult: false,
          onAttempt: (_, __) {},
        ),
      ),
    );

    expect(find.text('Try again'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 2,
          puzzle: puzzleTwo,
          onAttempt: (_, __) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Puzzle Two'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('Puzzle detail shows training snapshot in header', (WidgetTester tester) async {
    const puzzle = PuzzleData(
      title: 'Find the best move for White',
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 2',
      bestMoveUci: 'f3e5',
      bestMoveSan: 'Nxe5',
      actualMoveSan: 'Nxe5',
      evaluationCp: 250,
      mateIn: null,
      sourceUrl: 'https://example.com',
      opening: 'Italian Game',
      opponent: 'Opponent',
      playerColor: 'White',
      reason: 'A tactical shot wins material.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PuzzleDetailPage(
          index: 1,
          puzzle: puzzle,
          onAttempt: (_, __) {},
        ),
      ),
    );

    expect(find.text('Training snapshot'), findsOneWidget);
  });
}
