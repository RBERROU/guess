import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
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
              color: recording ? scheme.error : scheme.primary,
              boxShadow: [
                if (recording)
                  BoxShadow(
                    color: scheme.error.withValues(alpha: .45),
                    blurRadius: 34,
                    spreadRadius: 6,
                  ),
              ],
            ),
            child: Icon(
              recording ? Icons.stop_rounded : Icons.mic_rounded,
              size: 62,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          recording ? 'Relâche pour arrêter' : idleLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
