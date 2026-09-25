import 'package:employee_shift_management_ui/services/api_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a release build refuses a plain-http address', () {
    expect(
      () => checkApiAddress('http://10.0.2.2:8080/api/v1', isRelease: true),
      throwsStateError,
    );
  });

  test('a release build accepts an https address', () {
    expect(
      () => checkApiAddress('https://shifts.example.com/api/v1', isRelease: true),
      returnsNormally,
    );
  });

  test('a debug build may use plain http to reach the PC', () {
    expect(
      () => checkApiAddress('http://10.0.2.2:8080/api/v1', isRelease: false),
      returnsNormally,
    );
  });
}
