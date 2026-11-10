import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'user_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const TimedSavingsApp());
}

class SavingsEntry {
  final String phone;
  final double amount;
  final String date;
  final String note;
  final String status;
  final String reference;
  final String createdAt;
  final String id;

  SavingsEntry({
    required this.phone,
    required this.amount,
    required this.date,
    required this.note,
    required this.status,
    required this.reference,
    required this.createdAt,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'amount': amount,
    'date': date,
    'note': note,
    'status': status,
    'reference': reference,
    'createdAt': createdAt,
    'id': id,
  };

  factory SavingsEntry.fromJson(Map<String, dynamic> json) => SavingsEntry(
    phone: json['phone'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: json['date'] as String,
    note: json['note'] as String,
    status: json['status'] as String,
    reference: json['reference'] as String,
    createdAt: json['createdAt'] as String,
    id: json['id'] as String,
  );
}

class TimedSavingsApp extends StatelessWidget {
  const TimedSavingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live M-Pesa Savings',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1ABC9C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AppEntryGate(),
    );
  }
}

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  bool isLoading = true;
  AppUser? user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final savedUser = await UserSessionStorage.load();
    if (mounted) {
      setState(() {
        user = savedUser;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return LoginScreen(
        onLoggedIn: (savedUser) {
          setState(() {
            user = savedUser;
          });
        },
      );
    }

    return HomePage(
      userName: user!.name,
      onLogout: () async {
        await UserSessionStorage.clear();
        if (mounted) {
          setState(() {
            user = null;
          });
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final void Function(AppUser user) onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  Future<void> _login() async {
    final name = nameController.text.trim();
    final pin = pinController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
      return;
    }

    if (pin.length != 4 || int.tryParse(pin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your PIN must be 4 digits.')),
      );
      return;
    }

    final user = AppUser(name: name, pin: pin);
    await UserSessionStorage.save(user);
    widget.onLoggedIn(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B3B2E), Color(0xFF0F766E), Color(0xFFD4AF37)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to M-Pesa Savings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B3B2E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your account to view your total saved and balance.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '4-digit PIN',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _login,
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.userName, required this.onLogout});
  final String userName;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  final List<SavingsEntry> savingsList = [];
  bool isLoading = false;
  String statusMessage = '';
  late AnimationController _animationController;
  bool isConnected = true;
  late Timer _statusPollingTimer;

  final String apiBaseUrl = 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    unawaited(NotificationService.initializeFirebase(apiBaseUrl: apiBaseUrl));
    loadData();
    // Start polling for transaction status updates every 3 seconds
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkPendingTransactions();
    });
  }

  Future<void> _checkPendingTransactions() async {
    final pendingTransactions = savingsList
        .where((entry) => entry.status == 'Pending')
        .toList();

    for (final transaction in pendingTransactions) {
      await _updateTransactionStatus(transaction);
    }
  }

  Future<void> _updateTransactionStatus(SavingsEntry transaction) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$apiBaseUrl/transaction-status/${transaction.reference}',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newStatus = data['status'] ?? transaction.status;

        if (newStatus != transaction.status) {
          // Find and update the transaction
          final index = savingsList.indexWhere(
            (e) => e.reference == transaction.reference,
          );
          if (index != -1) {
            setState(() {
              final oldEntry = savingsList[index];
              savingsList[index] = SavingsEntry(
                phone: oldEntry.phone,
                amount: oldEntry.amount,
                date: oldEntry.date,
                note: oldEntry.note,
                status: newStatus,
                reference: oldEntry.reference,
                createdAt: oldEntry.createdAt,
                id: oldEntry.id,
              );
              isConnected = true;
            });
            await persistData();

            // Show notification when status changes
            if (newStatus == 'Completed') {
              await NotificationService.showNotification(
                TransactionNotificationContent.forDepositStatus(
                  status: 'Completed',
                  amount: transaction.amount,
                ),
              );
              showMessage(
                '✓ Transaction completed! Ksh ${transaction.amount} saved.',
              );
            } else if (newStatus == 'Failed') {
              await NotificationService.showNotification(
                TransactionNotificationContent.forDepositStatus(
                  status: 'Failed',
                  amount: transaction.amount,
                ),
              );
              showMessage('✗ Transaction failed. Please try again.');
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        isConnected = false;
      });
      debugPrint('Error checking transaction status: $e');
    }
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('savingsList');

    if (savedData != null) {
      try {
        final List<dynamic> jsonData = jsonDecode(savedData);
        setState(() {
          savingsList
            ..clear()
            ..addAll(
              jsonData
                  .map(
                    (item) =>
                        SavingsEntry.fromJson(item as Map<String, dynamic>),
                  )
                  .toList(),
            );
        });
      } catch (e) {
        debugPrint('Error loading data: $e');
      }
    }
  }

  Future<void> persistData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(
      savingsList.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString('savingsList', jsonData);
  }

  bool validateInput() {
    if (phoneController.text.trim().isEmpty) {
      showMessage('Enter your phone number first.');
      return false;
    }

    final normalizedPhone = phoneController.text.trim().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (!RegExp(r'^\d{10,12}$').hasMatch(normalizedPhone)) {
      showMessage('Phone number must be 10 to 12 digits.');
      return false;
    }

    if (amountController.text.trim().isEmpty) {
      showMessage('Enter the amount you want to save.');
      return false;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      showMessage('Enter a valid amount greater than zero.');
      return false;
    }

    if (dateController.text.trim().isEmpty) {
      showMessage('Choose a target withdrawal date.');
      return false;
    }

    return true;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        dateController.text =
            '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String formatCurrency(double value) {
    return 'Ksh ${value.toStringAsFixed(0)}';
  }

  int get pendingCount =>
      savingsList.where((entry) => entry.status == 'Pending').length;

  double get totalSaved => savingsList
      .where((entry) => entry.status == 'Completed')
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get availableBalance => totalSaved;

  Future<void> startPayment() async {
    if (!validateInput()) return;

    setState(() {
      isLoading = true;
      statusMessage = '';
    });

    // Show step-by-step instructions
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payment, color: Color(0xFF1ABC9C)),
            SizedBox(width: 10),
            Text('M-Pesa Payment Confirmation'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transaction Details:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phone:',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          phoneController.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount:',
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          formatCurrency(double.parse(amountController.text)),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1ABC9C),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'What happens next:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a1a),
                ),
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                '1',
                'M-Pesa prompt appears on your phone',
                'Check your phone for the M-Pesa notification',
              ),
              const SizedBox(height: 10),
              _buildStepItem(
                '2',
                'Enter your M-Pesa PIN',
                'A 4-digit PIN prompt will ask for your security code',
              ),
              const SizedBox(height: 10),
              _buildStepItem(
                '3',
                'Money is deducted from M-Pesa',
                formatCurrency(double.parse(amountController.text)),
              ),
              const SizedBox(height: 10),
              _buildStepItem(
                '4',
                'Savings updated automatically',
                'Amount will appear in your savings history',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isLoading = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1ABC9C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _performPayment();
            },
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF1ABC9C),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF1a1a1a),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _performPayment() async {
    try {
      final normalizedPhone = phoneController.text.trim().replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final amount = double.parse(amountController.text.trim());

      final response = await http.post(
        Uri.parse('$apiBaseUrl/stkpush'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': normalizedPhone, 'amount': amount}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final status =
            data['ResponseCode'] == '0' || data['responseCode'] == '0'
            ? 'Pending'
            : 'Failed';
        final reference =
            data['CheckoutRequestID'] ?? data['checkoutRequestID'] ?? '';
        final checkoutMessage =
            data['CustomerMessage'] ??
            data['customerMessage'] ??
            data['errorMessage'] ??
            'Request sent. Please check your phone.';

        final newEntry = SavingsEntry(
          phone: normalizedPhone,
          amount: amount,
          date: dateController.text.trim(),
          note: noteController.text.trim().isEmpty
              ? 'M-Pesa savings deposit'
              : noteController.text.trim(),
          status: status,
          reference: reference.isNotEmpty ? reference : 'N/A',
          createdAt: DateTime.now().toIso8601String(),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        savingsList.insert(0, newEntry);
        await persistData();

        await NotificationService.showNotification(
          TransactionNotificationContent.forDepositStatus(
            status: 'Pending',
            amount: amount,
          ),
        );

        setState(() {
          statusMessage =
              '📱 M-Pesa prompt on your phone!\n⏳ Enter your PIN to complete savings.\nWe\'re monitoring for confirmation...';
        });

        phoneController.clear();
        amountController.clear();
        dateController.clear();
        noteController.clear();
        showMessage(checkoutMessage.toString());
      } else {
        final errorData = jsonDecode(response.body);
        showMessage(
          'Payment request failed: ${errorData['message'] ?? response.reasonPhrase}',
        );
      }
    } catch (error) {
      showMessage('Unable to contact the backend: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteEntry(int index) async {
    savingsList.removeAt(index);
    await persistData();
    setState(() {});
    showMessage('Entry deleted successfully.');
  }

  Future<void> _showPinDialog(SavingsEntry entry) async {
    pinController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF1ABC9C)),
            SizedBox(width: 10),
            Text('Enter M-Pesa PIN'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Withdrawing: ${formatCurrency(entry.amount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a1a),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To: ${entry.phone}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'M-Pesa PIN',
                  hintText: '****',
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF1ABC9C)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1ABC9C),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF1ABC9C),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your PIN is secure and never stored.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              pinController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1ABC9C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _processWithdrawal(entry, pinController.text);
            },
            child: const Text(
              'Withdraw',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawal(SavingsEntry entry, String pin) async {
    if (pin.length != 4) {
      showMessage('PIN must be 4 digits');
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = 'Processing withdrawal...';
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': entry.phone,
          'amount': entry.amount,
          'pin': pin,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        showMessage(data['message'] ?? 'Withdrawal initiated successfully!');

        await NotificationService.showNotification(
          TransactionNotificationContent.forWithdrawalStatus(
            status: 'Pending',
            amount: entry.amount,
          ),
        );

        // Remove from savings after successful withdrawal
        final index = savingsList.indexWhere((e) => e.id == entry.id);
        if (index != -1) {
          setState(() {
            savingsList.removeAt(index);
          });
          await persistData();
        }

        setState(() {
          statusMessage = 'Withdrawal in progress. Check your phone.';
        });
      } else {
        final errorData = jsonDecode(response.body);
        await NotificationService.showNotification(
          TransactionNotificationContent.forWithdrawalStatus(
            status: 'Failed',
            amount: entry.amount,
          ),
        );
        showMessage(
          'Withdrawal failed: ${errorData['message'] ?? response.reasonPhrase}',
        );
      }
    } catch (error) {
      showMessage('Error processing withdrawal: $error');
    } finally {
      setState(() {
        isLoading = false;
        pinController.clear();
      });
    }
  }

  Widget statusChip(String status) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    switch (status) {
      case 'Completed':
        bgColor = const Color(0xFF27AE60);
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case 'Pending':
        bgColor = const Color(0xFFF39C12);
        textColor = Colors.white;
        icon = Icons.hourglass_bottom;
        break;
      default:
        bgColor = const Color(0xFFE74C3C);
        textColor = Colors.white;
        icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.userName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Smart savings, effortless deposits',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF27AE60)
                            : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Live' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isConnected
                            ? const Color(0xFF27AE60)
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _checkPendingTransactions,
              tooltip: 'Refresh status',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: widget.onLogout,
              tooltip: 'Logout',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.help_outline, color: Color(0xFF1ABC9C)),
                        SizedBox(width: 10),
                        Text('How it works'),
                      ],
                    ),
                    content: const Text(
                      'Enter your M-Pesa number and amount, then submit. A prompt will appear on your phone so you can confirm the payment securely. Your transaction status updates automatically in real-time.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B3B2E), Color(0xFF0F766E), Color(0xFFD4AF37)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card with Stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFFD4AF37)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.savings,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Saved',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatCurrency(totalSaved),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Available Balance: ${formatCurrency(availableBalance)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pendingCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.lock, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Secure STK push. Your PIN never leaves your phone.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account snapshot',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Balance: ${formatCurrency(availableBalance)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Payment Form Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.credit_card,
                              color: Color(0xFF1ABC9C),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Payment Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildCustomTextField(
                          controller: phoneController,
                          labelText: 'M-Pesa Phone Number',
                          hintText: '254712345678',
                          icon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildCustomTextField(
                          controller: amountController,
                          labelText: 'Amount to Save',
                          hintText: 'Enter amount in KSH',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildCustomTextField(
                          controller: dateController,
                          labelText: 'Target Withdrawal Date',
                          hintText: 'Select date',
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: selectDate,
                        ),
                        const SizedBox(height: 16),
                        _buildCustomTextField(
                          controller: noteController,
                          labelText: 'Savings Note (Optional)',
                          hintText: 'e.g., Holiday fund',
                          icon: Icons.note_alt,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Quick Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            _buildQuickAmount('500'),
                            _buildQuickAmount('1000'),
                            _buildQuickAmount('1500'),
                            _buildQuickAmount('2000'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFFD4AF37)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFD4AF37,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isLoading ? null : startPayment,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isLoading)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isLoading
                                          ? 'Processing...'
                                          : 'Withdraw from M-Pesa',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (statusMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1ABC9C,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF1ABC9C,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF1ABC9C),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    statusMessage,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Transaction History
                if (savingsList.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.history,
                            color: Color(0xFF1ABC9C),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a1a1a),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: savingsList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = savingsList[index];
                          return _buildTransactionCard(entry, index);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 28),

                // Security Info Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Color(0xFF1ABC9C),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Live & Secure',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a1a1a),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.6,
                            ),
                            children: [
                              TextSpan(
                                text: '✓ ',
                                style: TextStyle(
                                  color: Color(0xFF27AE60),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'Live transaction status updates every 3 seconds.\n',
                              ),
                              TextSpan(
                                text: '✓ ',
                                style: TextStyle(
                                  color: Color(0xFF27AE60),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'Your M-Pesa PIN is entered directly on your phone.\n',
                              ),
                              TextSpan(
                                text: '✓ ',
                                style: TextStyle(
                                  color: Color(0xFF27AE60),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'We never store or view your PIN.\n',
                              ),
                              TextSpan(
                                text: '✓ ',
                                style: TextStyle(
                                  color: Color(0xFF27AE60),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: 'All transactions are encrypted.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF1ABC9C)),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1ABC9C), width: 2),
        ),
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: Colors.black26),
      ),
    );
  }

  Widget _buildQuickAmount(String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          amountController.text = value;
          setState(() {});
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF1ABC9C).withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'Ksh $value',
            style: const TextStyle(
              color: Color(0xFF1ABC9C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(SavingsEntry entry, int index) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatCurrency(entry.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.note.isEmpty ? 'Savings deposit' : entry.note,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                statusChip(entry.status),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  entry.phone,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 8),
                Text(
                  'Target: ${entry.date}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
            if (entry.reference.isNotEmpty && entry.reference != 'N/A') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_number,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: ${entry.reference}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (entry.status == 'Completed')
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1ABC9C), Color(0xFF16A085)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPinDialog(entry),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (entry.status == 'Completed') const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => deleteEntry(index),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE74C3C),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    amountController.dispose();
    dateController.dispose();
    noteController.dispose();
    pinController.dispose();
    _animationController.dispose();
    _statusPollingTimer.cancel();
    super.dispose();
  }
}
