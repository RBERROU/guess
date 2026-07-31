// Banc d'essai hors application : vérifie que l'empreinte et le score
// tournent sur de vrais fichiers et qu'ils DISCRIMINENT.
//
//   dart run tool/bench.dart <cible.wav> <candidat.wav> [candidat2.wav ...]
//
// Le premier fichier est la cible, les suivants sont classés contre elle.
import 'dart:io';

import '../lib/scoring/fingerprint.dart';
import '../lib/scoring/matcher.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/bench.dart <cible.wav> <candidat.wav> ...');
    exit(64);
  }

  final target = Fingerprint.fromWav(File(args.first).readAsBytesSync());
  print('CIBLE  ${_name(args.first)}');
  _describe(target);
  print('');

  final attempts = <String, Fingerprint>{};
  for (final p in args.skip(1)) {
    attempts[_name(p)] = Fingerprint.fromWav(File(p).readAsBytesSync());
  }

  final ranked = Matcher.rank(target, attempts);
  print('CLASSEMENT');
  print('  ${'candidat'.padRight(26)} total  durée rythme hauteur texture');
  for (var i = 0; i < ranked.length; i++) {
    final e = ranked[i];
    final s = e.value;
    print('  ${(i + 1)}. ${e.key.padRight(23)} '
        '${_f(s.total)} ${_f(s.duration)} ${_f(s.rhythm)} '
        '${_f(s.pitch)}  ${_f(s.texture)}');
  }
}

void _describe(Fingerprint f) {
  print('  durée ${f.durationSec.toStringAsFixed(2)} s  '
      'bouffées/s ${f.burstRate.toStringAsFixed(2)}  '
      'centroïde ${f.centroidHz.toStringAsFixed(0)} Hz  '
      'hauteur ${f.pitchHz.toStringAsFixed(0)} Hz  '
      'souffle ${f.noisiness.toStringAsFixed(2)}');
}

String _f(double v) => v.toStringAsFixed(1).padLeft(5);
String _name(String p) => p.split(RegExp(r'[\\/]')).last.replaceAll('.wav', '');
