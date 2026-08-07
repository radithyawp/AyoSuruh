import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color jobBackgroundColor = Color(0xFFFFF9FC);
const Color jobBrownColor = Color(0xFF9A5B00);
const Color jobDarkBrownColor = Color(0xFF6F4300);
const Color jobOrangeColor = Color(0xFFFF9800);
const Color jobGreenColor = Color(0xFF5C704B);
const Color jobCardColor = Color(0xFFFFFFFF);
const Color jobBorderColor = Color(0xFFE8D5C4);

final NumberFormat _rupiahFormatter = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String formatRupiah(dynamic value) {
  if (value == null) return 'Rp 0';
  final num amount = value is num
      ? value
      : num.tryParse(value.toString()) ?? 0;
  return _rupiahFormatter.format(amount);
}

const List<String> _indonesianMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatJobDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return '-';
  try {
    final DateTime date = DateTime.parse(value.toString()).toLocal();
    return '${date.day.toString().padLeft(2, '0')} '
        '${_indonesianMonths[date.month - 1]} ${date.year}';
  } catch (_) {
    return value.toString();
  }
}

String formatJobDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return '-';
  try {
    final DateTime date = DateTime.parse(value.toString()).toLocal();
    return '${formatJobDate(date.toIso8601String())}, '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return value.toString();
  }
}

String formatJobTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return '-';
  final String raw = value.toString();
  if (raw.length >= 5) return raw.substring(0, 5);
  return raw;
}

String jobStatusLabel(dynamic status) {
  switch (status?.toString()) {
    case 'draft':
      return 'Draft';
    case 'posted':
      return 'Mencari Mitra';
    case 'waiting_bid':
      return 'Menunggu Mitra';
    case 'accepted':
      return 'Mitra Terpilih';
    case 'on_progress':
      return 'Sedang Dikerjakan';
    case 'completed':
      return 'Selesai';
    case 'cancelled':
      return 'Dibatalkan';
    default:
      return 'Pekerjaan';
  }
}

Color jobStatusBackground(dynamic status) {
  switch (status?.toString()) {
    case 'posted':
    case 'waiting_bid':
      return const Color(0xFFFFDAD5);
    case 'accepted':
      return const Color(0xFFFFE5B5);
    case 'on_progress':
      return const Color(0xFFD9EDCB);
    case 'completed':
      return const Color(0xFFD4EDC1);
    case 'cancelled':
      return const Color(0xFFFFD8D4);
    default:
      return const Color(0xFFEDE7E2);
  }
}

Color jobStatusForeground(dynamic status) {
  switch (status?.toString()) {
    case 'posted':
    case 'waiting_bid':
      return const Color(0xFFB64A3D);
    case 'accepted':
      return const Color(0xFF8A5600);
    case 'on_progress':
    case 'completed':
      return const Color(0xFF4F6B3E);
    case 'cancelled':
      return const Color(0xFFB83B32);
    default:
      return const Color(0xFF62564D);
  }
}

String bidStatusLabel(dynamic status) {
  switch (status?.toString()) {
    case 'accepted':
      return 'Diterima';
    case 'rejected':
      return 'Ditolak';
    default:
      return 'Menunggu';
  }
}

String categoryName(Map<String, dynamic> job) {
  final dynamic category = job['categories'];
  if (category is Map && category['name'] != null) {
    return category['name'].toString();
  }
  return 'Lainnya';
}

String jobAddress(Map<String, dynamic> job) {
  final dynamic address = job['addresses'];
  if (address is Map && address['address'] != null) {
    return address['address'].toString();
  }
  return 'Alamat belum tersedia';
}

String customerName(Map<String, dynamic> job) {
  final dynamic customer = job['customer'];
  if (customer is Map && customer['fullname'] != null) {
    return customer['fullname'].toString();
  }
  return 'Customer';
}

String? customerAvatar(Map<String, dynamic> job) {
  final dynamic customer = job['customer'];
  if (customer is Map && customer['avatar_url'] != null) {
    return customer['avatar_url'].toString();
  }
  return null;
}

String selectedMitraName(Map<String, dynamic> job) {
  final dynamic mitra = job['mitra'];
  if (mitra is Map && mitra['fullname'] != null) {
    return mitra['fullname'].toString();
  }
  return 'Mitra';
}

