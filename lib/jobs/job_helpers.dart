import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/ayo_theme.dart';
import '../settings/app_settings.dart';

Color get jobBackgroundColor => AppSettingsController.instance.isDarkMode
    ? AyoDarkColors.canvas
    : AyoColors.canvas;
Color get jobBrownColor => AppSettingsController.instance.isDarkMode
    ? AyoDarkColors.warm
    : AyoColors.brown;
Color get jobDarkBrownColor => AppSettingsController.instance.isDarkMode
    ? AyoDarkColors.onSurface
    : AyoColors.brownDark;
const Color jobOrangeColor = AyoColors.orange;
Color get jobGreenColor => AppSettingsController.instance.isDarkMode
    ? AyoColors.green
    : AyoColors.greenDark;
Color get jobCardColor => AppSettingsController.instance.isDarkMode
    ? AyoDarkColors.surface
    : AyoColors.surface;
Color get jobBorderColor => AppSettingsController.instance.isDarkMode
    ? AyoDarkColors.border
    : AyoColors.border;

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

const List<String> _englishMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatJobDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return '-';
  try {
    final DateTime date = DateTime.parse(value.toString()).toLocal();
    final List<String> months = AppSettingsController.instance.isEnglish
        ? _englishMonths
        : _indonesianMonths;
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
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
  Color light;
  switch (status?.toString()) {
    case 'posted':
    case 'waiting_bid':
      light = const Color(0xFFFFDAD5);
      break;
    case 'accepted':
      light = const Color(0xFFFFE5B5);
      break;
    case 'on_progress':
      light = const Color(0xFFD9EDCB);
      break;
    case 'completed':
      light = const Color(0xFFD4EDC1);
      break;
    case 'cancelled':
      light = const Color(0xFFFFD8D4);
      break;
    default:
      light = const Color(0xFFEDE7E2);
  }
  if (!AppSettingsController.instance.isDarkMode) return light;
  return Color.alphaBlend(
    light.withValues(alpha: 0.18),
    AyoDarkColors.surfaceRaised,
  );
}

