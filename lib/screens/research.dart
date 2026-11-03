import '../main.dart' show Skel, openSheet, CountUp;
import '../main.dart' show Skel, openSheet, Prefs, CountUp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/cite.dart';
import 'company.dart';

class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key, this.initialTicker, required this.onResearch});
  final String? initialTicker;
  final ValueChanged<String> onResearch;

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  final _ctrl = TextEditingController();
  String? _ticker;
  Map<String, dynamic>? _d;
  String? _err;
  bool _loading = false;
  int _lens = 0;

  static const _lenses = [
    'Snapshot', 'Trajectory', 'Balance', 'Cash', 'Promise', 'Bull / bear',
  ];

  @override
  void initState() {
    super.initState();
    _ticker = widget.initialTicker;
    if (_ticker != null) _load(_ticker!);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load(String ticker) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _err = null;
      _ticker = ticker.toUpperCase();
      _d = null;
    });
    try {
      final d = await Api.I.research(ticker.toUpperCase());
      if (mounted) setState(() {
        _d = d;
        _loading = false;
      });
    } on ApiException {
      // Not pre-warmed: build it live, then read it back.
      try {
        await Api.I.buildResearch(ticker.toUpperCase());
        final d = await Api.I.research(ticker.toUpperCase());
        if (mounted) setState(() {
          _d = d;
          _loading = false;
        });
      } catch (e) {
        if (mounted) setState(() {
          _err = '$e';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 12, T.pad, 8),
          child: Row(
            children: [
              const Label('Research'),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: p.lineSoft)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: T.pad),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: p.line),
                ),
                child: Row(children: [
                  Icon(Icons.tag, size: 14, color: p.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _load(v.trim());
                      },
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(fontSize: 12.5, color: p.ink),
                      cursorColor: T.accent,
                      cursorHeight: 14,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Any NSE ticker — TCS, AMBER, DMART',
                        hintStyle: TextStyle(fontSize: 12.5, color: p.ink3),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                if (_ctrl.text.trim().isNotEmpty) _load(_ctrl.text.trim());
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                height: 40,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.arrow_forward, size: 16, color: T.bg),
              ),
            ),
          ]),
        ),
        Expanded(child: _body(p)),
      ],
    );
  }

  Widget _body(Palette p) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(T.pad),
        children: const [
          Skel(h: 60, r: 10), SizedBox(height: 14),
          Skel(h: 120, r: 10), SizedBox(height: 12), Skel(h: 120, r: 10),
        ],
      );
    }
    if (_err != null) {
      return ListView(
        padding: const EdgeInsets.all(T.pad),
        children: [
          EmptyNote('No research for that symbol. $_err'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final t in const ['TCS', 'RELIANCE', 'HDFCBANK', 'DIXON'])
              OutlinedButton(
                onPressed: () => _load(t),
                style: OutlinedButton.styleFrom(
                  foregroundColor: T.accent,
                  side: BorderSide(color: T.accent.withValues(alpha: 0.45)),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(t, style: const TextStyle(fontSize: 11)),
              ),
          ]),
        ],
      );
    }
    final d = _d;
    if (d == null) {
      return ListView(
        padding: const EdgeInsets.all(T.pad),
        children: [
          Text('Pick a name.', style: TextStyle(fontSize: 20, color: p.ink,
              fontWeight: FontWeight.w600, fontFamily: 'serif')),
          const SizedBox(height: 8),
          Text('Any NSE symbol works. Pre-warmed names open instantly; others are '
              'fetched and indexed on demand in about ten seconds.',
              style: TextStyle(fontSize: 12, height: 1.5, color: p.ink2)),
          const SizedBox(height: 18),
          const Label('Pre-warmed'),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final t in const ['TCS', 'RELIANCE', 'HDFCBANK', 'MARUTI',
              'DIXON', 'APOLLOHOSP'])
              InkWell(
                onTap: () => _load(t),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.line),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 11.5, color: p.ink)),
                ),
              ),
          ]),
        ],
      );
    }

    final lenses = map(d['lenses']);
    final led = map(d['ledger']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(T.pad, 12, T.pad, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(d['name']), style: TextStyle(fontSize: 19,
                  fontWeight: FontWeight.w600, color: p.ink, fontFamily: 'serif',
                  height: 1.2)),
              const SizedBox(height: 4),
              Text('${str(d['ticker'])} · ${str(d['sector'])} · ${str(d['cap'])} cap',
                  style: TextStyle(fontSize: 10.5, color: p.ink3)),
            ]),
          ),
          if (d['in_portfolio'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: T.accent.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('HOLDING', style: TextStyle(fontSize: 8,
                  color: T.accent, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ),
        ]),
        if (str(d['reason']).isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(str(d['reason']), style: TextStyle(fontSize: 11.5,
              color: p.ink2, height: 1.45, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _lenses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (c, i) => InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _lens = i);
              },
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == _lens ? T.accent : Colors.transparent,
                  border: Border.all(color: i == _lens ? T.accent : p.line),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(_lenses[i], style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: i == _lens ? T.bg : p.ink2)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _lensBody(p, lenses, led),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.surfaceHi, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.verified_outlined, size: 12, color: p.ink3),
            const SizedBox(width: 8),
            Expanded(child: Text('Grounded in ${str(d['grounding'])}.',
                style: TextStyle(fontSize: 10, color: p.ink3, height: 1.4))),
          ]),
        ),
      ],
    );
  }

  Widget _lensBody(Palette p, Map<String, dynamic> l, Map<String, dynamic> led) {
    switch (_lens) {
      case 0: return _snapshot(p, l);
      case 1: return _trajectory(p, l);
      case 2: return _balance(p, l);
      case 3: return _cash(p, l);
      case 4: return _promise(p, led);
      default: return _cases(p, l);
    }
  }

  Widget _snapshot(Palette p, Map<String, dynamic> l) {
    final b = map(l['business']);
    final s = map(l['snapshot']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionRule('Snapshot · ${str(s['period'])}'),
      Row(children: [
        for (final it in [
          ('Revenue', s['revenue_cr'], '₹ cr'),
          ('PBT', s['pbt_cr'], '₹ cr'),
          ('PAT', s['pat_cr'], '₹ cr'),
        ])
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Label(it.$1),
            const SizedBox(height: 4),
            CountUp((numOrNull(it.$2) ?? 0).toDouble(), size: 16),
          ])),
      ]),
      const SizedBox(height: 12),
      StatRow(label: 'PBT margin', value: fmtPct(numOrNull(s['pbt_margin_pct']), sign: false)),
      StatRow(label: 'EPS', value: '₹ ${numOrNull(s['eps'])?.toStringAsFixed(2) ?? '—'}'),
      const SizedBox(height: 16),
      if (str(b['about']).isNotEmpty) ...[
        SectionRule('Business'),
        Text(str(b['about']), maxLines: 8, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.55, color: p.ink2)),
      ],
    ]);
  }

  Widget _trajectory(Palette p, Map<String, dynamic> l) {
    final t = map(l['trajectory']);
    final periods = (t['periods'] is List)
        ? (t['periods'] as List).map((e) => e.toString()).toList() : <String>[];
    List<double?> ser(String k) => (t[k] is List)
        ? (t[k] as List).map(numOrNull).toList() : [];
    final rev = ser('revenue');
    final pat = ser('pat');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionRule('Revenue · last ${periods.length} quarters'),
      TrendChart(rev,
          labels: periods.length > 2
              ? ['', periods[periods.length ~/ 2], periods.last] : null),
      const SizedBox(height: 14),
      SectionRule('PAT'),
      TrendChart(pat, color: T.up, height: 80),
      const SizedBox(height: 14),
      if (periods.isNotEmpty && rev.isNotEmpty)
        StatRow(label: 'Latest revenue', value: fmtCr(rev.last),
            pct: rev.length > 4 && rev[rev.length - 5] != null
                ? (rev.last! / rev[rev.length - 5]! - 1) * 100 : null),
    ]);
  }

  Widget _balance(Palette p, Map<String, dynamic> l) {
    final b = map(l['balance']);
    final roce = map(b['roce']);
    final bor = (b['borrowings'] is List)
        ? (b['borrowings'] as List).map(numOrNull).whereType<double>().toList()
        : <double>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionRule('Balance sheet'),
      if (bor.isNotEmpty) ...[
        StatRow(label: 'Borrowings (latest)', value: fmtCr(bor.last) + ' cr'),
        if (bor.length > 1 && bor.first > 0)
          StatRow(label: 'Change over period',
              value: fmtPct((bor.last / bor.first - 1) * 100)),
      ],
      if (roce.isNotEmpty) ...[
        const SizedBox(height: 12),
        SectionRule('ROCE'),
        TrendChart(roce.values.map((e) => numOrNull(e)).toList(),
            color: T.accent, height: 76,
            labels: ['', roce.keys.last]),
      ],
      if (bor.isEmpty && roce.isEmpty)
        const EmptyNote('No balance-sheet detail in the snapshot for this name.'),
    ]);
  }

  Widget _cash(Palette p, Map<String, dynamic> l) {
    final c = map(l['cash_quality']);
    final conv = (c['conversion'] is List)
        ? (c['conversion'] as List).map(numOrNull).toList() : <double?>[];
    final cfo = (c['cfo'] is List) ? (c['cfo'] as List).map(numOrNull).toList() : <double?>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionRule('Cash from operations'),
      TrendChart(cfo, color: T.up),
      const SizedBox(height: 14),
      SectionRule('Cash conversion · CFO / PAT'),
      for (var i = 0; i < conv.length; i++)
        if (conv[i] != null)
          StatRow(label: 'Year ${i + 1}', value: '${conv[i]!.toStringAsFixed(2)}x',
              pct: conv[i]! >= 1 ? 1 : -1),
      const SizedBox(height: 8),
      Text('Above 1.0x means the profit is arriving as cash.',
          style: TextStyle(fontSize: 10, color: p.ink3)),
    ]);
  }

  Widget _promise(Palette p, Map<String, dynamic> led) {
    final rows = maps(led['rows']);
    final sum = map(led['summary']);
    final note = led['no_guidance_note'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.lineSoft),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Label('Credibility'),
            const Spacer(),
            Num('${((numOrNull(sum['score']) ?? 0) * 100).round()}',
                size: 17, weight: FontWeight.w700, color: T.accent),
          ]),
          const SizedBox(height: 6),
          Text(str(sum['takeaway'], 'No measurable guidance found in the transcripts.'),
              style: TextStyle(fontSize: 12, height: 1.45, color: p.ink)),
          const SizedBox(height: 10),
          Row(children: [
            for (final it in [
              ('Delivered', sum['delivered'], T.up),
              ('Partial', sum['partially'], T.warn),
              ('Missed', sum['missed'], T.down),
              ('n/a', sum['not_measurable'], p.ink3),
            ])
              Expanded(child: Column(children: [
                Num('${it.$2 ?? 0}', size: 14, weight: FontWeight.w600, color: it.$3),
                const SizedBox(height: 2),
                Text(it.$1, style: TextStyle(fontSize: 8.5, color: p.ink3)),
              ])),
          ]),
        ]),
      ),
      if (note != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: p.surfaceHi, borderRadius: BorderRadius.circular(8)),
          child: Text('Management said: "${str(note)}"',
              style: TextStyle(fontSize: 10.5, color: p.ink3, height: 1.4,
                  fontStyle: FontStyle.italic)),
        ),
      ],
      const SizedBox(height: 16),
      SectionRule('Promises, verbatim'),
      if (rows.isEmpty)
        const EmptyNote('No forward-looking management claims found in the '
            'downloaded transcripts for this name.')
      else
        for (final r in rows) _promiseRow(p, r),
    ]);
  }

  Widget _promiseRow(Palette p, Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: p.lineSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Label(str(r['quarter'])),
          const SizedBox(width: 7),
          Text(str(r['metric']).replaceAll('_', ' '),
              style: TextStyle(fontSize: 9.5, color: p.ink3)),
          const Spacer(),
          VerdictChip(str(r['verdict']), compact: true),
        ]),
        const SizedBox(height: 8),
        Text('"${str(r['quote'])}"',
            style: TextStyle(fontSize: 12, height: 1.5, color: p.ink,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        Row(children: [
          if (r['page'] != null)
            CiteChip(docId: str(r['doc_id']), page: (numOrNull(r['page']) ?? 0).toInt()),
          const SizedBox(width: 6),
          if (str(r['speaker']).isNotEmpty)
            Flexible(child: Text(str(r['speaker']),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: p.ink3))),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: p.surfaceHi, borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Expanded(child: Text(str(r['reading']),
                style: TextStyle(fontSize: 10.5, color: p.ink2, height: 1.35))),
            if (r['actual'] != null)
              Num('${numOrNull(r['actual'])!.toStringAsFixed(1)}%',
                  size: 11, color: p.ink),
          ]),
        ),
      ]),
    );
  }

  Widget _cases(Palette p, Map<String, dynamic> l) {
    final c = map(l['cases']);
    Widget col(String title, List<Map<String, dynamic>> items, Color accent) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionRule(title),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 2, height: 14, margin: const EdgeInsets.only(top: 3),
                      color: accent),
                  const SizedBox(width: 9),
                  Expanded(child: Text(str(it['text']),
                      style: TextStyle(fontSize: 12, height: 1.45, color: p.ink2))),
                ]),
              ),
            const SizedBox(height: 10),
          ],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      col('Bull', maps(c['bull']), T.up),
      col('Bear', maps(c['bear']), T.down),
      Text('Every line is computed from the snapshot, not written by a model. '
          'Where the data supports no further read, it says so.',
          style: TextStyle(fontSize: 10, color: p.ink3, height: 1.4)),
    ]);
  }
}
