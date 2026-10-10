import 'package:ms_core/ms_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses GET /v1/disk', () {
    final u = DiskUsage.fromJson({
      'total_space': 10737418240,
      'used_space': 2469606195,
      'trash_size': 0,
    })!;
    expect(u.total, 10737418240);
    expect(u.used, 2469606195);
    expect(u.fraction, closeTo(0.23, 0.001));
  });

  test('missing fields → null; empty disk → 0', () {
    expect(DiskUsage.fromJson({'used_space': 1}), isNull);
    expect(const DiskUsage(total: 0, used: 0).fraction, 0);
  });
}
