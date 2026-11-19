import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_settings.dart';
import '../theme/app_theme.dart';

/// Claves gratuitas de Groq y Gemini. Se guardan solo en este teléfono.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final AiSettings _s = AiSettings.instance;
  final TextEditingController _groq = TextEditingController();
  final TextEditingController _gemini = TextEditingController();
  final TextEditingController _groqModel = TextEditingController();
  final TextEditingController _geminiModel = TextEditingController();
  bool _hideGroq = true;
  bool _hideGemini = true;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _s.load();
    _groq.text = _s.groqKey;
    _gemini.text = _s.geminiKey;
    _groqModel.text = _s.groqModel;
    _geminiModel.text = _s.geminiModel;
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _groq.dispose();
    _gemini.dispose();
    _groqModel.dispose();
    _geminiModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _s.groqKey = _groq.text;
    _s.geminiKey = _gemini.text;
    _s.groqModel = _groqModel.text;
    _s.geminiModel = _geminiModel.text;
    await _s.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Guardado en tu teléfono.')));
    Navigator.of(context).pop();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _paste(TextEditingController c) async {
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final t = (d?.text ?? '').trim();
      if (t.isEmpty) return;
      setState(() => c.text = t);
    } catch (_) {}
  }

  /// Tarjeta de una clave: estado, pasos, abrir página, pegar y campo.
  Widget _keyCard({
    required String name,
    required String subtitle,
    required String url,
    required String steps,
    required TextEditingController c,
    required bool hide,
    required VoidCallback toggle,
    required String hint,
  }) {
    final has = c.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: has
                      ? const Color.fromRGBO(255, 176, 46, 0.16)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(has ? 'Clave puesta' : 'Falta la clave',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: has ? AppColors.amber : AppColors.textDim)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          const SizedBox(height: 12),
          Text(steps,
              style: const TextStyle(fontSize: 13, height: 1.45)),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _open(url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir la página'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            obscureText: hide,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Pega aquí tu clave',
              hintText: hint,
              suffixIcon: IconButton(
                tooltip: hide ? 'Mostrar' : 'Ocultar',
                icon: Icon(hide
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: toggle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextButton.icon(
              onPressed: () => _paste(c),
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Pegar desde el portapapeles'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claves del asistente')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'El asistente usa primero Gemini y, si falla o se acaba el '
                  'límite gratis, usa Groq. Sin ninguna clave usa reglas simples. '
                  'Las claves se guardan solo en este teléfono.',
                  style: TextStyle(color: AppColors.textDim, height: 1.45),
                ),
                const SizedBox(height: 16),
                _keyCard(
                  name: 'Gemini (Google)',
                  subtitle: 'La principal. Gratis.',
                  url: 'https://aistudio.google.com/apikey',
                  steps:
                      '1. Toca «Abrir la página» e inicia sesión con Google.\n'
                      '2. Toca «Create API key» y copia la clave.\n'
                      '3. Vuelve aquí y toca «Pegar».',
                  c: _gemini,
                  hide: _hideGemini,
                  toggle: () => setState(() => _hideGemini = !_hideGemini),
                  hint: 'AIza…',
                ),
                _keyCard(
                  name: 'Groq',
                  subtitle: 'De respaldo. Gratis.',
                  url: 'https://console.groq.com/keys',
                  steps:
                      '1. Toca «Abrir la página» y crea tu cuenta.\n'
                      '2. Toca «Create API Key» y copia la clave.\n'
                      '3. Vuelve aquí y toca «Pegar».',
                  c: _groq,
                  hide: _hideGroq,
                  toggle: () => setState(() => _hideGroq = !_hideGroq),
                  hint: 'gsk_…',
                ),
                const SizedBox(height: 6),
                const Text('Canciones por lista',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Máximo de canciones que trae el asistente. Menos canciones = respuesta más rápida y menos gasto de tu cuota gratis.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in AiSettings.maxOptions)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: AiSettings.instance.maxSongs == n,
                        onSelected: (_) {
                          setState(() => AiSettings.instance.maxSongs = n);
                          AiSettings.instance.save();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Avanzado: modelos'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _groqModel,
                        autocorrect: false,
                        decoration:
                            const InputDecoration(labelText: 'Modelo de Groq'),
                      ),
                    ),
                    TextField(
                      controller: _geminiModel,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(labelText: 'Modelo de Gemini'),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Si un modelo deja de existir, el asistente avisa '
                        '"modelo no encontrado". Cámbialo aquí por otro.',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: const Text('Guardar')),
              ],
            ),
    );
  }
}
