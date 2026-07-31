import 'package:flutter/material.dart';

import '../main.dart';
import '../models/challenge.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';
import 'create_challenge_screen.dart';
import 'reveal_screen.dart';
import 'submit_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _cloud = CloudService();
  List<Challenge> _challenges = [];
  Set<String> _submitted = {};
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
      final list = await _cloud.listChallenges(AppConfig.groupCode);
      // Une soumission par défi et par joueur : savoir lesquels sont déjà
      // faits évite de proposer de rejouer (la base refuserait de toute façon).
      final mine = <String>{};
      for (final c in list) {
        final subs = await _cloud.listSubmissions(c.id);
        if (subs.any((s) => s.playerId == _cloud.userId)) mine.add(c.id);
      }
      if (!mounted) return;
      setState(() {
        _challenges = list;
        _submitted = mine;
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

  /// Révéler sans attendre les 12 h. Réservé à l'auteur — c'est lui qui sait
  /// si tout le monde a joué, et sans ça il faudrait attendre une demi-journée
  /// pour voir le moindre classement.
  Future<void> _revealNow(Challenge c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Révéler maintenant ?'),
        content: const Text(
          'Ton pet deviendra audible et le classement s\'affichera. '
          'Plus personne ne pourra soumettre après. C\'est irréversible.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Révéler')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _cloud.revealNow(c.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guess My Fart'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Lancer un défi'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Défis inaccessibles',
          message: _error!,
          action: FilledButton(onPressed: _load, child: const Text('Réessayer')),
        ),
      ]);
    }
    if (_challenges.isEmpty) {
      return ListView(children: const [
        EmptyState(
          icon: Icons.air_rounded,
          title: 'Aucun défi en cours',
          message: 'Enregistre ton pet du matin, donne quelques indices, '
              'et laisse tes potes tenter de le reproduire à la bouche.',
        ),
      ]);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: _challenges.length,
      itemBuilder: (_, i) => _ChallengeCard(
        challenge: _challenges[i],
        alreadySubmitted: _submitted.contains(_challenges[i].id),
        isMine: _challenges[i].authorId == _cloud.userId,
        onReveal: () => _revealNow(_challenges[i]),
        onOpen: () async {
          final c = _challenges[i];
          if (c.isRevealed) {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RevealScreen(challenge: c)),
            );
          } else if (!_submitted.contains(c.id) && c.authorId != _cloud.userId) {
            final done = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => SubmitScreen(challenge: c)),
            );
            if (done == true) _load();
          }
        },
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final bool alreadySubmitted;
  final bool isMine;
  final VoidCallback onOpen;
  final VoidCallback onReveal;

  const _ChallengeCard({
    required this.challenge,
    required this.alreadySubmitted,
    required this.isMine,
    required this.onOpen,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final revealed = challenge.isRevealed;

    final (String status, Color color) = revealed
        ? ('Révélé — voir le classement', AppTheme.accent)
        : isMine
            ? ('Ton défi — en attente des autres', AppTheme.muted)
            : alreadySubmitted
                ? ('Tentative envoyée', AppTheme.muted)
                : ('À toi de jouer', AppTheme.accent);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isMine ? 'Ton pet' : 'Le pet de ${challenge.authorPseudo ?? "?"}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink),
                    ),
                  ),
                  if (!revealed)
                    Text(
                      _left(challenge.timeLeft),
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.muted),
                    ),
                ],
              ),
              if (challenge.context != null && challenge.context!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(challenge.context!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(challenge.durationHint.label),
                  _Chip(challenge.textureHint.label),
                  _Chip(challenge.rhythmHint.label),
                  _Chip(challenge.pitchHint.label),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ),
                  if (isMine && !revealed)
                    TextButton(
                      onPressed: onReveal,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Révéler'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _left(Duration d) {
    if (d.isNegative) return 'terminé';
    if (d.inHours >= 1) return 'encore ${d.inHours} h';
    if (d.inMinutes >= 1) return 'encore ${d.inMinutes} min';
    return 'dernière minute';
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.raised,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
      ),
    );
  }
}
