import '../scoring/fingerprint.dart';

/// Les quatre axes d'indice. Ils sont **à la fois** ce qu'on montre aux
/// joueurs et ce sur quoi le score est calculé : on note les gens sur ce
/// qu'on leur a dit. C'est ce qui rend le classement défendable.
enum DurationHint { court, moyen, long }

enum TextureHint { sec, humide }

enum RhythmHint { continu, saccade }

enum PitchHint { grave, aigu }

extension HintLabels on Object {
  String get label => switch (this) {
        DurationHint.court => 'court',
        DurationHint.moyen => 'moyen',
        DurationHint.long => 'long',
        TextureHint.sec => 'sec',
        TextureHint.humide => 'humide',
        RhythmHint.continu => 'continu',
        RhythmHint.saccade => 'saccadé',
        PitchHint.grave => 'grave',
        PitchHint.aigu => 'aigu',
        _ => toString(),
      };
}

class Challenge {
  final String id;
  final String authorId;
  final String? authorPseudo;
  final String groupCode;
  final DateTime createdAt;
  final DateTime revealAt;
  final DurationHint durationHint;
  final TextureHint textureHint;
  final RhythmHint rhythmHint;
  final PitchHint pitchHint;
  final String? context;

  /// Absents tant que le défi n'est pas révélé : la base refuse de les servir.
  final String? audioPath;
  final Fingerprint? fingerprint;

  const Challenge({
    required this.id,
    required this.authorId,
    required this.groupCode,
    required this.createdAt,
    required this.revealAt,
    required this.durationHint,
    required this.textureHint,
    required this.rhythmHint,
    required this.pitchHint,
    this.authorPseudo,
    this.context,
    this.audioPath,
    this.fingerprint,
  });

  bool get isRevealed => DateTime.now().isAfter(revealAt);
  Duration get timeLeft => revealAt.difference(DateTime.now());

  /// Lecture défensive : une ligne incomplète est ignorée plutôt que de faire
  /// tomber la liste entière.
  static Challenge? tryFromRow(Map<String, dynamic> r,
      {Map<String, dynamic>? secret}) {
    try {
      final fp = secret?['fingerprint'];
      return Challenge(
        id: r['id'] as String,
        authorId: r['author_id'] as String,
        authorPseudo: (r['profiles'] as Map?)?['pseudo'] as String?,
        groupCode: '${r['group_code'] ?? ''}',
        createdAt: DateTime.tryParse('${r['created_at']}')?.toLocal() ??
            DateTime.now(),
        revealAt: DateTime.tryParse('${r['reveal_at']}')?.toLocal() ??
            DateTime.now(),
        durationHint: _enum(DurationHint.values, r['duration_hint']),
        textureHint: _enum(TextureHint.values, r['texture_hint']),
        rhythmHint: _enum(RhythmHint.values, r['rhythm_hint']),
        pitchHint: _enum(PitchHint.values, r['pitch_hint']),
        context: r['context'] as String?,
        audioPath: secret?['audio_path'] as String?,
        fingerprint: fp is Map
            ? Fingerprint.fromJson(Map<String, dynamic>.from(fp))
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static T _enum<T extends Enum>(List<T> values, dynamic raw) {
    final s = (raw as String?)?.replaceAll('é', 'e');
    return values.firstWhere((v) => v.name == s, orElse: () => values.first);
  }
}
