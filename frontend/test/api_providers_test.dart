// The network layer as the app builds it (api_providers.dart), with only the
// network itself faked: networkClientProvider is overridden with a MockClient,
// and AuthClient, ApiService and the session are the real ones.

import 'package:employee_shift_management_ui/models/user_model.dart';
import 'package:employee_shift_management_ui/services/api_providers.dart';
import 'package:employee_shift_management_ui/state/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/app_scope.dart';

User worker() =>
    User(id: 7, name: 'Worker', email: 'worker@example.com', role: 'EMPLOYEE');

void main() {
  // A rejected token navigates to login through navigatorKey, which needs
  // Flutter's binding; plain test()s do not start it the way testWidgets does.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.BaseRequest> sent;

  setUp(() => sent = []);

  /// A fake network that answers every request with [status].
  MockClient network({int status = 200}) => MockClient((request) async {
        sent.add(request);
        return http.Response('[]', status);
      });

  Future<void> loadShifts(ProviderContainer container) => container
      .read(apiServiceProvider)
      .getAllShifts(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

  test("requests carry the logged-in user's token", () async {
    final container = testContainer(
        user: worker(),
        token: 'abc',
        overrides: [networkClientProvider.overrideWithValue(network())]);

    await loadShifts(container);

    expect(sent.single.headers['Authorization'], 'Bearer abc');
  });

  test('the token is looked up per request, so a new login is used at once',
      () async {
    final container = testContainer(
        user: worker(),
        token: 'first',
        overrides: [networkClientProvider.overrideWithValue(network())]);
    final api = container.read(apiServiceProvider);

    container.read(authProvider.notifier).logIn(worker(), 'second');
    await api.getAllShifts(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

    expect(sent.single.headers['Authorization'], 'Bearer second');
  });

  test('a 401 for the current token ends the session', () async {
    final container = testContainer(
        user: worker(),
        token: 'expired',
        overrides: [
          networkClientProvider.overrideWithValue(network(status: 401))
        ]);

    await expectLater(loadShifts(container), throwsA(isA<Exception>()));

    expect(container.read(authProvider), isNull);
  });
}
