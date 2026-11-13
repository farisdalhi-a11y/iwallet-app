import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'security_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ضع مفتاح Brevo API المجاني هنا لإرسال رمز تحقق حقيقي إلى Gmail
  static const String _brevoApiKey = 'YOUR_BREVO_API_KEY';
  static const String _senderEmail = 'noreply@yourdomain.com';

  /// 1. تسجيل الدخول المباشر عبر حساب Google
  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user != null) {
      await _initializeUserWallet(userCredential.user!);
    }
    return userCredential.user;
  }

  /// 2. إرسال رمز تحقق حقيقي (6 أرقام) إلى بريد Gmail
  Future<void> sendRealEmailOtp(String email) async {
    final otp = SecurityService.generateOtpCode();
    final hashedOtp = SecurityService.hashString(otp);
    final expiresAt = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;

    // تخزين الرمز المشفر في Firestore
    await _db.collection('email_otps').doc(email.toLowerCase()).set({
      'hash': hashedOtp,
      'expiresAt': expiresAt,
      'attempts': 0,
    });

    // إرسال الرسالة الفعلية عبر Brevo SMTP REST API
    final response = await http.post(
      Uri.parse('https://api.brevo.com/v3/smtp/email'),
      headers: {
        'accept': 'application/json',
        'api-key': _brevoApiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'sender': {'name': 'iWallet Security', 'email': _senderEmail},
        'to': [
          {'email': email}
        ],
        'subject': 'رمز التحقق الأمني الخاص بمحفظتك: $otp',
        'htmlContent': '''
          <div style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 24px; background: #f5f5f7; border-radius: 16px;">
            <h2 style="color: #1d1d1f;">رمز التحقق الأمني</h2>
            <p style="color: #515154;">استخدم الرمز التالي لإتمام تسجيل الدخول الآمن إلى محفظتك الإلكترونية:</p>
            <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #0071e3; padding: 16px; background: #fff; border-radius: 12px; text-align: center;">
              $otp
            </div>
            <p style="color: #86868b; font-size: 12px; margin-top: 16px;">الرمز صالح لمدة 5 دقائق فقط. لا تشاركه مع أي شخص.</p>
          </div>
        ''',
      }),
    );

    if (response.statusCode >= 400) {
      throw Exception('فشل إرسال البريد: تأكد من إعداد مفتاح API');
    }
  }

  /// 3. التحقق من الرمز المدخل وإنشاء الجلسة الآمنة
  Future<User?> verifyEmailOtpAndLogin(String email, String code, String password) async {
    final docRef = _db.collection('email_otps').doc(email.toLowerCase());
    final snapshot = await docRef.get();

    if (!snapshot.exists) throw Exception('لم يتم طلب رمز لهذا البريد');

    final data = snapshot.data()!;
    if (DateTime.now().millisecondsSinceEpoch > data['expiresAt']) {
      await docRef.delete();
      throw Exception('انتهت صلاحية الرمز');
    }

    if (SecurityService.hashString(code.trim()) != data['hash']) {
      throw Exception('رمز التحقق غير صحيح');
    }

    await docRef.delete();

    UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        rethrow;
      }
    }

    if (cred.user != null) {
      await _initializeUserWallet(cred.user!);
    }
    return cred.user;
  }

  /// إنشاء البطاقات العالمية التجريبية (Visa & Mastercard) برصيد اختباري عند أول دخول
  Future<void> _initializeUserWallet(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'email': user.email,
        'name': user.displayName ?? user.email?.split('@').first ?? 'User',
        'createdAt': FieldValue.serverTimestamp(),
        'cards': [
          {
            'id': 'card_visa_test',
            'brand': 'VISA',
            'tier': 'Infinite Sandbox',
            'last4': '4242',
            'fullNumber': '4242 4242 4242 4242',
            'expiry': '12/29',
            'cvv': '842',
            'balance': 2500.00,
            'colorStart': 0xFF1C1C1E,
            'colorEnd': 0xFF3A3A3C,
          },
          {
            'id': 'card_mc_test',
            'brand': 'Mastercard',
            'tier': 'World Elite Test',
            'last4': '4444',
            'fullNumber': '5555 5555 5555 4444',
            'expiry': '09/28',
            'cvv': '319',
            'balance': 1850.50,
            'colorStart': 0xFF0A84FF,
            'colorEnd': 0xFF0040DD,
          }
        ],
      });
    }
  }
}
