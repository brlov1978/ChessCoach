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
  bool _isBuffering = false;
  bool _hasStartedAutoLoad = false;
  bool _hasOpenedFirstPuzzle = false;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startSeamlessSession());
      }
    });
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

    if (!Navigator.of(context).canPop()) {
      unawaited(_startSeamlessSession(force: true));
    }
  }

  Future<void> _startSeamlessSession({bool force = false}) async {
    if ((_hasStartedAutoLoad && !force) || _isLoading) {
      return;
    }

    _hasStartedAutoLoad = true;
    _hasOpenedFirstPuzzle = false;

    await _generatePuzzles(
      openFirstPuzzle: true,
      requestedBatchSize: 1,
      resetSession: true,
      background: false,
    );
  }

  Future<void> _generatePuzzles({
    required bool openFirstPuzzle,
    required int requestedBatchSize,
    required bool resetSession,
    required bool background,
  }) async {
    final baseUrl = _backendUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final username = _usernameController.text.trim();

    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() {
        _errorMessage = 'Open settings and enter both a backend URL and a Chess.com username.';
      });
      return;
    }

    if (background && (_isLoading || _isBuffering)) {
      return;
    }
    if (!background && _isLoading) {
      return;
    }

    setState(() {
      if (background) {
        _isBuffering = true;
      } else {
        _isLoading = true;
        _errorMessage = null;
      }

      if (resetSession) {
        _puzzles = const [];
        _puzzleResults.clear();
        _stats = null;
        _gamesCount = 0;
      }
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/puzzles'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'max_games': _maxGames.round(),
              'max_puzzles': requestedBatchSize,
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
        final merged = resetSession ? <PuzzleData>[] : <PuzzleData>[..._puzzles];
        final seenFens = merged.map((puzzle) => puzzle.fen).toSet();

        for (final puzzle in puzzleList) {
          if (seenFens.add(puzzle.fen)) {
            merged.add(puzzle);
          }
        }

        _puzzles = merged;
        _stats = Map<String, dynamic>.from(payload['stats'] as Map? ?? <String, dynamic>{});
        _gamesCount = payload['games_count'] as int? ?? 0;

        if (!background && _puzzles.isEmpty) {
          _errorMessage = 'No puzzles were found right now. Open settings to try different training options.';
        }
      });

      if (openFirstPuzzle && _puzzles.isNotEmpty && !_hasOpenedFirstPuzzle && mounted) {
        _hasOpenedFirstPuzzle = true;
        _openPuzzle(context, 0);
        unawaited(_prefetchMorePuzzles(currentIndex: 0));
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      if (!background) {
        setState(() {
          _errorMessage = 'Still searching for a good puzzle. Try Fast mode or a shorter time cap.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (!background) {
        setState(() {
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (background) {
            _isBuffering = false;
          } else {
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _prefetchMorePuzzles({required int currentIndex}) async {
    final bufferTarget = _maxPuzzles.round().clamp(2, 12);
    final remaining = _puzzles.length - currentIndex - 1;

    if (_isLoading || _isBuffering || bufferTarget <= 1) {
      return;
    }
    if (remaining >= 2 || _puzzles.length >= bufferTarget) {
      return;
    }

    await _generatePuzzles(
      openFirstPuzzle: false,
      requestedBatchSize: bufferTarget,
      resetSession: false,
      background: true,
    );
  }

  void _recordAttempt(int puzzleIndex, bool isCorrect) {
    setState(() {
      final previous = _puzzleResults[puzzleIndex];
      if (previous == null || (previous == false && isCorrect)) {
        _puzzleResults[puzzleIndex] = isCorrect;
      }
    });
  }

  Future<void> _goToNextPuzzle(BuildContext context, int currentIndex) async {
    final navigator = Navigator.of(context);
    final nextIndex = currentIndex + 1;

    if (nextIndex < _puzzles.length) {
      unawaited(_prefetchMorePuzzles(currentIndex: nextIndex));
      navigator.pushReplacement(_buildPuzzleRoute(context, nextIndex));
      return;
    }

    await _prefetchMorePuzzles(currentIndex: currentIndex);

    if (!mounted) {
      return;
    }

    if (nextIndex < _puzzles.length) {
      navigator.pushReplacement(_buildPuzzleRoute(context, nextIndex));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding your next puzzle...')),
      );
    }
  }

  MaterialPageRoute<void> _buildPuzzleRoute(BuildContext context, int puzzleIndex) {
    return MaterialPageRoute<void>(
      builder: (routeContext) => PuzzleDetailPage(
        index: puzzleIndex + 1,
        puzzle: _puzzles[puzzleIndex],
        initialResult: _puzzleResults[puzzleIndex],
        onAttempt: (isCorrect) => _recordAttempt(puzzleIndex, isCorrect),
        onNextPuzzle: () => _goToNextPuzzle(routeContext, puzzleIndex),
        onOpenSettings: () => _openSettings(context),
        gamesCount: _gamesCount,
        puzzleCount: _puzzles.length,
        attemptCount: _puzzleResults.length,
        correctCount: _puzzleResults.values.where((value) => value).length,
        stats: _stats,
        isPreparingNext: _isBuffering,
      ),
    );
  }

  void _openPuzzle(BuildContext context, int puzzleIndex) {
    unawaited(_prefetchMorePuzzles(currentIndex: puzzleIndex));
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
              'Your first puzzle appears automatically, and the next ones load quietly while you solve.',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
              const SizedBox(height: 8),
              const Text('Use the gear icon to adjust the username or make the search faster.'),
            ],
          ),
        ),
      );
    }

    if (_isLoading || !_hasOpenedFirstPuzzle) {
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
                  'Preparing your first puzzle and quietly lining up the next ones...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training is live',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _isBuffering ? 'Lining up your next puzzle in the background.' : 'Your next puzzle will be ready when you are.',
            ),
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
                const SizedBox(height: 12),
                const Text(
                  'Use the gear icon anytime to update your training settings.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
