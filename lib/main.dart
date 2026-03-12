import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'core/constants/current_user.dart';
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

  // محاولة استعادة الجلسة من Supabase
  bool isLoggedIn = false;
  try {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      isLoggedIn = true;
      await CurrentUser.loadFromSession();
    } else {
      isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) await CurrentUser.loadFromSession();
    }
  } catch (e) {
    isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) await CurrentUser.loadFromSession();
  }

  runApp(FamilyTreeApp(isLoggedIn: isLoggedIn));
}

class FamilyTreeApp extends StatelessWidget {
  final bool isLoggedIn;

  const FamilyTreeApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجرة عائلة القويز',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(AppTheme.darkTheme.textTheme),
      ),
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
