import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart' show Prefs, toast;
import '../theme/tokens.dart';
import '../widgets/cite.dart';

/// Settings is where the app shows its own costs. The routing table and the
/// real ledger are the point: a tool that hides its token spend is not
/// trustworthy in a cost-sensitive shop.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _cost;
  Map<String, dynamic>? _meta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.I.cost(), Api.I.meta()]);
      if (!mounted) return;
      setState(() {
        _cost = r[0];
        _meta = r[1];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final prefs = Prefs.of(context);
    final cost = _cost;
    final meta = _meta;
    final counts = map(meta?['counts']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 28),
      children: [
        Row(children: [
          const Label('Settings'),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: p.lineSoft)),
        ]),
        const SizedBox(height: 16),

        _toggle(p, 'Dark mode', 'Editorial terminal palette, near-black surfaces.',
            prefs.dark.value, prefs.onDark),
        _toggle(p, 'Explain like I\'m a PM',
            'Adds a plain-language gloss under each metric.', prefs.plain.value,
            prefs.onPlain),

        const SizedBox(height: 20),
        SectionRule('Data freshness'),
        _kv(p, 'Mode', str(meta?['mode'], 'snapshot')),
        _kv(p, 'Prices as of', '${str(meta?['snapshot_asof'])} EOD'),
        _kv(p, 'Snapshot built', str(meta?['built_at'])),
        _kv(p, 'Companies', '${counts['companies'] ?? 0}'),
        _kv(p, 'Filings', '${counts['announcements'] ?? 0}'),
        _kv(p, 'Documents', '${counts['documents'] ?? 0}'),
        _kv(p, 'Indexed chunks', '${counts['chunks'] ?? 0}'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.surfaceHi, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.schedule, size: 12, color: p.ink3),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'Every screen reads from the frozen snapshot, so a blocked exchange '
                'or a rate limit cannot break a demo. Nothing is generated on the fly.',
                style: TextStyle(fontSize: 10, color: p.ink3, height: 1.45))),
          ]),
        ),

        const SizedBox(height: 22),
        SectionRule('Cost ledger'),
        if (cost == null)
          const EmptyNote('Ledger unavailable.')
        else ...[
          Row(children: [
            Expanded(child: _big(p, '₹${numOrNull(cost['total_inr'])?.toStringAsFixed(2) ?? '0.00'}',
                'spent')),
            Expanded(child: _big(p, '${numOrNull(cost['total_tokens'])?.round() ?? 0}',
                'tokens')),
            Expanded(child: _big(p, '${cost['documents'] ?? 0}', 'documents')),
          ]),
          const SizedBox(height: 12),
          Text(str(cost['assumption']),
              style: TextStyle(fontSize: 10, color: p.ink3, height: 1.4)),
          const SizedBox(height: 14),
          SectionRule('Routing'),
          for (final r in maps(cost['routing_table']))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 96,
                  child: Text(str(r['task']),
                      style: TextStyle(fontSize: 10.5, color: p.ink,
                          fontWeight: FontWeight.w600, height: 1.35)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(r['tier']), style: TextStyle(fontSize: 10,
                        color: T.accent, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(str(r['why']),
                        style: TextStyle(fontSize: 10, color: p.ink3, height: 1.35)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.surfaceHi, borderRadius: BorderRadius.circular(8)),
            child: Text(
                'Active inference chain: '
                '${(map(cost['providers'])['active_chain'] is List) ? (map(cost['providers'])['active_chain'] as List).join(' → ') : 'deterministic'}'
                '. Zero hosted tokens were spent producing this snapshot.',
                style: TextStyle(fontSize: 10, color: p.ink3, height: 1.45)),
          ),
        ],
      ],
    );
  }

  Widget _big(Palette p, String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Num(value, size: 16, weight: FontWeight.w600),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8.5, color: p.ink3,
              letterSpacing: 0.5)),
        ],
      );

  Widget _kv(Palette p, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(k, style: TextStyle(fontSize: 11.5, color: p.ink2)),
          const Spacer(),
          Num(v, size: 11, color: p.ink3, align: TextAlign.right),
        ]),
      );

  Widget _toggle(Palette p, String title, String sub, bool value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 12.5, color: p.ink)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 10, color: p.ink3,
                    height: 1.35)),
              ]),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 36,
              height: 21,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: value ? T.accent : p.line,
                borderRadius: BorderRadius.circular(11),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 170),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? T.bg : p.ink3,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}
