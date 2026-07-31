import 'dart:math' as math;

import 'fingerprint.dart';

/// Poids du score, réglables **à distance** (table de configuration Supabase).
///
/// Ils ne sont pas calibrés : personne n'a encore comparé un classement machine
/// à un classement humain. Ils sont donc faits pour être corrigés sans
/// republier l'app, et les empreintes brutes sont conservées pour pouvoir
/// recalculer les défis passés.
class ScoreWeights {
  final double duration;
  final double rhythm;
  final double pitch;
  final double texture;

  /// Écarts considérés comme « complètement à côté ». Un écart supérieur donne
  /// zéro sur l'axe. Ils fixent l'échelle : trop serrés, tout le monde a zéro ;
  /// trop larges, tout le monde a la même note.
  final double durationTolerance;   // en proportion (0.8 = 80 % d'écart)
  final double burstTolerance;      // bouffées par seconde
  final double pitchTolerance;      // en proportion
  final double centroidTolerance;   // en proportion

  const ScoreWeights({
    this.duration = 0.25,
    this.rhythm = 0.35,
    this.pitch = 0.25,
    this.texture = 0.15,
    this.durationTolerance = 0.8,
    this.burstTolerance = 4.0,
    this.pitchTolerance = 0.9,
    this.centroidTolerance = 1.2,
  });

  factory ScoreWeights.fromJson(Map<String, dynamic> j) => ScoreWeights(
        duration: _d(j['duration'], 0.25),
        rhythm: _d(j['rhythm'], 0.35),
        pitch: _d(j['pitch'], 0.25),
        texture: _d(j['texture'], 0.15),
        durationTolerance: _d(j['durationTolerance'], 0.8),
        burstTolerance: _d(j['burstTolerance'], 4.0),
        pitchTolerance: _d(j['pitchTolerance'], 0.9),
        centroidTolerance: _d(j['centroidTolerance'], 1.2),
      );

  static double _d(dynamic v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  static const ScoreWeights defaults = ScoreWeights();
}

/// Résultat lisible : un total, et le détail par axe pour que le classement
/// soit explicable. « Tu avais la bonne durée mais tu étais trop aigu » se
/// discute ; un « 43 % » tout seul se conteste.
class MatchScore {
  final double total;      // 0 à 100
  final double duration;   // 0 à 100 par axe
  final double rhythm;
  final double pitch;
  final double texture;

  const MatchScore({
    required this.total,
    required this.duration,
    required this.rhythm,
    required this.pitch,
    required this.texture,
  });

  /// L'axe le mieux réussi et le plus raté, pour le retour à l'écran.
  String get bestAxis => _rank().first.key;
  String get worstAxis => _rank().last.key;

  List<MapEntry<String, double>> _rank() {
    final l = [
      MapEntry('durée', duration),
      MapEntry('rythme', rhythm),
      MapEntry('hauteur', pitch),
      MapEntry('texture', texture),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return l;
  }

  Map<String, dynamic> toJson() => {
        'total': total, 'duration': duration, 'rhythm': rhythm,
        'pitch': pitch, 'texture': texture,
      };
}

class Matcher {
  /// Compare une imitation à la cible.
  ///
  /// Le score absolu n'a pas de sens et n'a pas besoin d'en avoir : les
  /// joueurs soumettent à l'aveugle, donc tout le monde sera loin. Seul
  /// **l'ordre** compte, et les biais systématiques s'annulent puisque toutes
  /// les soumissions sont comparées à la même cible.
  static MatchScore score(
    Fingerprint target,
    Fingerprint attempt, {
    ScoreWeights weights = ScoreWeights.defaults,
  }) {
    // Durée : écart relatif, symétrique (deux fois trop long est aussi faux
    // que deux fois trop court).
    final dRel = _relDiff(target.durationSec, attempt.durationSec);
    final durationScore = _falloff(dRel, weights.durationTolerance);

    // Rythme : nombre de bouffées par seconde, plus la forme de l'enveloppe.
    final burstDiff = (target.burstRate - attempt.burstRate).abs();
    final burstScore = _falloff(burstDiff, weights.burstTolerance);
    final envScore = _envelopeSimilarity(target.envelope, attempt.envelope);
    final rhythmScore = 0.5 * burstScore + 0.5 * envScore;

    // Hauteur : fréquence dominante, plus le sens de la dérive.
    final pRel = _relDiff(target.pitchHz, attempt.pitchHz);
    final pitchBase = _falloff(pRel, weights.pitchTolerance);
    final slopeAgree = _slopeAgreement(target.pitchSlope, attempt.pitchSlope);
    final pitchScore = 0.75 * pitchBase + 0.25 * slopeAgree;

    // Texture : brillance et part de souffle. Pesée faible volontairement —
    // une bouche ne peut pas reproduire le timbre d'un vrai pet.
    final cRel = _relDiff(target.centroidHz, attempt.centroidHz);
    final cScore = _falloff(cRel, weights.centroidTolerance);
    final nScore = _falloff((target.noisiness - attempt.noisiness).abs(), 0.6);
    final textureScore = 0.6 * cScore + 0.4 * nScore;

    final wSum = weights.duration + weights.rhythm + weights.pitch + weights.texture;
    final total = wSum <= 0
        ? 0.0
        : (durationScore * weights.duration +
                rhythmScore * weights.rhythm +
                pitchScore * weights.pitch +
                textureScore * weights.texture) /
            wSum;

    return MatchScore(
      total: _pct(total),
      duration: _pct(durationScore),
      rhythm: _pct(rhythmScore),
      pitch: _pct(pitchScore),
      texture: _pct(textureScore),
    );
  }

