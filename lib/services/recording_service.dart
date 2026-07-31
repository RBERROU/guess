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

  /// Dernière erreur rencontrée au démarrage, pour l'écran de diagnostic.
  String? lastError;

  /// Il faut du **PCM décodable en Dart pur** : ni AAC ni Opus ne le sont, et
  /// c'est eux que produisent la plupart des navigateurs par défaut.
  ///
  /// On essaie donc, dans l'ordre : enregistrement fichier en WAV s'il est
  /// annoncé supporté (le chemin le plus éprouvé), puis capture du flux PCM
  /// brut dont on écrit l'en-tête nous-mêmes, puis en dernier recours
  /// n'importe quel format — l'audio est alors conservé mais non analysable,
  /// ce que l'interface signale plutôt que d'échouer en silence.
  Future<void> start() async {
    _pcm.clear();
    _streaming = false;
    _filePath = '';
    lastError = null;

    if (await _trySupported(AudioEncoder.wav)) {
      _stopwatch = Stopwatch()..start();
      return;
    }
    if (await _tryStream()) {
      _stopwatch = Stopwatch()..start();
      return;
    }
    for (final e in [AudioEncoder.pcm16bits, AudioEncoder.aacLc, AudioEncoder.opus]) {
      if (await _trySupported(e)) {
        _stopwatch = Stopwatch()..start();
        return;
      }
    }
    throw StateError(lastError ?? 'aucun format d\'enregistrement disponible');
  }

  Future<bool> _trySupported(AudioEncoder encoder) async {
    try {
      if (!await _recorder.isEncoderSupported(encoder)) return false;
      var path = '';
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/gmf_${_uuid.v4()}.${encoder == AudioEncoder.wav ? "wav" : "bin"}';
      }
      await _recorder.start(
        RecordConfig(encoder: encoder, sampleRate: sampleRate, numChannels: 1),
        path: path,
      );
      _filePath = path;
      return true;
    } catch (e) {
      lastError = '$encoder : $e';
      return false;
    }
  }

  Future<bool> _tryStream() async {
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );
      _streaming = true;
      _sub = stream.listen(_pcm.addAll, onError: (Object e) {
        lastError = 'flux : $e';
      });
      return true;
    } catch (e) {
      lastError = 'flux : $e';
      _streaming = false;
      return false;
    }
  }

  /// Ce que le navigateur expose réellement. Sert à trancher sans deviner
  /// quand la capture échoue sur un appareil qu'on n'a pas sous la main.
  Future<Map<String, String>> diagnostics() async {
    final out = <String, String>{
      'Adresse': '${Uri.base.scheme}://${Uri.base.host}',
      'Connexion sécurisée': isSecureContext ? 'oui' : 'NON — micro bloqué',
      'Plateforme': kIsWeb ? 'navigateur' : 'application native',
    };
    try {
      out['Permission micro'] =
          await _recorder.hasPermission() ? 'accordée' : 'REFUSÉE';
    } catch (e) {
      out['Permission micro'] = 'erreur : $e';
    }
    for (final e in [
      AudioEncoder.wav,
      AudioEncoder.pcm16bits,
      AudioEncoder.aacLc,
      AudioEncoder.opus,
    ]) {
      final name = e.name;
      try {
        out['Format $name'] =
            await _recorder.isEncoderSupported(e) ? 'supporté' : 'non supporté';
      } catch (err) {
        out['Format $name'] = 'erreur : $err';
      }
    }
    if (lastError != null) out['Dernière erreur'] = lastError!;
    return out;
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
