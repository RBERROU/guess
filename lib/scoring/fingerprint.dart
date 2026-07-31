import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';
import 'wav.dart';

/// Empreinte d'un enregistrement : une vingtaine de nombres qui décrivent
/// ce qu'un humain reproduit réellement quand il imite un bruit.
///
/// Volontairement centrée sur la DURÉE, le RYTHME et la HAUTEUR — pas sur le
/// timbre fin, qu'aucun imitateur ne peut reproduire avec sa bouche. Une mesure
/// qui pèserait sur le timbre pénaliserait tout le monde à égalité et ne
/// classerait plus rien.
class Fingerprint {
  /// Version du calcul. À incrémenter si les caractéristiques changent, pour
  /// pouvoir distinguer les empreintes recalculables des anciennes.
  ///
  /// v2 : enveloppe passée de 16 à 32 points. Le doublement de résolution
  /// permet de distinguer deux rythmes proches, ce que 16 points lissaient.
  static const int version = 2;

  /// Durée utile en secondes, silences de début et de fin retirés.
  final double durationSec;

  /// Forme de l'enveloppe d'énergie, rééchantillonnée en 16 points et
  /// normalisée à son maximum. C'est l'attaque, le maintien, la chute.
  final List<double> envelope;

  /// Nombre de bouffées d'énergie par seconde — le côté saccadé « brap »
  /// contre le souffle continu. Le trait le plus caractéristique et le plus
  /// imitable.
  final double burstRate;

  /// Irrégularité de l'énergie (écart-type de l'enveloppe).
  final double envelopeRoughness;

  /// Centroïde spectral moyen en Hz : la brillance. Grave et sourd contre
  /// aigu et sec.
  final double centroidHz;

  /// Dérive du centroïde entre la première et la seconde moitié : le son
  /// s'éclaircit-il ou s'assombrit-il ?
  final double centroidSlope;

  /// Fréquence dominante dans la bande basse (50-500 Hz) : le bourdonnement.
  final double pitchHz;

  /// Dérive de cette fréquence sur la durée : ça monte ou ça descend.
  final double pitchSlope;

  /// Part de l'énergie hors de la bande dominante : souffle contre bourdon.
  final double noisiness;

  const Fingerprint({
    required this.durationSec,
    required this.envelope,
    required this.burstRate,
    required this.envelopeRoughness,
    required this.centroidHz,
    required this.centroidSlope,
    required this.pitchHz,
    required this.pitchSlope,
    required this.noisiness,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'duration': _r(durationSec),
        'envelope': envelope.map(_r).toList(),
        'burstRate': _r(burstRate),
        'envelopeRoughness': _r(envelopeRoughness),
        'centroidHz': _r(centroidHz),
        'centroidSlope': _r(centroidSlope),
        'pitchHz': _r(pitchHz),
        'pitchSlope': _r(pitchSlope),
        'noisiness': _r(noisiness),
      };

  /// Lecture **tolérante** : un champ absent ou d'un type inattendu donne une
  /// valeur neutre au lieu de faire tomber l'écran.
  ///
  /// Ce n'est pas de la complaisance : les empreintes vivent en base et leur
  /// format évoluera (voir `version`). Une ancienne empreinte, ou une écrite
  /// à la main, ne doit jamais empêcher d'afficher un classement.
  factory Fingerprint.fromJson(Map<String, dynamic> j) => Fingerprint(
        durationSec: _num(j['duration']),
        envelope: _list(j['envelope']),
        burstRate: _num(j['burstRate']),
        envelopeRoughness: _num(j['envelopeRoughness']),
        centroidHz: _num(j['centroidHz']),
        centroidSlope: _num(j['centroidSlope']),
        pitchHz: _num(j['pitchHz']),
        pitchSlope: _num(j['pitchSlope']),
        noisiness: _num(j['noisiness'], fallback: 1),
      );

  /// Une empreinte sans enveloppe ni durée n'est pas comparable : on peut
  /// l'afficher, mais la classer n'aurait aucun sens.
  bool get isUsable => durationSec > 0 && envelope.length >= 4;

  static double _num(dynamic v, {double fallback = 0}) =>
      v is num ? v.toDouble() : fallback;

  static List<double> _list(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e is num ? e.toDouble() : 0.0).toList();
  }

  static double _r(double v) => (v * 10000).roundToDouble() / 10000;

  // ---------------------------------------------------------------- calcul

  static const int _envPoints = 32;
  static const int _frame = 1024;
  static const int _hop = 128;   // pas plus fin : meilleure résolution temporelle

  static Fingerprint fromWav(Uint8List wavBytes) => fromPcm(WavReader.decode(wavBytes));