List<Map<String, dynamic>> embeddedBids(Map<String, dynamic> job) {
  final dynamic bids = job['bids'];
  if (bids is List) {
    return bids.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }
  return <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> embeddedReviews(Map<String, dynamic> job) {
  final dynamic reviews = job['reviews'];
  if (reviews is List) {
    return reviews.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }
  return <Map<String, dynamic>>[];
}

IconData categoryIcon(String value) {
  final String category = value.toLowerCase();
  if (category.contains('elektronik')) return Icons.electrical_services_rounded;
  if (category.contains('antar-jemput')) return Icons.commute_rounded;
  if (category.contains('jasa titip')) return Icons.shopping_bag_rounded;
  if (category.contains('kost')) return Icons.apartment_rounded;
  if (category.contains('administrasi')) return Icons.description_rounded;
  if (category.contains('design') || category.contains('coding')) {
    return Icons.code_rounded;
  }
  if (category.contains('rumah tangga') || category.contains('bersih')) {
    return Icons.home_repair_service_rounded;
  }
  if (category.contains('otomotif')) return Icons.two_wheeler_rounded;
  if (category.contains('kurir') || category.contains('antar')) {
    return Icons.local_shipping_rounded;
  }
  if (category.contains('tukang') || category.contains('perbaikan')) {
    return Icons.handyman_rounded;
  }
  return Icons.grid_view_rounded;
}

Color categoryBackground(String value) {
  final String category = value.toLowerCase();
  if (category.contains('elektronik') || category.contains('administrasi')) {
    return const Color(0xFFFFE9C9);
  }
  if (category.contains('antar') ||
      category.contains('kurir') ||
      category.contains('kost')) {
    return const Color(0xFFE8F3DF);
  }
  if (category.contains('jasa titip') ||
      category.contains('design') ||
      category.contains('coding')) {
    return const Color(0xFFFFE3E0);
  }
  if (category.contains('rumah tangga') ||
      category.contains('otomotif') ||
      category.contains('tukang')) {
    return const Color(0xFFFFEDCC);
  }
  return const Color(0xFFF2ECE7);
}

const List<String> jobProgressStages = <String>[
  'heading_to_location',
  'arrived',
  'working',
  'completion_submitted',
];

String jobProgressLabel(String? stage) {
  switch (stage) {
    case 'heading_to_location':
      return 'Menuju Lokasi';
    case 'arrived':
      return 'Tiba di Lokasi';
    case 'working':
      return 'Mulai Bekerja';
    case 'completion_submitted':
      return 'Pekerjaan Selesai';
    default:
      return 'Belum Dimulai';
  }
}

String jobProgressDescription(String stage) {
  switch (stage) {
    case 'heading_to_location':
      return 'Mitra sedang dalam perjalanan ke alamat pelanggan.';
    case 'arrived':
      return 'Mitra sudah tiba di lokasi pekerjaan.';
    case 'working':
      return 'Mitra sedang melaksanakan pekerjaan.';
    case 'completion_submitted':
      return 'Mitra telah menyelesaikan tugas dan menunggu konfirmasi customer.';
    default:
      return 'Pekerjaan belum memiliki pembaruan progres.';
  }
}

IconData jobProgressIcon(String stage) {
  switch (stage) {
    case 'heading_to_location':
      return Icons.directions_walk_rounded;
    case 'arrived':
      return Icons.location_on_rounded;
    case 'working':
      return Icons.play_arrow_rounded;
    case 'completion_submitted':
      return Icons.check_circle_outline_rounded;
    default:
      return Icons.schedule_rounded;
  }
}

String? currentJobProgressStage(Map<String, dynamic> job) {
  final String status = (job['status'] ?? '').toString();
  if (status == 'completed') return 'completion_submitted';
  if (status != 'on_progress') return null;
  final String? stage = job['progress_stage']?.toString();
  if (stage != null && stage.isNotEmpty) return stage;
  return 'heading_to_location';
}

String? nextJobProgressStage(String? currentStage) {
  if (currentStage == null) return 'heading_to_location';
  final int index = jobProgressStages.indexOf(currentStage);
  if (index < 0 || index >= jobProgressStages.length - 1) return null;
  return jobProgressStages[index + 1];
}

int jobProgressIndex(String? stage) {
  final int index = jobProgressStages.indexOf(stage ?? '');
  return index < 0 ? -1 : index;
}
