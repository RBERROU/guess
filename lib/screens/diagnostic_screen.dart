import 'package:flutter/material.dart';

import '../services/recording_service.dart';
import '../theme/app_theme.dart';

/// Ce que le navigateur expose vraiment.
///
/// Existe parce que la capture audio échoue de façons très différentes selon
/// le navigateur, et qu'on ne peut pas déboguer un appareil qu'on n'a pas sous
/// la main. Cet écran remplace les allers-retours par un constat.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final _rec = RecordingService();
  Map<String, String> _info = {};
  bool _loading = true;
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rec.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final info = await _rec.diagnostics();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  /// Enregistre deux secondes et rend compte de ce qui est réellement sorti :
  /// c'est la seule preuve qui vaille, le reste n'est que déclaratif.
  Future<void> _testRecording() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await _rec.start();
      await Future.delayed(const Duration(seconds: 2));
      final r = await _rec.stop();
      if (!mounted) return;
      if (r == null) {
        setState(() => _testResult =
            'Échec : rien n\'a été capté. ${_rec.lastError ?? ""}');
      } else {
        final fp = r.fingerprint;
        setState(() => _testResult = fp == null
            ? 'Audio capté (${(r.bytes.length / 1024).toStringAsFixed(0)} Ko) '
                'mais NON analysable — le format n\'est pas du PCM.'
            : 'OK : ${(r.bytes.length / 1024).toStringAsFixed(0)} Ko, '
                '${fp.durationSec.toStringAsFixed(2)} s utiles, '
                '${fp.burstRate.toStringAsFixed(1)} bouffées/s, '
                'hauteur ${fp.pitchHz.toStringAsFixed(0)} Hz.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = 'Erreur : $e');
    } finally {
      if (mounted) {
        setState(() => _testing = false);
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const Text(
                  'À montrer si l\'enregistrement ne marche pas sur un appareil.',
                  style: TextStyle(color: AppTheme.muted, height: 1.35),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (final e in _info.entries)
                        _Line(
                          label: e.key,
                          value: e.value,
                          alarming: e.value.contains('NON') ||
                              e.value.contains('REFUS') ||
                              e.value.startsWith('erreur'),
                          last: e.key == _info.keys.last,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _testing ? null : _testRecording,
                  child: _testing
                      ? const Text('Enregistrement de 2 secondes…')
                      : const Text('Tester le micro (2 s)'),
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        height: 1.4,
                        color: _testResult!.startsWith('OK')
                            ? AppTheme.tGreen
                            : AppTheme.tRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool alarming;
  final bool last;

  const _Line({
    required this.label,
    required this.value,
    required this.alarming,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.line, width: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(fontSize: 14.5, color: AppTheme.ink)),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: alarming ? FontWeight.w700 : FontWeight.w500,
                color: alarming ? AppTheme.tRed : AppTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
