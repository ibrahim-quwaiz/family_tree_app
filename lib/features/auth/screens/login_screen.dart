import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/supabase_config.dart';
import '../../../screens/home_screen.dart';
import '../../../core/constants/current_user.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _qfController = TextEditingController();
  final _pinController = TextEditingController();
  final _qfFocus = FocusNode();
  final _pinFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  bool _obscurePin = true;
  String _adminWhatsapp = '966555113730';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadAdminWhatsapp();
  }

  Future<void> _loadAdminWhatsapp() async {
    try {
      final response = await SupabaseConfig.client
          .from('family_info')
          .select('content')
          .eq('type', 'whatsapp')
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _adminWhatsapp = response['content'] as String? ?? _adminWhatsapp;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _qfController.dispose();
    _pinController.dispose();
    _qfFocus.dispose();
    _pinFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final qfId = _qfController.text.trim().toUpperCase();
    final pin = _pinController.text.trim();

    if (qfId.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال رقم العضوية');
      return;
    }

    if (pin.isEmpty || pin.length != 4) {
      setState(() => _errorMessage = 'الرجاء إدخال الرقم السري (4 أرقام)');
      return;
    }

    if (_failedAttempts >= 5) {
      setState(() => _errorMessage = 'تم تجاوز الحد الأقصى للمحاولات. حاول لاحقاً.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.login(qfId, pin);
      await CurrentUser.loadFromSession();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on AuthException catch (e) {
      setState(() {
        _failedAttempts++;
        if (e.message == 'الرقم السري غير صحيح') {
          _errorMessage = '${e.message} (${5 - _failedAttempts} محاولات متبقية)';
        } else {
          _errorMessage = e.message;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال. حاول مرة أخرى.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SizedBox(height: 60),
                  _buildHeader(),
                  SizedBox(height: 50),
                  _buildLoginForm(),
                  SizedBox(height: 30),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/app_logo.png',
            width: 120,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'عائلة القويز',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'سجل دخولك للوصول إلى شجرة العائلة',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // حقل رقم العضوية
          Text(
            'رقم العضوية',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _qfController,
            focusNode: _qfFocus,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              hintText: 'مثال: QF07023',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.badge_rounded, color: AppColors.gold, size: 18),
              ),
              filled: true,
              fillColor: AppColors.bgDeep.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
            onSubmitted: (_) => _pinFocus.requestFocus(),
          ),

          SizedBox(height: 20),

          // حقل الرقم السري
          Text(
            'الرقم السري',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _pinController,
            focusNode: _pinFocus,
            keyboardType: TextInputType.number,
            obscureText: _obscurePin,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              hintText: '● ● ● ●',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.3),
                fontSize: 18,
                letterSpacing: 8,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lock_rounded, color: AppColors.gold, size: 18),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
              filled: true,
              fillColor: AppColors.bgDeep.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onSubmitted: (_) => _login(),
          ),

          // رسالة الخطأ
          if (_errorMessage != null) ...[
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.accentRed, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 24),

          // زر الدخول
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isLoading ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgDeep,
                disabledBackgroundColor: AppColors.gold.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.bgDeep,
                      ),
                    )
                  : Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              final url = Uri.parse(
                  'https://wa.me/${_normalizePhone(_adminWhatsapp)}?text=${Uri.encodeComponent("السلام عليكم، أحتاج مساعدة في الدخول للتطبيق")}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: Icon(Icons.help_outline,
                color: AppColors.textSecondary, size: 18),
            label: Text(
              'تواجه مشكلة؟ تواصل مع مدير التطبيق',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizePhone(String phone) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    String result = phone;
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'ليس لديك رقم سري؟',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'تواصل مع إدارة التطبيق للحصول على بيانات الدخول',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// تحويل النص لحروف كبيرة تلقائياً
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
