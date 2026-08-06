import 'package:flutter/material.dart';

import '../jobs/job_helpers.dart';
import 'payment_helpers.dart';

class JobPaymentStatusCard extends StatelessWidget {
  const JobPaymentStatusCard({
    super.key,
    required this.payment,
    required this.isCustomer,
    this.onPressed,
  });

  final Map<String, dynamic>? payment;
  final bool isCustomer;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool required = isPaymentRequired(payment);
    final bool paid = isPaymentPaid(payment);
    final num total = paymentTotalAmount(payment);

    String description;
    if (!required) {
      description = isCustomer
          ? 'Pembayaran belum dibuat. Buka halaman pembayaran untuk melanjutkan melalui Midtrans.'
          : 'Customer belum membuat transaksi pembayaran Midtrans.';
    } else if (paid) {
      description = 'Pembayaran sudah terverifikasi. Pekerjaan dapat dilanjutkan.';
    } else {
      description = isCustomer
          ? 'Selesaikan pembayaran Midtrans agar mitra dapat memulai pekerjaan.'
          : 'Customer belum menyelesaikan pembayaran. Tombol mulai pekerjaan akan aktif setelah pembayaran terverifikasi.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paymentStatusBackground(payment),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: paymentStatusColor(payment)),
                ),
                child: Icon(
                  paymentStatusIcon(payment),
                  color: paymentStatusColor(payment),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Status Pembayaran Midtrans',
                      style: TextStyle(fontSize: 11, color: Color(0xFF72665F)),
                    ),
                    Text(
                      paymentStatusLabel(payment),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Text(
                  formatRupiah(total),
                  style: const TextStyle(
                    color: paymentBrown,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: Color(0xFF655A53),
            ),
          ),
          if (onPressed != null) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: paymentBrown,
                  side: const BorderSide(color: paymentOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                icon: Icon(
                  paid ? Icons.receipt_long_outlined : Icons.payments_outlined,
                ),
                label: Text(
                  paid ? 'Lihat Pembayaran' : 'Buka Pembayaran',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
