import '../main.dart' show openSheet, Skel, toast;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme/tokens.dart';
import '../widgets/cite.dart';

/// Alert rules, in plain English. The rule builder is token-based: each row
/// reads as a sentence and each variable part is adjustable.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.onResearch});
  final ValueChanged<String> onResearch;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _err;
  final Set<String> _tickers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Api.I.rules();
      final h = await Api.I.history();
      if (!mounted) return;
      setState(() {
        _rules = maps(r['rules']);
        _history = maps(h['alerts']);
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _simulate() async {
    HapticFeedback.mediumImpact();
    try {
      final r = await Api.I.runAlerts();
      if (!mounted) return;
      toast(context, '${r['count']} alerts fired on the snapshot');
      await _load();
    } catch (e) {
      if (mounted) toast(context, 'Could not run: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      color: T.accent,
      backgroundColor: p.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 24),
        children: [
          Row(children: [
            const Label('Alerts'),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: p.lineSoft)),
            const SizedBox(width: 10),
            InkWell(
              onTap: _simulate,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: T.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: T.accent.withValues(alpha: 0.45)),
                ),
                child: Row(children: [
                  Icon(Icons.play_arrow, size: 12, color: T.accent),
                  const SizedBox(width: 4),
                  Text('Simulate', style: TextStyle(fontSize: 10.5,
                      color: T.accent, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            Column(children: const [
              Skel(h: 56, r: 9), SizedBox(height: 8), Skel(h: 56, r: 9),
            ])
          else if (_err != null)
            EmptyNote('Could not load rules. $_err')
          else ...[
            SectionRule('Rules · ${_rules.length}'),
            for (final r in _rules) _ruleCard(p, r),
            const SizedBox(height: 8),
            _addButton(p),
            const SizedBox(height: 22),
            SectionRule('History · ${_history.length}'),
            if (_history.isEmpty)
              const EmptyNote('No alerts fired yet. Tap Simulate to replay the '
                  'snapshot through these rules.')
            else
              for (final a in _history.take(25)) _alertRow(p, a),
          ],
        ],
      ),
    );
  }

  Widget _ruleCard(Palette p, Map<String, dynamic> r) {
    final expr = map(r['expr']);
    final kind = str(expr['kind'], 'volume');
    final enabled = r['enabled'] == true;
    final scope = str(expr['scope'], 'any');
    final thresh = kind == 'volume'
        ? '${numOrNull(expr['multiplier'])?.toStringAsFixed(1) ?? '2.0'}x 20-day average'
        : (kind == 'price'
            ? '±${numOrNull(expr['pct'])?.toStringAsFixed(0) ?? '4'}% in a day'
            : '${(expr['categories'] is List) ? (expr['categories'] as List).length : 3} filing types');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.lineSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(str(r['label']),
              style: TextStyle(fontSize: 12.5, height: 1.4,
                  color: enabled ? p.ink : p.ink3))),
          InkWell(
            onTap: () async {
              await Api.I.post('/api/rules', {}).catchError((_) => {});
              if (mounted) setState(() => _rules.removeWhere((x) => x['id'] == r['id']));
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 13, color: p.ink3),
            ),
          ),
        ]),
        const SizedBox(height: 7),
        Wrap(spacing: 5, runSpacing: 5, children: [
          _tok(p, scope == 'any' ? 'any holding' : scope),
          _tok(p, kind),
          _tok(p, thresh),
        ]),
      ]),
    );
  }

  Widget _tok(Palette p, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: p.surfaceHi,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.lineSoft),
        ),
        child: Text(text, style: TextStyle(fontSize: 9.5, color: p.ink2)),
      );

  Widget _addButton(Palette p) => InkWell(
        onTap: () => openSheet(context, _builder()),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 13, color: T.accent),
            const SizedBox(width: 6),
            Text('New rule', style: TextStyle(fontSize: 12, color: p.ink)),
          ]),
        ),
      );

  Widget _alertRow(Palette p, Map<String, dynamic> a) {
    final d = map(a['detail']);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.lineSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(str(a['ticker']), style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700, color: p.ink, letterSpacing: 0.2)),
          const SizedBox(width: 8),
          Text(str(a['fired_at']).length > 10
              ? str(a['fired_at']).substring(0, 10) : str(a['fired_at']),
              style: TextStyle(fontSize: 9.5, color: p.ink3)),
          const Spacer(),
          if (d['correlation_note'] != null)
            Text('correlation', style: TextStyle(fontSize: 8.5, color: p.ink3)),
        ]),
        const SizedBox(height: 5),
        Text(str(a['trigger_text']), style: TextStyle(fontSize: 11.5,
            color: p.ink2, height: 1.4)),
        if (d['linked_title'] != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.link, size: 10, color: p.ink3),
            const SizedBox(width: 4),
            Expanded(child: Text('Probable cause: ${str(d['linked_title'])}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: p.ink3))),
          ]),
        ],
      ]),
    );
  }

  Widget _builder() {
    final p = Palette.of(context);
    String kind = 'volume';
    double mult = 2.0;
    double pct = 4.0;

    return StatefulBuilder(builder: (context, setSheet) {
      final label = switch (kind) {
        'volume' => 'Any holding: volume above ${mult.toStringAsFixed(1)}x its 20-day average',
        'price' => 'Any holding: moves more than ${pct.toStringAsFixed(0)}% in a day',
        _ => 'Any holding: results, M&A or management change filing',
      };
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHeader(
          kicker: 'New rule',
          title: 'Plain English, adjustable',
          sub: 'Rules run on the EOD snapshot and on new filings.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: p.surfaceHi, borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(fontSize: 12.5,
                  color: p.ink, height: 1.45)),
            ),
            const SizedBox(height: 16),
            const Label('Trigger'),
            const SizedBox(height: 8),
            Row(children: [
              for (final k in const ['volume', 'price', 'filing'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setSheet(() => kind = k),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kind == k ? T.accent : Colors.transparent,
                        border: Border.all(color: kind == k ? T.accent : p.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(k, style: TextStyle(fontSize: 11,
                          color: kind == k ? T.bg : p.ink2,
                          fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ]),
            if (kind == 'volume') ...[
              const SizedBox(height: 16),
              Row(children: [
                const Label('Multiplier'),
                const Spacer(),
                Num('${mult.toStringAsFixed(1)}x', size: 12, color: T.accent),
              ]),
              Slider(value: mult, min: 1.2, max: 5, divisions: 19,
                  activeColor: T.accent, inactiveColor: p.line,
                  onChanged: (v) => setSheet(() => mult = v)),
            ],
            if (kind == 'price') ...[
              const SizedBox(height: 16),
              Row(children: [
                const Label('Move'),
                const Spacer(),
                Num('±${pct.toStringAsFixed(0)}%', size: 12, color: T.accent),
              ]),
              Slider(value: pct, min: 1, max: 12, divisions: 22,
                  activeColor: T.accent, inactiveColor: p.line,
                  onChanged: (v) => setSheet(() => pct = v)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: T.accent, foregroundColor: T.bg,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                onPressed: () async {
                  final expr = kind == 'volume'
                      ? {'scope': 'any', 'kind': 'volume', 'multiplier': mult}
                      : (kind == 'price'
                          ? {'scope': 'any', 'kind': 'price', 'pct': pct}
                          : {'scope': 'any', 'kind': 'filing',
                              'categories': ['results', 'm_and_a', 'management_change']});
                  try {
                    await Api.I.post('/api/rules', {'label': label, 'expr': expr});
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    await _load();
                  } catch (e) {
                    if (context.mounted) toast(context, 'Could not save: $e');
                  }
                },
                child: const Text('Save rule', style: TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ]);
    });
  }
}
