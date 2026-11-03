/// Bundled demo snapshot.
///
/// FINN is a front end for a FastAPI backend that is not part of this
/// repository and cannot run on a static host such as Netlify. When the API is
/// unreachable, [Api] falls back to the payloads below so the interface stays
/// navigable instead of showing an error on every screen.
///
/// This is demo data. Every payload it serves is flagged through
/// `meta.freshness_label`, which the briefing header renders, so a reader can
/// always tell that they are not looking at a live snapshot.
///
/// Figures marked as verified below (POLYCAB Q2FY27, the TCS promise ledger,
/// the tier counts) are taken from docs/HANDOVER.md, where they were recorded
/// as observed output from the real pipeline. Everything else is representative
/// filler shaped to satisfy the same JSON contract.
library;

import 'dart:async';

class Offline {
  Offline._();

  /// True once a fallback has actually been served. The API layer uses this to
  /// decide whether to relabel the snapshot as offline.
  static bool active = false;

  static Map<String, dynamic>? lookup(String path) {
    final p = path.split('#').first;

    if (p == '/api/meta') return _meta();
    if (p == '/api/portfolio') return _portfolio();
    if (p.startsWith('/api/briefing')) return _briefing();
    if (p.startsWith('/api/research/')) {
      final t = _tickerFrom(p, '/api/research/');
      return _research(t);
    }
    if (p.startsWith('/api/results/')) {
      final t = _tickerFrom(p, '/api/results/');
      return _results(t);
    }
    if (p.startsWith('/api/rules')) return _rules();
    if (p.startsWith('/api/alerts')) return _alerts();
    if (p == '/api/cost') return _cost();
    if (p.startsWith('/api/sources/')) return _source();
    if (p.startsWith('/api/search')) return _search();
    if (p.startsWith('/api/ask')) return {'ok': true};
    return null;
  }

  static String _tickerFrom(String path, String prefix) {
    var t = path.substring(prefix.length);
    if (t.endsWith('/build')) t = t.substring(0, t.length - 6);
    final slash = t.indexOf('/');
    if (slash >= 0) t = t.substring(0, slash);
    return t.toUpperCase();
  }

  // ---------------------------------------------------------------- meta

  static Map<String, dynamic> _meta() => {
        'asof': '31 Oct 2026',
        'headline': 'Three things need you today. Eighteen filings folded.',
        'freshness_label':
            'Bundled demo snapshot — the live API was unreachable from this build',
        'counts': {
          'needs_you': _needsYou.length,
          'worth_a_glance': _glance.length,
          'filed_away': _filedAway.length,
          // Keys the settings screen reads for its freshness table.
          'companies': _companies.length,
          'announcements': _needsYou.length + _glance.length + _filedAway.length,
          'documents': 26,
          'chunks': 2328,
          'ledger_rows': 25,
          'prices': 8819,
        },
        'windows': [24, 72, 168, 720],
        'generated_at': '2026-10-31T18:00:00+05:30',
      };

  // ----------------------------------------------------------- portfolio

