import 'package:flutter_test/flutter_test.dart';
import 'package:timed_savings_app/notification_service.dart';

void main() {
  test('deposit completed notification content is informative', () {
    final notification = TransactionNotificationContent.forDepositStatus(
      status: 'Completed',
      amount: 2500,
    );

    expect(notification.title, 'Savings deposit confirmed');
    expect(notification.body, contains('Ksh 2500'));
  });

  test('withdrawal failed notification content is clear', () {
    final notification = TransactionNotificationContent.forWithdrawalStatus(
      status: 'Failed',
      amount: 1500,
    );

    expect(notification.title, 'Withdrawal failed');
    expect(notification.body, contains('Ksh 1500'));
  });
}
