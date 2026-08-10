begin;

alter table public.home_trivia
  add column if not exists topic text not null default 'general';

create index if not exists home_trivia_active_topic_idx
  on public.home_trivia (is_active, topic, created_at desc);

-- Klasifikasikan seed lama supaya algoritma variasi tidak menganggap semuanya general.
update public.home_trivia
set topic = case id
  when '0d88d620-33a8-4e50-9b5b-663426a1b201'::uuid then 'sains'
  when '7f18db53-6dd8-40f7-a6ae-9fa763ee7d35'::uuid then 'alam'
  when 'e5563fb2-69ea-4ab6-a73c-949f666c1502'::uuid then 'alam'
  when '991eb22e-2695-4f1f-b9c5-2715194218c8'::uuid then 'sains'
  when '8297814f-b2b1-49ea-b58a-865a4ec35b7c'::uuid then 'alam'
  else topic
end,
updated_at = now()
where id in (
  '0d88d620-33a8-4e50-9b5b-663426a1b201'::uuid,
  '7f18db53-6dd8-40f7-a6ae-9fa763ee7d35'::uuid,
  'e5563fb2-69ea-4ab6-a73c-949f666c1502'::uuid,
  '991eb22e-2695-4f1f-b9c5-2715194218c8'::uuid,
  '8297814f-b2b1-49ea-b58a-865a4ec35b7c'::uuid
);

insert into public.home_trivia
  (id, content, kind, topic, sort_order)
