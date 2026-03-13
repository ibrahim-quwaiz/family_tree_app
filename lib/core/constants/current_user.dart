import '../../../features/auth/services/auth_service.dart';
import '../config/supabase_config.dart';

class CurrentUser {
  static String legacyUserId = '';

  static Future<void> loadFromSession() async {
    // أولاً: حاول من Supabase مباشرة
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        final response = await SupabaseConfig.client
            .from('people')
            .select('legacy_user_id')
            .eq('auth_user_id', user.id)
            .maybeSingle();
        if (response != null && response['legacy_user_id'] != null) {
          legacyUserId = response['legacy_user_id'] as String;
          return;
        }
      }
    } catch (e) {}

    // ثانياً: احتياطي من SharedPreferences
    final qfId = await AuthService.getCurrentQfId();
    if (qfId != null && qfId.isNotEmpty) {
      legacyUserId = qfId;
    }
  }
}
