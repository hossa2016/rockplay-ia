import 'package:flutter/material.dart';

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

  Widget _keyField(String label, TextEditingController c, bool hide,
      VoidCallback toggle, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: c,
        obscureText: hide,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
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
                  'El asistente usa Groq primero y Gemini si Groq falla. Si no hay '
                  'ninguna clave o se acaba el límite gratuito, usa reglas simples. '
                  'Las claves se guardan solo en este teléfono.',
                  style: TextStyle(color: AppColors.textDim, height: 1.45),
                ),
                const SizedBox(height: 20),
                _keyField('Clave de Groq', _groq, _hideGroq,
                    () => setState(() => _hideGroq = !_hideGroq), 'gsk_…'),
                const Text(
                  'Se crea gratis en console.groq.com → API Keys → Create API Key.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                _keyField('Clave de Gemini', _gemini, _hideGemini,
                    () => setState(() => _hideGemini = !_hideGemini), 'AIza…'),
                const Text(
                  'Se crea gratis en aistudio.google.com → Get API key.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                ),
                const SizedBox(height: 20),
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
