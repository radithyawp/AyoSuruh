import 'package:flutter/material.dart';

const Color paymentOrange = Color(0xFFFF9800);
const Color paymentBrown = Color(0xFF8A5300);
const Color paymentDarkBrown = Color(0xFF583600);
const Color paymentGreen = Color(0xFF5E774F);
const Color paymentBackground = Color(0xFFFFF9FC);
const Color paymentBorder = Color(0xFFEAD8CB);

String paymentStatusLabel(Map<String, dynamic>? payment) {
  if (!isPaymentRequired(payment)) return 'Belum Diaktifkan';

  switch ((payment?['status'] ?? 'pending').toString().toLowerCase()) {
    case 'paid':
      return 'Sudah Dibayar';
    case 'failed':
      return 'Pembayaran Gagal';
    case 'expired':
      return 'Pembayaran Kedaluwarsa';
    default:
      return 'Menunggu Pembayaran';
  }
}

Color paymentStatusColor(Map<String, dynamic>? payment) {
  if (!isPaymentRequired(payment)) return const Color(0xFF8A7B72);

  switch ((payment?['status'] ?? 'pending').toString().toLowerCase()) {
    case 'paid':
      return paymentGreen;
    case 'failed':
      return Colors.red.shade700;
    case 'expired':
      return const Color(0xFF9B5D00);
    default:
      return paymentOrange;
  }
}

Color paymentStatusBackground(Map<String, dynamic>? payment) {
  if (!isPaymentRequired(payment)) return const Color(0xFFF1ECE8);

  switch ((payment?['status'] ?? 'pending').toString().toLowerCase()) {
    case 'paid':
      return const Color(0xFFE2F1D8);
    case 'failed':
      return const Color(0xFFFFE1DE);
    case 'expired':
      return const Color(0xFFFFEBCB);
    default:
      return const Color(0xFFFFEED5);
  }
}

IconData paymentStatusIcon(Map<String, dynamic>? payment) {
  if (!isPaymentRequired(payment)) return Icons.construction_rounded;

  switch ((payment?['status'] ?? 'pending').toString().toLowerCase()) {
    case 'paid':
      return Icons.check_circle_rounded;
    case 'failed':
      return Icons.error_rounded;
    case 'expired':
      return Icons.timer_off_rounded;
    default:
      return Icons.hourglass_top_rounded;
  }
}

num paymentBaseAmount(Map<String, dynamic>? payment) {
  final dynamic value = payment?['amount'];
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

num paymentServiceFee(Map<String, dynamic>? payment) {
  final dynamic value = payment?['service_fee'];
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

num paymentTotalAmount(Map<String, dynamic>? payment) {
  return paymentBaseAmount(payment) + paymentServiceFee(payment);
}

bool isPaymentPaid(Map<String, dynamic>? payment) {
  return (payment?['status'] ?? '').toString().toLowerCase() == 'paid';
}

bool isPaymentRequired(Map<String, dynamic>? payment) {
  return payment?['payment_required'] == true;
}

bool canMitraStartJob(Map<String, dynamic>? payment) {
  return !isPaymentRequired(payment) || isPaymentPaid(payment);
}

bool hasActiveMidtransCheckout(Map<String, dynamic>? payment) {
  final String link = (payment?['redirect_url'] ?? '').toString().trim();
  final String status = (payment?['status'] ?? '').toString().toLowerCase();
  if (link.isEmpty || status != 'pending' || !isPaymentRequired(payment)) {
    return false;
  }

  final DateTime? expiresAt = DateTime.tryParse(
    (payment?['expires_at'] ?? '').toString(),
  );
  return expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc());
}

String paymentMethodLabel(Object? rawValue) {
  final String value = (rawValue ?? '').toString().trim().toLowerCase();
  switch (value) {
    case 'qris':
      return 'QRIS';
    case 'gopay':
      return 'GoPay';
    case 'shopeepay':
      return 'ShopeePay';
    case 'bank_transfer':
      return 'Transfer Bank';
    case 'echannel':
      return 'Mandiri Bill';
    case 'bca_va':
      return 'BCA Virtual Account';
    case 'bni_va':
      return 'BNI Virtual Account';
    case 'bri_va':
      return 'BRI Virtual Account';
    case 'permata_va':
      return 'Permata Virtual Account';
    case 'cstore':
      return 'Gerai Retail';
    case 'credit_card':
      return 'Kartu Kredit';
    case 'akulaku':
      return 'Akulaku';
    case 'kredivo':
      return 'Kredivo';
    default:
      return value.isEmpty ? '' : value.replaceAll('_', ' ');
  }
}
