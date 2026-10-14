import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/menu/menu_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: TroubleApp()));
}

class TroubleApp extends StatelessWidget {
  const TroubleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trouble',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const MenuScreen(),
    );
  }
}
