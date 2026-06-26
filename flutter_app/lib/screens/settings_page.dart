import 'package:flutter/material.dart';

import 'package:flutter_app/widgets/slider_field.dart';

class TrainingSettings {
  const TrainingSettings({
    required this.backendUrl,
    required this.username,
    required this.monthsBack,
    required this.maxGames,
    required this.analysisDepth,
    required this.mistakeThresholdCp,
  });

  final String backendUrl;
  final String username;
  final double monthsBack;
  final double maxGames;
  final double analysisDepth;
  final double mistakeThresholdCp;
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
  late double _monthsBack;
  late double _maxGames;
  late double _analysisDepth;
  late double _mistakeThresholdCp;

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(text: widget.initialSettings.backendUrl);
    _usernameController = TextEditingController(text: widget.initialSettings.username);
    _monthsBack = widget.initialSettings.monthsBack;
    _maxGames = widget.initialSettings.maxGames;
    _analysisDepth = widget.initialSettings.analysisDepth;
    _mistakeThresholdCp = widget.initialSettings.mistakeThresholdCp;
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      TrainingSettings(
        backendUrl: _backendUrlController.text.trim(),
        username: _usernameController.text.trim(),
        monthsBack: _monthsBack,
        maxGames: _maxGames,
        analysisDepth: _analysisDepth,
        mistakeThresholdCp: _mistakeThresholdCp,
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
                      'Analysis settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose how the background analyzer scans your games. Puzzles are loaded from stored results only.',
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
                    const SizedBox(height: 16),
                    SliderField(
                      label: 'How far back to scan (months)',
                      value: _monthsBack,
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (value) => setState(() => _monthsBack = value),
                    ),
                    SliderField(
                      label: 'Max games to scan per run',
                      value: _maxGames,
                      min: 50,
                      max: 2000,
                      divisions: 39,
                      onChanged: (value) => setState(() => _maxGames = value),
                    ),
                    SliderField(
                      label: 'Analysis depth',
                      value: _analysisDepth,
                      min: 6,
                      max: 18,
                      divisions: 12,
                      onChanged: (value) => setState(() => _analysisDepth = value),
                    ),
                    SliderField(
                      label: 'Mistake threshold (centipawns)',
                      value: _mistakeThresholdCp,
                      min: 40,
                      max: 300,
                      divisions: 26,
                      onChanged: (value) => setState(() => _mistakeThresholdCp = value),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Save and run analysis'),
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
