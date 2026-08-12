import 'package:flutter/material.dart';
import 'widgets/home_shortcut_button.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';
import './theme/ayo_theme.dart';

class SyaratKetentuanPage extends StatelessWidget {
  const SyaratKetentuanPage({super.key});

  static Color get _brown => AyoAdaptiveColors.brown;
  static const Color _orange = Color(0xFFF6990E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: AyoText(
          'Syarat & Ketentuan',
          style: TextStyle(
            color: _brown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: <Widget>[
          _TermsHeader(),
          SizedBox(height: 20),
          _TermsSection(
            number: '1',
            title: 'Penerimaan Ketentuan',
            body:
                'Dengan membuat akun atau menggunakan Ayo Suruh, pengguna menyatakan telah membaca dan menyetujui ketentuan layanan serta kebijakan privasi yang berlaku. Ayo Suruh dapat memperbarui layanan untuk meningkatkan keamanan, kualitas, dan pengalaman pengguna.',
          ),
          _TermsSection(
            number: '2',
            title: 'Akun dan Keamanan',
            body: AyoI18n.isEnglish
                ? 'Users must provide accurate information, protect access to their account and device, and must not misuse another person’s identity or phone number. On supported Android devices, Ayo Suruh may offer SIM-based Phone Number Hint as a free device-confirmation step. Device confirmation helps reduce incorrect phone-number entry, but it is not SMS OTP verification or legal identity proof. Ayo Suruh may add a stronger phone-verification method in the future.'
                : 'Pengguna wajib memberikan informasi yang benar, menjaga akses akun dan perangkat, serta tidak menyalahgunakan identitas atau nomor telepon pihak lain. Pada perangkat Android yang mendukung, Ayo Suruh dapat menyediakan Phone Number Hint berbasis SIM sebagai langkah konfirmasi perangkat tanpa biaya SMS. Konfirmasi perangkat membantu mengurangi salah input nomor, tetapi bukan verifikasi OTP SMS atau bukti identitas hukum. Ayo Suruh dapat menambahkan metode verifikasi nomor yang lebih kuat di kemudian hari.',
          ),
          _TermsSection(
            number: '3',
            title: 'Peran Customer',
            body:
                'Customer bertanggung jawab menjelaskan kebutuhan pekerjaan secara wajar, memilih kategori, lokasi dan jadwal yang tepat, menilai penawaran mitra, melakukan pembayaran sesuai alur aplikasi, serta memberikan konfirmasi pekerjaan secara jujur.',
          ),
          _TermsSection(
            number: '4',
            title: AyoI18n.isEnglish ? 'Partner Responsibilities' : 'Peran Mitra',
            body: AyoI18n.isEnglish
                ? 'For the current release, Partner registration is limited to active UPI students. On supported Android devices, applicants must also confirm the submitted phone number from the device before sending the application. Applicants must provide accurate registration information, upload a UPI Student Card (KTM) as proof of student eligibility, upload a valid legal photo ID, take the verification selfie directly with the front camera, and approve the active Partner Contract/MoU electronically. Device phone confirmation is not a replacement for identity verification. The admin verifies the KTM and manually compares the selfie with the portrait on the submitted photo ID before approval. Partners must only take jobs they can handle, maintain professional communication, and complete work according to the agreement with the Customer. The contract version and approval timestamp are recorded by the system.'
                : 'Untuk rilis saat ini, pendaftaran Mitra dibatasi bagi mahasiswa aktif UPI. Pada perangkat Android yang mendukung, pendaftar juga wajib mengonfirmasi nomor HP dari perangkat sebelum mengirim pengajuan. Pendaftar wajib memberikan informasi yang benar, mengunggah KTM UPI sebagai bukti status mahasiswa, mengunggah identitas legal berfoto yang masih berlaku, mengambil selfie verifikasi langsung melalui kamera depan, serta menyetujui Kontrak/MoU Mitra versi aktif secara elektronik. Konfirmasi nomor dari perangkat tidak menggantikan verifikasi identitas. Admin memeriksa KTM dan mencocokkan selfie secara manual dengan pas foto pada identitas yang dikirim sebelum menyetujui pengajuan. Mitra hanya boleh mengambil pekerjaan yang dapat ditangani, menjaga komunikasi profesional, dan menyelesaikan pekerjaan sesuai kesepakatan dengan Customer. Versi dan waktu persetujuan kontrak dicatat oleh sistem.',
          ),
          _TermsSection(
            number: '5',
            title: 'Harga dan Penawaran',
            body:
                'Ayo Suruh menggunakan pendekatan competitive bidding. Customer menetapkan estimasi awal dan mitra dapat mengirim penawaran. Harga jasa final mengikuti penawaran yang dipilih customer dan tercatat pada transaksi.',
          ),
          _TermsSection(
            number: '6',
            title: 'Komisi Platform 6%',
            body: AyoI18n.isEnglish
                ? 'Ayo Suruh charges a 6% platform commission on successful transactions, including Cash transactions, unless stated otherwise in the app. For Cash transactions, the Customer pays the Partner directly and the platform commission is settled through the Partner’s AyoPay balance. If the balance is insufficient, the commission obligation is recorded and automatically offset by the next available balance or earnings. Eligible new Partners may receive a one-time 0% commission bonus on their first qualifying successfully completed job. Once the bonus is used, the normal platform rate applies. Platform commission is separate from payment gateway or withdrawal fees, and the applied economics are recorded with each transaction.'
                : 'Ayo Suruh mengenakan komisi platform sebesar 6% dari nilai jasa pada transaksi berhasil, termasuk transaksi Cash, kecuali diinformasikan lain pada aplikasi. Pada transaksi Cash, Customer membayar langsung kepada Mitra dan komisi platform diselesaikan melalui saldo AyoPay Mitra. Jika saldo belum mencukupi, kewajiban komisi dicatat dan akan tertutup otomatis oleh saldo atau pendapatan berikutnya. Mitra baru yang memenuhi syarat dapat memperoleh bonus satu kali berupa 0% komisi pada pekerjaan pertama yang memenuhi syarat dan berhasil selesai. Setelah bonus digunakan, tarif platform normal berlaku. Komisi platform berbeda dari biaya payment gateway atau biaya pencairan, dan ekonomi yang diterapkan dicatat pada setiap transaksi.',
            highlight: true,
          ),
          _TermsSection(
            number: '7',
            title: 'Pembayaran dan Biaya Pemrosesan',
            body:
                'Pembayaran yang menggunakan payment gateway diproses melalui penyedia yang terintegrasi. Biaya pemrosesan dapat berbeda menurut metode pembayaran dan dapat ditampilkan terpisah dari nilai jasa. Status yang tercatat pada penyedia pembayaran menjadi salah satu acuan penyelesaian transaksi.',
          ),
          _TermsSection(
            number: '8',
            title: 'Dompet Mitra dan Pencairan',
            body:
                'Pendapatan mitra dihitung dari nilai jasa setelah komisi platform dan dicatat pada ledger. Saldo dapat melalui masa hold sebelum tersedia. Pencairan mensyaratkan rekening yang valid dan dapat dikenakan biaya transfer atau ketentuan minimum pencairan sesuai mekanisme yang digunakan Ayo Suruh.',
          ),
          _TermsSection(
            number: '9',
            title: 'Pembatalan dan Refund',
            body:
                'Pembatalan atau refund hanya diproses pada kondisi yang memenuhi kebijakan transaksi dan status pembayaran. Refund dapat menimbulkan penyesuaian pada pendapatan mitra atau saldo ledger apabila dana sebelumnya telah dikreditkan.',
          ),
          _TermsSection(
            number: '10',
            title: AyoI18n.isEnglish
                ? 'Chat and In-App Voice Calls'
                : 'Chat dan Panggilan Suara In-App',
            body: AyoI18n.isEnglish
                ? 'Chat and voice calls are provided to coordinate an accepted active job. Voice calls use an internet connection and microphone permission, and do not require Ayo Suruh to expose the Customer or Partner phone number. Users must not use calls for harassment, threats, unlawful activity, spam, or purposes unrelated to the job. Ayo Suruh does not enable recording or transcription for this voice-call feature. Internet or mobile-data charges from the user’s network provider may still apply.'
                : 'Chat dan panggilan suara disediakan untuk koordinasi pekerjaan yang sudah diterima dan masih aktif. Panggilan suara menggunakan koneksi internet dan izin mikrofon tanpa mengharuskan Ayo Suruh menampilkan nomor telepon Customer atau Mitra. Pengguna dilarang menggunakan panggilan untuk pelecehan, ancaman, aktivitas melanggar hukum, spam, atau tujuan yang tidak berkaitan dengan pekerjaan. Ayo Suruh tidak mengaktifkan perekaman atau transkripsi pada fitur panggilan suara ini. Biaya internet atau data dari penyedia jaringan pengguna tetap dapat berlaku.',
          ),
          _TermsSection(
            number: '11',
            title: 'Perilaku yang Dilarang',
            body:
                'Pengguna dilarang menggunakan Ayo Suruh untuk penipuan, ancaman, pelecehan, aktivitas melanggar hukum, pekerjaan yang membahayakan pihak lain, manipulasi transaksi/rating, penyalahgunaan data pribadi, atau tindakan lain yang merusak keamanan dan kepercayaan ekosistem.',
          ),
          _TermsSection(
            number: '12',
            title: 'Penangguhan dan Penghapusan Akun',
            body:
                'Ayo Suruh dapat membatasi akun yang terindikasi melanggar ketentuan. Pengguna dapat memilih nonaktif sementara atau penghapusan permanen melalui pengaturan akun. Penghapusan dapat memerlukan penyelesaian pekerjaan aktif, transaksi, saldo, refund/dispute, pencairan, atau kewajiban kemitraan terlebih dahulu. Alasan keluar bersifat opsional dan dapat digunakan sebagai evaluasi produk.',
          ),
          _TermsSection(
            number: '13',
            title: 'Perubahan Layanan',
            body:
                'Fitur, biaya, ketentuan, atau integrasi layanan dapat diperbarui seiring perkembangan Ayo Suruh. Perubahan material akan diinformasikan melalui aplikasi atau kanal resmi sebelum diterapkan apabila diperlukan.',
          ),
          _TermsSection(
            number: '14',
            title: 'Ketersediaan Fitur',
            body:
                'Ketersediaan fitur dapat berbeda menurut akun, wilayah, metode pembayaran, status mitra layanan pihak ketiga, kebutuhan keamanan, dan pemeliharaan sistem. Ayo Suruh dapat membatasi sementara fitur tertentu untuk menjaga keamanan, kualitas layanan, atau kepatuhan yang berlaku.',
          ),
          SizedBox(height: 6),
          AyoText(
            AyoI18n.isEnglish ? 'Last updated: 12 August 2026.' : 'Pembaruan terakhir: 12 Agustus 2026.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, height: 1.4, color: Color(0xFF7C716A)),
          ),
        ],
      ),
    );
  }
}

class _TermsHeader extends StatelessWidget {
  const _TermsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? <Color>[
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(context).colorScheme.surface,
                ]
              : const <Color>[Color(0xFFFFE5B8), Color(0xFFFFF2DD)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.handshake_outlined, color: SyaratKetentuanPage._brown, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: AyoText(
              'Ketentuan ini menjelaskan aturan penggunaan Ayo Suruh untuk customer, mitra, transaksi, dan fitur pendukungnya.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF654327),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.number,
    required this.title,
    required this.body,
    this.highlight = false,
  });

  final String number;
  final String title;
  final String body;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : highlight
                ? const Color(0xFFFFF0D7)
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? SyaratKetentuanPage._orange
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AyoText(
            '$number.',
            style: TextStyle(
              color: SyaratKetentuanPage._brown,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AyoText(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF40352F),
                  ),
                ),
                const SizedBox(height: 5),
                AyoText(
                  body,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF6B605A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
