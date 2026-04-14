import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_app/models/puzzle_data.dart';
import 'package:flutter_app/screens/puzzle_detail_page.dart';
import 'package:flutter_app/screens/settings_page.dart';

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
  String _speedMode = 'balanced';
  String _difficulty = 'medium';
  double _timeCapSeconds = 20;
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
    final isLocalHost = host.isEmpty || host == 'localhost' || host == '127.0.0.1';
    return isLocalHost ? 'http://127.0.0.1:8000' : Uri.base.origin;
  }

  String _displayLabel(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  TrainingSettings _currentSettings() {
    return TrainingSettings(
      backendUrl: _backendUrlController.text.trim(),
      username: _usernameController.text.trim(),
      maxGames: _maxGames,
      maxPuzzles: _maxPuzzles,
      analysisDepth: _analysisDepth,
      speedMode: _speedMode,
      difficulty: _difficulty,
      timeCapSeconds: _timeCapSeconds,
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final settings = await Navigator.of(context).push<TrainingSettings>(
      MaterialPageRoute<TrainingSettings>(
        builder: (_) => SettingsPage(initialSettings: _currentSettings()),
      ),
    );

    if (settings == null || !mounted) {
      return;
    }

    setState(() {
      _backendUrlController.text = settings.backendUrl;
      _usernameController.text = settings.username;
      _maxGames = settings.maxGames;
      _maxPuzzles = settings.maxPuzzles;
      _analysisDepth = settings.analysisDepth;
      _speedMode = settings.speedMode;
      _difficulty = settings.difficulty;
      _timeCapSeconds = settings.timeCapSeconds;
      _errorMessage = null;
    });
  }

  Future<void> _generatePuzzles() async {
    final baseUrl = _backendUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final username = _usernameController.text.trim();

    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() {
        _errorMessage = 'Open settings and enter both a backend URL and a Chess.com username.';
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
              'speed_mode': _speedMode,
              'difficulty': _difficulty,
              'time_budget_seconds': _timeCapSeconds.round(),
            }),
          )
          .timeout(const Duration(seconds: 45));

      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic> payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(payload['error'] ?? 'Request failed with status ${response.statusCode}.');
      }

      final puzzleList = (payload['puzzles'] as List<dynamic>? ?? <dynamic>[]).map((item) => PuzzleData.fromJson(Map<String, dynamic>.from(item as Map))).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _puzzles = puzzleList;
        _stats = Map<String, dynamic>.from(payload['stats'] as Map? ?? <String, dynamic>{});
        _gamesCount = payload['games_count'] as int? ?? 0;
        _puzzleResults.clear();
        if (puzzleList.isEmpty) {
          _errorMessage = 'No puzzles were found in those recent games. Try a different username or broader search.';
        }
      });

      if (puzzleList.isNotEmpty) {
        _openPuzzle(context, 0);
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Puzzle generation took too long. Try fewer games or a lower analysis depth.';
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

  MaterialPageRoute<void> _buildPuzzleRoute(BuildContext context, int puzzleIndex) {
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
        onOpenSettings: () => _openSettings(context),
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

  Widget _buildStatusCard(BuildContext context) {
    final username = _usernameController.text.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to train',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate a fresh set of puzzles from your recent Chess.com games and jump straight into the first challenge.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: Text(username.isEmpty ? 'No username set' : username),
                ),
                Chip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text('${_maxGames.round()} games'),
                ),
                Chip(
                  avatar: const Icon(Icons.extension, size: 18),
                  label: Text('${_maxPuzzles.round()} puzzles'),
                ),
                Chip(
                  avatar: const Icon(Icons.analytics, size: 18),
                  label: Text('Depth ${_analysisDepth.round()}'),
                ),
                Chip(
                  avatar: const Icon(Icons.speed, size: 18),
                  label: Text(_displayLabel(_speedMode)),
                ),
                Chip(
                  avatar: const Icon(Icons.trending_up, size: 18),
                  label: Text(_displayLabel(_difficulty)),
                ),
                Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text('${_timeCapSeconds.round()}s cap'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    if (_errorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red.shade900),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Analyzing recent games and preparing your first puzzle...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_puzzles.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No puzzle set loaded yet. Use Create puzzles to begin.',
          ),
        ),
      );
    }

    final solved = _puzzleResults.values.where((value) => value).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Loaded ${_puzzles.length} puzzle${_puzzles.length == 1 ? '' : 's'} from $_gamesCount game${_gamesCount == 1 ? '' : 's'}.',
            ),
            const SizedBox(height: 4),
            Text('Solved: $solved/${_puzzleResults.length} attempts'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('♟ Chess Coach'),
        actions: [
          IconButton(
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(context),
                const SizedBox(height: 16),
                _buildFeedbackCard(context),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _generatePuzzles,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt),
                  label: Text(
                    _isLoading ? 'Analyzing...' : 'Create puzzles',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoading ? 'This can take around 10–30 seconds.' : 'Use the gear icon anytime to adjust your settings.',
                  textAlign: TextAlign.center,
                ),
                if (_puzzles.isNotEmpty && !_isLoading) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openPuzzle(context, 0),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume latest set'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
