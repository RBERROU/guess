import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connexion anonyme : zéro friction, l'utilisateur a un compte sans le savoir.
/// La session est persistée par supabase_flutter, donc l'identité reste stable
/// entre les lancements sur un même appareil.
class AuthService {
  static const _timeout = Duration(seconds: 8);

  Future<void> ensureSignedIn() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously().timeout(_timeout);
      }
      final user = client.auth.currentUser;
      if (user == null) return;
      await client.from('profiles').upsert(
        {'id': user.id, 'pseudo': 'Joueur ${user.id.substring(0, 4).toUpperCase()}'},
        ignoreDuplicates: true,
      ).timeout(_timeout);
    } catch (e) {
      debugPrint('Auth Supabase indisponible : $e');
    }
  }

  Future<void> setPseudo(String pseudo) async {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null) return;
    await client.from('profiles').update({'pseudo': pseudo}).eq('id', id);
  }
}
