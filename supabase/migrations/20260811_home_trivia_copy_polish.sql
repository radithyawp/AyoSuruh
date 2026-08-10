begin;

update public.home_trivia
set content = case id
  when '0d88d620-33a8-4e50-9b5b-663426a1b201'::uuid then
    'Kalau kamu ngerasa satu hari terasa lama, Venus beda level. Di sana, satu hari malah lebih panjang daripada satu tahun.'
  when '7f18db53-6dd8-40f7-a6ae-9fa763ee7d35'::uuid then
    'Gurita punya tiga jantung dan darah biru. Satu aja kadang bikin ribet, dia santai bawa tiga.'
  when 'e5563fb2-69ea-4ab6-a73c-949f666c1502'::uuid then
    'Hiu udah eksis jauh sebelum pohon modern muncul. Kalau soal senioritas di Bumi, mereka memang beda angkatan.'
  when '991eb22e-2695-4f1f-b9c5-2715194218c8'::uuid then
    'Sehari di Mars cuma sekitar 39 menit lebih lama dari Bumi. Jadi kalau pindah ke sana, jam tidurmu mungkin masih aman.'
  when '8297814f-b2b1-49ea-b58a-865a4ec35b7c'::uuid then
    'Paus dan lumba-lumba punya cara tidur yang unik karena mereka tetap harus ingat buat naik ke permukaan dan bernapas.'
  else content
end,
updated_at = now()
where id in (
  '0d88d620-33a8-4e50-9b5b-663426a1b201'::uuid,
  '7f18db53-6dd8-40f7-a6ae-9fa763ee7d35'::uuid,
  'e5563fb2-69ea-4ab6-a73c-949f666c1502'::uuid,
  '991eb22e-2695-4f1f-b9c5-2715194218c8'::uuid,
  '8297814f-b2b1-49ea-b58a-865a4ec35b7c'::uuid
);

commit;
