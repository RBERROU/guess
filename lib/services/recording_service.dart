import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'dart:async';

import '../scoring/fingerprint.dart';
import '../scoring/wav.dart';
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

  /// Les navigateurs n'exposent le micro que sur une origine sûre : HTTPS, ou
  /// localhost. Sur une adresse en `http://` ou une IP locale, l'API micro
  /// n'existe tout simplement pas — et l'erreur remontée ressemble à un refus
  /// de permission, ce qui envoie chercher au mauvais endroit.
  static bool get isSecureContext {
    if (!kIsWeb) return true;
    final u = Uri.base;
    return u.scheme == 'https' ||
        u.host == 'localhost' ||
        u.host == '127.0.0.1';
  }

  /// Message précis quand la capture est impossible, `null` si tout va bien.
  static String? get blockedReason {
    if (!isSecureContext) {
      return 'Ton navigateur bloque le micro parce que la page n\'est pas en '
          'HTTPS (adresse actuelle : ${Uri.base.host}). Ouvre le site avec une '
          'adresse commençant par https://';
    }
    return null;
  }

  Future<bool> hasPermission() => _recorder.hasPermission();
  Future<bool> isRecording() => _recorder.isRecording();

  /// Niveau du micro, pour animer le bouton pendant l'enregistrement.
  Stream<Amplitude> amplitude() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  StreamSubscription<Uint8List>? _sub;
  final List<int> _pcm = [];
  bool _streaming = false;
  String _filePath = '';

  /// On capte le **flux PCM brut** plutôt qu'un fichier encodé.
  ///
  /// Selon la plateforme et le navigateur, l'enregistreur produit du AAC, de
  /// l'Opus ou du WAV — et aucun de ces formats compressés n'est décodable en
  /// Dart pur. En partant du PCM et en écrivant l'en-tête WAV nous-mêmes,
  /// l'analyse fonctionne partout, Safari compris.
  ///
  /// Repli sur l'enregistrement fichier si le flux n'est pas disponible.
  Future<void> start() async {
    _pcm.clear();
    _streaming = false;
    _filePath = '';
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );
      _streaming = true;
      _sub = stream.listen(_pcm.addAll);
    } catch (_) {
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
      _filePath = path;
    }
    _stopwatch = Stopwatch()..start();
  }

  /// Arrête, relit les octets et calcule l'empreinte dans la foulée.
  /// Renvoie `null` si rien n'a été capturé.
  Future<Recorded?> stop() async {
    final path = await _recorder.stop();
    final elapsed = _stopwatch?.elapsedMilliseconds ?? 0;
    _stopwatch?.stop();
    _stopwatch = null;

    Uint8List? bytes;
    String outPath = path ?? _filePath;

    if (_streaming) {
      await _sub?.cancel();
      _sub = null;
      _streaming = false;
      if (_pcm.isEmpty) return null;
      bytes = WavWriter.fromPcm16(
        Uint8List.fromList(_pcm),
        sampleRate: sampleRate,
      );
      _pcm.clear();
      // Sur mobile, on écrit le WAV pour pouvoir le réécouter avant envoi.
      if (!kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          outPath = '${dir.path}/gmf_${_uuid.v4()}.wav';
          await writeLocalFile(outPath, bytes);
        } catch (_) {
          outPath = '';
        }
      }
    } else {
      if (path == null) return null;
      bytes = await _read(path);
    }

    if (bytes == null || bytes.isEmpty) return null;
    final resolvedPath = outPath;

    Fingerprint? print;
    try {
      print = Fingerprint.fromWav(bytes);
    } catch (_) {
      // Un encodeur exotique ne doit pas faire perdre l'enregistrement :
      // on renvoie l'audio quand même, l'empreinte sera recalculée plus tard.
      print = null;
    }
    return Recorded(
      path: resolvedPath,
      bytes: bytes,
      durationMs: elapsed,
      fingerprint: print,
    );
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    _streaming = false;
    _pcm.clear();
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
