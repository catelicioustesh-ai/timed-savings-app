import 'package:flutter_test/flutter_test.dart';
import 'package:timed_savings_app/user_session.dart';

void main() {
  test('user profile stores a name and pin', () {
    final user = AppUser(name: 'Amina', pin: '1234');

    expect(user.name, 'Amina');
    expect(user.pin, '1234');
  });

  test('account summary calculates total saved and balance', () {
    final summary = AccountSummary(
      totalSaved: 2500,
      pendingAmount: 500,
      availableBalance: 2000,
    );

    expect(summary.totalSaved, 2500);
    expect(summary.availableBalance, 2000);
    expect(summary.pendingAmount, 500);
  });
}
