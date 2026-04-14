import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/puzzle_data.dart';
import 'package:flutter_app/screens/puzzle_detail_page.dart';
import 'package:flutter_app/screens/settings_page.dart';

void main() {
  testWidgets('Chess Coach home screen renders seamless loading UI', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessCoachApp());

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.textContaining('Ready to train'), findsOneWidget);
    expect(find.textContaining('Preparing your first puzzle'), findsOneWidget);
    expect(find.text('Create puzzles'), findsNothing);
  });

  testWidgets('Settings page renders speed and difficulty options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(
          initialSettings: TrainingSettings(
            backendUrl: 'http://127.0.0.1:8000',
            username: 'hikaru',
            maxGames: 10,
            maxPuzzles: 5,
            analysisDepth: 10,
            speedMode: 'balanced',
            difficulty: 'medium',
            timeCapSeconds: 20,
          ),
        ),
      ),
    );

    expect(find.text('Speed mode'), findsOneWidget);
    expect(find.text('Difficulty'), findsOneWidget);
    expect(find.textContaining('Generation time cap'), findsOneWidget);
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
          onAttempt: (_) {},
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
                        onAttempt: (_) {},
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
          onAttempt: (_) {},
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
          onAttempt: (_) {},
        ),
      ),
    );

    expect(find.text('Try again'), findsWidgets);
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
          onAttempt: (_) {},
        ),
      ),
    );

    expect(find.text('Training snapshot'), findsOneWidget);
  });
}
