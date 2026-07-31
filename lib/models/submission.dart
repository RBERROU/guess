import '../scoring/fingerprint.dart';
import '../scoring/matcher.dart';

class Submission {
  final String id;
  final String challengeId;
  final String playerId;
  final String? playerPseudo;
  final DateTime createdAt;
  final String audioPath;
  final Fingerprint fingerprint;

  /// Calculé au moment de la révélation, sur l'appareil, puis écrit en base.
  /// Conservé pour l'affichage et pour pouvoir comparer plus tard un
  /// classement recalculé à celui qui a été montré aux joueurs.
  final MatchScore? score;

  const Submission({
    required this.id,
    required this.challengeId,
    required this.playerId,
    required this.createdAt,
    required this.audioPath,
    required this.fingerprint,
    this.playerPseudo,
    this.score,
  });

  /// Lecture défensive : une ligne mal formée est ignorée (`null`) plutôt que
  /// de faire tomber tout l'écran de révélation.
  static Submission? tryFromRow(Map<String, dynamic> r) {
    try {
      return Submission(
        id: r['id'] as String,
        challengeId: r['challenge_id'] as String,
        playerId: r['player_id'] as String,
        playerPseudo: (r['profiles'] as Map?)?['pseudo'] as String?,
        createdAt: DateTime.tryParse('${r['created_at']}')?.toLocal() ??
            DateTime.now(),
        audioPath: '${r['audio_path'] ?? ''}',
        fingerprint: r['fingerprint'] is Map
            ? Fingerprint.fromJson(
                Map<String, dynamic>.from(r['fingerprint'] as Map))
            : const Fingerprint(
                durationSec: 0, envelope: [], burstRate: 0,
                envelopeRoughness: 0, centroidHz: 0, centroidSlope: 0,
                pitchHz: 0, pitchSlope: 0, noisiness: 1),
        score: r['score'] is Map
            ? _score(Map<String, dynamic>.from(r['score'] as Map))
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static MatchScore _score(Map<String, dynamic> j) => MatchScore(
        total: _d(j['total']),
        duration: _d(j['duration']),
        rhythm: _d(j['rhythm']),
        pitch: _d(j['pitch']),
        texture: _d(j['texture']),
      );

  static double _d(dynamic v) => v is num ? v.toDouble() : 0;

  Submission withScore(MatchScore s) => Submission(
        id: id, challengeId: challengeId, playerId: playerId,
        playerPseudo: playerPseudo, createdAt: createdAt,
        audioPath: audioPath, fingerprint: fingerprint, score: s,
      );
}
