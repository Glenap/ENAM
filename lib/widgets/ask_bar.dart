import 'dart:ui' show FontFeature;
import '../main.dart' show openSheet, Skel, toast;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme/tokens.dart';
import 'cite.dart';

/// The persistent command bar. Two jobs: ask a question, or jump to a name.
class AskBar extends StatefulWidget {
  const AskBar({super.key, required this.onOpenResearch});
  final ValueChanged<String> onOpenResearch;

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    _focus.unfocus();
    openSheet(context, AskSheet(question: q, onOpenResearch: widget.onOpenResearch));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(T.pad, 6, T.pad, 8),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.lineSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 15, color: p.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onSubmitted: (_) => _submit(),
                      textInputAction: TextInputAction.send,
                      style: TextStyle(fontSize: 12.5, color: p.ink),
                      cursorColor: T.accent,
                      cursorHeight: 14,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Ask FINN — grounded in filings',
                        hintStyle: TextStyle(fontSize: 12.5, color: p.ink3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Send question',
            child: InkWell(
              onTap: _submit,
              borderRadius: BorderRadius.circular(21),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: T.accent, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward, size: 17, color: T.bg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AskSheet extends StatefulWidget {
  const AskSheet({super.key, required this.question, required this.onOpenResearch});
  final String question;
  final ValueChanged<String> onOpenResearch;

  @override
  State<AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<AskSheet> {
  final List<String> _steps = [];
  Map<String, dynamic>? _answer;
  String? _err;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await for (final ev in Api.I.stream('/api/ask/stream', {'q': widget.question})) {
        if (!mounted) return;
        final t = str(ev['type']);
        if (t == 'step') {
          setState(() => _steps.add(str(ev['label'])));
        } else if (t == 'answer') {
          setState(() => _answer = ev);
          setState(() {
            if (!_steps.contains('Verified')) _steps.add('Verified');
          });
        } else if (t == 'error') {
          setState(() => _err = str(ev['message']));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ans = _answer;
    final cites = maps(ans?['citations']);
    final followups = (ans?['followups'] is List)
        ? (ans!['followups'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Column(
      children: [
        SheetHeader(
          kicker: 'Ask FINN',
          title: widget.question,
          sub: 'Answers come from stored annual reports, concall transcripts and '
              'quarterly tables. Nothing else.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(T.pad, 14, T.pad, 24),
            children: [
              // Progress timeline, shown until the answer lands.
              if (ans == null && _err == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 4; i++)
                      _stepRow(p, i, i < _steps.length),
                  ],
                ),
              if (_err != null)
                EmptyNote('Could not reach the API. $_err')
              else if (ans != null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final s in _steps)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 9, color: T.up),
                          const SizedBox(width: 3),
                          Text(s, style: TextStyle(fontSize: 9, color: p.ink3)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _kindTag(str(ans['kind'])),
                const SizedBox(height: 9),
                Text(str(ans['answer']),
                    style: TextStyle(fontSize: 14, height: 1.55, color: p.ink)),
                if (cites.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SectionRule('Citations'),
                  for (final c in cites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CiteChip(
                                docId: str(c['doc_id']),
                                page: (numOrNull(c['page']) ?? 0).toInt(),
                                label: '${str(c['doc_id'])} · p${str(c['page'])}',
                              ),
                              const SizedBox(width: 6),
                              Text(str(c['period']),
                                  style: TextStyle(fontSize: 9.5, color: p.ink3)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(str(c['excerpt']),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, height: 1.45,
                                  color: p.ink2)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: p.surfaceHi,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 12, color: p.ink3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(str(ans['grounding_note']),
                            style: TextStyle(fontSize: 10, height: 1.4, color: p.ink3)),
                      ),
                    ],
                  ),
                ),
                if (followups.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionRule('Ask next'),
                  for (final f in followups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          openSheet(context,
                              AskSheet(question: f, onOpenResearch: widget.onOpenResearch));
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: p.line),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(f, style: TextStyle(fontSize: 11.5,
                                    color: p.ink2, height: 1.35)),
                              ),
                              Icon(Icons.north_east, size: 12, color: p.ink3),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _kindTag(String kind) {
    final label = switch (kind) {
      'numbers' => 'From the quarterly table',
      'ledger' => 'From the promise ledger',
      'not_stated' => 'Not stated in sources',
      _ => 'Quoted from a filing',
    };
    final c = kind == 'not_stated' ? T.warn : T.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9.5, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _stepRow(Palette p, int i, bool done) {
    const labels = [
      'Retrieving source chunks',
      'Ranking by relevance',
      'Checking claims against the source',
      'Drafting answer',
    ];
    final active = i == _steps.length;
    final c = done ? T.up : (active ? T.accent : p.line);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? T.up.withValues(alpha: 0.15) : Colors.transparent,
              border: Border.all(color: c),
            ),
            child: done
                ? const Icon(Icons.check, size: 8, color: T.up)
                : (active
                    ? SizedBox(
                        width: 6,
                        height: 6,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.4, color: T.accent))
                    : null),
          ),
          const SizedBox(width: 10),
          Text(labels[i],
              style: TextStyle(fontSize: 11.5,
                  color: done ? p.ink2 : (active ? p.ink : p.ink3))),
          const Spacer(),
          if (done)
            Num('ok', size: 9, color: p.ink3),
        ],
      ),
    );
  }
}

/// Tiny helper so screens can render a tabular number without importing tokens.
class Mono extends StatelessWidget {
  const Mono(this.text, {super.key, this.size = 12, this.color});
  final String text;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: size,
          color: color ?? Palette.of(context).ink2,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()]));
}
