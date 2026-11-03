import 'package:flutter_test/flutter_test.dart';
import 'package:finn/offline_data.dart';

/// Verifies that the bundled demo payloads satisfy the JSON contract each
/// screen reads, so the offline fallback cannot half-render in production.
void main() {
  test('meta and portfolio carry the header fields the briefing reads', () {
    final meta = Offline.lookup('/api/meta')!;
    expect(meta['headline'], isA<String>());
    expect(meta['asof'], isA<String>());
    expect(meta['freshness_label'], isA<String>());

    final port = Offline.lookup('/api/portfolio')!;
    final list = port['portfolio'] as List;
    expect(list, isNotEmpty);
    for (final e in list.cast<Map<String, dynamic>>()) {
      expect(e['ticker'], isA<String>());
      expect(e['day_change_pct'], isA<num>());
      expect(e['spark'], isA<List>());
      expect((e['spark'] as List).length, greaterThan(2));
    }
  });

  test('meta counts satisfy the settings freshness table', () {
    final counts = Offline.lookup('/api/meta')!['counts'] as Map;
    // settings.dart reads exactly these four keys.
    for (final k in ['companies', 'announcements', 'documents', 'chunks']) {
      expect(counts[k], isA<int>(), reason: 'meta.counts.$k');
      expect(counts[k], greaterThan(0), reason: 'meta.counts.$k is zero');
    }
  });

  test('briefing inlines its own header and every tier is populated', () {
    final b = Offline.lookup('/api/briefing?window=24')!;
    expect(b['headline'], isA<String>());
    expect(b['asof'], isA<String>());

    final tiers = b['tiers'] as Map<String, dynamic>;
    for (final k in ['needs_you', 'worth_a_glance', 'filed_away']) {
      expect(tiers[k], isA<List>(), reason: 'tier $k');
      expect((tiers[k] as List), isNotEmpty, reason: 'tier $k empty');
    }

    // Every card field the widget tree dereferences must be present and typed.
    for (final tier in tiers.keys) {
      for (final raw in tiers[tier] as List) {
        final e = raw as Map<String, dynamic>;
        expect(e['id'], isA<String>());
        expect(e['ticker'], isA<String>());
        expect(e['company'], isA<String>());
        expect(e['category'], isA<String>());
        expect(e['summary'], isA<String>());
        expect(e['tier'], isA<String>());
        expect(e['filed_at'], isA<String>());
        expect(e['materiality'], isA<num>());
        expect(e['in_portfolio'], isA<bool>());
        expect(e['url'], isA<String>());
        expect(e['why'], isA<List>());
        for (final w in (e['why'] as List).cast<Map<String, dynamic>>()) {
          expect(w['label'], isA<String>());
          expect(w['points'], isA<num>());
          expect(w['weight'], isA<num>());
        }
      }
    }
  });

  test('materiality is a real score, not a parse failure', () {
    final b = Offline.lookup('/api/briefing')!;
    final needs = (b['tiers'] as Map)['needs_you'] as List;
    final first = needs.first as Map<String, dynamic>;
    expect(first['materiality'], greaterThan(50),
        reason: 'needs_you items must carry a high score');
    for (final raw in needs.cast<Map<String, dynamic>>()) {
      expect(raw['materiality'], greaterThan(0));
    }
  });

  test('research payload satisfies all six lenses', () {
    for (final t in ['TCS', 'POLYCAB', 'HDFCBANK', 'DIXON', 'SBIN']) {
      final d = Offline.lookup('/api/research/$t')!;
      expect(d['ticker'], t);
      expect(d['name'], isA<String>());
      expect(d['grounding'], isA<String>());

      final l = d['lenses'] as Map<String, dynamic>;
      for (final k in [
        'business',
        'snapshot',
        'trajectory',
        'balance',
        'cash_quality',
        'cases',
      ]) {
        expect(l[k], isA<Map>(), reason: '$t lens $k');
      }

      final snap = l['snapshot'] as Map;
      for (final k in [
        'period',
        'revenue_cr',
        'pbt_cr',
        'pat_cr',
        'pbt_margin_pct',
        'eps',
      ]) {
        expect(snap[k], isNotNull, reason: '$t snapshot.$k');
      }

      final tr = l['trajectory'] as Map;
      expect((tr['periods'] as List).length, (tr['revenue'] as List).length);
      expect((tr['periods'] as List).length, (tr['pat'] as List).length);

      final cases = l['cases'] as Map;
      expect((cases['bull'] as List), isNotEmpty);
      expect((cases['bear'] as List), isNotEmpty);

      final led = d['ledger'] as Map<String, dynamic>;
      final sum = led['summary'] as Map;
      for (final k in [
        'score',
        'takeaway',
        'delivered',
        'partially',
        'missed',
        'not_measurable',
      ]) {
        expect(sum[k], isNotNull, reason: '$t ledger.summary.$k');
      }
    }
  });

  test('HDFCBANK is the documented no-guidance case', () {
    final d = Offline.lookup('/api/research/HDFCBANK')!;
    final led = d['ledger'] as Map<String, dynamic>;
    expect(led['no_guidance_note'], isA<String>());
    expect((led['rows'] as List), isEmpty);
    expect((led['summary'] as Map)['score'], 0);
  });

  test('TCS ledger score matches the documented credibility', () {
    final d = Offline.lookup('/api/research/TCS')!;
    final sum = (d['ledger'] as Map)['summary'] as Map;
    expect(sum['score'], 0.80);
    expect((sum['takeaway'] as String), contains('measurable claims'));
  });

  test('results payload marks banks and no-verification cases honestly', () {
    final poly = Offline.lookup('/api/results/POLYCAB')!;
    expect(poly['is_bank'], false);
    final m = poly['metrics'] as Map;
    for (final k in ['Revenue', 'PBT', 'PAT', 'EPS']) {
      final row = m[k] as Map;
      expect(row['value'], isA<num>(), reason: 'POLYCAB $k.value');
      expect(row['yoy_pct'], isA<num>(), reason: 'POLYCAB $k.yoy_pct');
    }
    expect((poly['verification'] as Map)['status'], 'verified');
    expect((poly['qoq'] as Map)['revenue'], isNotNull);

    final hdfc = Offline.lookup('/api/results/HDFCBANK')!;
    expect(hdfc['is_bank'], true);
    final ebitda = (hdfc['metrics'] as Map)['EBITDA'] as Map;
    expect(ebitda['value'], isNull,
        reason: 'banks have no EBITDA line, and the payload must say so');

    final tcs = Offline.lookup('/api/results/TCS')!;
    expect((tcs['verification'] as Map)['status'], 'extracted');
  });

  test('rules and alerts satisfy the alerts screen', () {
    final r = Offline.lookup('/api/rules')!;
    final rules = r['rules'] as List;
    expect(rules, isNotEmpty);
    for (final raw in rules.cast<Map<String, dynamic>>()) {
      expect(raw['label'], isA<String>());
      expect(raw['enabled'], isA<bool>());
      expect(raw['expr'], isA<Map>());
    }

    final a = Offline.lookup('/api/alerts/history')!;
    final alerts = a['alerts'] as List;
    expect(alerts, isNotEmpty);
    for (final raw in alerts.cast<Map<String, dynamic>>()) {
      expect(raw['ticker'], isA<String>());
      expect(raw['fired_at'], isA<String>());
      expect(raw['trigger_text'], isA<String>());
      expect(raw['detail'], isA<Map>());
    }
  });

  test('unknown paths return null so the caller can raise a real error', () {
    expect(Offline.lookup('/api/nope'), isNull);
  });

  test('ask stream emits steps then a well-formed answer', () async {
    final events =
        await Offline.askStream('What did TCS guide on margin?').toList();
    expect(events.any((e) => e['type'] == 'step'), isTrue);
    final ans = events.last;
    expect(ans['type'], 'answer');
    expect(ans['answer'], isA<String>());
    expect((ans['answer'] as String), contains('73,188'));
    expect((ans['citations'] as List), isNotEmpty);
    expect((ans['followups'] as List), isNotEmpty);
    expect(ans['grounding_note'], isA<String>());
  });

  test('ask stream is honest when the question is outside the demo set',
      () async {
    final events = await Offline.askStream('What is the airspeed of a swallow?')
        .toList();
    final ans = events.last;
    expect(ans['kind'], 'demo');
    expect((ans['answer'] as String), contains('no API attached'));
  });
}
