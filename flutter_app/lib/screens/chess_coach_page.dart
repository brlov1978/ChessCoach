import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_app/models/puzzle_data.dart';
import 'package:flutter_app/screens/puzzle_detail_page.dart';
import 'package:flutter_app/widgets/puzzle_list_item.dart';
import 'package:flutter_app/widgets/slider_field.dart';

class ChessCoachPage extends StatefulWidget {
  const ChessCoachPage({super.key});

  @override
  State<ChessCoachPage> createState() => _ChessCoachPageState();
}

class _ChessCoachPageState extends State<ChessCoachPage> {
  late final TextEditingController _backendUrlController;
  late final TextEditingController _usernameController;

  double _maxGames = 10;
  double _maxPuzzles = 5;
  double _analysisDepth = 10;
  bool _isLoading = false;
  String? _errorMessage;
  List<PuzzleData> _puzzles = const [];
  Map<String, dynamic>? _stats;
  int _gamesCount = 0;
  final Map<int, bool> _puzzleResults = <int, bool>{};

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(text: _defaultBackendUrl());
    _usernameController = TextEditingController(text: 'hikaru');
  }

  String _defaultBackendUrl() {
    final host = Uri.base.host.toLowerCase();
    final isLocalHost =
        host.isEmpty || host == 'localhost' || host == '127.0.0.1';
    return isLocalHost ? 'http://127.0.0.1:8000' : Uri.base.origin;
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _generatePuzzles() async {
    final baseUrl =
        _backendUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final username = _usernameController.text.trim();

    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() {
        _errorMessage = 'Enter both a backend URL and a Chess.com username.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/puzzles'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'max_games': _maxGames.round(),
              'max_puzzles': _maxPuzzles.round(),
              'analysis_depth': _analysisDepth.round(),
            }),
          )
          .timeout(const Duration(seconds: 45));

      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic> payload =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(payload['error'] ??
            'Request failed with status ${response.statusCode}.');
      }

      final puzzleList = (payload['puzzles'] as List<dynamic>? ?? <dynamic>[])
          .map((item) =>
              PuzzleData.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _puzzles = puzzleList;
        _stats = Map<String, dynamic>.from(
            payload['stats'] as Map? ?? <String, dynamic>{});
        _gamesCount = payload['games_count'] as int? ?? 0;
        _puzzleResults.clear();
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Puzzle generation took too long. Try fewer games or a lower analysis depth.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _recordAttempt(int puzzleIndex, bool isCorrect) {
    setState(() {
      final previous = _puzzleResults[puzzleIndex];
      if (previous == null || (previous == false && isCorrect)) {
        _puzzleResults[puzzleIndex] = isCorrect;
      }
    });
  }

  MaterialPageRoute<void> _buildPuzzleRoute(
      BuildContext context, int puzzleIndex) {
    return MaterialPageRoute<void>(
      builder: (_) => PuzzleDetailPage(
        index: puzzleIndex + 1,
        puzzle: _puzzles[puzzleIndex],
        initialResult: _puzzleResults[puzzleIndex],
        onAttempt: (isCorrect) => _recordAttempt(puzzleIndex, isCorrect),
        onNextPuzzle: puzzleIndex + 1 < _puzzles.length
            ? () => Navigator.of(context).pushReplacement(
                  _buildPuzzleRoute(context, puzzleIndex + 1),
                )
            : null,
        gamesCount: _gamesCount,
        puzzleCount: _puzzles.length,
        attemptCount: _puzzleResults.length,
        correctCount: _puzzleResults.values.where((value) => value).length,
        stats: _stats,
      ),
    );
  }

  void _openPuzzle(BuildContext context, int puzzleIndex) {
    Navigator.of(context).push(_buildPuzzleRoute(context, puzzleIndex));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('♟ Chess Coach'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControlPanel(context),
                const SizedBox(height: 16),
                _buildResultsPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generate puzzles from your games',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Run the Python backend locally, then enter your Chess.com username here.'),
            const SizedBox(height: 16),
            TextField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://127.0.0.1:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Chess.com username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SliderField(
              label: 'Recent games to scan',
              value: _maxGames,
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (value) => setState(() => _maxGames = value),
            ),
            SliderField(
              label: 'Max puzzle candidates',
              value: _maxPuzzles,
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (value) => setState(() => _maxPuzzles = value),
            ),
            SliderField(
              label: 'Analysis depth',
              value: _analysisDepth,
              min: 8,
              max: 16,
              divisions: 8,
              onChanged: (value) => setState(() => _analysisDepth = value),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generatePuzzles,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt),
                label: Text(_isLoading ? 'Analyzing...' : 'Create puzzles'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLoading
                  ? 'Analyzing recent games. This can take around 10–30 seconds.'
                  : 'Tip: on an Android emulator, use http://10.0.2.2:8000 as the backend URL.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Puzzle library',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text('Choose a puzzle from the list below.'),
        const SizedBox(height: 12),
        if (_errorMessage != null)
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_errorMessage!,
                  style: TextStyle(color: Colors.red.shade900)),
            ),
          )
        else if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_puzzles.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No puzzles yet. Generate some from your Chess.com games.'),
            ),
          )
        else
          ..._puzzles.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PuzzleListItem(
                    index: entry.key + 1,
                    puzzle: entry.value,
                    result: _puzzleResults[entry.key],
                    onTap: () => _openPuzzle(context, entry.key),
                  ),
                ),
              ),
      ],
    );
  }
}
