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

  factory Submission.fromRow(Map<String, dynamic> r) => Submission(
        id: r['id'] as String,
        challengeId: r['challenge_id'] as String,
        playerId: r['player_id'] as String,
        playerPseudo: (r['profiles'] as Map?)?['pseudo'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        audioPath: r['audio_path'] as String,
        fingerprint: Fingerprint.fromJson(
            Map<String, dynamic>.from(r['fingerprint'] as Map)),
        score: r['score'] == null
            ? null
            : _score(Map<String, dynamic>.from(r['score'] as Map)),
      );

  static MatchScore _score(Map<String, dynamic> j) => MatchScore(
        total: (j['total'] as num).toDouble(),
        duration: (j['duration'] as num).toDouble(),
        rhythm: (j['rhythm'] as num).toDouble(),
        pitch: (j['pitch'] as num).toDouble(),
        texture: (j['texture'] as num).toDouble(),
      );

  Submission withScore(MatchScore s) => Submission(
        id: id, challengeId: challengeId, playerId: playerId,
        playerPseudo: playerPseudo, createdAt: createdAt,
        audioPath: audioPath, fingerprint: fingerprint, score: s,
      );
}