  static Fingerprint fromPcm(Pcm pcm) {
    final trimmed = _trimSilence(pcm.samples);
    final sr = pcm.sampleRate;
    if (trimmed.length < _frame * 2) {
      // Trop court pour analyser : on renvoie une empreinte plate plutôt que
      // de lancer une exception, l'app doit rester utilisable.
      return Fingerprint(
        durationSec: trimmed.length / sr,
        envelope: List.filled(_envPoints, 0),
        burstRate: 0, envelopeRoughness: 0, centroidHz: 0,
        centroidSlope: 0, pitchHz: 0, pitchSlope: 0, noisiness: 1,
      );
    }

    final frames = ((trimmed.length - _frame) ~/ _hop) + 1;
    final rms = Float64List(frames);
    final centroid = Float64List(frames);
    final peak = Float64List(frames);
    final noise = Float64List(frames);

    final win = Fft.hann(_frame);
    final buf = Float64List(_frame);
    final binHz = sr / _frame;

    for (int f = 0; f < frames; f++) {
      final off = f * _hop;
      double acc = 0;
      for (int i = 0; i < _frame; i++) {
        final s = trimmed[off + i];
        acc += s * s;
        buf[i] = s * win[i];
      }
      rms[f] = math.sqrt(acc / _frame);

      final mag = Fft.magnitudes(buf);
      double num = 0, den = 0, best = 0, bestHz = 0, total = 0;
      final loMax = math.min(mag.length - 1, (500 / binHz).floor());
      final loMin = math.max(1, (50 / binHz).floor());
      for (int b = 1; b < mag.length; b++) {
        final m = mag[b];
        final hz = b * binHz;
        num += hz * m;
        den += m;
        total += m;
        if (b >= loMin && b <= loMax && m > best) {
          best = m;
          bestHz = hz;
        }
      }
      centroid[f] = den > 0 ? num / den : 0;
      peak[f] = bestHz;
      // énergie hors de la bande dominante, +/- 1 bin autour du pic
      final around = best * 3;
      noise[f] = total > 0 ? math.max(0, (total - around) / total) : 1;
    }

    final maxRms = rms.reduce(math.max);
    final env = _resample(rms, _envPoints);
    if (maxRms > 0) {
      for (int i = 0; i < env.length; i++) {
        env[i] = env[i] / maxRms;
      }
    }

    // Pondération par l'énergie : la hauteur d'un passage silencieux n'a
    // aucun sens, il ne doit pas peser dans la moyenne.
    double wSum = 0, cSum = 0, pSum = 0, nSum = 0;
    for (int f = 0; f < frames; f++) {
      final w = rms[f];
      wSum += w;
      cSum += centroid[f] * w;
      pSum += peak[f] * w;
      nSum += noise[f] * w;
    }
    final centroidMean = wSum > 0 ? cSum / wSum : 0.0;
    final pitchMean = wSum > 0 ? pSum / wSum : 0.0;
    final noiseMean = wSum > 0 ? nSum / wSum : 1.0;

    final half = frames ~/ 2;
    final cA = _wmean(centroid, rms, 0, half), cB = _wmean(centroid, rms, half, frames);
    final pA = _wmean(peak, rms, 0, half), pB = _wmean(peak, rms, half, frames);

    return Fingerprint(
      durationSec: trimmed.length / sr,
      envelope: env,
      burstRate: _burstRate(rms, sr / _hop, maxRms),
      envelopeRoughness: _std(env),
      centroidHz: centroidMean,
      centroidSlope: cA > 0 ? (cB - cA) / cA : 0,
      pitchHz: pitchMean,
      pitchSlope: pA > 0 ? (pB - pA) / pA : 0,
      noisiness: noiseMean,
    );
  }

  /// Retire les silences en tête et en queue : sinon la durée mesurée dépend
  /// du temps de réaction du joueur sur le bouton, pas du son lui-même.
  static Float64List _trimSilence(Float64List x, {double relThreshold = 0.06}) {
    if (x.isEmpty) return x;
    double peak = 0;
    for (final s in x) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    if (peak == 0) return x;
    final thr = peak * relThreshold;
    int a = 0, b = x.length - 1;
    while (a < b && x[a].abs() < thr) {
      a++;
    }
    while (b > a && x[b].abs() < thr) {
      b--;
    }
    return Float64List.sublistView(x, a, b + 1);
  }

  /// Compte les bouffées d'énergie par seconde. Un pic doit dépasser 35 % du
  /// maximum et redescendre sous 20 % avant qu'on en compte un nouveau —
  /// l'hystérésis évite de compter dix fois le même souffle qui tremble.
  static double _burstRate(Float64List rms, double framesPerSec, double maxRms) {
    if (maxRms <= 0 || rms.length < 2) return 0;
    final hi = maxRms * 0.35, lo = maxRms * 0.20;
    int count = 0;
    bool inBurst = false;
    for (final v in rms) {
      if (!inBurst && v >= hi) {
        count++;
        inBurst = true;
      } else if (inBurst && v < lo) {
        inBurst = false;
      }
    }
    final sec = rms.length / framesPerSec;
    return sec > 0 ? count / sec : 0;
  }

  static Float64List _resample(Float64List x, int n) {
    final out = Float64List(n);
    if (x.isEmpty) return out;
    for (int i = 0; i < n; i++) {
      final a = (i * x.length / n).floor();
      final b = math.max(a + 1, ((i + 1) * x.length / n).floor());
      double acc = 0;
      int c = 0;
      for (int k = a; k < math.min(b, x.length); k++) {
        acc += x[k];
        c++;
      }
      out[i] = c > 0 ? acc / c : 0;
    }
    return out;
  }

  static double _wmean(Float64List v, Float64List w, int from, int to) {
    double s = 0, ws = 0;
    for (int i = from; i < to && i < v.length; i++) {
      s += v[i] * w[i];
      ws += w[i];
    }
    return ws > 0 ? s / ws : 0;
  }

  static double _std(List<double> v) {
    if (v.isEmpty) return 0;
    final m = v.reduce((a, b) => a + b) / v.length;
    double acc = 0;
    for (final x in v) {
      acc += (x - m) * (x - m);
    }
    return math.sqrt(acc / v.length);
  }
}
