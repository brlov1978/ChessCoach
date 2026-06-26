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

  double _monthsBack = 12;
  double _maxGames = 500;
  double _analysisDepth = 10;
  double _mistakeThresholdCp = 90;

  bool _isLoading = false;
  bool _hasStartedAutoLoad = false;
  bool _hasOpenedFirstPuzzle = false;
  bool _isAnalyzing = false;
  int _analysisProgress = 0;
  String _analysisStatus = 'idle';
  String? _activeJobId;
  Timer? _analysisPollTimer;
  bool _isPollingJob = false;

  String? _errorMessage;
  List<PuzzleData> _puzzles = const [];
  Map<String, dynamic>? _stats;
  int _gamesCount = 0;
  int _currentPuzzleIndex = 0;
  final Map<int, bool> _puzzleResults = <int, bool>{};
  final Map<int, Set<String>> _wrongMovesByPuzzle = <int, Set<String>>{};
  final Set<int> _roundSolvedIndexes = <int>{};
  int _starsCount = 0;
  int _facepalmCount = 0;
  int _sadCount = 0;

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(text: _defaultBackendUrl());
    _usernameController = TextEditingController(text: 'brlov1978');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_startSeamlessSession());
      }
    });
  }

  @override
  void dispose() {
    _analysisPollTimer?.cancel();
    _backendUrlController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _defaultBackendUrl() {
    final host = Uri.base.host.toLowerCase();
    final isLocalHost = host.isEmpty || host == 'localhost' || host == '127.0.0.1';
    return isLocalHost ? 'http://127.0.0.1:8000' : Uri.base.origin;
  }

  TrainingSettings _currentSettings() {
    return TrainingSettings(
      backendUrl: _backendUrlController.text.trim(),
      username: _usernameController.text.trim(),
      monthsBack: _monthsBack,
      maxGames: _maxGames,
      analysisDepth: _analysisDepth,
      mistakeThresholdCp: _mistakeThresholdCp,
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
      _monthsBack = settings.monthsBack;
      _maxGames = settings.maxGames;
      _analysisDepth = settings.analysisDepth;
      _mistakeThresholdCp = settings.mistakeThresholdCp;
      _errorMessage = null;
    });

    await _startBackgroundAnalysis();
  }

  Future<void> _startSeamlessSession({bool force = false}) async {
    if ((_hasStartedAutoLoad && !force) || _isLoading) {
      return;
    }

    _hasStartedAutoLoad = true;
    _hasOpenedFirstPuzzle = false;

    await _loadStoredPuzzles(openFirstPuzzle: true, resetSession: true);
  }

  Future<void> _loadStoredPuzzles({
    required bool openFirstPuzzle,
    required bool resetSession,
  }) async {
    final baseUrl = _backendUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final username = _usernameController.text.trim();

    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() {
        _errorMessage = 'Open settings and enter both a backend URL and a Chess.com username.';
      });
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (resetSession) {
        _puzzles = const [];
        _puzzleResults.clear();
        _wrongMovesByPuzzle.clear();
        _roundSolvedIndexes.clear();
        _starsCount = 0;
        _facepalmCount = 0;
        _sadCount = 0;
        _stats = null;
        _gamesCount = 0;
        _currentPuzzleIndex = 0;
      }
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/puzzles/mistakes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final dynamic decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode != 200) {
        throw Exception(payload['error'] ?? 'Request failed with status ${response.statusCode}.');
      }

      final puzzleList = (payload['puzzles'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => PuzzleData.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _puzzles = puzzleList;
        _stats = Map<String, dynamic>.from(payload['stats'] as Map? ?? <String, dynamic>{});
        _gamesCount = (_stats?['games_processed'] as int?) ?? 0;

        if (openFirstPuzzle && _puzzles.isNotEmpty) {
          _hasOpenedFirstPuzzle = true;
          _currentPuzzleIndex = 0;
        }

        if (_puzzles.isEmpty && !_isAnalyzing) {
          _errorMessage = 'No stored puzzles yet. Open settings to run background analysis.';
        }
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'The request timed out while loading stored puzzles.';
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

  Future<void> _startBackgroundAnalysis() async {
    final baseUrl = _backendUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final username = _usernameController.text.trim();

    if (baseUrl.isEmpty || username.isEmpty) {
      setState(() {
        _errorMessage = 'Open settings and enter both a backend URL and a Chess.com username.';
      });
      return;
    }

    _analysisPollTimer?.cancel();

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0;
      _analysisStatus = 'queued';
      _activeJobId = null;
      _errorMessage = null;
      _hasOpenedFirstPuzzle = false;
      _puzzles = const [];
      _puzzleResults.clear();
      _currentPuzzleIndex = 0;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/analysis/jobs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'months_back': _monthsBack.round(),
              'max_games': _maxGames.round(),
              'analysis_depth': _analysisDepth.round(),
              'mistake_threshold_cp': _mistakeThresholdCp.round(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final dynamic decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode != 202) {
        throw Exception(payload['error'] ?? 'Failed to start analysis job.');
      }

      final jobId = payload['job_id']?.toString() ?? '';
      if (jobId.isEmpty) {
        throw Exception('Job id missing from analysis response.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _activeJobId = jobId;
      });

      _analysisPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_pollAnalysisJob(jobId));
      });
      await _pollAnalysisJob(jobId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
        _analysisStatus = 'failed';
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pollAnalysisJob(String jobId) async {
    if (_isPollingJob || !mounted) {
      return;
    }

    _isPollingJob = true;
    try {
      final baseUrl = _backendUrlController.text.trim().replaceAll(RegExp(r'/$'), '');
      final response = await http
          .get(Uri.parse('$baseUrl/api/analysis/jobs/$jobId'))
          .timeout(const Duration(seconds: 20));

      final dynamic decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(payload['error'] ?? 'Failed to read analysis status.');
      }

      final status = payload['status']?.toString() ?? 'unknown';
      final progress = (payload['progress_percent'] as num?)?.toInt() ?? 0;

      if (!mounted) {
        return;
      }

      setState(() {
        _analysisStatus = status;
        _analysisProgress = progress.clamp(0, 100);
        _stats = <String, dynamic>{
          'positions_checked': payload['positions_analyzed'] ?? 0,
          'games_processed': payload['games_processed'] ?? 0,
          'mistakes_found': payload['mistakes_found'] ?? 0,
        };
      });

      if (status == 'completed') {
        _analysisPollTimer?.cancel();
        _analysisPollTimer = null;

        if (mounted) {
          setState(() {
            _isAnalyzing = false;
          });
        }

        await _loadStoredPuzzles(openFirstPuzzle: true, resetSession: true);
      } else if (status == 'failed') {
        _analysisPollTimer?.cancel();
        _analysisPollTimer = null;

        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = payload['error']?.toString() ?? 'Background analysis failed.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisStatus = 'failed';
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
      _analysisPollTimer?.cancel();
      _analysisPollTimer = null;
    } finally {
      _isPollingJob = false;
    }
  }

  void _recordAttempt(int puzzleIndex, bool isCorrect, String attemptedMove) {
    setState(() {
      if (isCorrect) {
        final firstSolve = _puzzleResults[puzzleIndex] != true;
        _puzzleResults[puzzleIndex] = true;
        if (firstSolve) {
          _starsCount += 1;
          _roundSolvedIndexes.add(puzzleIndex);
        }
      } else {
        _puzzleResults.putIfAbsent(puzzleIndex, () => false);
        final seenMoves = _wrongMovesByPuzzle.putIfAbsent(puzzleIndex, () => <String>{});
        if (seenMoves.contains(attemptedMove)) {
          _facepalmCount += 1;
        } else {
          seenMoves.add(attemptedMove);
          _sadCount += 1;
        }
      }
    });
  }

  Future<void> _goToNextPuzzle() async {
    final nextIndex = _currentPuzzleIndex + 1;
    if (nextIndex < _puzzles.length) {
      setState(() {
        _currentPuzzleIndex = nextIndex;
      });
      return;
    }

    final completedScore = '${_roundSolvedIndexes.length}/${_puzzles.length}';
    if (_puzzles.isNotEmpty) {
      setState(() {
        _currentPuzzleIndex = 0;
        _roundSolvedIndexes.clear();
      });
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Round complete: $completedScore. Starting again from puzzle 1.')),
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    final title = _isAnalyzing ? 'Analyzing your games...' : 'Preparing your first puzzle...';
    final subtitle = _isAnalyzing
        ? 'Background process: $_analysisStatus'
        : (_errorMessage ?? 'Checking database for existing puzzle results.');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isAnalyzing)
                LinearProgressIndicator(value: _analysisProgress / 100)
              else
                const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
              ),
              if (_activeJobId != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Job: $_activeJobId ($_analysisProgress%)',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasOpenedFirstPuzzle && _puzzles.isNotEmpty) {
      final currentIndex = _currentPuzzleIndex < _puzzles.length ? _currentPuzzleIndex : _puzzles.length - 1;
      final scoreLabel = '${_roundSolvedIndexes.length}/${_puzzles.length}';

      return PuzzleDetailPage(
        key: ValueKey('puzzle-$currentIndex-${_puzzles[currentIndex].fen}'),
        index: currentIndex + 1,
        puzzle: _puzzles[currentIndex],
        initialResult: _puzzleResults[currentIndex],
        onAttempt: (isCorrect, attemptedMove) => _recordAttempt(currentIndex, isCorrect, attemptedMove),
        onNextPuzzle: _goToNextPuzzle,
        onOpenSettings: () => _openSettings(context),
        puzzleCount: _puzzles.length,
        starsCount: _starsCount,
        facepalmCount: _facepalmCount,
        sadCount: _sadCount,
        scoreLabel: scoreLabel,
        isPreparingNext: _isAnalyzing,
      );
    }

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
      body: _buildLoadingBody(context),
    );
  }
}
