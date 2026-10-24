import 'package:flutter/material.dart';

import '../providers/language_provider.dart';
import 'coffee_overlays.dart';

class CartCheckoutPanel extends StatelessWidget {
  const CartCheckoutPanel({
    super.key,
    required this.total,
    required this.itemCount,
    required this.language,
    required this.onCheckout,
    this.busy = false,
  });

  final String total;
  final int itemCount;
  final LanguageProvider language;
  final VoidCallback onCheckout;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final english = language.isEnglish;
    return Container(
      key: const ValueKey('cart-checkout-panel'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: CoffeeColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('cart-payment-method'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CoffeeColors.cream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: CoffeeColors.ink,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        english ? 'Payment method' : 'Metode pembayaran',
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 11,
                          color: CoffeeColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'QRIS',
                        style: TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CoffeeColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: CoffeeColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final label = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? 'Total payment' : 'Total pembayaran',
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontSize: 12,
                      color: CoffeeColors.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$itemCount ${english ? 'items' : 'item'}',
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontSize: 11,
                      color: CoffeeColors.muted,
                    ),
                  ),
                ],
              );
              final amount = Text(
                total,
                key: const ValueKey('cart-total'),
                style: const TextStyle(
                  fontFamily: 'CiksSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CoffeeColors.ink,
                ),
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.25 ||
                  total.length > 16) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 6), amount],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  label,
                  const SizedBox(width: 12),
                  Flexible(child: amount),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          CoffeeButton(
            key: const ValueKey('cart-checkout-action'),
            label: english ? 'Continue to payment' : 'Lanjutkan Pembayaran',
            icon: Icons.arrow_forward_rounded,
            loading: busy,
            onPressed: onCheckout,
          ),
        ],
      ),
    );
  }
}
