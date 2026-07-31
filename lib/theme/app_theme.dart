import 'package:flutter/material.dart';

/// Identité visuelle calquée sur les captures de référence : fond gris très
/// clair, cartes blanches arrondies, bleu système pour toute action, titres
/// noirs en gras et texte secondaire gris.
///
/// Les couleurs vives sont réservées aux **icônes des tuiles de statistiques**,
/// une par catégorie — c'est ce qui donne de la vie sans colorer le fond.
class AppTheme {
  static const accent = Color(0xFF007AFF);  // bleu système, toutes les actions
  static const ground = Color(0xFFF2F2F7);  // fond des écrans
  static const surface = Colors.white;      // cartes
  static const raised = Color(0xFFEFEFF4);  // boutons secondaires, champs
  static const line = Color(0xFFE1E1E6);
  static const ink = Color(0xFF111114);
  static const muted = Color(0xFF8A8A8E);

  // Accents des tuiles, repris de la palette des captures.
  static const tViolet = Color(0xFF7B5CE0);
  static const tGreen = Color(0xFF34C759);
  static const tOrange = Color(0xFFFF9500);
  static const tBlue = Color(0xFF32ADE6);
  static const tYellow = Color(0xFFFFCC00);
  static const tRed = Color(0xFFFF3B30);
  static const tPink = Color(0xFFFF2D55);
  static const tPurple = Color(0xFFAF52DE);

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outlineVariant: line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ground,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: ground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: ink,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: accent,
        checkmarkColor: Colors.white,
        side: BorderSide.none,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13.5, color: ink),
        secondaryLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: raised,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(44),
          side: BorderSide.none,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFF9F9FB),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 27,
            color: s.contains(WidgetState.selected)
                ? accent
                : const Color(0xFF9A9AA0),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 0.7, space: 1),
      textTheme: const TextTheme(
        headlineSmall:
            TextStyle(fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.5),
        titleLarge:
            TextStyle(fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.3),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
        titleSmall: TextStyle(fontWeight: FontWeight.w600, color: ink),
        bodyMedium: TextStyle(color: ink),
        bodySmall: TextStyle(color: muted),
      ),
    );
  }
}

/// Tuile de statistique : icône colorée en haut, grand nombre noir, libellé
/// gris. Reprise directe des captures.
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: color),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5, height: 1.2, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

/// État vide : icône grise, titre noir en gras, phrase grise, une seule action.
/// C'est exactement le motif des captures.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFFB4B4BA)),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.ink),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, color: AppTheme.muted, height: 1.35),
            ),
            if (action != null) ...[const SizedBox(height: 26), action!],
          ],
        ),
      ),
    );
  }
}

/// Carte de section blanche avec un titre et un lien « Voir tout » en bleu,
/// comme les blocs « Public leagues » et « Achievements » des captures.
class SectionCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink)),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}
