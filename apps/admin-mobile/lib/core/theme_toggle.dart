import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class PanizThemeToggle extends ConsumerWidget {
  const PanizThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'تغییر به حالت روشن' : 'تغییر به حالت تیره',
      onPressed: () => ref.read(themeModeProvider.notifier).setDark(!isDark),
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }
}
