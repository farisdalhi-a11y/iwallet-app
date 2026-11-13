# iWallet Pay (NFC HCE + QR Digital Wallet)

تطبيق محفظة إلكترونية بواجهة iOS (Apple Wallet) مع نظام حماية بيومتري ودفع فعلي عبر NFC HCE و QR Code.

## خطوات التجهيز وبناء ملف APK:
1. أنشئ مشروعاً في **Firebase Console**، وفعّل **Authentication** (Google و Email/Password) و **Firestore Database**.
2. حمّل ملف `google-services.json` وضعه داخل المسار: `android/app/google-services.json`.
3. افتح ملف `lib/services/auth_service.dart` وضع مفتاح **Brevo API** المجاني في `_brevoApiKey` لإرسال رموز التحقق الحقيقية عبر البريد.
4. ارفع محتويات مجلد `apple_pay_clone` إلى مستودع جديد على **GitHub**.
5. افتح تبويب **Actions** في المستودع لتحميل ملف `app-release.apk` الجاهز للتثبيت.