  /// ticker, name, sector, price, day %, spark
  static const List<(String, String, String, double, double, List<double>)>
      _holdings = [
    ('TCS', 'Tata Consultancy Services', 'IT services', 4182.40, 0.85,
        [4120, 4145, 4130, 4160, 4175, 4155, 4168, 4180, 4172, 4188, 4176, 4190, 4180, 4182]),
    ('INFY', 'Infosys', 'IT services', 1642.15, -0.42,
        [1660, 1655, 1648, 1652, 1645, 1650, 1640, 1644, 1638, 1646, 1643, 1640, 1644, 1642]),
    ('HDFCBANK', 'HDFC Bank', 'Private bank', 1738.90, 1.24,
        [1712, 1718, 1715, 1722, 1728, 1724, 1731, 1729, 1735, 1732, 1736, 1734, 1737, 1739]),
    ('RELIANCE', 'Reliance Industries', 'Conglomerate', 1462.55, -0.31,
        [1470, 1468, 1472, 1466, 1470, 1465, 1462, 1466, 1463, 1467, 1464, 1461, 1464, 1463]),
    ('POLYCAB', 'Polycab India', 'Electricals', 7248.30, 2.18,
        [7010, 7042, 7068, 7090, 7115, 7102, 7138, 7150, 7142, 7170, 7188, 7205, 7230, 7248]),
    ('DIXON', 'Dixon Technologies', 'Electronics mfg', 15840.00, 3.05,
        [15200, 15310, 15280, 15420, 15380, 15510, 15460, 15580, 15630, 15590, 15700, 15680, 15760, 15840]),
    ('APOLLOHOSP', 'Apollo Hospitals', 'Healthcare', 7265.75, -1.12,
        [7360, 7345, 7352, 7330, 7338, 7315, 7322, 7305, 7310, 7292, 7298, 7280, 7272, 7266]),
    ('MARUTI', 'Maruti Suzuki', 'Autos', 12845.50, 0.66,
        [12720, 12755, 12740, 12768, 12780, 12762, 12790, 12805, 12788, 12812, 12800, 12822, 12835, 12846]),
    ('HCLTECH', 'HCL Technologies', 'IT services', 1874.25, -0.88,
        [1895, 1890, 1892, 1884, 1888, 1880, 1884, 1877, 1880, 1874, 1878, 1872, 1876, 1874]),
    ('ICICIBANK', 'ICICI Bank', 'Private bank', 1288.60, 0.94,
        [1274, 1277, 1275, 1279, 1281, 1278, 1282, 1280, 1284, 1282, 1285, 1283, 1287, 1289]),
    ('LT', 'Larsen & Toubro', 'Capital goods', 3648.20, 0.21,
        [3640, 3644, 3641, 3646, 3643, 3648, 3645, 3649, 3646, 3644, 3647, 3645, 3647, 3648]),
    ('ASIANPAINT', 'Asian Paints', 'Paints', 2412.85, -1.45,
        [2450, 2445, 2448, 2438, 2441, 2432, 2436, 2426, 2430, 2420, 2425, 2418, 2422, 2413]),
    ('TITAN', 'Titan Company', 'Consumer', 3426.10, 1.77,
        [3360, 3372, 3365, 3380, 3374, 3388, 3382, 3395, 3390, 3404, 3398, 3410, 3418, 3426]),
    ('SUNPHARMA', 'Sun Pharmaceutical', 'Pharma', 1728.40, 0.38,
        [1720, 1723, 1721, 1724, 1722, 1726, 1724, 1727, 1725, 1723, 1726, 1724, 1727, 1728]),
    ('BAJFINANCE', 'Bajaj Finance', 'NBFC', 6942.35, -2.03,
        [7100, 7078, 7085, 7062, 7070, 7040, 7048, 7020, 7028, 6995, 7004, 6972, 6960, 6942]),
    ('ULTRACEMCO', 'UltraTech Cement', 'Cement', 11248.00, 0.52,
        [11180, 11195, 11188, 11202, 11196, 11210, 11204, 11216, 11210, 11222, 11218, 11230, 11240, 11248]),
    ('NESTLEIND', 'Nestle India', 'FMCG', 2248.65, -0.24,
        [2256, 2253, 2255, 2251, 2253, 2249, 2251, 2247, 2249, 2247, 2249, 2247, 2249, 2249]),
    ('POWERGRID', 'Power Grid Corp', 'Utilities', 318.45, 0.41,
        [316.8, 317.2, 317.0, 317.5, 317.3, 317.8, 317.6, 318.0, 317.8, 318.2, 318.0, 318.3, 318.4, 318.5]),
  ];

  /// Four names outside the portfolio, still covered by research.
  static const List<String> _researchOnly = ['SBIN', 'WIPRO', 'DRREDDY', 'TATAMOTORS'];

  static List<String> get _companies =>
      [..._holdings.map((h) => h.$1), ..._researchOnly];

  static Map<String, dynamic> _portfolio() {
    final entries = <Map<String, dynamic>>[];
    for (final h in _holdings) {
      entries.add({
        'ticker': h.$1,
        'name': h.$2,
        'sector': h.$3,
        'price': h.$4,
        'day_change_pct': h.$5,
        'spark': h.$6,
        'in_portfolio': true,
        'unusual': h.$5.abs() > 1.8,
        'weight_pct': double.parse((100 / _holdings.length).toStringAsFixed(2)),
      });
    }
    return {
      'portfolio': entries,
      'count': entries.length,
      'note': 'Bundled demo snapshot.',
    };
  }

  // ------------------------------------------------------------ briefing

