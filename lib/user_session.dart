import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppUser {
  final String name;
  final String pin;

  const AppUser({required this.name, required this.pin});

  Map<String, String> toMap() => {'name': name, 'pin': pin};

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      name: map['name'] as String? ?? '',
      pin: map['pin'] as String? ?? '',
    );
  }
}

class UserSessionStorage {
  static const _key = 'app_user';

  static Future<void> save(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toMap()));
  }

  static Future<AppUser?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_key);

    if (userString == null || userString.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(userString) as Map<String, dynamic>;
      final user = AppUser.fromMap(map);
      if (user.name.isEmpty || user.pin.isEmpty) {
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class AccountSummary {
  final double totalSaved;
  final double pendingAmount;
  final double availableBalance;

  const AccountSummary({
    required this.totalSaved,
    required this.pendingAmount,
    required this.availableBalance,
  });
}
