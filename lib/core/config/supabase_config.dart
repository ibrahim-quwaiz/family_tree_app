import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ← ضع Project URL هنا
  static const String supabaseUrl = 'https://vohbplvvneecwsbpzwns.supabase.co';
  
  // ← ضع Publishable key هنا (الكود الطويل)
  static const String supabaseAnonKey = 'sb_publishable_4nHoDiiyR4HXF3xCRegtpw_nZgTMXBn';
  
  static Future<void> initialize() async {
    try {
      print('🔌 تهيئة Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('✅ تم تهيئة Supabase بنجاح');
    } catch (e) {
      print('❌ خطأ في تهيئة Supabase: $e');
      rethrow;
    }
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}