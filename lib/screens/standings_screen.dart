import 'package:flutter/material.dart';

import '../main.dart';
import '../models/stats.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

/// Le classement cumulé du groupe — l'équivalent des « ligues » des apps de
/// référence, mais calculé depuis les défis déjà joués plutôt que stocké.
class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final _cloud = CloudService();
  List<PlayerStats> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _cloud.fetchStandings(AppConfig.groupCode);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classement'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
            tooltip: 'Recalculer',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Classement indisponible',
          message: _error!,
          action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
        ),
      ]);
    }
    if (_rows.isEmpty) {
      return ListView(children: const [
        EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Rien à classer',
          message: 'Le classement se remplit dès qu\'un défi est révélé. '
              'Lance-en un, ou attends que quelqu\'un s\'y colle.',
        ),
      ]);
    }

    final me = _cloud.userId;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: _rows.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Classé par victoires, puis podiums, puis score moyen.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final r = _rows[i - 1];
        return _StandingRow(rank: i, stats: r, isMe: r.playerId == me);
      },
    );
  }
}

class _StandingRow extends StatelessWidget {
  final int rank;
  final PlayerStats stats;
  final bool isMe;

  const _StandingRow({
    required this.rank,
    required this.stats,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final podium = rank <= 3;

    const medals = [AppTheme.tYellow, Color(0xFFAFAFB6), Color(0xFFCD8C5C)];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: AppTheme.accent, width: 1.4) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: podium
                  ? medals[rank - 1].withValues(alpha: .18)
                  : AppTheme.raised,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: podium ? medals[rank - 1] : AppTheme.muted,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.pseudo}${isMe ? " · toi" : ""}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stats.attempts} imitation${stats.attempts > 1 ? "s" : ""}'
                  ' · ${stats.challengesCreated} défi${stats.challengesCreated > 1 ? "s" : ""}'
                  '${stats.avgScore > 0 ? " · moy. ${stats.avgScore.toStringAsFixed(0)}" : ""}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.wins}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text('victoire${stats.wins > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
