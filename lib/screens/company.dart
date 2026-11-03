import '../main.dart' show Skel, openSheet;
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/cite.dart';

/// Results card: the extracted quarter, its arithmetic, and the extraction's
/// own confidence. Nine rows of numbers, no interpretation.
class ResultsSheet extends StatefulWidget {
  const ResultsSheet({super.key, required this.ticker});
  final String ticker;
  @override
  State<ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends State<ResultsSheet> {
  Map<String, dynamic>? _d;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.results(widget.ticker);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final d = _d;
    if (_err != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(kicker: widget.ticker, title: 'Results unavailable'),
        Padding(padding: const EdgeInsets.all(T.pad), child: EmptyNote(_err!)),
      ]);
    }
    if (d == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SheetHeader(kicker: widget.ticker, title: 'Loading results'),
        const Padding(
          padding: EdgeInsets.all(T.pad),
          child: Column(children: [Skel(h: 14), SizedBox(height: 10),
            Skel(h: 120, r: 10)]),
        ),
      ]);
    }

    final m = map(d['metrics']);
    final qoq = map(d['qoq']);
    final ver = map(d['verification']);
    final bank = d['is_bank'] == true;
    final rev = map(m['Revenue']);
    final ebitda = map(m['EBITDA']);
    final pbt = map(m['PBT']);
    final pat = map(m['PAT']);

    String v(Map<String, dynamic> x) =>
        x['value'] == null ? '—' : fmtCr(numOrNull(x['value']));
    String yoy(Map<String, dynamic> x) => fmtPct(numOrNull(x['yoy_pct']));

    double? q(String key) {
      final e = qoq.entries.firstWhere((k) => k.key.toLowerCase().contains(key),
          orElse: () => const MapEntry('', null));
      return numOrNull(map(e.value)['qoq_pct']);
    }

    return Column(
      children: [
        SheetHeader(
          kicker: '${widget.ticker} · ${str(d['period'])} · ${str(d['scope'])}',
          title: 'Quarterly results',
          sub: 'Extracted from the filing, cross-checked against the quarterly table.',
          trailing: _Verified(ver),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 26),
            children: [
              Row(
                children: [
                  for (final item in [
                    ('Revenue', v(rev), yoy(rev), q('revenue')),
                    ('PBT', v(pbt), yoy(pbt), q('profit before')),
                    ('PAT', v(pat), yoy(pat), q('net profit')),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Label(item.$1),
                          const SizedBox(height: 5),
                          Num(item.$2, size: 17, weight: FontWeight.w600),
                          const SizedBox(height: 3),
                          Row(children: [
                            Num(item.$3, size: 10.5,
                                color: (numOrNull(item.$4 == null ? null : 0) ?? 0) >= 0
                                    ? T.up : T.down),
                            const SizedBox(width: 3),
                            Text('YoY', style: TextStyle(fontSize: 9, color: p.ink3)),
                          ]),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (!bank && ebitda['value'] != null) ...[
                SectionRule('EBITDA'),
                PairedBars(items: [
                  BarItem('EBITDA',
                      numOrNull(ebitda['value']) ?? 0,
                      numOrNull(ebitda['prior_year']) ?? 0,
                      pct: numOrNull(ebitda['yoy_pct'])),
                  BarItem('Revenue',
                      numOrNull(rev['value']) ?? 0,
                      numOrNull(rev['prior_year']) ?? 0,
                      pct: numOrNull(rev['yoy_pct'])),
                ]),
                const SizedBox(height: 14),
                StatRow(label: 'EBITDA margin', value: fmtPct(
                    numOrNull(ebitda['margin_pct']), sign: false),
                    delta: fmtPct(numOrNull(ebitda['margin_py_pct']), sign: false)),
              ] else if (bank)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.surfaceHi, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 12, color: p.ink3),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'EBITDA is not reported by banks — there is no operating '
                        'cost line to subtract. Shown is PBT instead.',
                        style: TextStyle(fontSize: 10.5, height: 1.4, color: p.ink3))),
                  ]),
                ),
              const SizedBox(height: 16),
              SectionRule('Detail'),
              StatRow(label: 'Revenue', value: v(rev), delta: yoy(rev),
                  pct: numOrNull(rev['yoy_pct'])),
              StatRow(label: 'Prior year', value: fmtCr(numOrNull(rev['prior_year']))),
              StatRow(label: 'PBT', value: v(pbt), delta: yoy(pbt),
                  pct: numOrNull(pbt['yoy_pct'])),
              StatRow(label: 'PAT', value: v(pat), delta: yoy(pat),
                  pct: numOrNull(pat['yoy_pct'])),
              if (m['EBITDA'] != null)
                StatRow(label: 'EBITDA', value: v(ebitda), delta: yoy(ebitda),
                    pct: numOrNull(ebitda['yoy_pct'])),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: p.surfaceHi,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: p.lineSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Label('Extraction'),
                      const Spacer(),
                      ConfidenceTicks(
                          passed: (numOrNull(ver['passed']) ?? 0).toInt(),
                          total: (numOrNull(ver['total']) ?? 0).toInt()),
                    ]),
                    const SizedBox(height: 7),
                    Text(str(ver['note']), style: TextStyle(fontSize: 10.5,
                        color: p.ink2, height: 1.4)),
                    const SizedBox(height: 4),
                    Text(str(d['judgement']), style: TextStyle(fontSize: 10.5,
                        color: p.ink3, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Source: ${str(d['source'])}',
                  style: TextStyle(fontSize: 9.5, color: p.ink3)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified(this.ver);
  final Map<String, dynamic> ver;
  @override
  Widget build(BuildContext context) {
    final ok = str(ver['status']) == 'verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: (ok ? T.up : T.warn).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: (ok ? T.up : T.warn).withValues(alpha: 0.4)),
      ),
      child: Text(str(ver['status']),
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: ok ? T.up : T.warn)),
    );
  }
}

