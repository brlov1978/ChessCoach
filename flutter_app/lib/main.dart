import 'package:flutter/material.dart';

import 'package:flutter_app/screens/chess_coach_page.dart';
import 'package:flutter_app/theme/app_theme.dart';

void main() {
  runApp(const ChessCoachApp());
}

class ChessCoachApp extends StatelessWidget {
  const ChessCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Coach',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ChessCoachPage(),
    );
  }
}
