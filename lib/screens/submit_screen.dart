import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../services/cloud_service.dart';
import '../services/player_service.dart';
import '../services/recording_service.dart';
import '../widgets/record_button.dart';

/// Soumettre son imitation, **à l'aveugle**. Le pet n'est pas jouable ici :
/// la base refuse de servir le fichier avant la révélation, ce n'est pas
/// l'interface qui le cache.
class SubmitScreen extends StatefulWidget {
  final Challenge challenge;
  const SubmitScreen({super.key, required this.challenge});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _rec = RecordingService();
  final _cloud = CloudService();
  final _player = PlayerService();

  bool _recording = false;
  bool _sending = false;
  Recorded? _taken;
  String? _error;

  @override
  void dispose() {
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_recording) return;
    if (!await _rec.hasPermission()) {
      setState(() => _error = 'Le micro est refusé. Autorise-le dans les réglages.');
      return;
    }
    setState(() {
      _error = null;
      _recording = true;
    });
    await _rec.start();
  }

  Future<void> _stop() async {
    if (!_recording) return;
    final r = await _rec.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _taken = r;
      if (r == null) _error = 'Rien n\'a été capté, réessaie.';
    });
  }

  Future<void> _send() async {
    final t = _taken;
    if (t == null || t.fingerprint == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _cloud.submit(
        challengeId: widget.challenge.id,
        wav: t.bytes,
        fingerprint: t.fingerprint!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Envoi impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final hasTake = _taken?.fingerprint != null;

    return Scaffold(
      appBar: AppBar(title: Text('Imite ${c.authorPseudo ?? "le défi"}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tes seuls indices',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _Line('Durée', c.durationHint.label),
                  _Line('Texture', c.textureHint.label),
                  _Line('Rythme', c.rhythmHint.label),
                  _Line('Hauteur', c.pitchHint.label),
                  if (c.context != null && c.context!.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(c.context!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tu ne peux pas l\'écouter avant d\'avoir soumis — c\'est tout '
            'l\'intérêt. Fais le bruit avec ta bouche.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Center(
            child: RecordButton(
              recording: _recording,
              onStart: _start,
              onStop: _stop,
              idleLabel: hasTake
                  ? 'Maintiens pour refaire'
                  : 'Maintiens pour t\'enregistrer',
            ),
          ),
          if (hasTake) ...[
            const SizedBox(height: 18),
            Center(
              child: TextButton.icon(
                onPressed: () => _player.playFile(_taken!.path),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                    'Réécouter (${_taken!.fingerprint!.durationSec.toStringAsFixed(1)} s)'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: (!hasTake || _sending) ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Envoyer ma tentative'),
          ),
          const SizedBox(height: 10),
          Text(
            'Une seule tentative par défi. Réfléchis bien.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