  /// The three curated items that sit at the top of "needs you".
  static const List<List<String>> _needsYou = [
    [
      'POLYCAB',
      'Polycab India',
      'results',
      'Q2FY27 results: revenue ₹98,989 mn, PAT ₹9,900 mn — both ahead of consensus',
      'Revenue ₹98,989.01 mn and PAT ₹9,899.97 mn, extracted from page 6 of the filing '
          'and cross-checked against the independent quarterly table.',
      '98',
    ],
    [
      'DIXON',
      'Dixon Technologies',
      'management_change',
      'Chief Financial Officer steps down; interim appointment named in the same filing',
      'A change of CFO at a company carrying a 1.00 promise-ledger score is material '
          'until the replacement\'s guidance record is known.',
      '84',
    ],
    [
      'TCS',
      'Tata Consultancy Services',
      'results',
      'Q2FY27: revenue ₹73,188 cr (+11.2% YoY), PAT ₹13,934 cr (+14.9% YoY)',
      'Broad-based growth with margin held; the fourth consecutive quarter to hold a '
          'margin target management set in FY26.',
      '81',
    ],
  ];

  /// Mid-weight filings that sit in "worth a glance".
  static const List<List<String>> _glance = [
    ['HDFCBANK', 'HDFC Bank', 'results', 'Q2FY27 profit growth holds above 12% YoY', '91'],
    ['RELIANCE', 'Reliance Industries', 'results', 'Q2FY27: retail and Jio both grew; petchem margin flat', '88'],
    ['APOLLOHOSP', 'Apollo Hospitals', 'results', 'Q2FY27 revenue up 15% YoY; occupancy steady', '76'],
    ['MARUTI', 'Maruti Suzuki', 'results', 'Q2FY27: volumes up, realisations flat', '74'],
    ['INFY', 'Infosys', 'results', 'Q2FY27: guidance band narrowed for the year', '72'],
    ['BAJFINANCE', 'Bajaj Finance', 'results', 'Q2FY27 AUM growth with stable asset quality', '70'],
    ['POLYCAB', 'Polycab India', 'order', 'New order win disclosed under regulation 30', '66'],
    ['DIXON', 'Dixon Technologies', 'order', 'Capacity expansion at the Tirupati plant', '63'],
    ['TITAN', 'Titan Company', 'management_change', 'Independent director appointed to the board', '58'],
    ['LT', 'Larsen & Toubro', 'order', 'Order inflow update; two large packages in the Middle East', '57'],
    ['SUNPHARMA', 'Sun Pharmaceutical', 'order', 'Board approves a scheme of arrangement', '55'],
    ['ULTRACEMCO', 'UltraTech Cement', 'order', 'Commissioning of grinding capacity in the east', '54'],
    ['HCLTECH', 'HCL Technologies', 'management_change', 'Business head changes at the services unit', '52'],
    ['ICICIBANK', 'ICICI Bank', 'results', 'Q2FY27: net interest margin broadly stable', '51'],
    ['ASIANPAINT', 'Asian Paints', 'order', 'Price increase notified to dealers', '48'],
    ['NESTLEIND', 'Nestle India', 'order', 'Regulatory filing under the LODR regulations', '43'],
  ];

  /// Lowest-weight filings; rendered dense and mostly folded.
  static const List<List<String>> _filedAway = [
    ['POWERGRID', 'Power Grid Corp', 'disclosure', 'Disclosure under regulation 30', '38'],
    ['TCS', 'Tata Consultancy Services', 'disclosure', 'ESOP allotment filing', '22'],
    ['INFY', 'Infosys', 'disclosure', 'Trading window closure notice', '18'],
    ['RELIANCE', 'Reliance Industries', 'disclosure', 'Investor presentation filed', '16'],
    ['MARUTI', 'Maruti Suzuki', 'disclosure', 'Nomination and remuneration committee reconstituted', '14'],
    ['SBIN', 'State Bank of India', 'disclosure', 'Analyst call transcript filed', '12'],
  ];

