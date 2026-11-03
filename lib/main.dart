import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'screens/alerts.dart';
import 'screens/briefing.dart';
import 'screens/research.dart';
import 'screens/settings.dart';
import 'theme/tokens.dart';
import 'widgets/ask_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(FinnApp(
    dark: prefs.getBool('dark') ?? true,
    plainEnglish: prefs.getBool('plain') ?? false,
    port: prefs.getString('portfolio') ?? 'me',
  ));
}

/// Local, non-authoritative UI preferences. Kept here so screens stay pure.
class Prefs extends InheritedNotifier<ValueNotifier<int>> {
  const Prefs({super.key, required super.child, required this.dark, required this.plain,
    required this.port, required this.onDark, required this.onPlain});
  final ValueNotifier<bool> dark;
  final ValueNotifier<bool> plain;
  final String port;
  final VoidCallback onDark;
  final VoidCallback onPlain;

  static Prefs of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Prefs>()!;
}

class FinnApp extends StatefulWidget {
  const FinnApp({super.key, required this.dark, required this.plainEnglish, required this.port});
  final bool dark;
  final bool plainEnglish;
  final String port;

  @override
  State<FinnApp> createState() => _FinnAppState();
}

class _FinnAppState extends State<FinnApp> {
  late final ValueNotifier<bool> _dark = ValueNotifier(widget.dark);
  late final ValueNotifier<bool> _plain = ValueNotifier(widget.plainEnglish);

  @override
  void dispose() {
    _dark.dispose();
    _plain.dispose();
    super.dispose();
  }

  Future<void> _save(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_dark, _plain]),
      builder: (context, _) => MaterialApp(
        title: 'FINN',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(_dark.value),
        home: Prefs(
          dark: _dark,
          plain: _plain,
          port: widget.port,
          onDark: () {
            _dark.value = !_dark.value;
            _save('dark', _dark.value);
          },
          onPlain: () {
            _plain.value = !_plain.value;
            _save('plain', _plain.value);
          },
          child: Palette(
            dark: _dark.value,
            child: const Shell(),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  int _tab = 0;
  String? _pendingResearch;

  static const _labels = ['Briefing', 'Research', 'Alerts', 'Settings'];

  void openResearch(String ticker) {
    setState(() {
      _pendingResearch = ticker;
      _tab = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pages = [
      BriefingScreen(onResearch: openResearch),
      ResearchScreen(
        key: ValueKey('research-${_pendingResearch ?? 'auto'}'),
        initialTicker: _pendingResearch,
        onResearch: openResearch,
      ),
      AlertsScreen(onResearch: openResearch),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          // Designed at 390px. On desktop web the app keeps a phone column
          // rather than stretching into a web dashboard.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(index: _tab, children: pages),
                ),
                AskBar(onOpenResearch: openResearch),
                _NavBar(
                  index: _tab,
                  labels: _labels,
                  onTap: (i) => setState(() {
                    _tab = i;
                    if (i != 1) _pendingResearch = null;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.labels, required this.onTap});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.lineSoft)),
      ),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 8, top: 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: labels[i],
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  child: SizedBox(
                    height: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 2,
                          width: i == index ? 16 : 0,
                          color: T.accent,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.2,
                            fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                            color: i == index ? p.ink : p.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared helpers used by several screens.
Future<void> openSheet(BuildContext context, Widget child, {bool expand = true}) {
  final p = Palette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.surface,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => Palette(
      dark: p.dark,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(c).size.height * (expand ? 0.92 : 0.6)),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: child,
        ),
      ),
    ),
  );
}

void toast(BuildContext context, String msg) {
  final p = Palette.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: TextStyle(color: p.ink, fontSize: 13)),
    duration: const Duration(seconds: 2),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.radius),
        side: BorderSide(color: p.line)),
  ));
}

/// Skeleton placeholder: a single quiet shimmer, no spinners.
class Skel extends StatefulWidget {
  const Skel({super.key, this.h = 12, this.w = double.infinity, this.r = 6});
  final double h;
  final double w;
  final double r;

  @override
  State<Skel> createState() => _SkelState();
}

class _SkelState extends State<Skel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.h,
        width: widget.w,
        decoration: BoxDecoration(
          color: Color.lerp(p.lineSoft, p.line, _c.value),
          borderRadius: BorderRadius.circular(widget.r),
        ),
      ),
    );
  }
}

/// Count-up on first paint. Used for the few headline numbers.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.dp = 0, this.size = 18,
    this.weight = FontWeight.w600, this.color, this.prefix = '', this.suffix = ''});
  final double value;
  final int dp;
  final double size;
  final FontWeight weight;
  final Color? color;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Num('$prefix${fmtCr(v, dp: dp)}$suffix',
          size: size, weight: weight, color: color),
    );
  }
}