  /// Classe les soumissions d'un défi, de la plus proche à la plus éloignée.
  static List<MapEntry<K, MatchScore>> rank<K>(
    Fingerprint target,
    Map<K, Fingerprint> attempts, {
    ScoreWeights weights = ScoreWeights.defaults,
  }) {
    final out = attempts.entries
        .map((e) => MapEntry(e.key, score(target, e.value, weights: weights)))
        .toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return out;
  }

  // ------------------------------------------------------------- internes

  /// Écart relatif symétrique : rapporté à la plus grande des deux valeurs,
  /// pour que 1 s contre 2 s donne le même écart que 2 s contre 1 s.
  static double _relDiff(double a, double b) {
    final m = math.max(a.abs(), b.abs());
    if (m <= 0) return 0;
    return (a - b).abs() / m;
  }

  /// Décroissance douce : 1 quand l'écart est nul, 0 au-delà de la tolérance.
  /// Le cosinus évite l'effet de seuil brutal d'une droite.
  static double _falloff(double diff, double tolerance) {
    if (tolerance <= 0) return diff == 0 ? 1 : 0;
    final t = (diff / tolerance).clamp(0.0, 1.0);
    return 0.5 * (1 + math.cos(math.pi * t));
  }

  /// Corrélation des formes d'enveloppe, ramenée sur 0..1.
  /// Les deux sont déjà rééchantillonnées au même nombre de points, donc
  /// des durées différentes restent comparables : on compare la *forme*.
  static double _envelopeSimilarity(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    if (n < 2) return 0;
    double ma = 0, mb = 0;
    for (int i = 0; i < n; i++) {
      ma += a[i];
      mb += b[i];
    }
    ma /= n;
    mb /= n;
    double num = 0, da = 0, db = 0;
    for (int i = 0; i < n; i++) {
      final x = a[i] - ma, y = b[i] - mb;
      num += x * y;
      da += x * x;
      db += y * y;
    }
    final den = math.sqrt(da * db);
    if (den <= 0) return 0;
    return ((num / den) + 1) / 2;
  }

  /// Est-ce que ça monte ou descend dans le même sens ?
  static double _slopeAgreement(double a, double b) {
    if (a.abs() < 0.05 && b.abs() < 0.05) return 1; // les deux stables
    if (a == 0 || b == 0) return 0.5;
    return a.sign == b.sign ? 1 : 0;
  }

  /// Score en pourcentage, à la décimale près.
  ///
  /// Une décimale et pas plus : au-delà on afficherait une précision que la
  /// mesure n'a pas. C'est un **indice de similarité**, pas une probabilité —
  /// ce qu'il faut lire, c'est l'écart entre deux joueurs, pas la valeur
  /// absolue.
  static double _pct(double v) => (v.clamp(0.0, 1.0) * 1000).round() / 10;
}