values
  ('ad91ba85-3d8f-53ff-8d37-782c2ff8d079', 'Cleopatra hidup lebih dekat ke pendaratan manusia di Bulan daripada ke masa pembangunan Piramida Agung Giza. Sejarah emang suka bikin timeline kita terasa salah.', 'fact', 'sejarah', 101),
  ('cd488380-766e-5a63-a516-625352adee43', 'Perang Inggris-Zanzibar tahun 1896 berlangsung kurang dari satu jam. Belum sempat bikin kopi, perangannya keburu selesai.', 'fact', 'sejarah', 102),
  ('4f613372-b7cd-5453-86cd-e6c15086b353', 'Lampu lalu lintas pertama dipasang di London pada 1868, jauh sebelum mobil jadi pemandangan biasa. Jadi lampu merah lebih tua dari budaya macet.', 'fact', 'sejarah', 103),
  ('69c8fa56-048a-55e8-96df-ae331ab9d380', 'Oxford sudah punya kegiatan belajar-mengajar sejak akhir abad ke-11, jauh sebelum Kekaisaran Aztek berdiri. Kampus tua memang beda level senioritas.', 'fact', 'sejarah', 104),
  ('9e5e2350-a60e-5e4a-b0c0-9a972ef9d59a', 'Konsep mesin penjual otomatis sudah ada sejak zaman Romawi kuno. Versi awalnya dipakai buat mengeluarkan air suci setelah koin dimasukkan.', 'fact', 'sejarah', 105),
  ('be0b37d3-366c-521b-839c-6ffced594fc9', 'Patung Liberty awalnya berwarna tembaga kecokelatan. Warna hijaunya muncul pelan-pelan karena permukaan tembaganya bereaksi dengan udara dan lingkungan.', 'fact', 'sejarah', 106),
  ('35c4fe63-b270-55ab-a5f8-87e7dd9be893', 'Kata “robot” berasal dari bahasa Ceko “robota” yang berkaitan dengan kerja paksa. Dari istilah drama, sekarang malah jadi teman ngobrol manusia.', 'fact', 'bahasa', 107),
  ('ebdaf076-d9ad-5fcb-8837-505c7f46dcb2', '“Karaoke” berasal dari bahasa Jepang: “kara” berarti kosong dan “okesutora” berarti orkestra. Singkatnya, orkestra tanpa penyanyi—sisanya giliran kamu.', 'fact', 'bahasa', 108),
  ('22f45ca8-4efd-5e12-830b-a83dfeaae0f9', 'Emoji modern lahir di Jepang pada akhir 1990-an. Dari ikon kecil di layar ponsel, sekarang bisa jadi satu kalimat penuh tanpa satu kata pun.', 'fact', 'bahasa', 109),
  ('ed72e1f7-aa7e-5a6f-881a-d239b85559c9', 'Kata “OK” populer dari lelucon ejaan “oll korrect” di Amerika pada abad ke-19. Salah eja yang kariernya malah mendunia.', 'fact', 'bahasa', 110),
  ('b78b671a-e7d1-58a4-922a-d1363833c59c', 'Nama asli piano adalah “pianoforte”, karena alat ini bisa dimainkan lembut maupun keras. Namanya panjang, lama-lama manusia memilih versi hemat.', 'fact', 'bahasa', 111),
  ('2163797a-5d4f-5379-b480-d16137332b32', 'Nama LEGO berasal dari frasa Denmark “leg godt” yang berarti “bermain dengan baik”. Branding singkat, tapi awet puluhan tahun.', 'fact', 'bahasa', 112),
  ('aab405d4-5a50-5a1f-a8ee-17875eba001b', 'Nintendo berdiri pada 1889—jauh sebelum konsol dan video game ada. Awalnya mereka bikin kartu permainan tradisional Jepang.', 'fact', 'teknologi', 113),
  ('93ae8d2c-cbe1-598d-ab8b-649f294fbf63', 'Email sudah dipakai sebelum World Wide Web lahir. Jadi kirim pesan elektronik itu lebih senior daripada kebiasaan buka browser.', 'fact', 'teknologi', 114),
  ('64a5b9f9-b18f-5516-a1e0-08c80f112ffe', 'Webcam pertama yang terkenal dipakai buat ngawasin teko kopi di Universitas Cambridge. Teknologi streaming ternyata pernah punya misi sesederhana: kopinya masih ada nggak?', 'fact', 'teknologi', 115),
  ('57bb2a16-f709-543a-a085-0a0849ec2395', 'Nama Bluetooth diambil dari Raja Harald “Bluetooth” dari Denmark. Ide namanya: menyatukan perangkat, seperti sang raja menyatukan wilayah.', 'fact', 'teknologi', 116),
  ('3cbcab7b-b30e-5c94-a9d6-9770b9aac923', 'Wi-Fi sebenarnya bukan singkatan resmi dari “Wireless Fidelity”. Itu nama merek yang sengaja dibuat gampang diingat.', 'fact', 'teknologi', 117),
  ('9cdc6a7d-3ba0-5b3d-ae49-b289aaf9f736', 'QR Code dibuat di Jepang untuk membantu melacak komponen di industri otomotif. Sekarang nasibnya malah ada di kasir, poster, undangan, sampai menu warung.', 'fact', 'teknologi', 118),
  ('b0d39726-d921-535d-b097-0ba8a17f0ef0', 'Tanda pagar atau hashtag mulai dipakai di Twitter setelah Chris Messina mengusulkannya pada 2007. Simbol kecil itu akhirnya jadi cara internet mengelompokkan obrolan.', 'fact', 'teknologi', 119),
  ('97d16871-b77e-51a1-8dce-88ca6a6b1f9e', 'Netflix berdiri pada 1997, setahun sebelum Google lahir. Dulu fokusnya sewa DVD lewat pos, belum ada istilah binge-watching.', 'fact', 'teknologi', 120),
  ('4d9145f3-d6ae-5654-ad2b-01160b196fc8', 'Afrika adalah satu-satunya benua yang dilalui garis khatulistiwa sekaligus merentang ke belahan bumi utara, selatan, timur, dan barat.', 'fact', 'geografi', 121),
  ('d5c172b6-2b00-5049-89da-184ec52bd066', 'Rusia membentang melewati 11 zona waktu. Di satu negara yang sama, ada orang baru bangun sementara yang lain sudah siap tidur.', 'fact', 'geografi', 122),
  ('b0906474-1cf7-5454-b9d7-6bb7e33991a1', 'Menara Eiffel bisa sedikit lebih tinggi saat cuaca panas karena logam memuai. Bangunan juga ternyata punya versi “ngembang kena panas”.', 'fact', 'geografi', 123),
  ('e223a3ca-bf1e-57c9-a62b-962c39d97bb9', 'Tembok Besar China tidak bisa dilihat dengan mata telanjang dari Bulan. Cerita itu populer banget, tapi realitanya nggak segampang itu.', 'fact', 'geografi', 124),
  ('9f22688a-d947-5012-9a46-ffc5950ca449', 'London Underground mulai beroperasi pada 1863. Kereta bawah tanah ternyata sudah jadi solusi kota jauh sebelum era mobil modern.', 'fact', 'geografi', 125),
  ('e1b837b2-b454-51a0-9e99-f48c315cbbdc', 'Bubble wrap awalnya diciptakan sebagai wallpaper bertekstur, bukan pembungkus paket. Gagal jadi dekorasi, malah sukses bikin orang hobi mecahin gelembung.', 'fact', 'sehari-hari', 126),
  ('dde88653-d1d9-53e1-a19c-dd334db51343', 'Makanan kaleng muncul lebih dulu daripada pembuka kaleng khusus. Dulu orang benar-benar harus kreatif kalau mau makan isi kaleng.', 'fact', 'sehari-hari', 127),
  ('76a27c1a-13f8-5a8e-9eb6-6838c1ad2f21', 'Kotak hitam pesawat sebenarnya berwarna oranye terang. Namanya boleh “black box”, tapi warnanya justru dibuat mencolok supaya gampang ditemukan.', 'fact', 'sehari-hari', 128),
  ('9453c49d-4436-595a-852e-e2c89c408bef', 'Wiper kaca mobil dipatenkan Mary Anderson pada awal 1900-an. Ide sederhana yang sekarang terasa mustahil kalau nggak ada saat hujan.', 'fact', 'sehari-hari', 129),
  ('13a695fa-0633-5ccd-a44d-ba92d34df973', 'Kode batang dan QR Code sama-sama lahir dari kebutuhan melacak barang lebih cepat. Teknologi yang kelihatannya sederhana sering justru hidup paling lama.', 'fact', 'sehari-hari', 130),
  ('9e95c35d-70d3-5f27-ba36-f3d77a638bb0', 'Pertandingan basket pertama memakai keranjang buah persik sebagai ring dan bola sepak sebagai bolanya. Olahraga besar kadang memang mulai dari alat seadanya.', 'fact', 'olahraga', 131),
  ('f8a6fa91-ef63-5cc6-8d8e-453133c8be92', 'Kartu kuning dan merah di sepak bola terinspirasi dari konsep lampu lalu lintas: kuning hati-hati, merah berhenti. Simpel, langsung dipahami lintas bahasa.', 'fact', 'olahraga', 132),
  ('b3ce8b3a-98cb-52c4-91de-0230ce7ed06f', 'Medali emas Olimpiade modern bukan emas murni. Sebagian besar bahannya perak dengan lapisan emas di bagian luar.', 'fact', 'olahraga', 133),
  ('bbb5de0c-5e85-5504-bd37-0d0d31f82337', 'Jarak marathon 42,195 km baru dibakukan setelah era Olimpiade modern. Angka panjang itu bukan dipilih karena kelihatan rapi.', 'fact', 'olahraga', 134),
  ('91dc3bd9-f78b-511b-826f-da28e5a235c7', 'Basket diciptakan sebagai olahraga dalam ruangan supaya siswa tetap aktif saat musim dingin. Dari solusi kelas olahraga, sekarang jadi industri global.', 'fact', 'olahraga', 135),
  ('28a00da2-eda8-517f-bd49-aefc0964015c', 'Video pertama di YouTube berjudul “Me at the zoo” dan diunggah pada 2005. Durasi pendek, tapi jadi pembuka salah satu platform terbesar di internet.', 'fact', 'hiburan', 136),
  ('8aa8fcc5-cdea-5c64-befd-d60056b52c0a', 'Tetris dibuat pada 1984 di Uni Soviet oleh Alexey Pajitnov. Game balok sederhana itu masih hidup lintas generasi sampai sekarang.', 'fact', 'hiburan', 137),
  ('72f30897-548a-5472-8a6c-21680292a8be', 'Toy Story menjadi film panjang pertama yang seluruh gambarnya dibuat dengan animasi komputer. Sekarang teknik itu terasa biasa, dulu benar-benar lompatan besar.', 'fact', 'hiburan', 138),
  ('e6bc3f72-d254-5c89-8a12-bf2160c8c09a', 'Acara Oscar pertama pada 1929 jauh lebih singkat daripada siaran sekarang. Belum ada maraton pidato, iklan, dan potongan viral semalaman.', 'fact', 'hiburan', 139),
  ('c3648d0c-ccfe-5b68-99f4-86d6797d9d03', 'Pac-Man sengaja dibuat berbeda dari game tembak-tembakan yang ramai saat itu. Karakter bulat makan titik ternyata cukup buat jadi ikon budaya pop.', 'fact', 'hiburan', 140),
  ('da94bc60-8d82-581e-a905-c0e4589a6479', 'Barang pertama yang terkenal terjual di eBay adalah laser pointer rusak. Internet sudah dari awal membuktikan: selalu ada orang yang mau barang yang kamu kira nggak kepakai.', 'fact', 'internet', 141),
  ('84bd7a86-ed45-5a05-aa6c-0f1667791f85', 'Amazon awalnya fokus jual buku lewat internet. Dari katalog buku, pelan-pelan berubah jadi salah satu raksasa belanja online dunia.', 'fact', 'internet', 142),
  ('ee93fcf3-5b0b-565a-a8ea-f4ea8510e4b3', 'Domain .com pertama yang terdaftar adalah symbolics.com pada 1985. Waktu itu internet masih jauh dari kehidupan sehari-hari seperti sekarang.', 'fact', 'internet', 143),
  ('66954361-0ecc-550f-8ac6-138d1b8c61da', 'Sebelum jadi tempat video, YouTube sempat dirancang dengan konsep yang lebih dekat ke situs perkenalan. Produk internet memang sering berubah arah total.', 'fact', 'internet', 144),
  ('8dfdcb88-e024-5b08-8556-faf386dd2c6c', 'Hashtag awalnya cuma cara sederhana buat mengelompokkan percakapan. Sekarang satu hashtag bisa jadi kampanye, lelucon, sampai gerakan global.', 'fact', 'internet', 145),
  ('b5d2723f-b836-587d-bdd9-a0640bf2de9a', 'Wombat menghasilkan kotoran berbentuk kubus. Kedengarannya kayak bug di game, tapi memang begitu bentuk aslinya.', 'fact', 'alam', 146),
  ('63beb1cf-82af-59d9-a6b2-f68ee27b8add', 'Burung gagak bisa mengenali wajah manusia dan mengingatnya dalam waktu lama. Jadi kalau pernah bikin gagak kesel, mungkin jangan sok lupa.', 'fact', 'alam', 147),
  ('d069b775-1af3-5362-b292-56b98e2b7a0b', 'Pisang secara botani masuk kategori berry, sementara stroberi justru bukan berry sejati. Nama sehari-hari dan ilmu botani memang suka beda pendapat.', 'fact', 'alam', 148),
  ('2960df67-9e5d-59ef-8bf2-dc80f48965f2', 'Gurita punya tiga jantung dan darah biru. Satu jantung aja kadang bikin ribet, dia santai bawa tiga.', 'fact', 'alam', 149),
  ('adacaefc-53dd-596a-bbe6-ec5419061be3', 'Paus dan lumba-lumba punya cara tidur unik karena mereka tetap perlu mengatur kapan naik ke permukaan buat bernapas.', 'fact', 'alam', 150)
on conflict (id) do update set
  content = excluded.content,
  kind = excluded.kind,
  topic = excluded.topic,
  sort_order = excluded.sort_order,
  updated_at = now();

commit;
