import 'dart:typed_data';

/// Version web : il n'y a pas de système de fichiers. `record` renvoie une
/// blob URL, que RecordingService lit par HTTP — ces fonctions ne sont donc
/// jamais appelées sur le web.
Future<Uint8List?> readLocalFile(String path) async => null;

Future<void> writeLocalFile(String path, Uint8List bytes) async {}
