import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/home_shell.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

/// Réglages du v0.
class AppConfig {
  /// Un seul groupe pour le v0 : tout le monde partage le même code. Les
  /// groupes multiples viendront quand le jeu aura fait ses preuves — la
  /// colonne existe déjà en base, il n'y aura rien à migrer.
  static const String groupCode = 'POTES';

  /// Délai par défaut avant révélation automatique.
  static const Duration defaultWindow = Duration(hours: 12);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    await AuthService().ensureSignedIn();
  }

  runApp(const GuessMyFartApp());
}

class GuessMyFartApp extends StatelessWidget {
  const GuessMyFartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guess My Fart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: SupabaseConfig.isConfigured
          ? const HomeShell()
          : const _NotConfigured(),
    );
  }
}

/// Écran explicite plutôt qu'un plantage au démarrage : tant que le projet
/// Supabase n'existe pas, l'app dit quoi faire.
class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56),
              const SizedBox(height: 20),
              Text('Supabase pas encore configuré',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                'Crée un projet Supabase, exécute supabase/schema.sql, puis '
                'colle l\'URL et la clé anon dans '
                'lib/config/supabase_config.dart.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
