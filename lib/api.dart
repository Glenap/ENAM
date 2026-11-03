import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'offline_data.dart';

/// Thin client over the FINN API.
///
/// In the sandbox the API and the web build are served from the same origin
/// (port 5060), so a relative path is correct. During `flutter run` debugging
/// it falls back to the API port on the same host.
///
/// When the API cannot be reached at all — which is always the case on a static
/// host such as Netlify, because the FastAPI backend is a separate process — the
/// client serves the bundled demo snapshot in [Offline] so the interface stays
/// navigable. Fallback happens on transport failure, HTML response, or 404/405:
/// a 500 from a live API is still surfaced, because that is a real error worth showing.
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

    Map<String, dynamic> data;
    try {
      final r = await http
          .get(Uri.parse('$base$path'))
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 404 ||
          r.statusCode == 405 ||
          (r.headers['content-type']?.contains('text/html') ?? false)) {
        // A static host answers a missing /api/* with 404 or HTML index.html fallback.
        // Treat that as "no backend attached" and fall back rather than showing an error.
        data = _fallback(path);
      } else if (r.statusCode != 200) {
        throw ApiException('$path → HTTP ${r.statusCode}');
      } else {
        data = jsonDecode(r.body) as Map<String, dynamic>;
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      // Transport failure: unreachable host, DNS, CORS, timeout, JSON parse error.
      data = _fallback(path);
    }

    _cache[key] = _CacheEntry(data, DateTime.now());
    return data;
  }

  /// Serve the bundled snapshot for [path], or rethrow if we have nothing.
  Map<String, dynamic> _fallback(String path) {
    final demo = Offline.lookup(path);
    if (demo == null) {
      throw ApiException('$path → no backend attached, and no bundled data for it');
    }
    Offline.active = true;
    return demo;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(Uri.parse('$base$path'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 40));
      if (r.statusCode == 404 ||
          r.statusCode == 405 ||
          (r.headers['content-type']?.contains('text/html') ?? false)) {
        return _fallback(path);
      }
      if (r.statusCode != 200) throw ApiException('$path → HTTP ${r.statusCode}');
      return jsonDecode(r.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      return _fallback(path);
    }
  }

  /// SSE stream for Ask FINN. Yields decoded events.
  ///
  /// Frames are buffered on blank-line boundaries: a `data:` payload can be
  /// split across two TCP chunks, and decoding per-chunk silently dropped those.
  Stream<Map<String, dynamic>> stream(String path, Map<String, dynamic> body) async* {
    http.Client? client;
    try {
      final req = http.Request('POST', Uri.parse('$base$path'))
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(body);
      client = http.Client();
      final resp = await client.send(req).timeout(const Duration(seconds: 45));
      if (resp.statusCode == 404 ||
          resp.statusCode == 405 ||
          (resp.headers['content-type']?.contains('text/html') ?? false)) {
        yield* _offlineStream(body);
        return;
      }
      var emitted = false;
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
              emitted = true;
            } catch (_) {/* malformed frame: skip rather than kill the stream */}
          }
        }
        buf
          ..clear()
          ..write(text);
      }
      if (!emitted) {
        yield* _offlineStream(body);
      }
    } catch (_) {
      // Transport failure: serve the canned answer instead of a dead stream.
      yield* _offlineStream(body);
    } finally {
      client?.close();
    }
  }

  Stream<Map<String, dynamic>> _offlineStream(Map<String, dynamic> body) {
    Offline.active = true;
    return Offline.askStream(str(body['q']));
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
