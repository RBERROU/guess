import 'package:flutter/material.dart';

import '../main.dart';
import '../models/stats.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

/// Le profil, en tuiles de statistiques — le motif repris des apps de
/// référence, parce que c'est lui qui donne envie de revenir voir ses chiffres.
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
          decoration: const InputDecoration(hintText: 'CaptainBrap'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
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
    final scheme = Theme.of(context).colorScheme;
    final s = _me;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.gas.withValues(alpha: .16),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.gas.withValues(alpha: .4)),
                        ),
                        child: const Text('💨', style: TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s?.pseudo ?? 'Toi',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(
                              _rank > 0
                                  ? '$_rankᵉ sur $_total dans le groupe'
                                  : 'Pas encore classé',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _editPseudo,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Changer de pseudo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      StatTile(
                        icon: Icons.emoji_events_rounded,
                        color: AppTheme.trophy,
                        value: '${s?.wins ?? 0}',
                        label: 'Victoires',
                      ),
                      StatTile(
                        icon: Icons.military_tech_rounded,
                        color: const Color(0xFF7FB2E5),
                        value: '${s?.podiums ?? 0}',
                        label: 'Podiums',
                      ),
                      StatTile(
                        icon: Icons.mic_rounded,
                        color: AppTheme.gas,
                        value: '${s?.attempts ?? 0}',
                        label: 'Imitations envoyées',
                      ),
                      StatTile(
                        icon: Icons.air_rounded,
                        color: const Color(0xFFD98BD3),
                        value: '${s?.challengesCreated ?? 0}',
                        label: 'Défis lancés',
                      ),
                      StatTile(
                        icon: Icons.star_rounded,
                        color: const Color(0xFFE5C15A),
                        value: (s?.bestScore ?? 0).toStringAsFixed(0),
                        label: 'Meilleur score',
                      ),
                      StatTile(
                        icon: Icons.show_chart_rounded,
                        color: const Color(0xFF8FD9A8),
                        value: (s?.avgScore ?? 0).toStringAsFixed(0),
                        label: 'Score moyen',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.groups_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text('Groupe',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const Spacer(),
                              Text(
                                AppConfig.groupCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tout le monde partage le même groupe pour l\'instant. '
                            'Les groupes séparés viendront quand le jeu aura fait '
                            'ses preuves.',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Les scores sont recalculés à chaque affichage depuis les '
                    'empreintes audio. Si on affine la mesure, les classements '
                    'passés suivent.',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: .8),
                        height: 1.4),
                  ),
                ],
              ),
            ),
    );
  }
}
