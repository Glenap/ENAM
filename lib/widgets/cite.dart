import '../main.dart' show openSheet, Skel, toast;
import 'package:flutter/material.dart';

import '../api.dart';
import '../theme/tokens.dart';

/// A citation chip. Every grounded claim in the app carries one of these.
/// Tapping opens the source document at the cited page.
class CiteChip extends StatelessWidget {
  const CiteChip({super.key, required this.docId, this.page, this.label, this.kind});
  final String docId;
  final int? page;
  final String? label;
  final String? kind;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final text = label ?? _short();
    return InkWell(
      onTap: () => openSource(context, docId, page),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: T.accent.withValues(alpha: 0.10),
          border: Border.all(color: T.accent.withValues(alpha: 0.42)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 10, color: T.accent),
            const SizedBox(width: 4),
            Text(text,
                style: TextStyle(fontSize: 9.5, color: T.accent,
                    fontWeight: FontWeight.w600, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }

  String _short() {
    final base = docId.replaceAll('-call', '').replaceAll('-AR', ' AR ');
    final b = base.length > 22 ? base.substring(0, 22) : base;
    return page != null ? '$b · p$page' : b;
  }
}

/// Opens the source bottom sheet: the cited page first, the rest of the
/// document below, so a reader can check the neighbourhood of a claim.
Future<void> openSource(BuildContext context, String docId, int? page) async {
  await openSheet(
    context,
    _SourceSheet(docId: docId, page: page),
  );
}

class _SourceSheet extends StatefulWidget {
  const _SourceSheet({required this.docId, this.page});
  final String docId;
  final int? page;

  @override
  State<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<_SourceSheet> {
  Map<String, dynamic>? _data;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.source(widget.docId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final doc = map(_data?['document']);
    final chunks = maps(_data?['chunks']);
    final focus = widget.page;

    // Put the cited page first, then the rest in order.
    final ordered = [...chunks];
    if (focus != null) {
      ordered.sort((a, b) {
        final da = (numOrNull(a['page']) ?? 0).toInt();
        final db = (numOrNull(b['page']) ?? 0).toInt();
        final sa = da == focus ? 0 : (db == focus ? 1 : 0);
        final sb = db == focus || da == focus ? (db == focus ? 1 : 0) : 0;
        if (sa != sb) return sa.compareTo(sb);
        return da.compareTo(db);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Grip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 2, T.pad, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label('${str(doc['kind'])} · ${str(doc['period'])}'),
                    const SizedBox(height: 4),
                    Display(widget.docId, size: 16),
                  ],
                ),
              ),
              if (doc['pages'] != null)
                Num('${str(doc['pages'])} pp', size: 11, color: p.ink3),
            ],
          ),
        ),
        hairline(context),
        Expanded(
          child: _err != null
              ? Center(child: Text(_err!, style: TextStyle(color: p.ink3, fontSize: 12)))
              : _data == null
                  ? _loading(p)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(T.pad, 12, T.pad, 24),
                      itemCount: ordered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (c, i) {
                        final ch = ordered[i];
                        final pg = (numOrNull(ch['page']) ?? 0).toInt();
                        final isFocus = pg == focus;
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isFocus ? T.accent.withValues(alpha: 0.06) : p.surfaceHi,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: isFocus ? T.accent.withValues(alpha: 0.40) : p.lineSoft),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Label('page $pg', color: isFocus ? T.accent : null),
                                  if (str(ch['speaker']).isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(str(ch['speaker']),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10, color: p.ink2)),
                                    ),
                                  ],
                                  const Spacer(),
                                  if (isFocus)
                                    Text('cited',
                                        style: TextStyle(fontSize: 9.5, color: T.accent,
                                            fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(str(ch['text']),
                                  style: TextStyle(fontSize: 12.5, height: 1.5,
                                      color: isFocus ? p.ink : p.ink2)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _loading(Palette p) => ListView(
        padding: const EdgeInsets.all(T.pad),
        children: const [Skel(h: 12), SizedBox(height: 8), Skel(h: 12),
          SizedBox(height: 8), Skel(h: 12, w: 220), SizedBox(height: 20),
          Skel(h: 80), SizedBox(height: 12), Skel(h: 80)],
      );
}

class _Grip extends StatelessWidget {
  const _Grip();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 34,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          decoration: BoxDecoration(
            color: Palette.of(context).line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

/// Standard sheet header. Reused by every sheet so the rhythm is identical.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.kicker, required this.title,
    this.sub, this.trailing});
  final String kicker;
  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Grip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(T.pad, 4, T.pad, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(kicker),
                    const SizedBox(height: 5),
                    Display(title, size: 19),
                    if (sub != null) ...[
                      const SizedBox(height: 5),
                      Text(sub!,
                          style: TextStyle(fontSize: 12, color: p.ink2, height: 1.4)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              IconButton(
                icon: Icon(Icons.close, size: 18, color: p.ink3),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        hairline(context),
      ],
    );
  }
}

/// Verdict chip for the Promise Ledger. Colour is semantic and never the only
/// signal: the word is always present.
class VerdictChip extends StatelessWidget {
  const VerdictChip(this.verdict, {super.key, this.compact = false});
  final String verdict;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (c, bg) = switch (verdict.toLowerCase()) {
      'delivered' => (T.up, T.up.withValues(alpha: 0.13)),
      'partially' || 'partially delivered' => (T.warn, T.warn.withValues(alpha: 0.13)),
      'missed' => (T.down, T.down.withValues(alpha: 0.13)),
      _ => (T.ink3, T.ink3.withValues(alpha: 0.10)),
    };
    final text = verdict.toLowerCase() == 'not measurable' ? 'Not measurable' : verdict;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withValues(alpha: 0.42)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: compact ? 9 : 10, color: c,
              fontWeight: FontWeight.w700, letterSpacing: 0.2)),
    );
  }
}

/// A number with its label, in a row. The workhorse of the results card.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value,
    this.delta, this.pct, this.note, this.emphasis = false});
  final String label;
  final String? value;
  final String? delta;
  final double? pct;
  final String? note;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final col = pct == null
        ? p.ink2
        : (pct! > 0 ? T.up : (pct! < 0 ? T.down : p.ink2));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: emphasis ? 12.5 : 12,
                    color: emphasis ? p.ink : p.ink2,
                    fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400)),
          ),
          if (value != null)
            Num(value!, size: emphasis ? 14 : 13,
                weight: emphasis ? FontWeight.w600 : FontWeight.w500,
                color: emphasis ? p.ink : null, align: TextAlign.right),
          if (delta != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 54,
              child: Num(delta!, size: 11, color: col, align: TextAlign.right),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section label with a hairline rule, used to separate sheet blocks.
class SectionRule extends StatelessWidget {
  const SectionRule(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Label(text),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: p.lineSoft)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Empty state that says something true instead of apologising.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon = Icons.remove_circle_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: p.ink3),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: TextStyle(fontSize: 12, color: p.ink3, height: 1.45))),
        ],
      ),
    );
  }
}
