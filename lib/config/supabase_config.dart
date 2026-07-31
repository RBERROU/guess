/// Coordonnées du projet Supabase de Guess My Fart.
///
/// Même convention que Just Fart : les identifiants sont **en clair dans le
/// code**. Ce n'est pas une négligence — la clé publiable est publique par
/// conception, elle est de toute façon distribuée dans chaque build, et toute
/// la sécurité repose sur les policies RLS de `supabase/schema.sql`.
/// Conséquence pratique : quelqu'un qui clone le dépôt a un backend qui
/// marche tout de suite, sans rien recréer.
///
/// Projet **distinct de Just Fart** : les deux ont une table `profiles`,
/// elles se marcheraient dessus.
///
/// Note : Supabase a remplacé les clés `anon` (format `eyJ…`) par des clés
/// publiables (`sb_publishable_…`). C'est le nouveau format qui est utilisé
/// ici, avec le paramètre `publishableKey` de `Supabase.initialize`.
class SupabaseConfig {
  static const String url = 'https://hbycfyxcwydygjbwxvsl.supabase.co';
  static const String publishableKey =
      'sb_publishable_TFk_ZibVLug8EsmbvE-kxg_n9ERbFIX';

  /// Tant que ce n'est pas rempli, l'app affiche un écran d'explication au
  /// lieu de planter au démarrage.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
