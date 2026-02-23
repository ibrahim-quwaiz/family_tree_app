import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/main_navigation.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 بدء تهيئة التطبيق...');
    await SupabaseConfig.initialize();
    print('✅ تم تهيئة Supabase بنجاح في main()');
  } catch (e) {
    print('❌ فشل تهيئة Supabase في main(): $e');
  }
  
  runApp(const FamilyTreeApp());
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجرة عائلة القويز',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(AppTheme.darkTheme.textTheme),
      ),
      home: const HomeScreen(),
    );
  }
}
