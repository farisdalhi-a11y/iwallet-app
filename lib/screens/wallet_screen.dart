import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import 'payment_sheet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _selectedCardIndex = 0;
  bool _revealCardDetails = false;

  Future<void> _toggleRevealDetails() async {
    HapticFeedback.mediumImpact();
    if (!_revealCardDetails) {
      final ok = await SecurityService.authenticateBiometric(
        'تأكيد الهوية لعرض بيانات البطاقة الحساسة',
      );
      if (!ok) return;
    }
    setState(() => _revealCardDetails = !_revealCardDetails);
  }

  void _openPaymentModal(Map<String, dynamic> card, {bool isMerchant = false}) async {
    HapticFeedback.heavyImpact();
    if (!isMerchant) {
      final verified = await SecurityService.authenticateBiometric(
        'استخدم البصمة أو الوجه لتفعيل الدفع الآمن',
      );
      if (!verified) return;
    }

    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => PaymentSheet(card: card, isMerchantMode: isMerchant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF000000),
        middle: const Text('Wallet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => FirebaseAuth.instance.signOut(),
          child: const Icon(CupertinoIcons.square_arrow_left, size: 22),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _toggleRevealDetails,
          child: Icon(
            _revealCardDetails ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
            size: 22,
          ),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final List<dynamic> cards = data['cards'] ?? [];
            if (cards.isEmpty) return const SizedBox();

            final selectedCard = Map<String, dynamic>.from(cards[_selectedCardIndex]);

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // تكديس البطاقات بأسلوب Apple Wallet
                  SizedBox(
                    height: 270,
                    child: Stack(
                      children: List.generate(cards.length, (index) {
                        final card = cards[index];
                        final isSelected = index == _selectedCardIndex;
                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          top: isSelected ? 0 : (index * 45.0) + 25,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCardIndex = index);
                            },
                            child: _buildAppleStyleCard(card),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // أزرار الدفع الفوري (NFC / QR) ووضع الاستقبال (التاجر)
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          onPressed: () => _openPaymentModal(selectedCard, isMerchant: false),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.wave_3_right, size: 22),
                              SizedBox(width: 8),
                              Text('ادفع الآن (NFC / QR)',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => _openPaymentModal(selectedCard, isMerchant: true),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.qrcode_viewfinder, color: CupertinoColors.activeGreen),
                          SizedBox(width: 8),
                          Text(
                            'استقبال دفعة (وضع التاجر)',
                            style: TextStyle(
                                color: CupertinoColors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'آخر العمليات الفورية',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _buildTransactionsList(uid)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppleStyleCard(Map<String, dynamic> card) {
    return Container(
      height: 205,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(card['colorStart'] ?? 0xFF1C1C1E),
            Color(card['colorEnd'] ?? 0xFF3A3A3C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.6),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card['brand'],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const Icon(CupertinoIcons.radiowaves_right, color: CupertinoColors.white, size: 24),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _revealCardDetails ? card['fullNumber'] : '••••  ••••  ••••  ${card['last4']}',
                style: const TextStyle(fontSize: 19, letterSpacing: 2, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${(card['balance'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _revealCardDetails
                        ? 'EXP ${card['expiry']}  |  CVV ${card['cvv']}'
                        : card['tier'],
                    style: const TextStyle(color: CupertinoColors.systemGrey2, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['payerUid'] == uid || data['merchantUid'] == uid;
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('لا توجد عمليات دفع بعد', style: TextStyle(color: CupertinoColors.systemGrey)),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final tx = docs[i].data() as Map<String, dynamic>;
            final isIncoming = tx['merchantUid'] == uid;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isIncoming
                            ? CupertinoIcons.arrow_down_left_circle_fill
                            : CupertinoIcons.arrow_up_right_circle_fill,
                        color: isIncoming
                            ? CupertinoColors.activeGreen
                            : CupertinoColors.systemOrange,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isIncoming ? 'دفعة مستلمة' : 'دفع (${tx['cardBrand']} ••${tx['last4']})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '${isIncoming ? '+' : '-'}\$${(tx['amount'] as num).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIncoming ? CupertinoColors.activeGreen : CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