/// Management change: who, when, why it matters. Biographies are outside
/// knowledge and are labelled as such, per the brief.
class ManagementChangeSheet extends StatelessWidget {
  const ManagementChangeSheet({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          kicker: '${str(item['ticker'])} · management change',
          title: str(item['title']),
          sub: str(item['company']),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 26),
            shrinkWrap: true,
            children: [
              SectionRule('What the filing says'),
              Text(str(item['summary'], str(item['title'])),
                  style: TextStyle(fontSize: 13, height: 1.5, color: p.ink)),
              const SizedBox(height: 16),
              SectionRule('Why it matters'),
              Text(
                'A change at the top resets the guidance track record: promises made '
                'by the outgoing executive are the ones the ledger holds the company '
                'to. Check the Promise Ledger before crediting the new guidance.',
                style: TextStyle(fontSize: 12, height: 1.55, color: p.ink2),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.surfaceHi,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.lineSoft),
                ),
                child: Row(children: [
                  Icon(Icons.public, size: 12, color: p.ink3),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                      'Biographical detail on the incoming person is not in the '
                      'filings, so none is shown here. Nothing is inferred.',
                      style: TextStyle(fontSize: 10.5, height: 1.4, color: p.ink3))),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact company sheet used from the portfolio strip: price, reason, and a
/// route into the full research screen.
class CompanySheet extends StatefulWidget {
  const CompanySheet({super.key, required this.ticker});
  final String ticker;
  @override
  State<CompanySheet> createState() => _CompanySheetState();
}

class _CompanySheetState extends State<CompanySheet> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    Api.I.portfolio().then((r) {
      final all = [...maps(r['portfolio']), ...maps(r['research'])];
      final hit = all.firstWhere((e) => str(e['ticker']) == widget.ticker,
          orElse: () => <String, dynamic>{});
      if (mounted) setState(() => _d = hit);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final d = _d ?? {};
    final pct = numOrNull(d['day_change_pct']);
    final spark = (d['spark'] is List)
        ? (d['spark'] as List).whereType<num>().map((x) => x.toDouble()).toList()
        : <double>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(
          kicker: '${str(d['sector'])} · ${str(d['cap'])} cap',
          title: str(d['name'], widget.ticker),
          sub: str(d['reason']),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 26),
            children: [
              Row(children: [
                Num(fmtCr(numOrNull(d['last']), dp: 0), size: 22,
                    weight: FontWeight.w600),
                const SizedBox(width: 10),
                Num(fmtPct(pct), size: 13,
                    color: (pct ?? 0) >= 0 ? T.up : T.down),
                const Spacer(),
                Sparkline(spark, w: 96, h: 26, fill: false),
              ]),
              const SizedBox(height: 14),
              if (d['vol_ratio'] != null)
                StatRow(label: 'Volume vs 20-day average',
                    value: '${numOrNull(d['vol_ratio'])!.toStringAsFixed(1)}x'),
              StatRow(label: 'In portfolio',
                  value: d['in_portfolio'] == true ? 'Yes' : 'No'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: T.accent,
                  side: BorderSide(color: T.accent.withValues(alpha: 0.5)),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
