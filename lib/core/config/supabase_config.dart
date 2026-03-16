import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ← ضع Project URL هنا
  static const String supabaseUrl = 'https://vohbplvvneecwsbpzwns.supabase.co';
  
  // ← ضع Publishable key هنا (الكود الطويل)
  static const String supabaseAnonKey = 'sb_publishable_4nHoDiiyR4HXF3xCRegtpw_nZgTMXBn';
  
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}