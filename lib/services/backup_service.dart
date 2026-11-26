import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_settings.dart';
import 'stats_service.dart';

/// Copia de seguridad de todo lo tuyo (favoritas, listas, historial,
/// escuchas, emisoras, alarmas, ajustes y, si quieres, las claves de IA) en
/// un archivo .json que guardas donde quieras (Drive, WhatsApp, Archivos).
class BackupService {
  BackupService._();

  static const String _tag = 'rockplay-ia-backup';
  static const String _lastKey = 'backup_last_at';

  /// Claves que no vale la pena copiar (cachés y estados temporales).
  static bool _skip(String k) =>
      k.startsWith('flutter.') ||
      k == _lastKey ||
      k.startsWith('cache_') ||
      k.startsWith('tmp_') ||
      k.endsWith('_cache') ||
      k.endsWith('_cache_v1') ||
      AiSettings.keyNames.contains(k);

  /// Fecha de la última copia exportada (null si nunca).
  static Future<DateTime?> lastBackup() async {
    final sp = await SharedPreferences.getInstance();
    final ms = sp.getInt(_lastKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// ¿Toca recordar la copia? (nunca hecha o hace más de 30 días).
  static Future<bool> due() async {
    final l = await lastBackup();
    return l == null || DateTime.now().difference(l).inDays >= 30;
  }

  /// Recordatorio en Inicio: solo si hay algo que perder (20+ escuchas) y
  /// no se pospuso en los últimos 7 días.
  static Future<bool> shouldRemind() async {
    if (!await due()) return false;
    final sp = await SharedPreferences.getInstance();
    final snooze = sp.getInt('backup_snooze') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - snooze <
        const Duration(days: 7).inMilliseconds) {
      return false;
    }
    try {
      return (await StatsService.instance.plays()).length >= 20;
    } catch (_) {
      return false;
    }
  }

  static Future<void> snooze() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('backup_snooze', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>> _collect({required bool keys}) async {
    await StatsService.instance.flush();
    final sp = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final k in sp.getKeys()) {
      if (_skip(k)) continue;
      final v = sp.get(k);
      if (v is List) {
        data[k] = {'t': 'l', 'v': v.map((e) => '$e').toList()};
      } else if (v is String) {
        data[k] = {'t': 's', 'v': v};
      } else if (v is bool) {
        data[k] = {'t': 'b', 'v': v};
      } else if (v is int) {
        data[k] = {'t': 'i', 'v': v};
      } else if (v is double) {
        data[k] = {'t': 'd', 'v': v};
      }
    }
    final out = <String, dynamic>{
      'app': _tag,
      'v': 1,
      'at': DateTime.now().toIso8601String(),
      'data': data,
    };
    if (keys) {
      await AiSettings.instance.load();
      out['keys'] = AiSettings.instance.keysMap();
    }
    return out;
  }

  /// Crea el archivo y abre «Compartir» para guardarlo donde quieras.
  /// Devuelve cuántos datos se copiaron.
  static Future<int> export({bool keys = false}) async {
    final j = await _collect(keys: keys);
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'RockPlayIA_copia_${d.year}-${two(d.month)}-${two(d.day)}.json';
    final f = File('${dir.path}/$name');
    await f.writeAsString(jsonEncode(j));
    await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')],
        subject: 'Copia de seguridad de RockPlay IA');
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
    return (j['data'] as Map).length;
  }

  /// Elige un archivo de copia y lo lee. Null si se canceló.
  static Future<Map<String, dynamic>?> pick() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    final file = r?.files.single;
    if (file == null) return null;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) return null;
    final j = jsonDecode(utf8.decode(bytes));
    if (j is! Map<String, dynamic> || j['app'] != _tag) {
      throw const FormatException('No es una copia de RockPlay IA');
    }
    return j;
  }

  /// Restaura una copia. [merge]: combina con lo que ya hay (las listas de
  /// favoritas, historial… se unen sin duplicar); si no, reemplaza todo.
  static Future<int> restore(Map<String, dynamic> j, {bool merge = true}) async {
    final sp = await SharedPreferences.getInstance();
    final data = (j['data'] as Map).cast<String, dynamic>();
    if (!merge) {
      for (final k in sp.getKeys().toList()) {
        if (!_skip(k)) await sp.remove(k);
      }
    }
    var n = 0;
    for (final e in data.entries) {
      final m = (e.value as Map).cast<String, dynamic>();
      final v = m['v'];
      switch (m['t']) {
        case 'l':
          final incoming = (v as List).map((x) => '$x').toList();
          if (merge) {
            final cur = sp.getStringList(e.key) ?? const <String>[];
            final seen = cur.toSet();
            await sp.setStringList(
                e.key, [...cur, ...incoming.where(seen.add)]);
          } else {
            await sp.setStringList(e.key, incoming);
          }
        case 's':
          // Con «combinar», los JSON de listas y escuchas se unen.
          final cur = sp.getString(e.key);
          if (merge && cur != null && cur != v) {
            await sp.setString(e.key, _mergeJson(cur, v as String));
          } else {
            await sp.setString(e.key, v as String);
          }
        case 'b':
          if (!merge || !sp.containsKey(e.key)) await sp.setBool(e.key, v as bool);
        case 'i':
          if (!merge || !sp.containsKey(e.key)) {
            await sp.setInt(e.key, (v as num).toInt());
          }
        case 'd':
          if (!merge || !sp.containsKey(e.key)) {
            await sp.setDouble(e.key, (v as num).toDouble());
          }
      }
      n++;
    }
    final keys = j['keys'];
    if (keys is Map) {
      await AiSettings.instance.load();
      await AiSettings.instance.restoreKeys(keys.cast<String, dynamic>());
    }
    return n;
  }

  /// Une dos JSON guardados: listas → unión sin duplicados; otro → el de la
  /// copia solo si el actual está vacío.
  static String _mergeJson(String cur, String inc) {
    try {
      final a = jsonDecode(cur), b = jsonDecode(inc);
      if (a is List && b is List) {
        final seen = a.map(jsonEncode).toSet();
        return jsonEncode([...a, ...b.where((x) => seen.add(jsonEncode(x)))]);
      }
      return cur;
    } catch (_) {
      return cur.isEmpty ? inc : cur;
    }
  }
}
