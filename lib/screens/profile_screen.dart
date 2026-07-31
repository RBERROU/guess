import 'package:flutter/material.dart';

import '../main.dart';
import '../models/stats.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';
import 'diagnostic_screen.dart';

/// Profil calqué sur la capture « Pooper » : avatar rond, pseudo en gras,
/// date d'arrivée, deux boutons gris, puis la grille de tuiles de statistiques
/// et des cartes de section.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _cloud = CloudService();
  final _auth = AuthService();

  PlayerStats? _me;
  int _rank = 0;
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _cloud.fetchStandings(AppConfig.groupCode);
      final id = _cloud.userId;
      final idx = rows.indexWhere((r) => r.playerId == id);
      if (!mounted) return;
      setState(() {
        _total = rows.length;
        _rank = idx >= 0 ? idx + 1 : 0;
        _me = idx >= 0
            ? rows[idx]
            : PlayerStats(playerId: id ?? '', pseudo: 'Toi');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _editPseudo() async {
    final ctrl = TextEditingController(text: _me?.pseudo ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ton pseudo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: 'CaptnFart'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    await _auth.setPseudo(v);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _me;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('💨', style: TextStyle(fontSize: 36)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s?.pseudo ?? 'Toi',
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _rank > 0
                                  ? '$_rank sur $_total dans le groupe'
                                  : 'Pas encore classé',
                              style: const TextStyle(
                                  color: AppTheme.muted, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _editPseudo,
                          child: const Text('Changer de pseudo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _load,
                          child: const Text('Actualiser'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                    children: [
                      StatTile(
                        icon: Icons.emoji_events_rounded,
                        color: AppTheme.tYellow,
                        value: '${s?.wins ?? 0}',
                        label: 'Victoires',
                      ),
                      StatTile(
                        icon: Icons.military_tech_rounded,
                        color: AppTheme.tViolet,
                        value: '${s?.podiums ?? 0}',
                        label: 'Podiums',
                      ),
                      StatTile(
                        icon: Icons.mic_rounded,
                        color: AppTheme.tGreen,
                        value: '${s?.attempts ?? 0}',
                        label: 'Imitations',
                      ),
                      StatTile(
                        icon: Icons.air_rounded,
                        color: AppTheme.tOrange,
                        value: '${s?.challengesCreated ?? 0}',
                        label: 'Défis',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                    children: [
                      StatTile(
                        icon: Icons.star_rounded,
                        color: AppTheme.tPink,
                        value: (s?.bestScore ?? 0).toStringAsFixed(0),
                        label: 'Meilleur',
                      ),
                      StatTile(
                        icon: Icons.show_chart_rounded,
                        color: AppTheme.tBlue,
                        value: (s?.avgScore ?? 0).toStringAsFixed(0),
                        label: 'Moyenne',
                      ),
                      StatTile(
                        icon: Icons.percent_rounded,
                        color: AppTheme.tPurple,
                        value: (s?.winRate ?? 0).toStringAsFixed(0),
                        label: 'Réussite',
                      ),
                      StatTile(
                        icon: Icons.groups_rounded,
                        color: AppTheme.tRed,
                        value: '$_total',
                        label: 'Joueurs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SectionCard(
                    title: 'Groupe',
                    actionLabel: AppConfig.groupCode,
                    onAction: () {},
                    child: const Text(
                      'Tout le monde partage le même groupe pour l\'instant. '
                      'Les groupes séparés viendront quand le jeu aura fait ses preuves.',
                      style: TextStyle(color: AppTheme.muted, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SectionCard(
                    title: 'Comment les scores marchent',
                    child: Text(
                      'Tout est recalculé à chaque affichage depuis les empreintes '
                      'audio, rien n\'est figé. Si on affine la mesure, les '
                      'classements passés suivent.',
                      style: TextStyle(color: AppTheme.muted, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Le micro ne marche pas ?',
                    actionLabel: 'Diagnostic',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const DiagnosticScreen()),
                    ),
                    child: const Text(
                      'Cet écran dit ce que ton navigateur autorise vraiment, '
                      'et permet de tester la capture en deux secondes.',
                      style: TextStyle(color: AppTheme.muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
