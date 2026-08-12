import 'package:flutter/material.dart';
import 'widgets/ayo_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/home_shortcut_button.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import './theme/ayo_theme.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  static Color get _brownColor => AyoAdaptiveColors.brown;
  static const Color _orangeColor = Color(0xFFF6990E);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showAll = false;

  static const List<_FaqItem> _faqs = <_FaqItem>[
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana cara membuat pekerjaan?',
      questionEn: 'How do I create a job?',
      answer:
          'Dari Home tekan Buat Pekerjaan, pilih kategori, isi judul dan deskripsi, tentukan lokasi, jadwal, serta estimasi harga. Setelah dipublikasikan, pekerjaan akan terlihat oleh mitra yang dapat mengirim penawaran.',
      answerEn:
          'From Home, tap Create Job, choose a category, enter the title and description, set the location, schedule, and estimated price. Once published, Partners can see the job and send offers.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana memilih mitra yang mengirim penawaran?',
      questionEn: 'How do I choose a Partner who sent an offer?',
      answer:
          'Buka detail pekerjaan lalu bandingkan harga, estimasi pengerjaan, pesan, dan profil mitra. Pilih penawaran yang paling sesuai. Setelah dipilih, pekerjaan masuk ke tahap transaksi dan pengerjaan.',
      answerEn:
          'Open the job details and compare the price, estimated completion time, message, and Partner profile. Choose the offer that best fits your needs. After you select one, the job moves to the payment and work stages.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Apakah lokasi pekerjaan harus sama dengan alamat profil?',
      questionEn: 'Does the job location have to match my profile address?',
      answer:
          'Tidak. Alamat profil hanya menjadi lokasi utama yang tampil di Home. Saat membuat pekerjaan Anda dapat memilih alamat lain, misalnya minimarket, kost, kampus, atau lokasi tujuan tertentu.',
      answerEn:
          'No. Your profile address is only the primary location shown on Home. When creating a job, you can choose another address such as a minimarket, boarding house, campus, or a specific destination.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana mencari titik lokasi pekerjaan?',
      questionEn: 'How do I find a job location point?',
      answer:
          'Pada form Buat Pekerjaan, buka pemilih peta. Anda dapat mencari alamat dengan OpenStreetMap, memakai lokasi perangkat, atau mengetuk peta untuk mengoreksi titik secara manual.',
      answerEn:
          'On the Create Job form, open the map picker. You can search for an address with OpenStreetMap, use your device location, or tap the map to adjust the point manually.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana pembayaran dilakukan?',
      questionEn: 'How is payment handled?',
      answer:
          'Pembayaran pekerjaan yang sudah menggunakan payment gateway diproses melalui Midtrans. Status pembayaran akan disinkronkan ke Ayo Suruh sebelum alur pekerjaan dilanjutkan.',
      answerEn:
          'Jobs that use the payment gateway are processed through Midtrans. Payment status is synchronized with Ayo Suruh before the job flow continues.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana jika saya membutuhkan refund?',
      questionEn: 'What if I need a refund?',
      answer:
          'Refund hanya tersedia pada transaksi dan kondisi yang memenuhi kebijakan. Ajukan dari detail transaksi jika opsi refund tersedia. Status permintaan akan tercatat dan dapat dipantau pada aplikasi.',
      answerEn:
          'Refunds are only available for eligible transactions and conditions. Request one from the transaction details when the refund option is available. The request status is recorded and can be tracked in the app.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana cara menggunakan panggilan suara?',
      questionEn: 'How do I use voice calls?',
      answer:
          'Panggilan suara tersedia langsung di dalam Ayo Suruh pada chat pekerjaan yang sudah diterima dan masih aktif. Tekan ikon telepon, izinkan mikrofon, lalu tunggu lawan transaksi menerima panggilan. Nomor telepon Customer dan Mitra tidak dibagikan melalui fitur ini. Ayo Suruh tidak mengaktifkan perekaman atau transkripsi panggilan suara.',
      answerEn:
          'Voice calls are available directly inside Ayo Suruh from the chat of an accepted active job. Tap the call icon, allow microphone access, then wait for the other party to answer. Customer and Partner phone numbers are not shared through this feature. Ayo Suruh does not enable call recording or transcription.',
    ),
    _FaqItem(
      category: 'Customer',
      categoryEn: 'Customer',
      question: 'Bagaimana cara memberi rating kepada mitra?',
      questionEn: 'How do I rate a Partner?',
      answer:
          'Setelah pekerjaan selesai dan dikonfirmasi, buka detail atau riwayat pekerjaan lalu berikan rating dan ulasan berdasarkan pengalaman Anda.',
      answerEn:
          'After the job is completed and confirmed, open the job details or history and leave a rating and review based on your experience.',
    ),
    _FaqItem(
      category: 'Akun',
      categoryEn: 'Account',
      question: 'Bagaimana cara mengonfirmasi nomor HP?',
      questionEn: 'How do I confirm my phone number?',
      answer:
          'Pada Android, buka Profil lalu ketuk status nomor HP atau Edit Profil dan pilih Gunakan nomor dari perangkat ini. Android akan menampilkan nomor berbasis SIM yang tersedia tanpa meminta izin membaca SMS. Nomor yang dipilih ditandai dikonfirmasi dari perangkat. Cara ini membantu mengurangi salah input, tetapi bukan OTP SMS dan bukan bukti identitas hukum. Nomor yang diketik manual tetap dapat disimpan dengan status belum dikonfirmasi.',
      answerEn:
          'On Android, open Profile and tap the phone-number status or Edit Profile, then choose Use a number from this device. Android shows available SIM-based phone numbers without requesting SMS-reading permission. A selected number is marked as confirmed from the device. This reduces input mistakes, but it is not SMS OTP or legal identity proof. A manually entered number can still be saved with an unconfirmed status.',
    ),
    _FaqItem(
      category: 'Akun',
      categoryEn: 'Account',
      question: 'Saya lupa password. Apakah harus menghubungi admin?',
      questionEn: 'I forgot my password. Do I need to contact an admin?',
      answer:
          'Tidak. Pada halaman Login tekan Lupa Password, masukkan email akun, lalu buka tautan pemulihan yang dikirim ke email untuk membuat password baru.',
      answerEn:
          'No. On the Sign In page, tap Forgot Password, enter your account email, then open the recovery link sent to your email to create a new password.',
    ),
    _FaqItem(
      category: 'Akun',
      categoryEn: 'Account',
      question: 'Apa fungsi Ingat Saya?',
      questionEn: 'What does Remember Me do?',
      answer:
          'Ingat Saya mempertahankan sesi login pada perangkat dan mengingat email. Ayo Suruh tidak menyimpan password mentah; password dapat dikelola oleh password manager atau autofill bawaan perangkat.',
      answerEn:
          'Remember Me keeps your sign-in session on the device and remembers your email. Ayo Suruh does not store plaintext passwords; credentials can be managed by your device password manager or autofill.',
    ),
    _FaqItem(
      category: 'Mitra',
      categoryEn: 'Partner',
      question: 'Bagaimana cara menjadi mitra Ayo Suruh?',
      questionEn: 'How do I become an Ayo Suruh Partner?',
      answer:
          'Pendaftaran Mitra pada tahap ini khusus mahasiswa aktif UPI. Dari Profil, unggah KTM UPI sebagai bukti status mahasiswa, pilih dan unggah identitas legal berfoto seperti KTP, SIM, Paspor, KITAS/KITAP, atau identitas sah lain, lalu ambil selfie dengan kamera depan. Admin memeriksa KTM dan mencocokkan selfie dengan pas foto identitas sebelum menyetujui pengajuan.',
      answerEn:
          'At this stage, Partner registration is limited to active UPI students. From Profile, upload your UPI Student Card (KTM) as proof of student eligibility, choose and upload a legal photo ID such as KTP, SIM, Passport, KITAS/KITAP, or another valid photo identity document, then take a selfie with the front camera. The admin checks the KTM and manually compares the selfie with the portrait on the photo ID before approval.',
    ),
    _FaqItem(
      category: 'Mitra',
      categoryEn: 'Partner',
      question: 'Bagaimana cara mengambil pekerjaan?',
      questionEn: 'How do I take a job?',
      answer:
          'Saat menggunakan akun sebagai Mitra, buka pekerjaan yang tersedia, pelajari kebutuhan customer, lalu kirim penawaran harga, estimasi waktu, dan pesan. Customer akan memilih penawaran yang dianggap paling sesuai.',
      answerEn:
          'While using Partner mode, open an available job, review the Customer requirements, then send your price, estimated time, and message. The Customer chooses the offer that best fits their needs.',
    ),
    _FaqItem(
      category: 'Mitra',
      categoryEn: 'Partner',
      question: 'Berapa komisi Ayo Suruh untuk mitra?',
      questionEn: 'What is the Ayo Suruh commission for Partners?',
      answer:
          'Ayo Suruh menggunakan komisi platform 6% dari nilai jasa pada transaksi berhasil, termasuk pembayaran Cash, kecuali diinformasikan lain pada aplikasi. Untuk Cash, Customer membayar langsung ke Mitra dan komisi diselesaikan melalui saldo AyoPay Mitra. Jika saldo belum cukup, kewajiban akan tertutup otomatis oleh saldo atau pendapatan berikutnya. Mitra baru mendapat Bonus Mitra Baru berupa 0% komisi pada satu pekerjaan pertama yang memenuhi syarat dan berhasil selesai.',
      answerEn:
          'Ayo Suruh applies a 6% platform commission to the service amount on successful transactions, including Cash payments, unless the app states otherwise. For Cash, the Customer pays the Partner directly and the commission is settled through the Partner’s AyoPay balance. If the balance is insufficient, the obligation is automatically offset by the next available balance or earnings. New Partners receive a one-time New Partner Bonus with 0% commission on their first eligible successfully completed job.',
    ),
    _FaqItem(
      category: 'Mitra',
      categoryEn: 'Partner',
      question: 'Kapan pendapatan masuk ke Dompet Mitra?',
      questionEn: 'When do earnings enter the Partner Wallet?',
      answer:
          'Pendapatan bersih masuk ke ledger Dompet Mitra setelah pembayaran berstatus berhasil dan pekerjaan selesai. Sistem dapat menerapkan masa hold sebelum saldo berubah menjadi tersedia untuk dicairkan.',
      answerEn:
          'Net earnings enter the Partner Wallet ledger after payment is successful and the job is completed. A hold period may apply before the balance becomes available for withdrawal.',
    ),
    _FaqItem(
      category: 'Mitra',
      categoryEn: 'Partner',
      question: 'Bagaimana cara mencairkan saldo Mitra?',
      questionEn: 'How do I withdraw Partner balance?',
      answer:
          'Buka Dompet & Rekening, pastikan rekening pencairan sudah tersedia, lalu ajukan nominal penarikan. Biaya transfer atau ketentuan pencairan ditampilkan terpisah dari komisi platform.',
      answerEn:
          'Open Wallet & Payout Account, make sure a payout account is available, then enter the amount you want to withdraw. Transfer fees or payout terms are shown separately from the platform commission.',
    ),
    _FaqItem(
      category: 'Mitra',
      categoryEn: 'Partner',
      question: 'Apa yang terjadi jika transaksi direfund?',
      questionEn: 'What happens if a transaction is refunded?',
      answer:
          'Jika pembayaran yang sudah mengkredit pendapatan mitra kemudian direfund atau dibatalkan, sistem melakukan penyesuaian pada ledger agar saldo mengikuti nilai transaksi yang valid.',
      answerEn:
          'If a payment that already credited Partner earnings is later refunded or cancelled, the system adjusts the ledger so the balance reflects the valid transaction amount.',
    ),
    _FaqItem(
      category: 'AyoPay',
      categoryEn: 'AyoPay',
      question: 'Bagaimana cara isi saldo AyoPay?',
      questionEn: 'How do I top up AyoPay?',
      answer:
          'Top up AyoPay akan tersedia pada akun dan metode pembayaran yang didukung. Saat aktif, instruksi pembayaran, status top up, dan riwayat saldo akan tersedia langsung di aplikasi.',
      answerEn:
          'AyoPay top up will be available for supported accounts and payment methods. Once active, payment instructions, top-up status, and balance history will be available directly in the app.',
    ),
    _FaqItem(
      category: 'Keamanan',
      categoryEn: 'Security',
      question: 'Apakah login Google membuat akun baru yang terpisah?',
      questionEn: 'Does Google sign-in create a separate account?',
      answer:
          'Ayo Suruh menyinkronkan akun Google dengan profil pengguna berdasarkan identitas Supabase. Untuk email yang sudah terhubung pada identitas yang sama, data profil tetap diarahkan ke akun pengguna yang sama.',
      answerEn:
          'Ayo Suruh syncs Google sign-in with the user profile through Supabase identity. If the email is already linked to the same identity, the profile remains connected to the same user account.',
    ),
    _FaqItem(
      category: 'Keamanan',
      categoryEn: 'Security',
      question: 'Apa yang harus dilakukan jika menemukan aktivitas mencurigakan?',
      questionEn: 'What should I do if I notice suspicious activity?',
      answer:
          'Segera ganti password, keluar dari akun pada perangkat yang tidak dikenal jika opsi sesi tersedia, dan hubungi Pusat Dukungan Ayo Suruh melalui WhatsApp untuk pemeriksaan lebih lanjut.',
      answerEn:
          'Change your password immediately, sign out of unknown devices if session controls are available, and contact Ayo Suruh Support through WhatsApp for further review.',
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
      return faq.questionText.toLowerCase().contains(query) ||
          faq.answerText.toLowerCase().contains(query) ||
          faq.categoryText.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<_FaqItem> filtered = _filteredFaqs;
    final List<_FaqItem> visible = _showAll || _query.trim().isNotEmpty
        ? filtered
        : filtered.take(5).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _brownColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: AyoText(
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
                child: AyoText(
                  _query.trim().isEmpty ? 'Pertanyaan Populer' : 'Hasil Pencarian',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (_query.trim().isEmpty)
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: AyoText(
                    _showAll ? 'Ringkas' : 'Lihat Semua',
                    style: TextStyle(
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const AyoText(
                'Topik belum ditemukan. Coba kata kunci lain atau hubungi tim dukungan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF766A62)),
              ),
            )
          else
            ...visible.map(_buildFaqTile),
          const SizedBox(height: 22),
          AyoText(
            'Masih butuh bantuan?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          _buildContactCard(
            assetPath: 'assets/images/whatsapp.png',
            fallbackIcon: Icons.chat_bubble_outline_rounded,
            iconBgColor: const Color(0xFFF3FFF5),
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
            assetPath: 'assets/images/instagram.png',
            fallbackIcon: Icons.camera_alt_outlined,
            iconBgColor: const Color(0xFFFFF5FA),
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
              colors: <Color>[Color(0xFFFFB64F), Color(0xFFF6990E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      'Ada yang bisa kami\nbantu?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF633D1F),
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 10),
                    AyoText(
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
              const SizedBox(width: 10),
              IgnorePointer(
                child: Image.asset(
                  'assets/images/ayos/ayos_support_headset.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.contain,
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            elevation: 3,
            shadowColor: Colors.black12,
            child: TextField(
              controller: _searchController,
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: AyoI18n.t('Cari bantuan atau topik...'),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _orangeColor,
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          title: AyoText(
            faq.questionText,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: AyoText(
            faq.categoryText,
            style: TextStyle(fontSize: 10.5, color: _brownColor),
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: AyoText(
                faq.answerText,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    required String assetPath,
    required IconData fallbackIcon,
    required Color iconBgColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
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
                child: Image.asset(
                  assetPath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    fallbackIcon,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AyoText(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AyoText(
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
    required this.categoryEn,
    required this.question,
    required this.questionEn,
    required this.answer,
    required this.answerEn,
  });

  final String category;
  final String categoryEn;
  final String question;
  final String questionEn;
  final String answer;
  final String answerEn;

  String get categoryText => AyoI18n.isEnglish ? categoryEn : category;
  String get questionText => AyoI18n.isEnglish ? questionEn : question;
  String get answerText => AyoI18n.isEnglish ? answerEn : answer;
}
