import 'package:flutter/material.dart';
import 'widgets/ayo_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/home_shortcut_button.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  static const Color _brownColor = Color(0xFF8B5A2B);
  static const Color _orangeColor = Color(0xFFF39C12);
  static const Color _bgGrey = Color(0xFFFAF6F3);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showAll = false;

  static const List<_FaqItem> _faqs = <_FaqItem>[
    _FaqItem(
      category: 'Customer',
      question: 'Bagaimana cara membuat pekerjaan?',
      answer:
          'Dari Home tekan Buat Pekerjaan, pilih kategori, isi judul dan deskripsi, tentukan lokasi, jadwal, serta estimasi harga. Setelah dipublikasikan, pekerjaan akan terlihat oleh mitra yang dapat mengirim penawaran.',
    ),
    _FaqItem(
      category: 'Customer',
      question: 'Bagaimana memilih mitra yang mengirim penawaran?',
      answer:
          'Buka detail pekerjaan lalu bandingkan harga, estimasi pengerjaan, pesan, dan profil mitra. Pilih penawaran yang paling sesuai. Setelah dipilih, pekerjaan masuk ke tahap transaksi dan pengerjaan.',
    ),
    _FaqItem(
      category: 'Customer',
      question: 'Apakah lokasi pekerjaan harus sama dengan alamat profil?',
      answer:
          'Tidak. Alamat profil hanya menjadi lokasi utama yang tampil di Home. Saat membuat pekerjaan Anda dapat memilih alamat lain, misalnya minimarket, kost, kampus, atau lokasi tujuan tertentu.',
    ),
    _FaqItem(
      category: 'Customer',
      question: 'Bagaimana mencari titik lokasi pekerjaan?',
      answer:
          'Pada form Buat Pekerjaan, buka pemilih peta. Anda dapat mencari alamat dengan OpenStreetMap, memakai lokasi perangkat, atau mengetuk peta untuk mengoreksi titik secara manual.',
    ),
    _FaqItem(
      category: 'Customer',
      question: 'Bagaimana pembayaran dilakukan?',
      answer:
          'Pembayaran pekerjaan yang sudah menggunakan payment gateway diproses melalui Midtrans. Status pembayaran akan disinkronkan ke Ayo Suruh sebelum alur pekerjaan dilanjutkan.',
    ),
    _FaqItem(
      category: 'Customer',
      question: 'Bagaimana jika saya membutuhkan refund?',
      answer:
          'Refund hanya tersedia pada transaksi dan kondisi yang memenuhi kebijakan. Ajukan dari detail transaksi jika opsi refund tersedia. Status permintaan akan tercatat dan dapat dipantau pada aplikasi.',
    ),
    _FaqItem(
      category: 'Customer',
      question: 'Bagaimana cara memberi rating kepada mitra?',
      answer:
          'Setelah pekerjaan selesai dan dikonfirmasi, buka detail atau riwayat pekerjaan lalu berikan rating dan ulasan berdasarkan pengalaman Anda.',
    ),
    _FaqItem(
      category: 'Akun',
      question: 'Saya lupa password. Apakah harus menghubungi admin?',
      answer:
          'Tidak. Pada halaman Login tekan Lupa Password, masukkan email akun, lalu buka tautan pemulihan yang dikirim ke email untuk membuat password baru.',
    ),
    _FaqItem(
      category: 'Akun',
      question: 'Apa fungsi Ingat Saya?',
      answer:
          'Ingat Saya mempertahankan sesi login pada perangkat dan mengingat email. Ayo Suruh tidak menyimpan password mentah; password dapat dikelola oleh password manager atau autofill bawaan perangkat.',
    ),
    _FaqItem(
      category: 'Mitra',
      question: 'Bagaimana cara menjadi mitra Ayo Suruh?',
      answer:
          'Ajukan pendaftaran mitra dari menu profil, lengkapi data dan dokumen yang diminta, lalu tunggu proses peninjauan. Setelah disetujui, akunmu dapat digunakan sebagai Mitra.',
    ),
    _FaqItem(
      category: 'Mitra',
      question: 'Bagaimana cara mengambil pekerjaan?',
      answer:
          'Saat menggunakan akun sebagai Mitra, buka pekerjaan yang tersedia, pelajari kebutuhan customer, lalu kirim penawaran harga, estimasi waktu, dan pesan. Customer akan memilih penawaran yang dianggap paling sesuai.',
    ),
    _FaqItem(
      category: 'Mitra',
      question: 'Berapa komisi Ayo Suruh untuk mitra?',
      answer:
          'Ayo Suruh menggunakan komisi platform 6% dari nilai jasa pada transaksi berhasil, kecuali diinformasikan lain pada aplikasi. Nilai komisi dicatat pada transaksi agar histori tetap konsisten jika kebijakan tarif diperbarui.',
    ),
    _FaqItem(
      category: 'Mitra',
      question: 'Kapan pendapatan masuk ke Dompet Mitra?',
      answer:
          'Pendapatan bersih masuk ke ledger Dompet Mitra setelah pembayaran berstatus berhasil dan pekerjaan selesai. Sistem dapat menerapkan masa hold sebelum saldo berubah menjadi tersedia untuk dicairkan.',
    ),
    _FaqItem(
      category: 'Mitra',
      question: 'Bagaimana cara mencairkan saldo Mitra?',
      answer:
          'Buka Dompet & Rekening, pastikan rekening pencairan sudah tersedia, lalu ajukan nominal penarikan. Biaya transfer atau ketentuan pencairan ditampilkan terpisah dari komisi platform.',
    ),
    _FaqItem(
      category: 'Mitra',
      question: 'Apa yang terjadi jika transaksi direfund?',
      answer:
          'Jika pembayaran yang sudah mengkredit pendapatan mitra kemudian direfund atau dibatalkan, sistem melakukan penyesuaian pada ledger agar saldo mengikuti nilai transaksi yang valid.',
    ),
    _FaqItem(
      category: 'AyoPay',
      question: 'Bagaimana cara isi saldo AyoPay?',
      answer:
          'Top up AyoPay akan tersedia pada akun dan metode pembayaran yang didukung. Saat aktif, instruksi pembayaran, status top up, dan riwayat saldo akan tersedia langsung di aplikasi.',
    ),
    _FaqItem(
      category: 'Keamanan',
      question: 'Apakah login Google membuat akun baru yang terpisah?',
      answer:
          'Ayo Suruh menyinkronkan akun Google dengan profil pengguna berdasarkan identitas Supabase. Untuk email yang sudah terhubung pada identitas yang sama, data profil tetap diarahkan ke akun pengguna yang sama.',
    ),
    _FaqItem(
      category: 'Keamanan',
      question: 'Apa yang harus dilakukan jika menemukan aktivitas mencurigakan?',
      answer:
          'Segera ganti password, keluar dari akun pada perangkat yang tidak dikenal jika opsi sesi tersedia, dan hubungi Pusat Dukungan Ayo Suruh melalui WhatsApp untuk pemeriksaan lebih lanjut.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          AyoSnackBar.error(context, 'Tautan belum dapat dibuka.');
        }
      }
    } catch (_) {
      if (context.mounted) {
        AyoSnackBar.error(context, 'Gagal membuka aplikasi tujuan.');
      }
    }
  }

  List<_FaqItem> get _filteredFaqs {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return _faqs;
    return _faqs.where((_FaqItem faq) {
      return faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<_FaqItem> filtered = _filteredFaqs;
    final List<_FaqItem> visible = _showAll || _query.trim().isNotEmpty
        ? filtered
        : filtered.take(5).toList();

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _brownColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bantuan & Pusat Dukungan',
          style: TextStyle(
            color: _brownColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: <Widget>[
          _buildHeaderWithSearch(),
          const SizedBox(height: 36),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _query.trim().isEmpty ? 'Pertanyaan Populer' : 'Hasil Pencarian',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_query.trim().isEmpty)
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll ? 'Ringkas' : 'Lihat Semua',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _brownColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Topik belum ditemukan. Coba kata kunci lain atau hubungi tim dukungan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF766A62)),
              ),
            )
          else
            ...visible.map(_buildFaqTile),
          const SizedBox(height: 22),
          const Text(
            'Masih butuh bantuan?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _buildContactCard(
            icon: Icons.chat_bubble_outline_rounded,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            borderColor: const Color(0xFFC8E6C9),
            title: 'Chat via WhatsApp',
            subtitle: 'WhatsApp Business Ayo Suruh',
            onTap: () => _launchURL(
              context,
              'https://wa.me/628895255693?text=Halo%20Ayo%20Suruh%2C%20saya%20ingin%20bertanya%20tentang%20layanan%20Ayo%20Suruh.',
            ),
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.camera_alt_outlined,
            iconBgColor: const Color(0xFFFDF0E6),
            iconColor: _brownColor,
            borderColor: const Color(0xFFE7D5C8),
            title: 'Instagram Kami',
            subtitle: '@ayo.suruh',
            onTap: () => _launchURL(
              context,
              'https://www.instagram.com/ayo.suruh?igsh=MWF6Y2M3NTFyYzJreQ==',
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderWithSearch() {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFFB64F), Color(0xFFF39C12)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ada yang bisa kami\nbantu?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF633D1F),
                  height: 1.25,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Cari panduan untuk Customer, Mitra,\npembayaran, akun, dan keamanan.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF754A27),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: -22,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 3,
            shadowColor: Colors.black12,
            child: TextField(
              controller: _searchController,
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Cari bantuan atau topik...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[500],
                  size: 22,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaqTile(_FaqItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _orangeColor,
          collapsedIconColor: Colors.black54,
          title: Text(
            faq.question,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            faq.category,
            style: const TextStyle(fontSize: 10.5, color: _brownColor),
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.answer,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6E625C),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF746A64),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A8E87)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}
