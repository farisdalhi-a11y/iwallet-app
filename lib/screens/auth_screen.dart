import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleLogin() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'فشل تسجيل الدخول عبر Google: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSendOtp() async {
    HapticFeedback.selectionClick();
    if (_emailCtrl.text.isEmpty || _passCtrl.text.length < 6) {
      setState(() => _error = 'أدخل بريداً صحيحاً وكلمة مرور من 6 أحرف على الأقل');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.sendRealEmailOtp(_emailCtrl.text.trim());
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.verifyEmailOtpAndLogin(
        _emailCtrl.text.trim(),
        _otpCtrl.text.trim(),
        _passCtrl.text,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                CupertinoIcons.creditcard_fill,
                size: 68,
                color: CupertinoColors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Wallet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'محفظة رقمية محمية للدفع الفوري عبر NFC و QR',
                textAlign: TextAlign.center,
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 15),
              ),
              const SizedBox(height: 36),
              CupertinoTextField(
                controller: _emailCtrl,
                placeholder: 'البريد الإلكتروني (Gmail)',
                keyboardType: TextInputType.emailAddress,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _passCtrl,
                placeholder: 'كلمة المرور الأمنية',
                obscureText: true,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _otpCtrl,
                  placeholder: 'أدخل رمز التحقق المرسل لبريدك (6 أرقام)',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CupertinoColors.activeBlue),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CupertinoColors.systemRed, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                onPressed: _loading ? null : (_otpSent ? _handleVerifyOtp : _handleSendOtp),
                child: _loading
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : Text(
                        _otpSent ? 'تأكيد الرمز والدخول' : 'إرسال رمز تحقق إلى Gmail',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
                onPressed: _loading ? null : _handleGoogleLogin,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.globe, color: CupertinoColors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'المتابعة باستخدام Google',
                      style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
