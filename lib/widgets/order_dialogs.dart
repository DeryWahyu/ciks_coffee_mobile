import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order_model.dart';
import 'coffee_overlays.dart';

class PickupConfirmationDialog extends StatelessWidget {
  const PickupConfirmationDialog({
    super.key,
    required this.orderNumber,
    this.english = false,
  });

  final String orderNumber;
  final bool english;

  @override
  Widget build(BuildContext context) => CoffeeDialog(
    title: english ? 'Already picked up?' : 'Pesanan sudah di tanganmu?',
    message: english
        ? 'Confirm only after collecting order $orderNumber. It will then move to transaction history.'
        : 'Konfirmasi hanya setelah kamu menerima pesanan $orderNumber. Setelah itu, pesanan akan masuk ke riwayat transaksi.',
    icon: Icons.shopping_bag_outlined,
    dismissLabel: english ? 'Close' : 'Tutup',
    actions: [
      CoffeeButton(
        key: const ValueKey('confirm-pickup'),
        label: english ? 'Yes, picked up' : 'Sudah Ambil',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      CoffeeButton(
        key: const ValueKey('cancel-pickup'),
        label: english ? 'Not yet' : 'Belum',
        secondary: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
}

class OrderDetailsSheet extends StatelessWidget {
  const OrderDetailsSheet({
    super.key,
    required this.order,
    this.english = false,
  });

  final OrderModel order;
  final bool english;

  String _money(double value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(
      order.createdAt,
    )?.toUtc().add(const Duration(hours: 7));
    return CoffeeSheet(
      title: english ? 'Order details' : 'Detail Pesanan',
      subtitle: order.orderNumber,
      dismissLabel: english ? 'Close' : 'Tutup',
      footer: CoffeeButton(
        label: english ? 'Done' : 'Selesai',
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CoffeeColors.cream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: CoffeeColors.success,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.statusLabel,
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontWeight: FontWeight.w600,
                          color: CoffeeColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (created != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    DateFormat(
                      'dd MMM yyyy, HH:mm',
                      english ? 'en_US' : 'id_ID',
                    ).format(created),
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontSize: 12,
                      color: CoffeeColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            english ? 'Your order' : 'Pesananmu',
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: CoffeeColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontFamily: 'CiksSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: CoffeeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${item.quantity} × ${_money(item.price)}',
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 12,
                          color: CoffeeColors.muted,
                        ),
                      ),
                      Text(
                        _money(item.subtotal),
                        style: const TextStyle(
                          fontFamily: 'CiksSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CoffeeColors.ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(color: CoffeeColors.border, height: 24),
          Text(
            '${english ? 'Payment' : 'Pembayaran'} · ${order.paymentMethod.toUpperCase()}',
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 12,
              color: CoffeeColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(order.total),
            style: const TextStyle(
              fontFamily: 'CiksSans',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: CoffeeColors.ink,
            ),
          ),
          if (order.paidAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '${english ? 'Paid at' : 'Dibayar pada'} ${order.paidAt}',
              style: const TextStyle(
                fontFamily: 'CiksSans',
                fontSize: 12,
                color: CoffeeColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
