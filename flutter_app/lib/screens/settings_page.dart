import 'package:flutter/material.dart';

import 'package:flutter_app/widgets/slider_field.dart';

class TrainingSettings {
  const TrainingSettings({
    required this.backendUrl,
    required this.username,
    required this.maxGames,
    required this.maxPuzzles,
    required this.analysisDepth,
  });

  final String backendUrl;
  final String username;
  final double maxGames;
  final double maxPuzzles;
  final double analysisDepth;
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

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(text: widget.initialSettings.backendUrl);
    _usernameController = TextEditingController(text: widget.initialSettings.username);
    _maxGames = widget.initialSettings.maxGames;
    _maxPuzzles = widget.initialSettings.maxPuzzles;
    _analysisDepth = widget.initialSettings.analysisDepth;
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
        maxGames: _maxGames,
        maxPuzzles: _maxPuzzles,
        analysisDepth: _analysisDepth,
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
