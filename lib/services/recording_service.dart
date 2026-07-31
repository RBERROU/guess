import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../scoring/fingerprint.dart';
import 'file_io_stub.dart' if (dart.library.io) 'file_io_native.dart';

/// Capture audio **en WAV**, et non en AAC comme Just Fart.
///
/// C'est un choix structurant : le WAV donne accès aux échantillons bruts,
/// donc l'app calcule l'empreinte elle-même, et on garde l'audio source pour
/// recalculer d'autres caractéristiques plus tard sans redemander aux joueurs
/// de réenregistrer.
///
/// 22 050 Hz mono suffit : tout ce qui caractérise un pet ou un bruit de
/// bouche vit sous 10 kHz, et ça divise le poids des fichiers par quatre par
/// rapport à du 44,1 kHz stéréo.
class RecordingService {
  static const int sampleRate = 22050;

  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  Stopwatch? _stopwatch;

  Future<bool> hasPermission() => _recorder.hasPermission();
  Future<bool> isRecording() => _recorder.isRecording();

  /// Niveau du micro, pour animer le bouton pendant l'enregistrement.
  Stream<Amplitude> amplitude() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  Future<void> start() async {
    var path = '';
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/gmf_${_uuid.v4()}.wav';
    }
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
      path: path,
    );
    _stopwatch = Stopwatch()..start();
  }

  /// Arrête, relit les octets et calcule l'empreinte dans la foulée.
  /// Renvoie `null` si rien n'a été capturé.
  Future<Recorded?> stop() async {
    final path = await _recorder.stop();
    final elapsed = _stopwatch?.elapsedMilliseconds ?? 0;
    _stopwatch?.stop();
    _stopwatch = null;
    if (path == null) return null;

    final bytes = await _read(path);
    if (bytes == null || bytes.isEmpty) return null;

    Fingerprint? print;
    try {
      print = Fingerprint.fromWav(bytes);
    } catch (_) {
      // Un encodeur exotique ne doit pas faire perdre l'enregistrement :
      // on renvoie l'audio quand même, l'empreinte sera recalculée plus tard.
      print = null;
    }
    return Recorded(
      path: path,
      bytes: bytes,
      durationMs: elapsed,
      fingerprint: print,
    );
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _stopwatch = null;
  }

  /// Sur le web, `record` renvoie une blob URL qu'il faut lire par HTTP ;
  /// ailleurs, c'est un vrai chemin de fichier.
  Future<Uint8List?> _read(String path) async {
    try {
      if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
        final r = await http.get(Uri.parse(path));
        return r.statusCode == 200 ? r.bodyBytes : null;
      }
      return await readLocalFile(path);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _recorder.dispose();
}

class Recorded {
  final String path;
  final Uint8List bytes;
  final int durationMs;

  /// `null` seulement si le décodage a échoué — l'app reste utilisable.
  final Fingerprint? fingerprint;

  const Recorded({
    required this.path,
    required this.bytes,
    required this.durationMs,
    required this.fingerprint,
  });
}
