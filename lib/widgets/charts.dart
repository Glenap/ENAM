import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// All charts are hand-painted. A charting dependency would have added ~200KB
/// to the bundle for four primitives, and none of them needed interaction.

class Sparkline extends StatelessWidget {
  const Sparkline(this.values, {super.key, this.w = 64, this.h = 22,
    this.color, this.stroke = 1.4, this.fill = true});
  final List<double> values;
  final double w;
  final double h;
  final Color? color;
  final double stroke;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final clean = values.where((v) => v.isFinite).toList();
    final up = clean.length > 1 ? clean.last >= clean.first : true;
    final c = color ?? (up ? T.up : T.down);
    if (clean.length < 2) {
      return SizedBox(width: w, height: h);
    }
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(painter: _SparkPainter(clean, c, stroke, fill)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color, this.stroke, this.fill);
  final List<double> v;
  final Color color;
  final double stroke;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    final dx = size.width / (v.length - 1);
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = dx * i;
      final y = size.height - ((v[i] - lo) / span) * (size.height - stroke) - stroke / 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v || old.color != color;
}

/// Grouped bars for a quarter-vs-prior-year comparison. Two series, labelled
/// outside the bars so the numbers stay tabular and legible at 390px.
class PairedBars extends StatelessWidget {
  const PairedBars({super.key, required this.items, this.height = 62});
  final List<BarItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
    final hi = items.map((e) => math.max(e.a.abs(), e.b.abs())).reduce(math.max);
    final span = hi <= 0 ? 1.0 : hi;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final it in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bar(it.b.abs() / span * height, p.line, height),
                        const SizedBox(width: 3),
                        _bar(it.a.abs() / span * height,
                            (it.a >= it.b ? T.up : T.down), height),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final it in items)
              Expanded(
                child: Column(
                  children: [
                    Text(it.label,
                        style: TextStyle(fontSize: 9.5, color: p.ink3, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Num(fmtCr(it.a), size: 10,
                            color: it.a >= it.b ? T.up : T.down),
                        if (it.pct != null) ...[
                          const SizedBox(width: 3),
                          Num(fmtPct(it.pct), size: 9.5, color: p.ink3),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar(double h, Color c, double max) => Container(
        width: 9,
        height: h.clamp(2.0, max),
        decoration: BoxDecoration(
          color: c,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      );
}

class BarItem {
  const BarItem(this.label, this.a, this.b, {this.pct});
  final String label;
  final double a;
  final double b;
  final double? pct;
}

/// A thin revenue trend: one line, area filled, last point marked. Deliberately
/// no axes — the numbers live in the table underneath.
class TrendChart extends StatelessWidget {
  const TrendChart(this.values, {super.key, this.labels, this.height = 96,
    this.color = T.accent, this.highlight = -1});
  final List<double?> values;
  final List<String>? labels;
  final double height;
  final Color color;
  final int highlight;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pts = <int>[];
    final vals = <double>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v != null) {
        pts.add(i);
        vals.add(v);
      }
    }
    if (vals.length < 2) {
      return Center(child: Text('Not enough history', style: TextStyle(color: p.ink3, fontSize: 12)));
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrendPainter(values, color, p.lineSoft, highlight),
        child: labels == null
            ? null
            : Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final l in labels!)
                      Text(l,
                          style: TextStyle(fontSize: 8.5, color: p.ink3, letterSpacing: 0.2)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.v, this.color, this.grid, this.highlight);
  final List<double?> v;
  final Color color;
  final Color grid;
  final int highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final vals = v.whereType<double>().toList();
    if (vals.length < 2) return;
    final lo = math.min(vals.reduce(math.min), 0).toDouble();
    final hi = vals.reduce(math.max) * 1.06;
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    final pad = size.height * 0.10;
    final usable = size.height - pad - 6;
    final n = v.length;
    final dx = size.width / (n - 1);

    double yOf(double d) => pad + usable - ((d - lo) / span) * usable;

    // baseline
    canvas.drawLine(Offset(0, size.height - 6), Offset(size.width, size.height - 6),
        Paint()..color = grid..strokeWidth = 1);

    final path = Path();
    var started = false;
    for (var i = 0; i < n; i++) {
      final d = v[i];
      if (d == null) continue;
      final x = dx * i, y = yOf(d);
      if (_isFirst(i)) {
        path.moveTo(x, y);
        started = true;
      } else if (started) {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height - 6)
      ..lineTo(0, size.height - 6)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.01)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );

    final last = vals.last;
    final lx = dx * (n - 1), ly = yOf(last);
    canvas.drawCircle(Offset(lx, ly), 3.0, Paint()..color = color);
    canvas.drawCircle(Offset(lx, ly), 6.0, Paint()..color = color.withValues(alpha: 0.18));
  }

  bool _isFirst(int i) {
    for (var j = 0; j < i; j++) {
      if (v[j] != null) return false;
    }
    return true;
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.v != v || old.color != color;
}

/// Range bar: a value plotted between its 52-week low and high, with the
/// midpoint marked. Cheaper to read than a chart of the whole year.
class RangeBar extends StatelessWidget {
  const RangeBar({super.key, required this.value, required this.low, required this.high,
    this.height = 6});
  final double value;
  final double low;
  final double high;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final span = (high - low).abs() < 1e-9 ? 1.0 : high - low;
    final t = ((value - low) / span).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: height + 10,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: p.lineSoft,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
            Positioned(
              left: (w - 9) * t,
              child: Container(
                width: 9,
                height: height + 8,
                decoration: BoxDecoration(
                  color: T.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Confidence of an extraction, as a row of ticks. Reads as "3 of 3 checks
/// passed" at a glance without a percentage badge.
class ConfidenceTicks extends StatelessWidget {
  const ConfidenceTicks({super.key, required this.passed, required this.total,
    this.label = 'checks'});
  final int passed;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final on = total <= 0 ? T.ink3 : (passed >= total ? T.up : (passed > 0 ? T.warn : T.down));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < math.max(total, 1); i++)
          Container(
            width: 10,
            height: 3,
            margin: const EdgeInsets.only(right: 2),
            color: i < passed ? on : p.line,
          ),
        const SizedBox(width: 5),
        Text('$passed/$total $label',
            style: TextStyle(fontSize: 9.5, color: p.ink3, letterSpacing: 0.2)),
      ],
    );
  }
}

/// Portfolio heat strip: one cell per holding, coloured by day move. This is
/// the one place colour density is intentional — the eye finds the outlier.
class HeatStrip extends StatelessWidget {
  const HeatStrip({super.key, required this.cells, this.height = 26});
  final List<HeatCell> cells;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (cells.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final c in cells)
            Expanded(
              child: Tooltip(
                message: '${c.ticker} ${fmtPct(c.pct, dp: 1)}',
                child: Container(
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: _heat(c.pct, p),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _heat(double pct, Palette p) {
    final a = (pct.abs() / 4).clamp(0.0, 1.0);
    final base = pct >= 0 ? T.up : T.down;
    return Color.lerp(p.lineSoft, base, 0.18 + a * 0.82)!;
  }
}

class HeatCell {
  const HeatCell(this.ticker, this.pct);
  final String ticker;
  final double pct;
}
