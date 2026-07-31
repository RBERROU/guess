import 'package:audioplayers/audioplayers.dart';

/// Lecture audio. Un seul son à la fois : relancer coupe le précédent, ce qui
/// est le comportement attendu quand on compare des tentatives à la chaîne.
class PlayerService {
  final AudioPlayer _player = AudioPlayer();
  String? _current;

  String? get current => _current;
  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> playUrl(String url, {String? tag}) async {
    await _player.stop();
    _current = tag ?? url;
    await _player.play(UrlSource(url));
  }

  Future<void> playFile(String path, {String? tag}) async {
    await _player.stop();
    _current = tag ?? path;
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stop() async {
    await _player.stop();
    _current = null;
  }

  void dispose() => _player.dispose();
}