Color jobStatusForeground(dynamic status) {
  final bool dark = AppSettingsController.instance.isDarkMode;
  switch (status?.toString()) {
    case 'posted':
    case 'waiting_bid':
      return dark ? const Color(0xFFFFA79D) : const Color(0xFFB64A3D);
    case 'accepted':
      return dark ? const Color(0xFFFFCC76) : const Color(0xFF8A5600);
    case 'on_progress':
    case 'completed':
      return dark ? const Color(0xFFC6E8B5) : const Color(0xFF4F6B3E);
    case 'cancelled':
      return dark ? const Color(0xFFFFA39B) : const Color(0xFFB83B32);
    default:
      return dark ? AyoDarkColors.muted : const Color(0xFF62564D);
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

bool isFirstJobPriority(Map<String, dynamic> job) {
  if (job['is_first_job_priority'] != true) return false;
  final DateTime? until = DateTime.tryParse(
    (job['priority_until'] ?? '').toString(),
  )?.toUtc();
  if (until == null) return false;
  return until.isAfter(DateTime.now().toUtc());
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

List<String> jobImageUrls(Map<String, dynamic> job) {
  final dynamic images = job['job_images'];
  if (images is! List) return <String>[];
  return images
      .whereType<Map>()
      .map((Map image) => (image['image_url'] ?? '').toString().trim())
      .where((String url) => url.isNotEmpty)
      .toList();
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
  if (category.contains('gaya hidup') ||
      category.contains('konsultasi') ||
      category.contains('wellness')) {
    return Icons.self_improvement_rounded;
  }
  return Icons.grid_view_rounded;
}


String? categoryImageAsset(String value) {
  final String category = value.toLowerCase();
  if (category.contains('elektronik')) {
    return 'assets/images/categories/elektronik.webp';
  }
  if (category.contains('antar-jemput')) {
    return 'assets/images/categories/antar_jemput.webp';
  }
  if (category.contains('jasa titip')) {
    return 'assets/images/categories/jasa_titip.webp';
  }
  if (category.contains('kost')) {
    return 'assets/images/categories/survey_kost.webp';
  }
  if (category.contains('administrasi')) {
    return 'assets/images/categories/administrasi.webp';
  }
  if (category.contains('design') || category.contains('coding')) {
    return 'assets/images/categories/design_coding.webp';
  }
  if (category.contains('rumah tangga') || category.contains('bersih')) {
    return 'assets/images/categories/rumah_tangga.webp';
  }
  if (category.contains('otomotif')) {
    return 'assets/images/categories/otomotif.webp';
  }
  if (category.contains('kurir')) {
    return 'assets/images/categories/kurir.webp';
  }
  if (category.contains('tukang') || category.contains('perbaikan')) {
    return 'assets/images/categories/tukang.webp';
  }
  if (category.contains('gaya hidup') ||
      category.contains('konsultasi') ||
      category.contains('wellness')) {
    return 'assets/images/categories/gaya_hidup.webp';
  }

  // Kategori "Lainnya" sengaja mempertahankan ikon grid 4 kotak.
  return null;
}

Color categoryBackground(String value) {
  final String category = value.toLowerCase();
  Color accent;
  if (category.contains('elektronik') || category.contains('administrasi')) {
    accent = const Color(0xFFFFE9C9);
  } else if (category.contains('antar') ||
      category.contains('kurir') ||
      category.contains('kost')) {
    accent = const Color(0xFFE8F3DF);
  } else if (category.contains('jasa titip') ||
      category.contains('design') ||
      category.contains('coding')) {
    accent = const Color(0xFFFFE3E0);
  } else if (category.contains('rumah tangga') ||
      category.contains('otomotif') ||
      category.contains('tukang')) {
    accent = const Color(0xFFFFEDCC);
  } else if (category.contains('gaya hidup') ||
      category.contains('konsultasi') ||
      category.contains('wellness')) {
    accent = const Color(0xFFE8F3DF);
  } else {
    accent = const Color(0xFFF2ECE7);
  }

  if (!AppSettingsController.instance.isDarkMode) return accent;
  // Keep category identity without placing a bright pastel tile on a dark UI.
  // The translucent tint is blended over the raised dark surface so icons and
  // labels preserve contrast across Home, Jobs and marketplace cards.
  return Color.alphaBlend(
    accent.withValues(alpha: 0.13),
    AyoDarkColors.surfaceRaised,
  );
}

const String jobWorkModeRemote = 'remote';
const String jobWorkModeOnsite = 'onsite';
const String jobWorkModeMobile = 'mobile';

const List<String> jobWorkModes = <String>[
  jobWorkModeRemote,
  jobWorkModeOnsite,
  jobWorkModeMobile,
];

String defaultJobWorkModeForCategory(String value) {
  final String category = value.trim().toLowerCase();
  if (category.contains('design') ||
      category.contains('coding') ||
      category.contains('administrasi')) {
    return jobWorkModeRemote;
  }
  if (category.contains('antar-jemput') ||
      category.contains('jasa titip') ||
      category.contains('kurir')) {
    return jobWorkModeMobile;
  }
  return jobWorkModeOnsite;
}

String jobWorkMode(Map<String, dynamic> job) {
  final String value = (job['work_mode'] ?? '').toString().trim().toLowerCase();
  if (jobWorkModes.contains(value)) return value;
  return defaultJobWorkModeForCategory(categoryName(job));
}

bool jobNeedsPhysicalLocation(Map<String, dynamic> job) {
  return jobWorkMode(job) != jobWorkModeRemote;
}

bool jobNeedsRouteEndpoints(Map<String, dynamic> job) {
  return jobWorkMode(job) == jobWorkModeMobile;
}

bool workModeNeedsRouteEndpoints(String mode) {
  return mode.trim().toLowerCase() == jobWorkModeMobile;
}

String jobOriginLabel(Map<String, dynamic> job) {
  final String category = categoryName(job).trim().toLowerCase();
  if (category.contains('antar-jemput')) return 'Titik Jemput';
  if (category.contains('jasa titip')) return 'Lokasi Pembelian / Pengambilan';
  if (category.contains('kurir')) return 'Titik Pengambilan';
  return 'Titik Awal';
}

String jobDestinationLabel(Map<String, dynamic> job) {
  final String category = categoryName(job).trim().toLowerCase();
  if (category.contains('antar-jemput')) return 'Tujuan Antar';
  if (category.contains('jasa titip')) return 'Titik Penyerahan';
  if (category.contains('kurir')) return 'Titik Pengantaran';
  return 'Titik Tujuan';
}

String jobOriginLabelForCategory(String categoryNameValue) {
  return jobOriginLabel(<String, dynamic>{
    'categories': <String, dynamic>{'name': categoryNameValue},
    'work_mode': jobWorkModeMobile,
  });
}

String jobDestinationLabelForCategory(String categoryNameValue) {
  return jobDestinationLabel(<String, dynamic>{
    'categories': <String, dynamic>{'name': categoryNameValue},
    'work_mode': jobWorkModeMobile,
  });
}

String jobDestinationAddress(Map<String, dynamic> job) {
  final dynamic destination = job['destination_address'];
  if (destination is Map && destination['address'] != null) {
    final String value = destination['address'].toString().trim();
    if (value.isNotEmpty) return value;
  }
  final dynamic direct = job['destination_address_text'];
  if (direct != null && direct.toString().trim().isNotEmpty) {
    return direct.toString().trim();
  }
  return 'Tujuan belum tersedia';
}

String jobWorkModeLabel(String mode) {
  switch (mode) {
    case jobWorkModeRemote:
      return 'Online / Jarak Jauh';
    case jobWorkModeMobile:
      return 'Mobilitas / Antar';
    case jobWorkModeOnsite:
    default:
      return 'Datang ke Lokasi';
  }
}

String jobWorkModeDescription(String mode) {
  switch (mode) {
    case jobWorkModeRemote:
      return 'Pekerjaan dilakukan secara online tanpa Mitra datang ke lokasi Customer.';
    case jobWorkModeMobile:
      return 'Pekerjaan membutuhkan perjalanan, pengambilan, pengantaran, atau kunjungan ke beberapa titik.';
    case jobWorkModeOnsite:
    default:
      return 'Mitra datang ke lokasi yang ditentukan Customer untuk mengerjakan pekerjaan.';
  }
}

IconData jobWorkModeIcon(String mode) {
  switch (mode) {
    case jobWorkModeRemote:
      return Icons.laptop_mac_rounded;
    case jobWorkModeMobile:
      return Icons.route_rounded;
    case jobWorkModeOnsite:
    default:
      return Icons.location_on_rounded;
  }
}

String jobAddress(Map<String, dynamic> job) {
  if (!jobNeedsPhysicalLocation(job)) {
    return 'Pengerjaan online / jarak jauh';
  }
  final dynamic address = job['addresses'];
  if (address is Map && address['address'] != null) {
    return address['address'].toString();
  }
  return 'Alamat belum tersedia';
}

const List<String> jobProgressStages = <String>[
  'heading_to_location',
  'arrived',
  'working',
  'completion_submitted',
];

const List<String> remoteJobProgressStages = <String>[
  'working',
  'completion_submitted',
];

List<String> jobProgressStagesFor(Map<String, dynamic> job) {
  return jobWorkMode(job) == jobWorkModeRemote
      ? remoteJobProgressStages
      : jobProgressStages;
}

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

String jobProgressLabelFor(Map<String, dynamic> job, String? stage) {
  final String mode = jobWorkMode(job);
  final String category = categoryName(job).trim().toLowerCase();

  if (mode == jobWorkModeRemote) {
    switch (stage) {
      case 'working':
        return 'Sedang Mengerjakan';
      case 'completion_submitted':
        return 'Ajukan Pekerjaan Selesai';
      default:
        return 'Belum Dimulai';
    }
  }

  if (mode == jobWorkModeMobile) {
    if (category.contains('kurir')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Menuju Titik Pengambilan';
        case 'arrived':
          return 'Barang Diambil';
        case 'working':
          return 'Sedang Diantar';
        case 'completion_submitted':
          return 'Pengantaran Selesai';
      }
    }
    if (category.contains('antar-jemput')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Menuju Titik Jemput';
        case 'arrived':
          return 'Tiba di Titik Jemput';
        case 'working':
          return 'Perjalanan Berlangsung';
        case 'completion_submitted':
          return 'Perjalanan Selesai';
      }
    }
    if (category.contains('jasa titip')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Menuju Lokasi Pembelian';
        case 'arrived':
          return 'Tiba di Lokasi';
        case 'working':
          return 'Menuju Titik Penyerahan';
        case 'completion_submitted':
          return 'Jasa Titip Selesai';
      }
    }
    if (category.contains('kost')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Menuju Lokasi Kost';
        case 'arrived':
          return 'Tiba di Lokasi Kost';
        case 'working':
          return 'Survey Berlangsung';
        case 'completion_submitted':
          return 'Survey Selesai';
      }
    }
    switch (stage) {
      case 'heading_to_location':
        return 'Menuju Titik Awal';
      case 'arrived':
        return 'Tiba di Titik Awal';
      case 'working':
        return 'Menuju Titik Tujuan';
      case 'completion_submitted':
        return 'Pekerjaan Selesai';
    }
  }

  return jobProgressLabel(stage);
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

