import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function readNamedKey(envName: string, fallbackName: string): string | undefined {
  const direct = Deno.env.get(fallbackName);
  if (direct) return direct;
  const raw = Deno.env.get(envName);
  if (!raw) return undefined;
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed?.default === 'string') return parsed.default;
    const first = Object.values(parsed ?? {}).find(
      (value) => typeof value === 'string',
    );
    return typeof first === 'string' ? first : undefined;
  } catch {
    return undefined;
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function sha512Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-512',
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

type LocalStatus = 'pending' | 'paid' | 'failed' | 'expired';

function mapStatus(payload: Record<string, unknown>, current: string): LocalStatus {
  const transaction = String(payload.transaction_status ?? '').toLowerCase();
  const fraud = String(payload.fraud_status ?? '').toLowerCase();

  if (current === 'paid') return 'paid';
  if (transaction === 'settlement') return 'paid';
  if (transaction === 'capture' && (fraud === 'accept' || fraud === '')) {
    return 'paid';
  }
  if (transaction === 'expire') return 'expired';
  if (['deny', 'cancel', 'failure'].includes(transaction)) return 'failed';
  return 'pending';
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = readNamedKey(
      'SUPABASE_SECRET_KEYS',
      'SUPABASE_SERVICE_ROLE_KEY',
    );
    const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY');
    if (!supabaseUrl || !serviceRoleKey || !serverKey) {
      return json({ error: 'Konfigurasi webhook belum lengkap.' }, 500);
    }

    const payload = await req.json().catch(() => ({}));
    const orderId = String(payload.order_id ?? '').trim();
    const statusCode = String(payload.status_code ?? '').trim();
    const grossAmount = String(payload.gross_amount ?? '').trim();
    const receivedSignature = String(payload.signature_key ?? '').trim();
    if (!orderId || !statusCode || !grossAmount || !receivedSignature) {
      return json({ error: 'Payload notifikasi tidak lengkap.' }, 400);
    }

    const expectedSignature = await sha512Hex(
      `${orderId}${statusCode}${grossAmount}${serverKey}`,
    );
    if (receivedSignature.toLowerCase() !== expectedSignature.toLowerCase()) {
      return json({ error: 'Signature Midtrans tidak valid.' }, 401);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .select('*')
      .eq('order_id', orderId)
      .maybeSingle();
    if (paymentError) return json({ error: 'Transaksi gagal dicari.' }, 500);
    if (!payment) {
      return json({ received: true, ignored: true, reason: 'Payment not found.' });
    }

    const mappedStatus = mapStatus(payload, String(payment.status));
    const expectedTotal =
      Number(payment.amount ?? 0) + Number(payment.service_fee ?? 0);
    const receivedTotal = Number(grossAmount);
    if (mappedStatus === 'paid' && Math.abs(expectedTotal - receivedTotal) > 0.01) {
      return json({ error: 'Nominal webhook tidak sesuai.' }, 409);
    }

    const wasPaid = payment.status === 'paid';
    const { data: updated, error: updateError } = await admin
      .from('payments')
      .update({
        status: mappedStatus,
        paid_at:
          mappedStatus === 'paid'
            ? payment.paid_at ?? new Date().toISOString()
            : payment.paid_at,
        transaction_id: payload.transaction_id ?? payment.transaction_id,
        transaction_status:
          payload.transaction_status ?? payment.transaction_status,
        fraud_status: payload.fraud_status ?? payment.fraud_status,
        payment_type: payload.payment_type ?? payment.payment_type,
        status_code: payload.status_code ?? payment.status_code,
        status_message: payload.status_message ?? payment.status_message,
        raw_notification: payload,
      })
      .eq('id', payment.id)
      .select('*')
      .single();
    if (updateError) return json({ error: 'Status transaksi gagal disimpan.' }, 500);

    if (!wasPaid && mappedStatus === 'paid') {
      const { data: job } = await admin
        .from('jobs')
        .select('id, title, customer_id, mitra_id')
        .eq('id', payment.job_id)
        .maybeSingle();
      if (job) {
        await admin.rpc('enqueue_notification', {
          p_user_id: job.customer_id,
          p_title: 'Pembayaran Berhasil',
          p_body: `Pembayaran pekerjaan ${job.title} sudah terverifikasi.`,
          p_type: 'payment_paid',
          p_job_id: job.id,
          p_data: { order_id: orderId },
        });
        if (job.mitra_id) {
          await admin.rpc('enqueue_notification', {
            p_user_id: job.mitra_id,
            p_title: 'Customer Sudah Membayar',
            p_body: `Pembayaran pekerjaan ${job.title} sudah diterima. Pekerjaan dapat dimulai.`,
            p_type: 'payment_paid',
            p_job_id: job.id,
            p_data: { order_id: orderId },
          });
        }
      }
    }

    return json({ received: true, payment: updated });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
