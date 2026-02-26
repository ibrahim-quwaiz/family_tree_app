import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/supabase_config.dart';

class AuthService {
  static const String _emailDomain = 'alquwaiz.family';

  /// تحويل رقم QF إلى إيميل وهمي
  static String _qfToEmail(String qfId) {
    return '${qfId.toLowerCase()}@$_emailDomain';
  }

  /// تسجيل الدخول بـ QF + PIN
  /// أول مرة: يسجّل حساب جديد في Supabase Auth ثم يربطه
  /// المرات التالية: يسجّل دخول عادي
  static Future<Map<String, dynamic>> login(String qfId, String pin) async {
    final client = SupabaseConfig.client;
    final email = _qfToEmail(qfId);

    // ١. تحقق إن رقم QF موجود في people وإن PIN صحيح
    final personResponse = await client
        .from('people')
        .select('id, name, legacy_user_id, pin_code, is_admin, auth_user_id, generation, gender')
        .eq('legacy_user_id', qfId.toUpperCase())
        .maybeSingle();

    if (personResponse == null) {
      throw AuthException('رقم العضوية غير موجود');
    }

    final storedPin = personResponse['pin_code'] as String?;
    if (storedPin == null || storedPin.isEmpty) {
      throw AuthException('لم يتم تعيين رقم سري لهذا الحساب. تواصل مع إدارة التطبيق.');
    }

    if (storedPin != pin) {
      throw AuthException('الرقم السري غير صحيح');
    }

    final personId = personResponse['id'] as String;
    final authUserId = personResponse['auth_user_id'] as String?;

    // ٢. لو ما عنده حساب Auth → أنشئ واحد
    if (authUserId == null || authUserId.isEmpty) {
      try {
        // محاولة إنشاء حساب جديد
        final signUpResponse = await client.auth.signUp(
          email: email,
          password: '${qfId.toUpperCase()}_$pin',
        );

        if (signUpResponse.user != null) {
          // ربط auth_user_id بـ people
          await client
              .from('people')
              .update({'auth_user_id': signUpResponse.user!.id})
              .eq('id', personId);
        }
      } on supabase.AuthException catch (e) {
        // لو الحساب موجود مسبقاً (من محاولة سابقة)
        if (e.message.contains('already registered') || e.message.contains('already been registered')) {
          // سجّل دخول بدلاً من ذلك
          await client.auth.signInWithPassword(
            email: email,
            password: '${qfId.toUpperCase()}_$pin',
          );

          // حدّث auth_user_id لو ما كان مربوط
          final currentUser = client.auth.currentUser;
          if (currentUser != null) {
            await client
                .from('people')
                .update({'auth_user_id': currentUser.id})
                .eq('id', personId);
          }
        } else {
          rethrow;
        }
      }
    } else {
      // ٣. عنده حساب Auth → سجّل دخول
      try {
        await client.auth.signInWithPassword(
          email: email,
          password: '${qfId.toUpperCase()}_$pin',
        );
      } on supabase.AuthException {
        // لو فشل (مثلاً PIN تغيّر) → حاول أنشئ حساب جديد
        try {
          final signUpResponse = await client.auth.signUp(
            email: email,
            password: '${qfId.toUpperCase()}_$pin',
          );
          if (signUpResponse.user != null) {
            await client
                .from('people')
                .update({'auth_user_id': signUpResponse.user!.id})
                .eq('id', personId);
          }
        } catch (_) {
          throw AuthException('فشل تسجيل الدخول. حاول مرة أخرى.');
        }
      }
    }

    // ٤. حفظ بيانات الجلسة محلياً
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_in_user_id', personId);
    await prefs.setString('logged_in_qf_id', qfId.toUpperCase());
    await prefs.setString('logged_in_name', personResponse['name'] as String? ?? '');
    await prefs.setBool('logged_in_is_admin', personResponse['is_admin'] as bool? ?? false);
    await prefs.setBool('is_logged_in', true);

    return personResponse;
  }

  /// هل المستخدم مسجل دخول؟
  static Future<bool> isLoggedIn() async {
    // تحقق من Supabase Auth أولاً
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) return true;

    // تحقق من SharedPreferences كبديل
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
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await SupabaseConfig.client
            .from('people')
            .select('is_admin')
            .eq('auth_user_id', user.id)
            .maybeSingle();
        if (response != null && response['is_admin'] == true) return true;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_in_is_admin') ?? false;
  }

  /// تسجيل الخروج
  static Future<void> logout() async {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_user_id');
    await prefs.remove('logged_in_qf_id');
    await prefs.remove('logged_in_name');
    await prefs.remove('logged_in_is_admin');
    await prefs.setBool('is_logged_in', false);
  }
}

/// استثناء مخصص
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
