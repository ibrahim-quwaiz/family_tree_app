import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Supabase قبل تشغيل التطبيق
  try {
    print('🚀 بدء تهيئة التطبيق...');
    await SupabaseConfig.initialize();
    print('✅ تم تهيئة Supabase بنجاح في main()');
  } catch (e) {
    print('❌ فشل تهيئة Supabase في main(): $e');
    // يمكنك إما إيقاف التطبيق أو المتابعة مع البيانات التجريبية
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
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),
    );
  }
}