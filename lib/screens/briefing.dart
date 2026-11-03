import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../main.dart' show openSheet, toast, Skel;
import '../theme/tokens.dart';
import '../widgets/charts.dart';
import '../widgets/cite.dart';
import 'company.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key, required this.onResearch});
  final ValueChanged<String> onResearch;

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  int _hours = 24;
  bool _showFiled = false;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _port;
  String? _err;
  final Set<String> _dismissed = {};
  final Set<String> _tracked = {};
  bool _loading = true;

  static const _windows = [(24, '24h'), (72, '3d'), (168, '7d'), (720, '30d')];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([Api.I.briefing(_hours), Api.I.portfolio()]);
      if (!mounted) return;
      setState(() {
        _data = results[0];
        _port = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _setWindow(int h) async {
    if (h == _hours) return;
    HapticFeedback.selectionClick();
    setState(() {
      _hours = h;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      color: T.accent,
      backgroundColor: p.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(p)),
          if (_loading)
            SliverToBoxAdapter(child: _skeleton(p))
          else if (_err != null)
            SliverToBoxAdapter(child: _error(p))
          else ...[
            SliverToBoxAdapter(child: _portfolioStrip(p)),
            SliverToBoxAdapter(child: _windowBar(p)),
            ..._tierSlivers(p),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ],
      ),
    );
  }

  Widget _header(Palette p) {
    final meta = _data;
    final counts = map(meta?['counts']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('FINN',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      letterSpacing: 2.4, color: p.ink)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                    border: Border.all(color: T.accent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(3)),
                child: Text('SNAPSHOT',
                    style: TextStyle(fontSize: 8, letterSpacing: 0.9,
                        fontWeight: FontWeight.w700, color: T.accent)),
              ),
              const Spacer(),
              Text(str(meta?['asof']),
                  style: TextStyle(fontSize: 10.5, color: p.ink3,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Skel(h: 20), SizedBox(height: 8), Skel(h: 20, w: 240),
            ])
          else
            Display(str(meta?['headline'], 'Nothing to brief.'), size: 21, height: 1.32),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 11, color: p.ink3),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                    _freshness(meta),
                    style: TextStyle(fontSize: 10.5, color: p.ink3, height: 1.3)),
              ),
              if (numOrNull(counts['filed_away']) != null)
                Text('${counts['filed_away']} folded',
                    style: TextStyle(fontSize: 10.5, color: p.ink3)),
            ],
          ),
        ],
      ),
    );
  }

  String _freshness(Map<String, dynamic>? meta) {
    if (meta == null) return '';
    return str(meta['freshness_label'], 'Snapshot data');
  }

  Widget _windowBar(Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.pad, 20, T.pad, 10),
      child: Row(
        children: [
          for (final (h, label) in _windows)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: InkWell(
                onTap: () => _setWindow(h),
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: h == _hours ? T.accent : Colors.transparent,
                    border: Border.all(
                        color: h == _hours ? T.accent : p.line),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: h == _hours ? T.bg : p.ink2)),
                ),
              ),
            ),
          const Spacer(),
          InkWell(
            onTap: () => openSheet(context, _weightsSheet()),
            child: Row(
              children: [
                Icon(Icons.tune, size: 13, color: p.ink3),
                const SizedBox(width: 4),
                Text('Ranking', style: TextStyle(fontSize: 10.5, color: p.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightsSheet() => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(
              kicker: 'Transparency',
              title: 'How the briefing is ranked',
              sub: 'Every score is the weighted sum of these four inputs. '
                  'Each card shows its own arithmetic.',
            ),
            Padding(
              padding: const EdgeInsets.all(T.pad),
              child: Column(
                children: [
                  for (final row in const [
                    ('Announcement category', 0.42,
                        'What type of filing it is. Results and management changes '
                            'outrank press releases by an order of magnitude.'),
                    ('Market reaction', 0.23,
                        'Same-day price move and volume versus the 20-day average. '
                            'A filing the market ignored ranks lower.'),
                    ('Position weight', 0.20,
                        'How much of the modelled portfolio sits in this name.'),
                    ('Novelty', 0.15,
                        'Repeated filings of the same category decay; a first-time '
                            'event ranks higher.'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(row.$1,
                                  style: TextStyle(fontSize: 12.5,
                                      color: Palette.of(context).ink,
                                      fontWeight: FontWeight.w600))),
                              Num('${(row.$2 * 100).round()}%',
                                  size: 12, color: T.accent),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: row.$2 / 0.42,
                              minHeight: 3,
                              backgroundColor: Palette.of(context).lineSoft,
                              valueColor: const AlwaysStoppedAnimation(T.accent),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(row.$3,
                              style: TextStyle(fontSize: 11.5, height: 1.45,
                                  color: Palette.of(context).ink2)),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Palette.of(context).surfaceHi,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Label('Tiers'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              '70+ needs you · 40–69 worth a glance · below 40 filed away',
                              style: TextStyle(fontSize: 10.5,
                                  color: Palette.of(context).ink2)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _portfolioStrip(Palette p) {
    final list = maps(_port?['portfolio']);
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 6, T.pad, 8),
          child: Row(
            children: [
              const Label('Portfolio'),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: p.lineSoft)),
              const SizedBox(width: 8),
              Text('${list.length} holdings', style: TextStyle(fontSize: 10, color: p.ink3)),
            ],
          ),
        ),
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: T.pad),
            itemCount: list.length,
            itemBuilder: (c, i) => _portCard(p, list[i]),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: T.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('Day move'),
              const SizedBox(height: 6),
              HeatStrip(cells: cellsheon(list)),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  List<HeatCell> cellsheon(List<Map<String, dynamic>> list) => [
        for (final e in list)
          if (numOrNull(e['day_change_pct']) != null)
            HeatCell(str(e['ticker']), numOrNull(e['day_change_pct'])!),
      ];

  Widget _portCard(Palette p, Map<String, dynamic> e) {
    final pct = numOrNull(e['day_change_pct']);
    final spark = (e['spark'] is List)
        ? (e['spark'] as List).whereType<num>().map((x) => x.toDouble()).toList()
        : <double>[];
    final unusual = e['unusual'] == true;
    return InkWell(
      onTap: () => openSheet(context, CompanySheet(ticker: str(e['ticker']))),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 116,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.lineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(str(e['ticker']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: p.ink, letterSpacing: 0.2)),
                ),
                if (unusual)
                  Container(width: 4, height: 4,
                      decoration: const BoxDecoration(
                          color: T.warn, shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(height: 2),
            Text(str(e['sector']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 8.5, color: p.ink3)),
            const Spacer(),
            Sparkline(spark, w: 96, h: 20,
                color: (pct ?? 0) >= 0 ? T.up : T.down, fill: false, stroke: 1.2),
            const SizedBox(height: 3),
            Row(
              children: [
                Num(fmtCr(numOrNull(e['last']), dp: 0), size: 11),
                const Spacer(),
                Num(fmtPct(pct), size: 10.5,
                    color: (pct ?? 0) >= 0 ? T.up : T.down),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tierSlivers(Palette p) {
    final tiers = map(_data?['tiers']);
    final needs = _visible(maps(tiers['needs_you']));
    final glance = _visible(maps(tiers['worth_a_glance']));
    final filed = maps(tiers['filed_away']).where((e) => !_dismissed.contains(str(e['id']))).toList();

    return [
      if (needs.isEmpty && glance.isEmpty && filed.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(T.pad),
            child: EmptyNote('No filings in this window. Widen the window, or the '
                'market was quiet — which is also information.'),
          ),
        ),
      if (needs.isNotEmpty) ..._group(p, 'Needs you', needs, open: true),
      if (glance.isNotEmpty) ..._group(p, 'Worth a glance', glance,
          open: false, count: glance.length),
      if (filed.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(T.pad, 22, T.pad, 0),
            child: InkWell(
              onTap: () => setState(() => _showFiled = !_showFiled),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.lineSoft),
                ),
                child: Row(
                  children: [
                    Icon(_showFiled ? Icons.unfold_less : Icons.unfold_more,
                        size: 14, color: p.ink3),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text('Filed away',
                          style: TextStyle(fontSize: 12.5, color: p.ink2,
                              fontWeight: FontWeight.w600)),
                    ),
                    Num('${filed.length}', size: 11, color: p.ink3),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (_showFiled && filed.isNotEmpty)
        SliverList.builder(
          itemCount: filed.length,
          itemBuilder: (c, i) => Padding(
            padding: const EdgeInsets.fromLTRB(T.pad, 8, T.pad, 0),
            child: _routineRow(p, filed[i]),
          ),
        ),
    ];
  }

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> items) =>
      items.where((e) => !_dismissed.contains(str(e['id']))).toList();

  List<Widget> _group(Palette p, String title, List<Map<String, dynamic>> items,
      {required bool open, int? count}) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 18, T.pad, 10),
          child: Row(
            children: [
              Container(width: 3, height: 13,
                  color: open ? T.accent : p.ink3),
              const SizedBox(width: 8),
              Template(title, open: open),
              const SizedBox(width: 8),
              Num('${count ?? items.length}', size: 11, color: p.ink3),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: p.lineSoft)),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: items.length,
        itemBuilder: (c, i) => Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 0, T.pad, 9),
          child: _card(p, items[i], dense: !open),
        ),
      ),
    ];
  }

  Widget _routineRow(Palette p, Map<String, dynamic> e) {
    return InkWell(
      onTap: () => openSheet(context, _detailSheet(e)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(str(e['ticker']),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                      color: p.ink3, letterSpacing: 0.2)),
            ),
            Expanded(
              child: Text(str(e['summary'], str(e['title'])),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: p.ink3)),
            ),
            const SizedBox(width: 6),
            Num('${numOrNull(e['materiality'])?.round() ?? 0}',
                size: 10, color: p.ink3),
          ],
        ),
      ),
    );
  }

  Widget _card(Palette p, Map<String, dynamic> e, {bool dense = false}) {
    final id = str(e['id']);
    final tracked = _tracked.contains(id);
    final cat = str(e['category']).replaceAll('_', ' ');
    final mat = numOrNull(e['materiality']) ?? 0;

    return Dismissible(
      key: ValueKey(id),
      background: _swipeBg(p, alignLeft: true, tracked: true),
      secondaryBackground: _swipeBg(p, alignLeft: false, tracked: false),
      confirmDismiss: (dir) async {
        HapticFeedback.mediumImpact();
        if (dir == DismissDirection.startToEnd) {
          setState(() => _tracked.add(id));
          toast(context, 'Tracking ${str(e['ticker'])}');
          return false;
        }
        setState(() => _dismissed.add(id));
        toast(context, 'Dismissed');
        return true;
      },
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onResearch(str(e['ticker']));
        },
        child: InkWell(
          onTap: () => openSheet(context, _detailSheet(e)),
          borderRadius: BorderRadius.circular(T.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(T.radius),
              border: Border.all(
                  color: tracked ? T.accent.withValues(alpha: 0.42) : p.lineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CatMark(category: str(e['category'])),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                          '${str(e['ticker'])} · $cat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, letterSpacing: 0.3,
                              color: p.ink2, fontWeight: FontWeight.w600)),
                    ),
                    if (tracked)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.push_pin, size: 11, color: T.accent),
                      ),
                    _ScoreBadge(score: mat, tier: str(e['tier'])),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  str(e['summary']).isEmpty ? str(e['title']) : str(e['summary']),
                  maxLines: dense ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, height: 1.42, color: p.ink,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(_when(str(e['filed_at'])),
                        style: TextStyle(fontSize: 10, color: p.ink3)),
                    const SizedBox(width: 10),
                    if (e['in_portfolio'] == true)
                      Text('holding',
                          style: TextStyle(fontSize: 10, color: p.ink3))
                    else
                      Text('not held', style: TextStyle(fontSize: 10, color: p.ink3)),
                    const Spacer(),
                    _WhyButton(item: e),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBg(Palette p, {required bool alignLeft, required bool tracked}) {
    final c = tracked ? T.accent : T.down;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(T.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignLeft) ...[
            Text('Dismiss', style: TextStyle(fontSize: 11, color: c,
                fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
          ],
          Icon(tracked ? Icons.push_pin_outlined : Icons.close, size: 14, color: c),
          if (alignLeft) ...[
            const SizedBox(width: 6),
            Text('Track', style: TextStyle(fontSize: 11, color: c,
                fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _detailSheet(Map<String, dynamic> e) {
    final p = Palette.of(context);
    final why = maps(e['why']);
    final cat = str(e['category']);
    final linkable = cat == 'results' || cat == 'management_change';

    return Column(
      children: [
        SheetHeader(
          kicker: '${str(e['ticker'])} · ${cat.replaceAll('_', ' ')}',
          title: str(e['summary']).isEmpty ? str(e['title']) : str(e['summary']),
          sub: '${str(e['company'])} · filed ${_when(str(e['filed_at']))}',
          trailing: _ScoreBadge(score: numOrNull(e['materiality']) ?? 0,
              tier: str(e['tier']), big: true),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 26),
            children: [
              SectionRule('Ranking · ${(numOrNull(e['materiality']) ?? 0).round()} of 100'),
              for (final w in why) _whyRow(p, w),
              const SizedBox(height: 16),
              SectionRule('Filing'),
              Text(str(e['title']),
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: p.ink2)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.link, size: 11, color: p.ink3),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(str(e['url']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: p.ink3)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (linkable) ...[
                SectionRule('Open the numbers'),
                _sheetAction(
                  p,
                  icon: cat == 'results' ? Icons.assessment_outlined : Icons.swap_horiz,
                  label: cat == 'results'
                      ? 'Results card — extracted from the filing'
                      : 'Management change — who and when',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (cat == 'results') {
                      openSheet(context, ResultsSheet(ticker: str(e['ticker'])));
                    } else {
                      openSheet(context, ManagementChangeSheet(item: e));
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              _sheetAction(
                p,
                icon: Icons.search,
                label: 'Research ${str(e['ticker'])} — lenses and promise ledger',
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onResearch(str(e['ticker']));
                },
              ),
              const SizedBox(height: 8),
              _sheetAction(
                p,
                icon: Icons.notifications_none,
                label: 'Track this name',
                onTap: () {
                  setState(() => _tracked.add(str(e['id'])));
                  Navigator.of(context).pop();
                  toast(context, 'Tracking ${str(e['ticker'])}');
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.surfaceHi,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: p.ink3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Classified by ${str(e['method'], 'rules')} at '
                          '${((numOrNull(e['confidence']) ?? 0) * 100).round()}% confidence. '
                          'Score inputs are shown above, not hidden.',
                          style: TextStyle(fontSize: 10.5, height: 1.4, color: p.ink3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetAction(Palette p, {required IconData icon, required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: T.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 12.5, color: p.ink)),
            ),
            Icon(Icons.chevron_right, size: 16, color: p.ink3),
          ],
        ),
      ),
    );
  }

  Widget _whyRow(Palette p, Map<String, dynamic> w) {
    final pts = numOrNull(w['points']) ?? 0;
    final wt = numOrNull(w['weight']) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(str(w['label']),
                    style: TextStyle(fontSize: 12, color: p.ink,
                        fontWeight: FontWeight.w500)),
              ),
              Num('+${pts.toStringAsFixed(1)}',
                  size: 12, color: pts > 0 ? T.accent : p.ink3),
              SizedBox(
                width: 38,
                child: Num('${(wt * 100).round()}%',
                    size: 10, color: p.ink3, align: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: wt <= 0 ? 0 : (pts / (wt * 100)).clamp(0.0, 1.0),
              minHeight: 2.5,
              backgroundColor: p.lineSoft,
              valueColor: AlwaysStoppedAnimation(
                  pts > 0 ? T.accent.withValues(alpha: 0.85) : p.line),
            ),
          ),
          const SizedBox(height: 4),
          Text(str(w['detail']),
              style: TextStyle(fontSize: 10.5, color: p.ink3, height: 1.35)),
        ],
      ),
    );
  }

  Widget _skeleton(Palette p) => Padding(
        padding: const EdgeInsets.fromLTRB(T.pad, 26, T.pad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skel(h: 84, r: 10),
            const SizedBox(height: 22),
            const Skel(h: 13, w: 90),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              const Skel(h: 92, r: 12),
              const SizedBox(height: 9),
            ],
          ],
        ),
      );

  Widget _error(Palette p) => Padding(
        padding: const EdgeInsets.all(T.pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmptyNote('Could not reach the API. $_err'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: T.accent,
                side: BorderSide(color: T.accent.withValues(alpha: 0.5)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  String _when(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final now = DateTime(2026, 11, 3, 18);
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 8) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}

class Template extends StatelessWidget {
  const Template(this.text, {super.key, this.open = false});
  final String text;
  final bool open;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: open ? Palette.of(context).ink : Palette.of(context).ink2));
}

/// Category glyph: a letterform, not an emoji, not a generic icon grid.
class _CatMark extends StatelessWidget {
  const _CatMark({required this.category});
  final String category;

  static const _map = {
    'results': 'R',
    'management_change': 'M',
    'm_and_a': 'A',
    'fund_raise': 'F',
    'rating_action': 'G',
    'large_order': 'O',
    'guidance': 'N',
    'regulatory': 'L',
    'capex': 'C',
    'dividend': 'D',
    'press_release': 'P',
    'routine': '·',
  };

  @override
  Widget build(BuildContext context) {
    final ch = _map[category] ?? '·';
    final hot = category == 'results' || category == 'management_change';
    final c = hot ? T.accent : Palette.of(context).ink3;
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: hot ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(ch,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
              color: c, height: 1)),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.tier, this.big = false});
  final double score;
  final String tier;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = tier == 'needs_you'
        ? T.accent
        : (tier == 'worth_a_glance' ? p.ink2 : p.ink3);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 9 : 6, vertical: big ? 4 : 2),
      decoration: BoxDecoration(
        color: tier == 'needs_you'
            ? T.accent.withValues(alpha: 0.11)
            : Colors.transparent,
        border: Border.all(
            color: tier == 'needs_you' ? T.accent.withValues(alpha: 0.4) : p.lineSoft),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Num(score.round().toString(),
          size: big ? 13 : 10.5, weight: FontWeight.w700, color: c),
    );
  }
}

class _WhyButton extends StatefulWidget {
  const _WhyButton({required this.item});
  final Map<String, dynamic> item;

  @override
  State<_WhyButton> createState() => _WhyButtonState();
}

class _WhyButtonState extends State<_WhyButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final why = maps(widget.item['why']);
    final top = why.isEmpty ? null : why.first;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _open = !_open);
      },
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('why this ranks here',
                    style: TextStyle(fontSize: 10, color: p.ink3)),
                const SizedBox(width: 3),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more, size: 12, color: p.ink3),
                ),
              ],
            ),
            if (_open && top != null) ...[
              const SizedBox(height: 5),
              SizedBox(
                width: 210,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.surfaceHi,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: p.lineSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final w in why)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${str(w['label'])}: ${str(w['detail'])}',
                                  style: TextStyle(fontSize: 9.5, height: 1.35,
                                      color: p.ink2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Num('+${(numOrNull(w['points']) ?? 0).toStringAsFixed(0)}',
                                  size: 9, color: T.accent),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