String jobProgressDescriptionFor(Map<String, dynamic> job, String stage) {
  final String mode = jobWorkMode(job);
  final String category = categoryName(job).trim().toLowerCase();

  if (mode == jobWorkModeRemote) {
    switch (stage) {
      case 'working':
        return 'Mitra sedang mengerjakan pekerjaan secara online / jarak jauh.';
      case 'completion_submitted':
        return 'Mitra telah mengajukan hasil pekerjaan dan menunggu konfirmasi Customer.';
    }
  }

  if (mode == jobWorkModeMobile) {
    if (category.contains('kurir')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Mitra sedang menuju titik pengambilan barang.';
        case 'arrived':
          return 'Barang sudah diambil oleh Mitra.';
        case 'working':
          return 'Barang sedang dalam proses pengantaran.';
        case 'completion_submitted':
          return 'Mitra telah menyelesaikan pengantaran dan menunggu konfirmasi Customer.';
      }
    }
    if (category.contains('antar-jemput')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Mitra sedang menuju titik penjemputan.';
        case 'arrived':
          return 'Mitra sudah tiba di titik penjemputan.';
        case 'working':
          return 'Perjalanan antar-jemput sedang berlangsung.';
        case 'completion_submitted':
          return 'Perjalanan telah selesai dan menunggu konfirmasi Customer.';
      }
    }
    if (category.contains('jasa titip')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Mitra sedang menuju lokasi pembelian.';
        case 'arrived':
          return 'Mitra sudah tiba di lokasi pembelian.';
        case 'working':
          return 'Barang titipan sudah diproses dan Mitra sedang menuju titik penyerahan.';
        case 'completion_submitted':
          return 'Jasa titip telah selesai dan menunggu konfirmasi Customer.';
      }
    }
    if (category.contains('kost')) {
      switch (stage) {
        case 'heading_to_location':
          return 'Mitra sedang menuju lokasi kost yang akan disurvey.';
        case 'arrived':
          return 'Mitra sudah tiba di lokasi kost.';
        case 'working':
          return 'Survey dan pengumpulan informasi sedang dilakukan.';
        case 'completion_submitted':
          return 'Survey telah selesai dan menunggu konfirmasi Customer.';
      }
    }
  }

  return jobProgressDescription(stage);
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
  return jobWorkMode(job) == jobWorkModeRemote
      ? 'working'
      : 'heading_to_location';
}

String? nextJobProgressStage(String? currentStage) {
  if (currentStage == null) return 'heading_to_location';
  final int index = jobProgressStages.indexOf(currentStage);
  if (index < 0 || index >= jobProgressStages.length - 1) return null;
  return jobProgressStages[index + 1];
}

String? nextJobProgressStageFor(
  Map<String, dynamic> job,
  String? currentStage,
) {
  final List<String> stages = jobProgressStagesFor(job);
  if (currentStage == null) return stages.first;
  final int index = stages.indexOf(currentStage);
  if (index < 0) return stages.first;
  if (index >= stages.length - 1) return null;
  return stages[index + 1];
}

int jobProgressIndex(String? stage) {
  final int index = jobProgressStages.indexOf(stage ?? '');
  return index < 0 ? -1 : index;
}

int jobProgressIndexFor(Map<String, dynamic> job, String? stage) {
  final int index = jobProgressStagesFor(job).indexOf(stage ?? '');
  return index < 0 ? -1 : index;
}
