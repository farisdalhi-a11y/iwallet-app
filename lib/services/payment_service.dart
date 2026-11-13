import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'security_service.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// توليد رمز دفع مشفر لمرة واحدة (يُستخدم في NFC HCE و QR Code)
  Future<String> createOneTimePaymentToken({
    required String cardId,
    required double maxAmount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('غير مسجل الدخول');

    final token = 'PAY_${const Uuid().v4().replaceAll('-', '').substring(0, 16).toUpperCase()}';
    final expiresAt = DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch;

    await _db.collection('payment_tokens').doc(token).set({
      'payerUid': user.uid,
      'payerEmail': user.email,
      'cardId': cardId,
      'amount': maxAmount,
      'expiresAt': expiresAt,
      'used': false,
    });

    // تفعيل شريحة NFC HCE في الهاتف لإرسال هذا الرمز عند التلامس
    await SecurityService.activateNfcPayment(token);
    return token;
  }

  /// تنفيذ الدفع الفعلي عند مسح QR أو استقبال NFC HCE (وضع التاجر)
  Future<Map<String, dynamic>> processPaymentToken(String token) async {
    final merchant = _auth.currentUser;
    if (merchant == null) throw Exception('يجب تسجيل الدخول لاستقبال الدفع');

    return await _db.runTransaction((transaction) async {
      final tokenRef = _db.collection('payment_tokens').doc(token);
      final tokenSnap = await transaction.get(tokenRef);

      if (!tokenSnap.exists) throw Exception('رمز الدفع غير صالح');
      final tokenData = tokenSnap.data()!;

      if (tokenData['used'] == true) throw Exception('تم استخدام رمز الدفع مسبقاً');
      if (DateTime.now().millisecondsSinceEpoch > tokenData['expiresAt']) {
        throw Exception('انتهت صلاحية رمز الدفع');
      }

      final String payerUid = tokenData['payerUid'];
      if (payerUid == merchant.uid) throw Exception('لا يمكنك الدفع لنفس الحساب');

      final double amount = (tokenData['amount'] as num).toDouble();
      final String cardId = tokenData['cardId'];

      final payerRef = _db.collection('users').doc(payerUid);
      final merchantRef = _db.collection('users').doc(merchant.uid);

      final payerSnap = await transaction.get(payerRef);
      final merchantSnap = await transaction.get(merchantRef);

      List<dynamic> payerCards = List.from(payerSnap.data()!['cards']);
      int cardIndex = payerCards.indexWhere((c) => c['id'] == cardId);
      if (cardIndex == -1) throw Exception('البطاقة غير موجودة');

      double currentBalance = (payerCards[cardIndex]['balance'] as num).toDouble();
      if (currentBalance < amount) throw Exception('الرصيد غير كافٍ في البطاقة');

      // خصم المبلغ من المشتري
      payerCards[cardIndex]['balance'] = currentBalance - amount;
      transaction.update(payerRef, {'cards': payerCards});

      // إضافة المبلغ لأول بطاقة لدى التاجر
      List<dynamic> merchantCards = List.from(merchantSnap.data()!['cards']);
      merchantCards[0]['balance'] = (merchantCards[0]['balance'] as num).toDouble() + amount;
      transaction.update(merchantRef, {'cards': merchantCards});

      // إبطال الرمز وتسجيل العملية
      transaction.update(tokenRef, {'used': true});

      final txRef = _db.collection('transactions').doc();
      transaction.set(txRef, {
        'payerUid': payerUid,
        'merchantUid': merchant.uid,
        'amount': amount,
        'cardBrand': payerCards[cardIndex]['brand'],
        'last4': payerCards[cardIndex]['last4'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      return {
        'amount': amount,
        'payerEmail': tokenData['payerEmail'],
        'brand': payerCards[cardIndex]['brand'],
      };
    });
  }
}
