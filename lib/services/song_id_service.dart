import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_settings.dart';

/// Resultado de reconocer la canción: (artista, título) o un motivo.
class SongIdResult {
  final String artist;
  final String title;
  final String error; // '' si salió bien
  const SongIdResult(this.artist, this.title, [this.error = '']);
  bool get ok => error.isEmpty && artist.isNotEmpty && title.isNotEmpty;
}

/// «¿Qué suena?» para la radio: graba ~10 s directamente de la transmisión
/// (no usa el micrófono) y los manda a AudD para reconocer la canción.
class SongIdService {
  SongIdService._();

  static Future<bool> hasKey() async {
    await AiSettings.instance.load();
    return AiSettings.instance.auddKey.trim().isNotEmpty;
  }

  static Future<SongIdResult> identify(String streamUrl) async {
    await AiSettings.instance.load();
    final key = AiSettings.instance.auddKey.trim();
    if (key.isEmpty) return const SongIdResult('', '', 'sin clave');
    Uint8List? clip;
    try {
      clip = await _clip(streamUrl);
    } catch (_) {}
    if (clip == null || clip.length < 40000) {
      return const SongIdResult('', '', 'No pude grabar la emisora.');
    }
    try {
      final req = http.MultipartRequest('POST', Uri.parse('https://api.audd.io/'))
        ..fields['api_token'] = key
        ..files.add(http.MultipartFile.fromBytes('file', clip, filename: 'radio.mp3'));
      final res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 25)));
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['status'] == 'error') {
        final code = (j['error'] as Map?)?['error_code'];
        if (code == 900 || code == 901) {
          return const SongIdResult('', '', 'La clave de AudD no es válida.');
        }
        if (code == 902) {
          return const SongIdResult('', '', 'Se acabaron los reconocimientos de AudD.');
        }
        return SongIdResult('', '', 'AudD: ${(j['error'] as Map?)?['error_message'] ?? 'error'}');
      }
      final r = j['result'];
      if (r is! Map) {
        return const SongIdResult('', '', 'No la reconocí (¿locutor o comerciales?).');
      }
      return SongIdResult('${r['artist'] ?? ''}'.trim(), '${r['title'] ?? ''}'.trim());
    } catch (_) {
      return const SongIdResult('', '', 'Sin conexión con AudD.');
    }
  }

  /// ~10 s de audio de la emisora (≈ 200 KB). Si es HLS (.m3u8), baja un
  /// segmento.
  static Future<Uint8List?> _clip(String url) async {
    final c = http.Client();
    try {
      var u = Uri.parse(url);
      // Listas .m3u/.pls: la primera URL de dentro.
      if (RegExp(r'\.(m3u8?|pls)(\?|$)', caseSensitive: false).hasMatch(u.path) ||
          url.toLowerCase().contains('.m3u')) {
        final body = (await c.get(u).timeout(const Duration(seconds: 8))).body;
        final lines = body
            .split(RegExp(r'\r?\n'))
            .map((l) => l.replaceFirst(RegExp(r'^File\d+='), '').trim())
            .where((l) => l.isNotEmpty && !l.startsWith('#') && !l.startsWith('['))
            .toList();
        if (lines.isEmpty) return null;
        final inner = u.resolve(lines.last);
        // HLS: la lista de segmentos puede estar un nivel más adentro.
        if (inner.path.toLowerCase().endsWith('.m3u8')) {
          return _clip(inner.toString());
        }
        if (url.toLowerCase().contains('.m3u8')) {
          // Segmento .ts/.aac: se baja entero.
          final seg = await c.get(inner).timeout(const Duration(seconds: 12));
          return seg.bodyBytes;
        }
        u = inner;
      }
      final req = http.Request('GET', u)..headers['User-Agent'] = 'RockPlay personal app';
      final resp = await c.send(req).timeout(const Duration(seconds: 10));
      final out = BytesBuilder();
      final done = Completer<void>();
      final stop = DateTime.now().add(const Duration(seconds: 14));
      late StreamSubscription<List<int>> sub;
      sub = resp.stream.listen((chunk) {
        out.add(chunk);
        if (out.length >= 220000 || DateTime.now().isAfter(stop)) {
          sub.cancel();
          if (!done.isCompleted) done.complete();
        }
      }, onDone: () {
        if (!done.isCompleted) done.complete();
      }, onError: (_) {
        if (!done.isCompleted) done.complete();
      });
      await done.future.timeout(const Duration(seconds: 16), onTimeout: () => sub.cancel());
      return out.takeBytes();
    } finally {
      c.close();
    }
  }
}