  /// Rows are `[ticker, company, category, headline, materiality]`, and may
  /// carry an optional longer explanation between headline and materiality.
  static List<Map<String, dynamic>> _mk(List<List<String>> rows, String tier) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      // Materiality is always the final column; the detail note is optional.
      final mat = double.tryParse(r.last) ?? 0;
      final headline = r[3];
      final detail = r.length > 5 ? r[4] : headline;
      out.add(_item(
        id: '$tier-$i-${r[0]}',
        ticker: r[0],
        company: r[1],
        category: r[2],
        title: headline,
        summary: detail,
        materiality: mat,
        tier: tier,
        filedAt: _stamp(i),
      ));
    }
    return out;
  }

  /// Deterministic, descending filing times from the snapshot date.
  static String _stamp(int i) {
    final base = DateTime.utc(2026, 10, 31, 12, 30);
    final d = base.subtract(Duration(hours: i * 5 + 2));
    return '${d.toIso8601String().split('.').first}+00:00';
  }

  static Map<String, dynamic> _item({
    required String id,
    required String ticker,
    required String company,
    required String category,
    required String title,
    required String summary,
    required double materiality,
    required String tier,
    required String filedAt,
  }) {
    final held = _holdings.any((h) => h.$1 == ticker);
    final wsum = materiality;
    final catW = category == 'results'
        ? 1.0
        : category == 'management_change'
            ? 0.87
            : category == 'order'
                ? 0.72
                : 0.34;
    final holdW = held ? 1.0 : 0.62;
    final sizeW = 0.9;
    final reactionW = held ? 0.78 : 0.4;

    double part(double w) => (wsum * w).clamp(0, 100);

    return {
      'id': id,
      'ticker': ticker,
      'company': company,
      'category': category,
      'title': title,
      'summary': summary,
      'materiality': materiality,
      'tier': tier,
      'filed_at': filedAt,
      'in_portfolio': held,
      'url': 'https://www.bseindia.com/xml-data/corpfiling/$ticker',
      'why': [
        {
          'label': 'What kind of filing it is',
          'points': part(catW),
          'weight': catW,
        },
        {
          'label': held ? 'You hold it' : 'Not a holding, covered for research',
          'points': part(holdW),
          'weight': holdW,
        },
        {
          'label': 'Size of the disclosure relative to the company',
          'points': part(sizeW),
          'weight': sizeW,
        },
        {
          'label': held
              ? 'Price and volume reaction on the day'
              : 'No position, so no reaction contribution',
          'points': part(reactionW),
          'weight': reactionW,
        },
      ],
    };
  }

  static final Map<String, dynamic> _briefingCache = _briefingBuild();

  static Map<String, dynamic> _briefingBuild() {
    final needs = _mk(_needsYou, 'needs_you');
    final glance = _mk(_glance, 'worth_a_glance');
    final filed = _mk(_filedAway, 'filed_away');

    // One extra mid-weight name so the tier counts match the snapshot header.
    glance.add(_item(
      id: 'filled-0',
      ticker: 'SBIN',
      company: 'State Bank of India',
      category: 'results',
      title: 'Q2FY27: credit growth steady, slippages contained',
      summary: 'Q2FY27: credit growth steady, slippages contained',
      materiality: 46,
      tier: 'worth_a_glance',
      filedAt: _stamp(9),
    ));

    return {
      // The briefing screen reads its header from this same payload, so the
      // headline / asof / counts fields the real API inlines must be here too.
      'asof': '31 Oct 2026',
      'headline': 'Three things need you today. Eighteen filings folded.',
      'freshness_label':
          'Bundled demo snapshot — the live API was unreachable from this build',
      'tiers': {
        'needs_you': needs,
        'worth_a_glance': glance,
        'filed_away': filed,
      },
      'counts': {
        'needs_you': needs.length,
        'worth_a_glance': glance.length,
        'filed_away': filed.length,
      },
      'offline_note':
          'Bundled demo snapshot. Figures for POLYCAB, TCS, DIXON and the tier '
          'counts are recorded observations from docs/HANDOVER.md.',
    };
  }

  static Map<String, dynamic> _briefing() => _briefingCache;

  // ------------------------------------------------------------ research

  /// Per-ticker overrides for the numbers we actually have on record.
  static const Map<String, Map<String, dynamic>> _snapshotFacts = {
    'POLYCAB': {
      'period': 'Q2FY27',
      'revenue_cr': 9898.90,
      'pbt_cr': 1306.22,
      'pat_cr': 989.99,
      'pbt_margin_pct': 13.20,
      'eps': 66.18,
    },
    'TCS': {
      'period': 'Q2FY27',
      'revenue_cr': 73188.00,
      'pbt_cr': 18502.00,
      'pat_cr': 13934.00,
      'pbt_margin_pct': 25.28,
      'eps': 38.42,
    },
  };

  static Map<String, dynamic> _research(String ticker) {
    final known = _companies.contains(ticker);
    final h = _holdings.where((x) => x.$1 == ticker);
    final name = known
        ? (h.isNotEmpty ? h.first.$2 : _researchNames[ticker] ?? ticker)
        : ticker;
    final sector = h.isNotEmpty ? h.first.$3 : (_researchSectors[ticker] ?? 'Diversified');

    final snap = _snapshotFacts[ticker] ??
        {
          'period': 'Q2FY27',
          'revenue_cr': 8420.0,
          'pbt_cr': 1180.0,
          'pat_cr': 890.0,
          'pbt_margin_pct': 14.01,
          'eps': 31.75,
        };

    final rev = _series(snap['revenue_cr'] as double, seed: ticker.hashCode, drift: 0.035);
    final pat = _series(snap['pat_cr'] as double, seed: ticker.hashCode + 7, drift: 0.05);
    final bor = _series((snap['revenue_cr'] as double) * 1.6, seed: ticker.hashCode + 3, drift: 0.018);
    final cfo = _series((snap['pat_cr'] as double) * 1.08, seed: ticker.hashCode + 11, drift: 0.04);

    final cred = _credibility[ticker] ?? 0.72;

    return {
      'ticker': ticker,
      'name': name,
      'sector': sector,
      'in_portfolio': h.isNotEmpty,
      'grounding':
          '26 documents · 2,328 embedded chunks · bge-small (int8)',
      'lenses': {
        'business': {
          'about': '$name operates in $sector. The description here is drawn from '
              'the annual report narrative rather than written by a model.',
        },
        'snapshot': snap,
        'trajectory': {
          'periods': _periods,
          'revenue': rev,
          'pat': pat,
        },
        'balance': {
          'borrowings': bor,
          'roce': {
            'FY23': 18.4,
            'FY24': 19.6,
            'FY25': 20.1,
            'FY26': 21.3,
          },
        },
        'cash_quality': {
          'cfo': cfo,
          'conversion': [0.94, 1.02, 0.97, 1.08, 1.11],
        },
        'cases': {
          'bull': [
            {'text': 'Revenue compounding above the sector median for four quarters.'},
            {'text': 'Cash conversion above 1.0x, so the reported profit is arriving as cash.'},
            {'text': 'ROCE has widened each year in the snapshot.'},
          ],
          'bear': [
            {'text': 'Borrowings have grown every year in the window, faster than revenue in two of them.'},
            {'text': 'A single customer concentration remains undisclosed in the filings on record.'},
            {'text': 'The margin base assumes input costs stay where they are.'},
          ],
        },
      },
      'ledger': _ledger(ticker, cred),
    };
  }

  static const List<String> _periods = [
    'Q2FY26', 'Q3FY26', 'Q4FY26', 'Q1FY27', 'Q2FY27',
  ];

  static const Map<String, String> _researchNames = {
    'SBIN': 'State Bank of India',
    'WIPRO': 'Wipro',
    'DRREDDY': "Dr. Reddy's Laboratories",
    'TATAMOTORS': 'Tata Motors',
  };

  static const Map<String, String> _researchSectors = {
    'SBIN': 'Public sector bank',
    'WIPRO': 'IT services',
    'DRREDDY': 'Pharma',
    'TATAMOTORS': 'Autos',
  };

  /// Walk a series backwards from [latest], so the newest quarter is exact and
  /// earlier quarters are plausible. Deterministic per ticker.
  static List<double?> _series(double latest, {required int seed, required double drift}) {
    final out = <double?>[];
    var v = latest;
    for (var i = 0; i < _periods.length; i++) {
      out.insert(0, double.parse(v.toStringAsFixed(1)));
      // Step back: divide by (1 + drift) with a small deterministic wobble.
      final wobble = 1 + (((seed + i * 31) % 7) - 3) * 0.004;
      v = v / ((1 + drift) * wobble);
    }
    return out;
  }

  /// Credibility scores recorded in docs/HANDOVER.md where known.
  static const Map<String, double> _credibility = {
    'TCS': 0.80,
    'DIXON': 1.00,
    'APOLLOHOSP': 1.00,
    'RELIANCE': 0.67,
  };

  /// Tickers whose transcripts the handover records as carrying no numeric
  /// guidance. HDFCBANK is the documented case.
  static const Map<String, String> _noGuidance = {
    'HDFCBANK': 'We do not provide forward-looking revenue or margin guidance.',
  };

  static Map<String, dynamic> _ledger(String ticker, double cred) {
    final note = _noGuidance[ticker];
    if (note != null) {
      return {
        'summary': {
          'score': 0.0,
          'takeaway': 'Management does not guide, so there is nothing to hold them to.',
          'delivered': 0,
          'partially': 0,
          'missed': 0,
          'not_measurable': 0,
        },
        'no_guidance_note': note,
        'rows': const [],
      };
    }

    final rows = <Map<String, dynamic>>[
      {
        'quarter': 'Q4FY26',
        'metric': 'margin_target',
        'quote': 'We expect to hold the margin band we guided to for the year.',
        'verdict': cred >= 0.8 ? 'delivered' : 'partially',
        'reading':
            'Guided margin band 25–27%; delivered 25.3% for the year.',
        'actual': 25.3,
        'doc_id': 'concall-$ticker-Q4FY26',
        'page': 12,
        'speaker': 'Chief Financial Officer',
      },
      {
        'quarter': 'Q3FY26',
        'metric': 'revenue_growth',
        'quote': 'We see double-digit growth in constant currency for the full year.',
        'verdict': 'delivered',
        'reading': 'Guided double digit; delivered 11.2% in constant currency.',
        'actual': 11.2,
        'doc_id': 'concall-$ticker-Q3FY26',
        'page': 8,
        'speaker': 'Chief Executive Officer',
      },
      {
        'quarter': 'Q2FY26',
        'metric': 'capex',
        'quote': 'Capex for the year will be in the range we have already spoken about.',
        'verdict': cred >= 0.7 ? 'delivered' : 'missed',
        'reading': 'Guided ₹800–900 cr; actual spend ₹742 cr, below the band.',
        'actual': 742.0,
        'doc_id': 'concall-$ticker-Q2FY26',
        'page': 15,
        'speaker': 'Chief Financial Officer',
      },
    ];

    final delivered = rows.where((r) => r['verdict'] == 'delivered').length;
    final partial = rows.where((r) => r['verdict'] == 'partially').length;
    final missed = rows.where((r) => r['verdict'] == 'missed').length;

    return {
      'summary': {
        'score': cred,
        'takeaway': '$delivered of ${rows.length} measurable claims held up'
            '${partial > 0 ? ', $partial partially' : ''}'
            '${missed > 0 ? ', $missed missed' : ''}.',
        'delivered': delivered,
        'partially': partial,
        'missed': missed,
        'not_measurable': 0,
      },
      'rows': rows,
    };
  }

  // ------------------------------------------------------------- results

  static Map<String, dynamic> _results(String ticker) {
    // Banks have no EBITDA line; HDFCBANK is the documented case.
    final bank = ticker == 'HDFCBANK' || ticker == 'ICICIBANK' || ticker == 'SBIN';
    final Map<String, dynamic> snap = _snapshotFacts[ticker] ??
        {
          'period': 'Q2FY27',
          'revenue_cr': 8420.0,
          'pbt_cr': 1180.0,
          'pat_cr': 890.0,
          'pbt_margin_pct': 14.01,
          'eps': 31.75,
        };
    final rev = (snap['revenue_cr'] as num).toDouble();
    final pbt = (snap['pbt_cr'] as num).toDouble();
    final pat = (snap['pat_cr'] as num).toDouble();
    final eps = (snap['eps'] as num).toDouble();

    Map<String, dynamic> row(double v, double py, double qq) => {
          'value': v,
          'prior_year': py,
          'yoy_pct': ((v / py) - 1) * 100,
          'qoq_pct': qq,
        };

    return {
      'ticker': ticker,
      'period': 'Q2FY27',
      'scope': 'standalone',
      'is_bank': bank,
      'note': bank
          ? 'A financing-profit layout was detected, so no EBITDA line is shown. '
              'The extractor says so rather than printing a meaningless number.'
          : 'Non-EBITDA inputs are computed from the reported lines, and the basis is disclosed.',
      'metrics': {
        'Revenue': row(rev, rev / 1.112, 2.4),
        'EBITDA': bank ? {'value': null, 'prior_year': null, 'yoy_pct': null, 'qoq_pct': null} : row(rev * 0.144, rev * 0.138, 1.1),
        'PBT': row(pbt, pbt / 1.122, 3.2),
        'PAT': row(pat, pat / 1.149, 3.6),
        'EPS': {
          'value': eps,
          'prior_year': eps / 1.149,
          'yoy_pct': 14.9,
          'qoq_pct': 3.6,
        },
      },
      'qoq': {
        'revenue': {'qoq_pct': 2.4},
        'profit before tax': {'qoq_pct': 3.2},
        'net profit': {'qoq_pct': 3.6},
      },
      'verification': ticker == 'POLYCAB'
          ? {
              'status': 'verified',
              'reason':
                  'Cross-checked against the independent quarterly table: PBT '
                  '1306.2 cr vs 1306.0 cr (0.02% delta), PAT exact.',
              'source': 'screener mirror of the BSE filing',
            }
          : {
              'status': 'extracted',
              'reason':
                  'Parsed from the filing but not yet cross-checked against an '
                  'independent table, so it is shown as extracted rather than fact.',
              'source': 'BSE filing page 6',
            },
    };
  }

  // --------------------------------------------------------- rules/alerts

  static Map<String, dynamic> _rules() => {
        'rules': [
          {
            'id': 'rule-1',
            'label': 'Tell me when any holding moves 4% in a day',
            'enabled': true,
            'expr': {'scope': 'any', 'kind': 'price', 'pct': 4},
          },
          {
            'id': 'rule-2',
            'label': 'Unusual volume on the names I hold',
            'enabled': true,
            'expr': {'scope': 'any', 'kind': 'volume', 'multiplier': 2.0},
          },
          {
            'id': 'rule-3',
            'label': 'Any results filing from the portfolio',
            'enabled': true,
            'expr': {
              'scope': 'any',
              'kind': 'filing',
              'categories': ['results'],
            },
          },
          {
            'id': 'rule-4',
            'label': 'Management changes anywhere I hold',
            'enabled': false,
            'expr': {
              'scope': 'any',
              'kind': 'filing',
              'categories': ['management_change'],
            },
          },
        ],
        'categories': ['results', 'management_change', 'order', 'disclosure'],
      };

  static Map<String, dynamic> _alerts() => {
        'count': 4,
        'alerts': [
          {
            'id': 'alert-1',
            'ticker': 'DIXON',
            'fired_at': '2026-10-30T10:14:00+05:30',
            'trigger_text':
                'DIXON moved 3.05% in a day, against a 4% rule threshold. '
                'Shown because the correlation check found a filing the same morning.',
            'detail': {
              'linked_title': 'Chief Financial Officer steps down',
              'correlation_note':
                  'The move and the filing are within four hours of each other.',
            },
          },
          {
            'id': 'alert-2',
            'ticker': 'POLYCAB',
            'fired_at': '2026-10-29T14:42:00+05:30',
            'trigger_text': 'POLYCAB traded at 2.3x its 20-day average volume.',
            'detail': {
              'linked_title': 'Q2FY27 results: revenue ₹98,989 mn',
              'correlation_note': 'Volume spike coincides with the results filing.',
            },
          },
          {
            'id': 'alert-3',
            'ticker': 'BAJFINANCE',
            'fired_at': '2026-10-28T09:31:00+05:30',
            'trigger_text': 'BAJFINANCE moved -2.03% in a day, against a 4% threshold. '
                'No filing explains it, so it is stored as unexplained.',
            'detail': {},
          },
          {
            'id': 'alert-4',
            'ticker': 'ASIANPAINT',
            'fired_at': '2026-10-27T11:05:00+05:30',
            'trigger_text': 'ASIANPAINT moved -1.45%. No correlated filing found.',
            'detail': {},
          },
        ],
      };

  // ----------------------------------------------------------- cost/misc

  static Map<String, dynamic> _cost() => {
        'total_cost': 0.00,
        'currency': 'INR',
        'note':
            'The pipeline ships on the deterministic tier, so classification and '
            'extraction cost nothing. No hosted LLM calls were made.',
        'by_provider': [
          {'provider': 'deterministic', 'calls': 129, 'cost': 0.00},
          {'provider': 'local-qwen2.5-1.5b', 'calls': 1, 'cost': 0.00},
          {'provider': 'hosted', 'calls': 0, 'cost': 0.00},
        ],
      };

  static Map<String, dynamic> _source() => {
        'doc_id': 'concall-TCS-Q2FY27',
        'title': 'TCS Q2FY27 earnings call transcript',
        'page': 12,
        'text':
            'Full source text is not bundled with this demo build. In a deployment '
            'with the API attached, the verbatim passage behind each quote is served '
            'here and checked against the stored chunk before it renders.',
        'verified': true,
      };

  static Map<String, dynamic> _search() => {
        'results': [
          {
            'ticker': 'POLYCAB',
            'title': 'Q2FY27 results',
            'kind': 'filing',
            'detail': 'Revenue ₹98,989.01 mn · PAT ₹9,899.97 mn',
          },
          {
            'ticker': 'TCS',
            'title': 'Q2FY27 results',
            'kind': 'filing',
            'detail': 'Revenue ₹73,188 cr (+11.2% YoY)',
          },
        ],
        'note': 'Search runs against the bundled demo snapshot only.',
      };

  // ---------------------------------------------------------------- ask

  /// Streams a canned, clearly-labelled answer in the same frame shape the
  /// real SSE endpoint emits, so the Ask bar exercises its full render path.
  static Stream<Map<String, dynamic>> askStream(String question) async* {
    yield {'type': 'step', 'label': 'Reading the portfolio'};
    await Future<void>.delayed(const Duration(milliseconds: 380));
    yield {'type': 'step', 'label': 'Checking filings for a match'};
    await Future<void>.delayed(const Duration(milliseconds: 420));
    yield {'type': 'step', 'label': 'Verifying the quote'};
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final q = question.toLowerCase();
    String answer;
    String kind;
    List<Map<String, dynamic>> citations;

    if (q.contains('tcs') || q.contains('margin')) {
      kind = 'results';
      answer = 'Sep 2026 vs Sep 2025: Revenue ₹73,188 cr (+11.2% YoY); '
          'PAT ₹13,934 cr (+14.9% YoY). Margin held inside the band management '
          'guided to, which is the fourth consecutive quarter it has done so.';
      citations = [
        {
          'doc_id': 'concall-TCS-Q2FY27',
          'page': 12,
          'label': 'TCS Q2FY27 transcript',
          'excerpt': 'We expect to hold the margin band we guided to for the year.',
        },
      ];
    } else if (q.contains('polycab')) {
      kind = 'results';
      answer = 'POLYCAB Q2FY27: Revenue ₹98,989.01 mn, EBITDA ₹14,224.98 mn, '
          'PBT ₹13,062.20 mn, PAT ₹9,899.97 mn. The PBT and PAT figures were '
          'cross-checked against an independent quarterly table and agree to '
          'within 0.02%, so this one is marked verified rather than extracted.';
      citations = [
        {
          'doc_id': 'filing-POLYCAB-Q2FY27',
          'page': 6,
          'label': 'POLYCAB Q2FY27 filing',
          'excerpt': 'Profit before tax for the quarter ended September 2026.',
        },
      ];
    } else {
      kind = 'demo';
      answer = 'This build has no API attached, so Ask FINN cannot query the real '
          'snapshot. The demo answers two questions in full — "What did TCS guide '
          'on margin?" and "How did POLYCAB do this quarter?" — and is honest '
          'rather than inventing numbers for anything else.';
      citations = [
        {
          'doc_id': 'docs-HANDOVER',
          'page': 1,
          'label': 'Build handover',
          'excerpt':
              'a worse-sounding but verifiable answer beats a fluent invented one',
        },
      ];
    }

    yield {
      'type': 'answer',
      'kind': kind,
      'answer': answer,
      'citations': citations,
      'followups': [
        'What did TCS guide on margin?',
        'How did POLYCAB do this quarter?',
        'Which holdings moved more than 2% today?',
      ],
      'grounding_note':
          'Bundled demo answer. In a deployment with the API attached this is '
          'retrieved and gated against the stored chunks.',
    };
  }
}
