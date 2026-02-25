import '../../../features/auth/services/auth_service.dart';

class CurrentUser {
  /// رقم QF — يُجلب من الجلسة المحفوظة (أو القيمة الافتراضية)
  static String legacyUserId = 'QF07023';

  /// تحميل رقم المستخدم من الجلسة
  static Future<void> loadFromSession() async {
    final qfId = await AuthService.getCurrentQfId();
    if (qfId != null && qfId.isNotEmpty) {
      legacyUserId = qfId;
    }
  }
}
