import 'package:flutter/material.dart';
import '../theme/ayo_theme.dart';

Color get refundBrown => AyoAdaptiveColors.brown;
const Color refundOrange = Color(0xFFF6990E);
Color get refundBackground => AyoAdaptiveColors.canvas;

String refundStatusLabel(Object? raw) {
  switch ((raw ?? '').toString().toLowerCase()) {
    case 'requested':
      return 'Permintaan Dikirim';
    case 'processing':
      return 'Sedang Diproses';
    case 'manual_review':
      return 'Perlu Ditinjau';
    case 'refunded':
      return 'Refund Disetujui';
    case 'partially_refunded':
      return 'Refund Sebagian Disetujui';
    case 'cancelled':
      return 'Transaksi Dibatalkan';
    case 'rejected':
      return 'Refund Ditolak';
    case 'failed':
      return 'Refund Gagal';
    default:
      return 'Belum Ada Permintaan';
  }
}

Color refundStatusColor(Object? raw) {
  switch ((raw ?? '').toString().toLowerCase()) {
    case 'refunded':
    case 'partially_refunded':
      return const Color(0xFF4F7340);
    case 'manual_review':
      return const Color(0xFF9B5D00);
    case 'rejected':
    case 'failed':
      return Colors.red.shade700;
    case 'cancelled':
      return const Color(0xFF766A64);
    default:
      return refundOrange;
  }
}

Color refundStatusBackground(Object? raw) {
  switch ((raw ?? '').toString().toLowerCase()) {
    case 'refunded':
    case 'partially_refunded':
      return const Color(0xFFE4F1DB);
    case 'manual_review':
      return const Color(0xFFFFEBCB);
    case 'rejected':
    case 'failed':
      return const Color(0xFFFFE1DE);
    case 'cancelled':
      return const Color(0xFFEDE8E5);
    default:
      return const Color(0xFFFFEED5);
  }
}

IconData refundStatusIcon(Object? raw) {
  switch ((raw ?? '').toString().toLowerCase()) {
    case 'refunded':
    case 'partially_refunded':
      return Icons.currency_exchange_rounded;
    case 'manual_review':
      return Icons.manage_search_rounded;
    case 'rejected':
    case 'failed':
      return Icons.error_outline_rounded;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.hourglass_top_rounded;
  }
}

bool isRefundFinal(Object? raw) {
  return <String>{
    'refunded',
    'partially_refunded',
    'cancelled',
    'rejected',
    'failed',
  }.contains((raw ?? '').toString().toLowerCase());
}
