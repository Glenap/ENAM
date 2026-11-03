import 'package:flutter_test/flutter_test.dart';
import 'package:finn/theme/tokens.dart';

void main() {
  test('currency formatting groups thousands and keeps sign', () {
    expect(fmtCr(73188), '73,188');
    expect(fmtCr(1234567), '1,234,567');
    expect(fmtCr(-4500), '-4,500');
    expect(fmtCr(null), '—');
  });

  test('percentage formatting carries an explicit sign', () {
    expect(fmtPct(11.24), '+11.2%');
    expect(fmtPct(-3.5), '-3.5%');
    expect(fmtPct(0), '0.0%');
    expect(fmtPct(null), '—');
  });
}
