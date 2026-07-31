import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readLocalFile(String path) async {
  final f = File(path);
  if (!await f.exists()) return null;
  return await f.readAsBytes();
}
