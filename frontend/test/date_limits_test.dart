import 'package:employee_shift_management_ui/utils/date_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pickers reach one year ahead', () {
    expect(latestPickableDate(DateTime(2026, 9, 18)), DateTime(2027, 9, 18));
  });

  test('the last pickable date is still after today on 1 January 2027', () {
    // The day the old DateTime(2027) limit broke the leave dialog (B23):
    // showDateRangePicker asserts that lastDate is not before firstDate.
    final today = DateTime(2027, 1, 1);

    expect(latestPickableDate(today).isAfter(today), isTrue);
  });
}
