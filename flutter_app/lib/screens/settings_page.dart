import 'package:flutter/material.dart';

import 'package:flutter_app/widgets/slider_field.dart';

class TrainingSettings {
  const TrainingSettings({
    required this.backendUrl,
    required this.username,
    required this.maxGames,
    required this.maxPuzzles,
    required this.analysisDepth,
    required this.speedMode,
    required this.difficulty,
    required this.timeCapSeconds,
  });

  final String backendUrl;
  final String username;
  final double maxGames;
  final double maxPuzzles;
  final double analysisDepth;
  final String speedMode;
  final String difficulty;
  final double timeCapSeconds;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialSettings,
  });

  final TrainingSettings initialSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _backendUrlController;
  late final TextEditingController _usernameController;
  late double _maxGames;
  late double _maxPuzzles;
  late double _analysisDepth;
  late String _speedMode;
  late String _difficulty;
  late double _timeCapSeconds;

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(text: widget.initialSettings.backendUrl);
    _usernameController = TextEditingController(text: widget.initialSettings.username);
    _maxGames = widget.initialSettings.maxGames;
    _maxPuzzles = widget.initialSettings.maxPuzzles;
    _analysisDepth = widget.initialSettings.analysisDepth;
    _speedMode = widget.initialSettings.speedMode;
    _difficulty = widget.initialSettings.difficulty;
    _timeCapSeconds = widget.initialSettings.timeCapSeconds;
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _speedModeDescription() {
    switch (_speedMode) {
      case 'fast':
        return 'Fast mode scans fewer positions and returns results sooner.';
      case 'deep':
        return 'Deep mode spends longer searching for stronger puzzle candidates.';
      default:
        return 'Balanced mode keeps puzzle quality high without long waits.';
    }
  }

  String _difficultyDescription() {
    switch (_difficulty) {
      case 'easy':
        return 'Easier tactics and more obvious winning ideas.';
      case 'hard':
        return 'Sharper positions with bigger tactical demands.';
      default:
        return 'A solid mix of practical tactics and challenging moves.';
    }
  }

  void _save() {
    Navigator.of(context).pop(
      TrainingSettings(
        backendUrl: _backendUrlController.text.trim(),
        username: _usernameController.text.trim(),
        maxGames: _maxGames,
        maxPuzzles: _maxPuzzles,
        analysisDepth: _analysisDepth,
        speedMode: _speedMode,
        difficulty: _difficulty,
        timeCapSeconds: _timeCapSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adjust your Chess.com username, backend URL, and puzzle generation settings here.',
                    ),
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
                    DropdownButtonFormField<String>(
                      value: _speedMode,
                      decoration: const InputDecoration(
                        labelText: 'Speed mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'fast', child: Text('Fast')),
                        DropdownMenuItem(
                          value: 'balanced',
                          child: Text('Balanced'),
                        ),
                        DropdownMenuItem(value: 'deep', child: Text('Deep')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _speedMode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(_speedModeDescription()),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _difficulty = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(_difficultyDescription()),
                    const SizedBox(height: 16),
                    SliderField(
                      label: 'Generation time cap',
                      value: _timeCapSeconds,
                      min: 10,
                      max: 30,
                      divisions: 4,
                      onChanged: (value) => setState(() => _timeCapSeconds = value),
                    ),
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
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
