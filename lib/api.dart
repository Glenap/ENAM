import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// Thin client over the FINN API.
///
/// In the sandbox the API and the web build are served from the same origin
/// (port 5060), so a relative path is correct. During `flutter run` debugging
/// it falls back to the API port on the same host.
class Api {
  Api._();
  static final Api I = Api._();

  static const String _base = String.fromEnvironment('FINN_API', defaultValue: '');

  String get base {
    if (_base.isNotEmpty) return _base;
    final origin = Uri.base.origin;
    if (origin.startsWith('http')) return origin;
    return 'http://localhost:8000';
  }

  final Map<String, _CacheEntry> _cache = {};

  Future<Map<String, dynamic>> get(String path, {Duration ttl = const Duration(seconds: 90)}) async {
    final key = path;
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return hit.data;
    }
    final r = await http
        .get(Uri.parse('$base$path'))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw ApiException('$path → HTTP ${r.statusCode}');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    _cache[key] = _CacheEntry(data, DateTime.now());
    return data;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$base$path'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) throw ApiException('$path → HTTP ${r.statusCode}');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// SSE stream for Ask FINN. Yields decoded events.
  ///
  /// Frames are buffered on blank-line boundaries: a `data:` payload can be
  /// split across two TCP chunks, and decoding per-chunk silently dropped those.
  Stream<Map<String, dynamic>> stream(String path, Map<String, dynamic> body) async* {
    final req = http.Request('POST', Uri.parse('$base$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(body);
    final resp = await req.send().timeout(const Duration(seconds: 45));
    final buf = StringBuffer();
    await for (final chunk in resp.stream.transform(utf8.decoder)) {
      buf.write(chunk);
      var text = buf.toString();
      while (true) {
        final cut = text.indexOf('\n\n');
        if (cut < 0) break;
        final frame = text.substring(0, cut);
        text = text.substring(cut + 2);
        for (final line in frame.split('\n')) {
          final t = line.trim();
          if (!t.startsWith('data:')) continue;
          final payload = t.substring(5).trim();
          if (payload.isEmpty) continue;
          try {
            yield jsonDecode(payload) as Map<String, dynamic>;
          } catch (_) {/* malformed frame: skip rather than kill the stream */}
        }
      }
      buf
        ..clear()
        ..write(text);
    }
  }

  Future<Map<String, dynamic>> meta() => get('/api/meta', ttl: const Duration(minutes: 10));
  Future<Map<String, dynamic>> portfolio() => get('/api/portfolio');
  Future<Map<String, dynamic>> briefing(int hours) => get('/api/briefing?window=$hours');
  Future<Map<String, dynamic>> research(String ticker) =>
      get('/api/research/$ticker', ttl: const Duration(minutes: 10));
  Future<Map<String, dynamic>> results(String ticker) => get('/api/results/$ticker');
  Future<Map<String, dynamic>> rules() => get('/api/rules', ttl: const Duration(seconds: 5));
  Future<Map<String, dynamic>> cost() => get('/api/cost', ttl: const Duration(seconds: 20));
  Future<Map<String, dynamic>> source(String docId) =>
      get('/api/sources/$docId', ttl: const Duration(minutes: 10));
  Future<Map<String, dynamic>> history() => get('/api/alerts/history');
  Future<Map<String, dynamic>> search(String q) => get('/api/search?q=${Uri.encodeComponent(q)}');

  /// Build a research payload for a ticker that is not pre-warmed.
  Future<Map<String, dynamic>> buildResearch(String ticker) =>
      post('/api/research/${ticker.toUpperCase()}/build', {});

  Future<Map<String, dynamic>> runAlerts({String? ticker}) =>
      post('/api/alerts/run', {if (ticker != null) 'ticker': ticker});

  Future<Map<String, dynamic>> ask(String q, {String? ticker}) =>
      post('/api/ask', {'q': q, if (ticker != null) 'ticker': ticker});
}

class _CacheEntry {
  _CacheEntry(this.data, this.at);
  final Map<String, dynamic> data;
  final DateTime at;
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Small helpers so screens stay declarative.
double? numOrNull(dynamic v) => v is num ? v.toDouble() : null;
String str(dynamic v, [String d = '']) => v?.toString() ?? d;
List<Map<String, dynamic>> maps(dynamic v) =>
    (v is List) ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
Map<String, dynamic> map(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
