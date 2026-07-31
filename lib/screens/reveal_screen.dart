import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../models/submission.dart';
import '../scoring/matcher.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';

/// La révélation : on entend enfin le vrai pet, puis chaque tentative,
/// classées de la plus proche à la plus éloignée.
///
/// Le score est calculé ici, sur l'appareil, à partir des empreintes. Ça
/// rend la triche inutile : personne ne peut connaître son score avant
/// d'avoir soumis, donc personne ne peut réessayer jusqu'à ce que ça monte.
class RevealScreen extends StatefulWidget {
  final Challenge challenge;
  const RevealScreen({super.key, required this.challenge});

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  final _cloud = CloudService();
  final _player = PlayerService();

  List<MapEntry<Submission, MatchScore>> _ranked = [];
  String? _fartUrl;
  bool _loading = true;
  String? _error;
  String? _playing;

  @override
  void initState() {
    super.initState();
    _load();
    _player.onComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final weights = await _cloud.fetchWeights();
      final subs = await _cloud.listSubmissions(widget.challenge.id);
      final target = widget.challenge.fingerprint;

      String? url;
      final path = widget.challenge.audioPath;
      if (path != null) {
        url = await _cloud.signedUrl('farts', path);
      }

      var ranked = <MapEntry<Submission, MatchScore>>[];
      final usable = subs.where((s) => s.fingerprint.isUsable).toList();
      if (target != null && target.isUsable && usable.isNotEmpty) {
        final scores = Matcher.rank(
          target,
          {for (final s in usable) s: s.fingerprint},
          weights: weights,
        );
        ranked = scores;
        // On persiste les scores affichés, pour pouvoir plus tard comparer un
        // classement recalculé à celui qui a réellement été montré.
        for (final e in scores) {
          if (e.key.playerId == _cloud.userId && e.key.score == null) {
            try {
              await _cloud.saveScore(e.key.id, e.value);
            } catch (_) {}
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _ranked = ranked;
        _fartUrl = url;
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

  Future<void> _play(String url, String tag) async {
    if (_playing == tag) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = tag);
    await _player.playUrl(url, tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Scaffold(
      appBar: AppBar(title: Text('Le pet de ${c.authorPseudo ?? "?"}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Chargement impossible.\n$_error',
                        textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Text('L\'original',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            if (_fartUrl != null)
                              FilledButton.icon(
                                onPressed: () => _play(_fartUrl!, 'original'),
                                icon: Icon(_playing == 'original'
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded),
                                label: Text(_playing == 'original'
                                    ? 'Arrêter'
                                    : 'Écouter le vrai pet'),
                              )
                            else
                              const Text('Audio indisponible.'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Classement',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Personne n\'a entendu le pet avant de soumettre — '
                      'les scores sont bas par nature, seul l\'ordre compte.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (_ranked.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Personne n\'a tenté sa chance.',
                            textAlign: TextAlign.center),
                      ),
                    ..._ranked.asMap().entries.map((e) => _Row(
                          rank: e.key + 1,
                          submission: e.value.key,
                          score: e.value.value,
                          isMe: e.value.key.playerId == _cloud.userId,
                          playing: _playing == e.value.key.id,
                          onPlay: () async {
                            try {
                              final url = await _cloud.signedUrl(
                                  'attempts', e.value.key.audioPath);
                              await _play(url, e.value.key.id);
                            } catch (_) {}
                          },
                        )),
                  ],
                ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final Submission submission;
  final MatchScore score;
  final bool isMe;
  final bool playing;
  final VoidCallback onPlay;

  const _Row({
    required this.rank,
    required this.submission,
    required this.score,
    required this.isMe,
    required this.playing,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final winner = rank == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    winner ? '🏆' : '$rank',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${submission.playerPseudo ?? "?"}${isMe ? " (toi)" : ""}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  score.total.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: winner ? scheme.primary : null,
                      ),
                ),
                IconButton(
                  onPressed: onPlay,
                  icon: Icon(playing
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Axis('durée', score.duration),
                _Axis('rythme', score.rhythm),
                _Axis('hauteur', score.pitch),
                _Axis('texture', score.texture),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Le détail par axe : c'est ce qui rend le verdict discutable plutôt que
/// contestable. « Bonne durée mais trop aigu » se comprend ; un nombre seul
/// se conteste.
class _Axis extends StatelessWidget {
  final String label;
  final double value;
  const _Axis(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: .5),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
