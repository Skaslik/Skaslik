import 'package:flutter_test/flutter_test.dart';
import 'package:ms_app/core/sync/sync_service.dart';

void main() {
  // The app's SyncService is one global for the app's lifetime; a provider
  // scope going away (tests, a nested scope) must not kill it.
  test('the global sync service survives a scope disposing it', () {
    final s = SyncService();
    s.dispose();
    var heard = 0;
    s.addListener(() => heard++);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    s.notifyListeners();
    expect(heard, 1);
  });
}
