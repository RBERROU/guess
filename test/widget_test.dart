import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guessmyfart/scoring/fingerprint.dart';
// `Matcher` existe aussi dans flutter_test : on préfixe pour lever l'ambiguïté.
import 'package:guessmyfart/scoring/matcher.dart' as scoring;
import 'package:guessmyfart/scoring/wav.dart';

/// Fabrique un WAV synthétique : une porteuse à `pitchHz` mêlée de bruit, le
/// tout haché à `burstHz`. Ça permet de tester la mesure sans dépendre de
/// fichiers audio réels.
Uint8List makeWav({
  required double seconds,
  required double pitchHz,
  required double burstHz,
  int sampleRate = 22050,
}) {
  final n = (seconds * sampleRate).round();
  final data = BytesBuilder();
  final rnd = math.Random(42);
  for (int i = 0; i < n; i++) {
    final t = i / sampleRate;
    final carrier = math.sin(2 * math.pi * pitchHz * t);
    final noise = (rnd.nextDouble() * 2 - 1) * 0.3;
    final gate = burstHz <= 0
        ? 1.0
        : (math.sin(2 * math.pi * burstHz * t) > 0 ? 1.0 : 0.05);
    final v =
        ((carrier * 0.7 + noise) * gate * 0.6 * 32767).clamp(-32768.0, 32767.0);
    final s = v.toInt();
    data.addByte(s & 0xFF);
    data.addByte((s >> 8) & 0xFF);
  }
  final pcm = data.toBytes();

  final header = ByteData(44);
  void tag(int off, String s) {
    for (int i = 0; i < 4; i++) {
      header.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}

void main() {
  test('le WAV se décode avec le bon débit et la bonne durée', () {
    final pcm = WavReader.decode(makeWav(seconds: 1.0, pitchHz: 120, burstHz: 0));
    expect(pcm.sampleRate, 22050);
    expect(pcm.durationSec, closeTo(1.0, 0.02));
  });

  test('un son comparé à lui-même donne le maximum', () {
    final f = Fingerprint.fromWav(makeWav(seconds: 1.5, pitchHz: 110, burstHz: 6));
    final s = scoring.Matcher.score(f, f);
    expect(s.total, closeTo(100, 0.1));
    expect(s.duration, closeTo(100, 0.1));
    expect(s.rhythm, closeTo(100, 0.1));
  });

  test('la mesure classe du plus proche au plus lointain', () {
    final target =
        Fingerprint.fromWav(makeWav(seconds: 1.5, pitchHz: 110, burstHz: 6));
    final proche =
        Fingerprint.fromWav(makeWav(seconds: 1.5, pitchHz: 118, burstHz: 6));
    final moyen =
        Fingerprint.fromWav(makeWav(seconds: 1.5, pitchHz: 180, burstHz: 11));
    final lointain =
        Fingerprint.fromWav(makeWav(seconds: 0.4, pitchHz: 420, burstHz: 0));

    final sProche = scoring.Matcher.score(target, proche).total;
    final sMoyen = scoring.Matcher.score(target, moyen).total;
    final sLointain = scoring.Matcher.score(target, lointain).total;

    expect(sProche, greaterThan(sMoyen));
    expect(sMoyen, greaterThan(sLointain));
  });

  test('la durée pèse : trois fois trop long est pénalisé', () {
    final court =
        Fingerprint.fromWav(makeWav(seconds: 1.0, pitchHz: 110, burstHz: 5));
    final long =
        Fingerprint.fromWav(makeWav(seconds: 3.0, pitchHz: 110, burstHz: 5));
    expect(scoring.Matcher.score(court, long).duration, lessThan(60));
  });
}
