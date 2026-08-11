import 'package:flutter/material.dart';
import '../theme/ayo_theme.dart';

const Color paymentOrange = Color(0xFFF6990E);
Color get paymentBrown => AyoAdaptiveColors.brown;
Color get paymentDarkBrown => AyoAdaptiveColors.brownDark;
const Color paymentGreen = Color(0xFF5E774F);
Color get paymentBackground => AyoAdaptiveColors.canvas;
Color get paymentBorder => AyoAdaptiveColors.border;

String paymentProvider(Map<String, dynamic>? payment) {
  return (payment?['provider'] ?? '').toString().trim().toLowerCase();
}

bool isCashPayment(Map<String, dynamic>? payment) {
  return paymentProvider(payment) == 'cash';
}

String paymentStatusLabel(Map<String, dynamic>? payment) {
  final String status =
      (payment?['status'] ?? 'pending').toString().toLowerCase();

  if (!isPaymentRequired(payment) &&
      !<String>['refunded', 'cancelled'].contains(status)) {
    return 'Pilih Metode Pembayaran';
  }

  if (isCashPayment(payment)) {
    switch (status) {
      case 'paid':
        return 'Tunai Sudah Dibayar';
      case 'cancelled':
        return 'Pembayaran Tunai Dibatalkan';
      case 'refunded':
        return 'Pembayaran Dikembalikan';
      default:
        return 'Menunggu Pembayaran Tunai';
    }
  }

  switch (status) {
    case 'paid':
      return 'Sudah Dibayar';
    case 'failed':
      return 'Pembayaran Gagal';
    case 'expired':
      return 'Pembayaran Kedaluwarsa';
    case 'refunded':
      return 'Sudah Direfund';
    case 'cancelled':
      return 'Transaksi Dibatalkan';
    default:
      return 'Menunggu Pembayaran';
  }
}

Color paymentStatusColor(Map<String, dynamic>? payment) {
  final String status =
      (payment?['status'] ?? 'pending').toString().toLowerCase();
  if (!isPaymentRequired(payment) &&
      !<String>['refunded', 'cancelled'].contains(status)) {
    return const Color(0xFF8A7B72);
  }

  switch (status) {
    case 'paid':
      return paymentGreen;
    case 'failed':
      return Colors.red.shade700;
    case 'expired':
      return const Color(0xFF9B5D00);
    case 'refunded':
      return const Color(0xFF3E6B7A);
    case 'cancelled':
      return const Color(0xFF7A6C65);
    default:
      return paymentOrange;
  }
}

Color paymentStatusBackground(Map<String, dynamic>? payment) {
  final String status =
      (payment?['status'] ?? 'pending').toString().toLowerCase();
  if (!isPaymentRequired(payment) &&
      !<String>['refunded', 'cancelled'].contains(status)) {
    return const Color(0xFFF1ECE8);
  }

  switch (status) {
    case 'paid':
      return const Color(0xFFE2F1D8);
    case 'failed':
      return const Color(0xFFFFE1DE);
    case 'expired':
      return const Color(0xFFFFEBCB);
    case 'refunded':
      return const Color(0xFFDCEEF3);
    case 'cancelled':
      return const Color(0xFFEDE7E3);
    default:
      return const Color(0xFFFFEED5);
  }
}

IconData paymentStatusIcon(Map<String, dynamic>? payment) {
  final String status =
      (payment?['status'] ?? 'pending').toString().toLowerCase();

  if (!isPaymentRequired(payment) &&
      !<String>['refunded', 'cancelled'].contains(status)) {
    return Icons.payment_rounded;
  }

  if (isCashPayment(payment) && status == 'pending') {
    return Icons.payments_rounded;
  }

  switch (status) {
    case 'paid':
      return Icons.check_circle_rounded;
    case 'failed':
      return Icons.error_rounded;
    case 'expired':
      return Icons.timer_off_rounded;
    case 'refunded':
      return Icons.currency_exchange_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
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

num paymentDiscountAmount(Map<String, dynamic>? payment) {
  final dynamic value = payment?['discount_amount'];
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

num paymentTotalAmount(Map<String, dynamic>? payment) {
  final dynamic explicit = payment?['payable_amount'];
  if (explicit is num) return explicit;
  final num? parsed = num.tryParse(explicit?.toString() ?? '');
  if (parsed != null) return parsed;

  final num calculated = paymentBaseAmount(payment) +
      paymentServiceFee(payment) -
      paymentDiscountAmount(payment);
  return calculated < 0 ? 0 : calculated;
}

bool isPaymentPaid(Map<String, dynamic>? payment) {
  return (payment?['status'] ?? '').toString().toLowerCase() == 'paid';
}

bool isPaymentRefunded(Map<String, dynamic>? payment) {
  return (payment?['status'] ?? '').toString().toLowerCase() == 'refunded';
}

bool isPaymentCancelled(Map<String, dynamic>? payment) {
  return (payment?['status'] ?? '').toString().toLowerCase() == 'cancelled';
}

bool isPaymentRequired(Map<String, dynamic>? payment) {
  return payment?['payment_required'] == true;
}

bool hasSelectedPaymentMethod(Map<String, dynamic>? payment) {
  if (payment == null || !isPaymentRequired(payment)) return false;
  final String provider = paymentProvider(payment);
  return provider.isNotEmpty;
}

bool canMitraStartJob(Map<String, dynamic>? payment) {
  if (!hasSelectedPaymentMethod(payment)) return false;

  final String status =
      (payment?['status'] ?? '').toString().trim().toLowerCase();
  if (isCashPayment(payment)) {
    return <String>['pending', 'paid'].contains(status);
  }
  return isPaymentPaid(payment);
}

String mitraPaymentGateLabel(Map<String, dynamic>? payment) {
  if (!hasSelectedPaymentMethod(payment)) {
    return 'Menunggu Customer Memilih Pembayaran';
  }
  if (isCashPayment(payment)) {
    return 'Pembayaran Cash Dipilih';
  }
  if (!isPaymentPaid(payment)) {
    return 'Menunggu Pembayaran Customer';
  }
  return 'Pembayaran Siap';
}

bool hasActiveMidtransCheckout(Map<String, dynamic>? payment) {
  if (isCashPayment(payment)) return false;

  final String link = (payment?['redirect_url'] ?? '').toString().trim();
  final String status =
      (payment?['status'] ?? '').toString().toLowerCase();

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
    case 'cash':
      return 'Tunai / Cash';
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
