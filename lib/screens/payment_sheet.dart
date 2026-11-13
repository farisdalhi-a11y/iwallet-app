import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/payment_service.dart';
import '../services/security_service.dart';

class PaymentSheet extends StatefulWidget {
  final Map<String, dynamic> card;
  final bool isMerchantMode;

  const PaymentSheet({super.key, required this.card, required this.isMerchantMode});

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final PaymentService _paymentService = PaymentService();
  final _amountCtrl = TextEditingController(text: '25.00');
  String? _activeToken;
  String _statusMessage = 'أدخل المبلغ ثم اضغط لتفعيل NFC و QR';
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isMerchantMode) {
      _statusMessage = 'قرّب هاتف المشتري (NFC) أو امسح رمز QR';
      SecurityService.startMerchantNfcReader(_handleTokenScanned);
    }
  }

  @override
  void dispose() {
    SecurityService.deactivateNfcPayment();
    SecurityService.stopMerchantNfcReader();
    super.dispose();
  }

  Future<void> _generatePaymentSession() async {
    HapticFeedback.heavyImpact();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _processing = true);
    try {
      final token = await _paymentService.createOneTimePaymentToken(
        cardId: widget.card['id'],
        maxAmount: amount,
      );
      setState(() {
        _activeToken = token;
        _statusMessage = 'قرّب الهاتف من جهاز الدفع (NFC) أو امسح الرمز';
      });
    } catch (e) {
      setState(() => _statusMessage = e.toString());
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _handleTokenScanned(String token) async {
    if (_processing) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _processing = true;
      _statusMessage = 'جاري معالجة الدفعة وتأكيد الرصيد...';
    });

    try {
      final result = await _paymentService.processPaymentToken(token);
      if (!mounted) return;
      Navigator.pop(context);
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('تمت العملية بنجاح'),
          content: Text('تم استلام مبلغ \$${result['amount']} عبر ${result['brand']}'),
          actions: [
            CupertinoDialogAction(
              child: const Text('موافق'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _processing = false;
        _statusMessage = 'فشلت العملية: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: widget.isMerchantMode ? _buildMerchantView() : _buildPayerView(),
    );
  }

  Widget _buildPayerView() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'الدفع عبر ${widget.card['brand']} •••• ${widget.card['last4']}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (_activeToken == null) ...[
          CupertinoTextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Text('\$', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          CupertinoButton.filled(
            onPressed: _processing ? null : _generatePaymentSession,
            child: const Text('تفعيل الدفع اللاتلامسي (NFC + QR)'),
          ),
        ] else ...[
          const Icon(CupertinoIcons.radiowaves_right, size: 54, color: CupertinoColors.activeBlue),
          const SizedBox(height: 8),
          const Text('NFC HCE نشط وجاهز للتلامس',
              style: TextStyle(color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: QrImageView(
              data: _activeToken!,
              size: 190,
            ),
          ),
        ],
        const Spacer(),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.systemGrey),
        ),
      ],
    );
  }

  Widget _buildMerchantView() {
    return Column(
      children: [
        const Text(
          'جهاز استقبال المدفوعات (NFC + QR)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: MobileScanner(
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  if (barcode.rawValue != null && barcode.rawValue!.startsWith('PAY_')) {
                    _handleTokenScanned(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.activeGreen, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
