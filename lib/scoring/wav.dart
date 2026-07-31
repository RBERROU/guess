import 'dart:typed_data';

/// Un enregistrement décodé : échantillons mono, normalisés entre -1 et 1.
class Pcm {
  final Float64List samples;
  final int sampleRate;
  const Pcm(this.samples, this.sampleRate);

  double get durationSec => samples.length / sampleRate;
}

/// Lecture d'un WAV PCM 16 bits (ce que produit l'enregistreur de l'app).
/// On parcourt les chunks plutôt que de supposer un en-tête de 44 octets :
/// certains encodeurs insèrent des chunks LIST ou fact avant les données.
class WavReader {
  static Pcm decode(Uint8List bytes) {
    if (bytes.length < 12) {
      throw const FormatException('fichier trop court');
    }
    final bd = ByteData.sublistView(bytes);
    if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') {
      throw const FormatException('ce n\'est pas un WAV');
    }

    int channels = 1, sampleRate = 44100, bits = 16;
    int dataOffset = -1, dataLength = 0;

    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final id = _tag(bytes, pos);
      final size = bd.getUint32(pos + 4, Endian.little);
      final body = pos + 8;
      if (id == 'fmt ') {
        channels = bd.getUint16(body + 2, Endian.little);
        sampleRate = bd.getUint32(body + 4, Endian.little);
        bits = bd.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = body;
        dataLength = size;
        // On ne s'arrête pas : certains fichiers annoncent une taille de 0
        // et il faut alors prendre tout ce qui reste.
        if (dataLength == 0 || body + dataLength > bytes.length) {
          dataLength = bytes.length - body;
        }
        break;
      }
      pos = body + size + (size.isOdd ? 1 : 0); // les chunks sont alignés
    }

    if (dataOffset < 0) throw const FormatException('aucun chunk data');
    if (bits != 16) throw FormatException('seul le PCM 16 bits est géré (reçu $bits)');

    final frames = dataLength ~/ (2 * channels);
    final out = Float64List(frames);
    for (int i = 0; i < frames; i++) {
      // Mixage mono par moyenne des canaux
      double acc = 0;
      for (int c = 0; c < channels; c++) {
        acc += bd.getInt16(dataOffset + (i * channels + c) * 2, Endian.little) / 32768.0;
      }
      out[i] = acc / channels;
    }
    return Pcm(out, sampleRate);
  }

  static String _tag(Uint8List b, int at) =>
      String.fromCharCodes(b.sublist(at, at + 4));
}
