import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';
import '../models/stats.dart';
import '../models/submission.dart';
import '../scoring/fingerprint.dart';
import '../scoring/matcher.dart';

/// Accès à Supabase. Toutes les règles de secret sont appliquées **côté
/// serveur** par les policies RLS : ce service ne fait que demander, et la
/// base refuse ce qui doit rester caché avant la révélation. Aucune sécurité
/// ne repose sur ce fichier.
class CloudService {
  SupabaseClient get _db => Supabase.instance.client;
  String? get userId => _db.auth.currentUser?.id;

  // ------------------------------------------------------------- défis

  Future<List<Challenge>> listChallenges(String groupCode) async {
    final rows = await _db
        .from('challenges')
        .select('*, profiles!challenges_author_id_fkey(pseudo)')
        .eq('group_code', groupCode)
        .order('created_at', ascending: false)
        .limit(50);

    final out = <Challenge>[];
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      Map<String, dynamic>? secret;
      // Tentative de lecture du secret : la base la rejette silencieusement
      // tant que le défi n'est pas révélé, ce qui est exactement le
      // comportement voulu.
      try {
        secret = await _db
            .from('challenge_secrets')
            .select()
            .eq('challenge_id', r['id'] as String)
            .maybeSingle();
      } catch (_) {
        secret = null;
      }
      final c = Challenge.tryFromRow(r, secret: secret);
      if (c != null) out.add(c);
    }
    return out;
  }

  /// Crée un défi : la ligne publique, puis l'audio, puis le secret.
  /// Dans cet ordre, un échec en cours de route laisse au pire un défi sans
  /// secret — visible mais jamais révélable, plutôt qu'un audio orphelin.
  Future<String> createChallenge({
    required String groupCode,
    required DateTime revealAt,
    required DurationHint durationHint,
    required TextureHint textureHint,
    required RhythmHint rhythmHint,
    required PitchHint pitchHint,
    String? context,
    required Uint8List wav,
    required Fingerprint fingerprint,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('pas de session');

    final inserted = await _db
        .from('challenges')
        .insert({
          'author_id': uid,
          'group_code': groupCode,
          'reveal_at': revealAt.toUtc().toIso8601String(),
          'duration_hint': durationHint.name,
          'texture_hint': textureHint.name,
          'rhythm_hint': rhythmHint.name,
          'pitch_hint': pitchHint.name,
          'context': context,
        })
        .select('id')
        .single();

    final id = inserted['id'] as String;
    final path = '$id.wav';

    await _db.storage.from('farts').uploadBinary(
          path,
          wav,
          fileOptions: const FileOptions(contentType: 'audio/wav'),
        );

    await _db.from('challenge_secrets').insert({
      'challenge_id': id,
      'audio_path': path,
      'fingerprint': fingerprint.toJson(),
    });

    return id;
  }

  /// Avance la révélation à maintenant — utilisé quand tout le monde a soumis.
  Future<void> revealNow(String challengeId) async {
    await _db
        .from('challenges')
        .update({'reveal_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', challengeId);
  }

  // ------------------------------------------------------- soumissions

  Future<List<Submission>> listSubmissions(String challengeId) async {
    final rows = await _db
        .from('submissions')
        .select('*, profiles!submissions_player_id_fkey(pseudo)')
        .eq('challenge_id', challengeId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Submission.tryFromRow)
        .whereType<Submission>()
        .toList();
  }

  Future<void> submit({
    required String challengeId,
    required Uint8List wav,
    required Fingerprint fingerprint,
  }) async {
    final uid = userId;
    if (uid == null) throw StateError('pas de session');
    final path = '$challengeId/$uid.wav';

    await _db.storage.from('attempts').uploadBinary(
          path,
          wav,
          fileOptions: const FileOptions(contentType: 'audio/wav', upsert: true),
        );

    await _db.from('submissions').insert({
      'challenge_id': challengeId,
      'player_id': uid,
      'audio_path': path,
      'fingerprint': fingerprint.toJson(),
    });
  }

  /// Écrit les scores calculés sur l'appareil au moment de la révélation.
  /// Chaque joueur ne peut écrire que le sien (policy RLS) : le score affiché
  /// est donc reconstituable et vérifiable par tous à partir des empreintes.
  Future<void> saveScore(String submissionId, MatchScore score) async {
    await _db
        .from('submissions')
        .update({'score': score.toJson()}).eq('id', submissionId);
  }

  // -------------------------------------------------------- classement

  /// Calcule le classement du groupe à partir des défis **révélés**.
  ///
  /// Les scores ne sont pas relus depuis la base : ils sont recalculés depuis
  /// les empreintes. C'est un peu plus de travail, mais ça reste juste le jour
  /// où on retouchera les poids — les classements passés suivent
  /// automatiquement, au lieu de figer un verdict rendu avec d'anciens
  /// réglages.
  Future<List<PlayerStats>> fetchStandings(String groupCode) async {
    final weights = await fetchWeights();
    final challenges = await listChallenges(groupCode);
    final revealed = challenges.where((c) => c.isRevealed).toList();

    final acc = <String, PlayerStats>{};
    final totals = <String, List<double>>{};

    PlayerStats slot(String id, String? pseudo) =>
        acc.putIfAbsent(id, () => PlayerStats(playerId: id, pseudo: pseudo ?? '?'));

    // Les pets enregistrés comptent aussi : lancer un défi est un acte de jeu.
    for (final c in challenges) {
      final s = slot(c.authorId, c.authorPseudo);
      acc[c.authorId] = s.copyWith(
        pseudo: c.authorPseudo ?? s.pseudo,
        challengesCreated: s.challengesCreated + 1,
      );
    }

    for (final c in revealed) {
      final target = c.fingerprint;
      if (target == null || !target.isUsable) continue;
      // Une empreinte inexploitable ne se classe pas : la compter fausserait
      // le classement de tout le monde.
      final subs = (await listSubmissions(c.id))
          .where((s) => s.fingerprint.isUsable)
          .toList();
      if (subs.isEmpty) continue;

      final ranked = Matcher.rank(
        target,
        {for (final s in subs) s: s.fingerprint},
        weights: weights,
      );

      for (var i = 0; i < ranked.length; i++) {
        final sub = ranked[i].key;
        final sc = ranked[i].value.total;
        final s = slot(sub.playerId, sub.playerPseudo);
        acc[sub.playerId] = s.copyWith(
          pseudo: sub.playerPseudo ?? s.pseudo,
          attempts: s.attempts + 1,
          wins: s.wins + (i == 0 ? 1 : 0),
          podiums: s.podiums + (i < 3 ? 1 : 0),
          bestScore: sc > s.bestScore ? sc : s.bestScore,
        );
        (totals[sub.playerId] ??= []).add(sc);
      }
    }

    for (final e in totals.entries) {
      final l = e.value;
      final avg = l.isEmpty ? 0.0 : l.reduce((a, b) => a + b) / l.length;
      acc[e.key] = acc[e.key]!.copyWith(avgScore: avg);
    }

    final out = acc.values.toList()
      ..sort((a, b) {
        final w = b.wins.compareTo(a.wins);
        if (w != 0) return w;
        final p = b.podiums.compareTo(a.podiums);
        if (p != 0) return p;
        return b.avgScore.compareTo(a.avgScore);
      });
    return out;
  }

  // ----------------------------------------------------------- fichiers

  /// URL temporaire pour la lecture. Échoue tant que la révélation n'a pas
  /// eu lieu : c'est la policy sur le stockage qui tranche, pas l'app.
  Future<String> signedUrl(String bucket, String path,
          {int seconds = 3600}) =>
      _db.storage.from(bucket).createSignedUrl(path, seconds);

  // -------------------------------------------------------------- poids

  /// Poids du score, servis par la base pour être corrigeables sans
  /// republier l'app. En cas d'échec, on retombe sur les valeurs par défaut.
  Future<ScoreWeights> fetchWeights() async {
    try {
      final row = await _db
          .from('score_weights')
          .select('weights')
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return ScoreWeights.defaults;
      return ScoreWeights.fromJson(
          Map<String, dynamic>.from(row['weights'] as Map));
    } catch (_) {
      return ScoreWeights.defaults;
    }
  }
}
