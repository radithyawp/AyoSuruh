Deno.serve(() => {
  const html = `<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AyoSuruh - Status Pembayaran</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 0; background: #fff9fc; color: #2f2723; }
    main { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
    section { max-width: 520px; text-align: center; background: white; border: 1px solid #ead8cb; border-radius: 24px; padding: 32px; }
    .icon { font-size: 52px; }
    h1 { color: #8a5300; }
    p { line-height: 1.6; color: #655a53; }
  </style>
</head>
<body>
  <main>
    <section>
      <div class="icon">✅</div>
      <h1>Pembayaran sedang diproses</h1>
      <p>Kembali ke aplikasi AyoSuruh, lalu tekan <strong>Cek Status Pembayaran</strong>. Status akhir tetap ditentukan oleh notifikasi server Midtrans.</p>
    </section>
  </main>
</body>
</html>`;

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
});
