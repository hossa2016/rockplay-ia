import 'package:shared_preferences/shared_preferences.dart';

/// Artistas que el usuario no quiere escuchar. Se filtran de búsquedas,
/// mixes y DJ.
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  static const String _key = 'blocked_artists_v1';
  final List<String> _names = <String>[];
  bool _loaded = false;

  List<String> get names => List<String>.unmodifiable(_names);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _names
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const <String>[]);
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _names);
    } catch (_) {}
  }

  Future<void> add(String name) async {
    await ensureLoaded();
    final n = name.trim();
    if (n.isEmpty || _names.any((x) => norm(x) == norm(n))) return;
    _names.add(n);
    await _save();
  }

  Future<void> remove(String name) async {
    await ensureLoaded();
    _names.removeWhere((x) => x == name);
    await _save();
  }

  /// Minúsculas, sin acentos y solo letras/números.
  static String norm(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      var c = String.fromCharCode(r);
      final i = from.indexOf(c);
      if (i >= 0) c = to[i];
      if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c);
    }
    return b.toString();
  }

  /// Quita "the/los/las/el/la" iniciales para comparar nombres de artistas.
  static String normName(String s) => norm(
      s.toLowerCase().replaceFirst(RegExp(r'^(the|los|las|el|la)\s+'), ''));

  /// ¿El canal [author] corresponde a un artista bloqueado?
  bool isBlockedAuthor(String author) {
    if (_names.isEmpty) return false;
    final a = normName(author
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), ''));
    if (a.isEmpty) return false;
    for (final n in _names) {
      final b = normName(n);
      if (b.isEmpty) continue;
      if (a == b) return true;
      if (b.length >= 6 && a.contains(b)) return true;
    }
    return false;
  }
}
