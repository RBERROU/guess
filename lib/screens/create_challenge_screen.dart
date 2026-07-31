import 'package:flutter/material.dart';

import '../main.dart';
import '../models/challenge.dart';
import '../services/cloud_service.dart';
import '../services/recording_service.dart';
import '../widgets/record_button.dart';

/// Créer un défi : enregistrer son pet, puis remplir les quatre indices.
///
/// Les indices ne sont pas décoratifs — ce sont exactement les axes sur
/// lesquels les tentatives seront notées. On note les gens sur ce qu'on leur
/// a dit, c'est ce qui rend le classement défendable.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _rec = RecordingService();
  final _cloud = CloudService();
  final _contextCtrl = TextEditingController();

  bool _recording = false;
  bool _sending = false;
  Recorded? _taken;
  String? _error;

  DurationHint _duration = DurationHint.moyen;
  TextureHint _texture = TextureHint.sec;
  RhythmHint _rhythm = RhythmHint.continu;
  PitchHint _pitch = PitchHint.grave;

  @override
  void dispose() {
    _rec.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_recording) return;
    final blocked = RecordingService.blockedReason;
    if (blocked != null) {
      setState(() => _error = blocked);
      return;
    }
    if (!await _rec.hasPermission()) {
      setState(() => _error =
          'Le micro est refusé. Autorise-le dans les réglages du navigateur, '
          'puis recharge la page.');
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
    // La durée mesurée alimente une proposition d'indice, que l'auteur peut
    // corriger : c'est lui qui sait, pas le chronomètre.
    if (r != null) {
      final s = (r.fingerprint?.durationSec ?? r.durationMs / 1000);
      setState(() {
        _duration = s < 1.0
            ? DurationHint.court
            : (s > 2.5 ? DurationHint.long : DurationHint.moyen);
      });
    }
  }

  Future<void> _publish() async {
    final t = _taken;
    if (t == null || t.fingerprint == null) {
      setState(() => _error = 'Enregistrement inexploitable, refais-en un.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _cloud.createChallenge(
        groupCode: AppConfig.groupCode,
        revealAt: DateTime.now().add(AppConfig.defaultWindow),
        durationHint: _duration,
        textureHint: _texture,
        rhythmHint: _rhythm,
        pitchHint: _pitch,
        context: _contextCtrl.text.trim().isEmpty ? null : _contextCtrl.text.trim(),
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
    final hasTake = _taken?.fingerprint != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Lancer un défi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SizedBox(height: 12),
          Center(
            child: RecordButton(
              recording: _recording,
              onStart: _start,
              onStop: _stop,
              idleLabel: hasTake
                  ? 'Maintiens pour refaire'
                  : 'Maintiens pour enregistrer ton pet',
            ),
          ),
          if (hasTake) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Capté : ${_taken!.fingerprint!.durationSec.toStringAsFixed(1)} s',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text('Les indices', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'C\'est tout ce que tes potes auront pour t\'imiter — '
            'et ce sur quoi ils seront notés.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _HintRow<DurationHint>(
            title: 'Durée',
            values: DurationHint.values,
            selected: _duration,
            onChanged: (v) => setState(() => _duration = v),
          ),
          _HintRow<TextureHint>(
            title: 'Texture',
            values: TextureHint.values,
            selected: _texture,
            onChanged: (v) => setState(() => _texture = v),
          ),
          _HintRow<RhythmHint>(
            title: 'Rythme',
            values: RhythmHint.values,
            selected: _rhythm,
            onChanged: (v) => setState(() => _rhythm = v),
          ),
          _HintRow<PitchHint>(
            title: 'Hauteur',
            values: PitchHint.values,
            selected: _pitch,
            onChanged: (v) => setState(() => _pitch = v),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _contextCtrl,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Le contexte (facultatif)',
              hintText: 'Au réveil, à jeun, après un kebab...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: (!hasTake || _sending) ? null : _publish,
            child: _sending
                ? const SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publier le défi'),
          ),
          const SizedBox(height: 10),
          Text(
            'Personne ne pourra l\'écouter avant que tout le monde ait soumis. '
            'Révélation automatique dans ${AppConfig.defaultWindow.inHours} h.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HintRow<T extends Enum> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  const _HintRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: values
                .map((v) => ChoiceChip(
                      label: Text(v.label),
                      selected: v == selected,
                      onSelected: (_) => onChanged(v),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
