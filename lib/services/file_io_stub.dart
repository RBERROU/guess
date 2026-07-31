import 'dart:typed_data';

/// Version web : il n'y a pas de système de fichiers. `record` renvoie une
/// blob URL, que RecordingService lit par HTTP — cette fonction n'est donc
/// jamais appelée sur le web.
Future<Uint8List?> readLocalFile(String path) async => null;
