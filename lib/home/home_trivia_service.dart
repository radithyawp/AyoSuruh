import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeTriviaService {
  HomeTriviaService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final Random _random = Random();

  static const int _maxTickerItems = 18;

  static const Map<String, List<String>> _fallbackByTopic =
      <String, List<String>>{
    'sejarah': <String>[
      'Cleopatra hidup lebih dekat ke pendaratan manusia di Bulan daripada ke masa pembangunan Piramida Agung Giza. Sejarah emang suka bikin timeline kita terasa salah.',
      'Perang Inggris-Zanzibar tahun 1896 berlangsung kurang dari satu jam. Belum sempat bikin kopi, perangannya keburu selesai.',
      'Lampu lalu lintas pertama dipasang di London pada 1868, jauh sebelum mobil jadi pemandangan biasa. Jadi lampu merah lebih tua dari budaya macet.',
      'Oxford sudah punya kegiatan belajar-mengajar sejak akhir abad ke-11, jauh sebelum Kekaisaran Aztek berdiri. Kampus tua memang beda level senioritas.',
      'Konsep mesin penjual otomatis sudah ada sejak zaman Romawi kuno. Versi awalnya dipakai buat mengeluarkan air suci setelah koin dimasukkan.',
      'Patung Liberty awalnya berwarna tembaga kecokelatan. Warna hijaunya muncul pelan-pelan karena permukaan tembaganya bereaksi dengan udara dan lingkungan.',
    ],
    'bahasa': <String>[
      'Kata “robot” berasal dari bahasa Ceko “robota” yang berkaitan dengan kerja paksa. Dari istilah drama, sekarang malah jadi teman ngobrol manusia.',
      '“Karaoke” berasal dari bahasa Jepang: “kara” berarti kosong dan “okesutora” berarti orkestra. Singkatnya, orkestra tanpa penyanyi—sisanya giliran kamu.',
      'Emoji modern lahir di Jepang pada akhir 1990-an. Dari ikon kecil di layar ponsel, sekarang bisa jadi satu kalimat penuh tanpa satu kata pun.',
      'Kata “OK” populer dari lelucon ejaan “oll korrect” di Amerika pada abad ke-19. Salah eja yang kariernya malah mendunia.',
      'Nama asli piano adalah “pianoforte”, karena alat ini bisa dimainkan lembut maupun keras. Namanya panjang, lama-lama manusia memilih versi hemat.',
      'Nama LEGO berasal dari frasa Denmark “leg godt” yang berarti “bermain dengan baik”. Branding singkat, tapi awet puluhan tahun.',
    ],
    'teknologi': <String>[
      'Nintendo berdiri pada 1889—jauh sebelum konsol dan video game ada. Awalnya mereka bikin kartu permainan tradisional Jepang.',
      'Email sudah dipakai sebelum World Wide Web lahir. Jadi kirim pesan elektronik itu lebih senior daripada kebiasaan buka browser.',
      'Webcam pertama yang terkenal dipakai buat ngawasin teko kopi di Universitas Cambridge. Teknologi streaming ternyata pernah punya misi sesederhana: kopinya masih ada nggak?',
      'Nama Bluetooth diambil dari Raja Harald “Bluetooth” dari Denmark. Ide namanya: menyatukan perangkat, seperti sang raja menyatukan wilayah.',
      'Wi-Fi sebenarnya bukan singkatan resmi dari “Wireless Fidelity”. Itu nama merek yang sengaja dibuat gampang diingat.',
      'QR Code dibuat di Jepang untuk membantu melacak komponen di industri otomotif. Sekarang nasibnya malah ada di kasir, poster, undangan, sampai menu warung.',
      'Tanda pagar atau hashtag mulai dipakai di Twitter setelah Chris Messina mengusulkannya pada 2007. Simbol kecil itu akhirnya jadi cara internet mengelompokkan obrolan.',
      'Netflix berdiri pada 1997, setahun sebelum Google lahir. Dulu fokusnya sewa DVD lewat pos, belum ada istilah binge-watching.',
    ],
    'geografi': <String>[
      'Afrika adalah satu-satunya benua yang dilalui garis khatulistiwa sekaligus merentang ke belahan bumi utara, selatan, timur, dan barat.',
      'Rusia membentang melewati 11 zona waktu. Di satu negara yang sama, ada orang baru bangun sementara yang lain sudah siap tidur.',
      'Menara Eiffel bisa sedikit lebih tinggi saat cuaca panas karena logam memuai. Bangunan juga ternyata punya versi “ngembang kena panas”.',
      'Tembok Besar China tidak bisa dilihat dengan mata telanjang dari Bulan. Cerita itu populer banget, tapi realitanya nggak segampang itu.',
      'London Underground mulai beroperasi pada 1863. Kereta bawah tanah ternyata sudah jadi solusi kota jauh sebelum era mobil modern.',
    ],
    'sehari-hari': <String>[
      'Bubble wrap awalnya diciptakan sebagai wallpaper bertekstur, bukan pembungkus paket. Gagal jadi dekorasi, malah sukses bikin orang hobi mecahin gelembung.',
      'Makanan kaleng muncul lebih dulu daripada pembuka kaleng khusus. Dulu orang benar-benar harus kreatif kalau mau makan isi kaleng.',
      'Kotak hitam pesawat sebenarnya berwarna oranye terang. Namanya boleh “black box”, tapi warnanya justru dibuat mencolok supaya gampang ditemukan.',
      'Wiper kaca mobil dipatenkan Mary Anderson pada awal 1900-an. Ide sederhana yang sekarang terasa mustahil kalau nggak ada saat hujan.',
      'Kode batang dan QR Code sama-sama lahir dari kebutuhan melacak barang lebih cepat. Teknologi yang kelihatannya sederhana sering justru hidup paling lama.',
    ],
    'olahraga': <String>[
      'Pertandingan basket pertama memakai keranjang buah persik sebagai ring dan bola sepak sebagai bolanya. Olahraga besar kadang memang mulai dari alat seadanya.',
      'Kartu kuning dan merah di sepak bola terinspirasi dari konsep lampu lalu lintas: kuning hati-hati, merah berhenti. Simpel, langsung dipahami lintas bahasa.',
      'Medali emas Olimpiade modern bukan emas murni. Sebagian besar bahannya perak dengan lapisan emas di bagian luar.',
      'Jarak marathon 42,195 km baru dibakukan setelah era Olimpiade modern. Angka panjang itu bukan dipilih karena kelihatan rapi.',
      'Basket diciptakan sebagai olahraga dalam ruangan supaya siswa tetap aktif saat musim dingin. Dari solusi kelas olahraga, sekarang jadi industri global.',
    ],
    'hiburan': <String>[
      'Video pertama di YouTube berjudul “Me at the zoo” dan diunggah pada 2005. Durasi pendek, tapi jadi pembuka salah satu platform terbesar di internet.',
      'Tetris dibuat pada 1984 di Uni Soviet oleh Alexey Pajitnov. Game balok sederhana itu masih hidup lintas generasi sampai sekarang.',
      'Toy Story menjadi film panjang pertama yang seluruh gambarnya dibuat dengan animasi komputer. Sekarang teknik itu terasa biasa, dulu benar-benar lompatan besar.',
      'Acara Oscar pertama pada 1929 jauh lebih singkat daripada siaran sekarang. Belum ada maraton pidato, iklan, dan potongan viral semalaman.',
      'Pac-Man sengaja dibuat berbeda dari game tembak-tembakan yang ramai saat itu. Karakter bulat makan titik ternyata cukup buat jadi ikon budaya pop.',
    ],
    'internet': <String>[
      'Barang pertama yang terkenal terjual di eBay adalah laser pointer rusak. Internet sudah dari awal membuktikan: selalu ada orang yang mau barang yang kamu kira nggak kepakai.',
      'Amazon awalnya fokus jual buku lewat internet. Dari katalog buku, pelan-pelan berubah jadi salah satu raksasa belanja online dunia.',
      'Domain .com pertama yang terdaftar adalah symbolics.com pada 1985. Waktu itu internet masih jauh dari kehidupan sehari-hari seperti sekarang.',
      'Sebelum jadi tempat video, YouTube sempat dirancang dengan konsep yang lebih dekat ke situs perkenalan. Produk internet memang sering berubah arah total.',
      'Hashtag awalnya cuma cara sederhana buat mengelompokkan percakapan. Sekarang satu hashtag bisa jadi kampanye, lelucon, sampai gerakan global.',
    ],
    'alam': <String>[
      'Wombat menghasilkan kotoran berbentuk kubus. Kedengarannya kayak bug di game, tapi memang begitu bentuk aslinya.',
      'Burung gagak bisa mengenali wajah manusia dan mengingatnya dalam waktu lama. Jadi kalau pernah bikin gagak kesel, mungkin jangan sok lupa.',
      'Pisang secara botani masuk kategori berry, sementara stroberi justru bukan berry sejati. Nama sehari-hari dan ilmu botani memang suka beda pendapat.',
      'Gurita punya tiga jantung dan darah biru. Satu jantung aja kadang bikin ribet, dia santai bawa tiga.',
      'Paus dan lumba-lumba punya cara tidur unik karena mereka tetap perlu mengatur kapan naik ke permukaan buat bernapas.',
    ],
  };

  List<String> get fallbackItems => _pickVariedFallback();

  Future<List<String>> fetchActiveTrivia() async {
    try {
      final dynamic response = await _client
          .from('home_trivia')
          .select(
            'content, kind, topic, starts_at, expires_at, sort_order, created_at',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(80);

      final DateTime now = DateTime.now().toUtc();
      final List<_TriviaCandidate> candidates =
          List<Map<String, dynamic>>.from(response as List)
              .where((Map<String, dynamic> row) {
                final DateTime? starts = DateTime.tryParse(
                  (row['starts_at'] ?? '').toString(),
                )?.toUtc();
                final DateTime? expires = DateTime.tryParse(
                  (row['expires_at'] ?? '').toString(),
                )?.toUtc();
                if (starts != null && starts.isAfter(now)) return false;
                if (expires != null && !expires.isAfter(now)) return false;
                return true;
              })
              .map((Map<String, dynamic> row) {
                final String content =
                    (row['content'] ?? '').toString().trim();
                if (content.isEmpty) return null;
                return _TriviaCandidate(
                  content: content,
                  kind: (row['kind'] ?? 'fact').toString(),
                  topic: (row['topic'] ?? 'general').toString().trim().isEmpty
                      ? 'general'
                      : (row['topic'] ?? 'general').toString().trim(),
                );
              })
              .whereType<_TriviaCandidate>()
              .toList();

      if (candidates.isEmpty) return _pickVariedFallback();
      return _pickVariedCandidates(candidates);
    } on PostgrestException catch (error) {
      debugPrint('home_trivia belum tersedia, memakai fallback lokal: $error');
      return _pickVariedFallback();
    } catch (error) {
      debugPrint('Gagal mengambil trivia Home: $error');
      return _pickVariedFallback();
    }
  }

  List<String> _pickVariedCandidates(List<_TriviaCandidate> candidates) {
    final List<_TriviaCandidate> trends = candidates
        .where((_TriviaCandidate item) => item.kind == 'trend')
        .toList()
      ..shuffle(_random);
    final List<_TriviaCandidate> facts = candidates
        .where((_TriviaCandidate item) => item.kind != 'trend')
        .toList();

    final Map<String, List<_TriviaCandidate>> grouped =
        <String, List<_TriviaCandidate>>{};
    for (final _TriviaCandidate item in facts) {
      grouped.putIfAbsent(item.topic, () => <_TriviaCandidate>[]).add(item);
    }
    for (final List<_TriviaCandidate> items in grouped.values) {
      items.shuffle(_random);
    }

    final List<String> result = <String>[];
    for (final _TriviaCandidate trend in trends.take(3)) {
      result.add('Lagi rame nih — ${trend.content}');
    }

    final List<String> topics = grouped.keys.toList()..shuffle(_random);
    int round = 0;
    while (result.length < _maxTickerItems && topics.isNotEmpty) {
      bool addedInRound = false;
      for (final String topic in topics) {
        final List<_TriviaCandidate> items = grouped[topic]!;
        if (round < items.length) {
          result.add(items[round].content);
          addedInRound = true;
          if (result.length >= _maxTickerItems) break;
        }
      }
      if (!addedInRound) break;
      round++;
    }

    return result.isEmpty ? _pickVariedFallback() : result;
  }

  List<String> _pickVariedFallback() {
    final Map<String, List<String>> grouped = <String, List<String>>{
      for (final MapEntry<String, List<String>> entry
          in _fallbackByTopic.entries)
        entry.key: List<String>.from(entry.value)..shuffle(_random),
    };
    final List<String> topics = grouped.keys.toList()..shuffle(_random);
    final List<String> result = <String>[];

    int round = 0;
    while (result.length < _maxTickerItems && topics.isNotEmpty) {
      bool addedInRound = false;
      for (final String topic in topics) {
        final List<String> items = grouped[topic]!;
        if (round < items.length) {
          result.add(items[round]);
          addedInRound = true;
          if (result.length >= _maxTickerItems) break;
        }
      }
      if (!addedInRound) break;
      round++;
    }
    return result;
  }
}

class _TriviaCandidate {
  const _TriviaCandidate({
    required this.content,
    required this.kind,
    required this.topic,
  });

  final String content;
  final String kind;
  final String topic;
}
