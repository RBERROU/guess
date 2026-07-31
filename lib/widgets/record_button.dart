import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gros bouton d'enregistrement : on maintient pour enregistrer, on relâche
/// pour arrêter. Plus direct qu'un appui/re-appui pour des sons d'une seconde.
class RecordButton extends StatelessWidget {
  final bool recording;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final String idleLabel;

  const RecordButton({
    super.key,
    required this.recording,
    required this.onStart,
    required this.onStop,
    this.idleLabel = 'Maintiens pour enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF3B30);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => onStart(),
          onTapUp: (_) => onStop(),
          onTapCancel: onStop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: recording ? 168 : 148,
            height: recording ? 168 : 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recording ? red : AppTheme.accent,
              boxShadow: [
                BoxShadow(
                  color: (recording ? red : AppTheme.accent)
                      .withValues(alpha: recording ? .38 : .22),
                  blurRadius: recording ? 34 : 18,
                  spreadRadius: recording ? 6 : 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, size: 62, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          recording ? 'Relâche pour arrêter' : idleLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppTheme.muted),
        ),
      ],
    );
  }
}
