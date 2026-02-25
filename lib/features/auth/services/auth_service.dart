import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  /// هل المستخدم مسجل دخول؟
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  /// جلب معرّف المستخدم الحالي
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_in_user_id');
  }

  /// جلب رقم QF الحالي
  static Future<String?> getCurrentQfId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_in_qf_id');
  }

  /// جلب اسم المستخدم الحالي
  static Future<String?> getCurrentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_in_name');
  }

  /// هل المستخدم مدير؟
  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_in_is_admin') ?? false;
  }

  /// تسجيل الخروج
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_id');
    await prefs.remove('logged_in_qf_id');
    await prefs.remove('logged_in_name');
    await prefs.remove('logged_in_is_admin');
    await prefs.setBool('is_logged_in', false);
  }
}
