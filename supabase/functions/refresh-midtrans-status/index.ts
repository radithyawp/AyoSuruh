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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

type LocalStatus =
  | 'pending'
  | 'paid'
  | 'failed'
  | 'expired'
  | 'refunded'
  | 'cancelled';

function mapStatus(data: Record<string, unknown>, current: string): LocalStatus {
  const transaction = String(data.transaction_status ?? '').toLowerCase();
  const fraud = String(data.fraud_status ?? '').toLowerCase();

  if (current === 'refunded') return 'refunded';
  if (current === 'cancelled') return 'cancelled';
  if (current === 'paid' && !['refund', 'partial_refund', 'cancel', 'chargeback', 'partial_chargeback'].includes(transaction)) {
    return 'paid';
  }
  if (transaction === 'settlement') return 'paid';
  if (transaction === 'capture' && (fraud === 'accept' || fraud === '')) {
    return 'paid';
  }
  if (transaction === 'expire') return 'expired';
  if (transaction === 'cancel') return 'cancelled';
  if (transaction === 'failure') return 'failed';
  // Satu Snap order dapat memiliki beberapa attempt. Deny tidak menutup order.
  if (transaction === 'deny') return 'pending';
  if (['refund', 'partial_refund'].includes(transaction)) return 'refunded';
  if (['chargeback', 'partial_chargeback'].includes(transaction)) return 'refunded';
  return 'pending';
}

async function notifyTransition(
  admin: ReturnType<typeof createClient>,
  job: Record<string, any>,
  previousStatus: string,
  nextStatus: LocalStatus,
  orderId: string,
) {
  if (previousStatus === nextStatus) return;

  if (nextStatus === 'paid') {
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
  } else if (nextStatus === 'expired') {
    await admin.rpc('enqueue_notification', {
      p_user_id: job.customer_id,
      p_title: 'Pembayaran Kedaluwarsa',
      p_body: `Waktu pembayaran pekerjaan ${job.title} telah berakhir. Buat pembayaran baru untuk melanjutkan.`,
      p_type: 'payment_expired',
      p_job_id: job.id,
      p_data: { order_id: orderId },
    });
  } else if (nextStatus === 'failed') {
    await admin.rpc('enqueue_notification', {
      p_user_id: job.customer_id,
      p_title: 'Pembayaran Gagal',
      p_body: `Pembayaran pekerjaan ${job.title} belum berhasil. Silakan coba kembali.`,
      p_type: 'payment_failed',
      p_job_id: job.id,
      p_data: { order_id: orderId },
    });
  } else if (nextStatus === 'refunded') {
    await admin.rpc('enqueue_notification', {
      p_user_id: job.customer_id,
      p_title: 'Refund Disetujui',
      p_body: `Pengembalian dana pekerjaan ${job.title} telah disetujui Midtrans.`,
      p_type: 'refund_success',
      p_job_id: job.id,
      p_data: { order_id: orderId },
    });
    if (job.mitra_id) {
      await admin.rpc('enqueue_notification', {
        p_user_id: job.mitra_id,
        p_title: 'Pembayaran Direfund',
        p_body: `Pembayaran pekerjaan ${job.title} telah direfund kepada customer.`,
        p_type: 'refund_success',
        p_job_id: job.id,
        p_data: { order_id: orderId },
      });
    }
  } else if (nextStatus === 'cancelled') {
    await admin.rpc('enqueue_notification', {
      p_user_id: job.customer_id,
      p_title: 'Transaksi Dibatalkan',
      p_body: `Transaksi pekerjaan ${job.title} telah dibatalkan.`,
      p_type: 'payment_cancelled',
      p_job_id: job.id,
      p_data: { order_id: orderId },
    });
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = readNamedKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
    const serviceRoleKey = readNamedKey(
      'SUPABASE_SECRET_KEYS',
      'SUPABASE_SERVICE_ROLE_KEY',
    );
    const serverKey = Deno.env.get('MIDTRANS_SERVER_KEY');
    const isProduction =
      (Deno.env.get('MIDTRANS_IS_PRODUCTION') ?? 'false').toLowerCase() ===
      'true';

    if (!supabaseUrl || !anonKey || !serviceRoleKey || !serverKey) {
      return json({ error: 'Konfigurasi server pembayaran belum lengkap.' }, 500);
    }

    const authorization = req.headers.get('Authorization') ?? '';
    const accessToken = authorization.replace(/^Bearer\s+/i, '').trim();
    if (!accessToken) return json({ error: 'Sesi login tidak valid.' }, 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
    });
    const { data: authData, error: authError } =
      await userClient.auth.getUser(accessToken);
    if (authError || !authData.user) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const jobId = String(body.job_id ?? '').trim();
    if (!jobId) return json({ error: 'job_id wajib diisi.' }, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: job } = await admin
      .from('jobs')
      .select('id, customer_id, mitra_id, title, status')
      .eq('id', jobId)
      .maybeSingle();
    if (!job) return json({ error: 'Pekerjaan tidak ditemukan.' }, 404);
    if (![job.customer_id, job.mitra_id].includes(authData.user.id)) {
      return json({ error: 'Kamu tidak memiliki akses ke pembayaran ini.' }, 403);
    }

    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .maybeSingle();
    if (paymentError || !payment) {
      return json({ error: 'Transaksi pembayaran belum tersedia.' }, 404);
    }
    if (!payment.order_id) {
      return json({ success: true, payment, message: 'Snap Token belum dibuat.' });
    }

    const baseUrl = isProduction
      ? 'https://api.midtrans.com'
      : 'https://api.sandbox.midtrans.com';
    const statusResponse = await fetch(
      `${baseUrl}/v2/${encodeURIComponent(payment.order_id)}/status`,
      {
        headers: {
          Authorization: `Basic ${btoa(`${serverKey}:`)}`,
          Accept: 'application/json',
        },
      },
    );
    const statusData = await statusResponse.json().catch(() => ({}));

    if (!statusResponse.ok) {
      const locallyExpired =
        payment.expires_at && new Date(payment.expires_at).getTime() <= Date.now();
      if (statusResponse.status === 404 && locallyExpired) {
        statusData.transaction_status = 'expire';
        statusData.status_message = 'Waktu pembayaran telah berakhir.';
      } else {
        return json(
          {
            error:
              statusData?.status_message ??
              'Status transaksi belum dapat dibaca dari Midtrans.',
          },
          statusResponse.status === 404 ? 404 : 502,
        );
      }
    }

    const mappedStatus = mapStatus(statusData, String(payment.status));
    const expected = Number(payment.amount ?? 0) + Number(payment.service_fee ?? 0);
    const received = Number(statusData.gross_amount ?? expected);
    if (mappedStatus === 'paid' && Math.abs(expected - received) > 0.01) {
      return json({ error: 'Nominal transaksi Midtrans tidak sesuai.' }, 409);
    }

    const previousStatus = String(payment.status);
    const now = new Date().toISOString();
    const transactionStatus = String(
      statusData.transaction_status ?? payment.transaction_status ?? '',
    ).toLowerCase();
    const refundAmount = Number(
      statusData.refund_amount ?? payment.refunded_amount ?? 0,
    );
    const updatePayload = {
      status: mappedStatus,
      payment_required:
        mappedStatus === 'refunded' || mappedStatus === 'cancelled'
          ? false
          : payment.payment_required,
      paid_at:
        mappedStatus === 'paid'
          ? payment.paid_at ?? now
          : payment.paid_at,
      refunded_amount:
        mappedStatus === 'refunded' && Number.isFinite(refundAmount)
          ? refundAmount
          : payment.refunded_amount,
      refund_status:
        mappedStatus === 'refunded'
          ? transactionStatus || 'refund'
          : payment.refund_status,
      refunded_at:
        mappedStatus === 'refunded'
          ? payment.refunded_at ?? now
          : payment.refunded_at,
      transaction_id: statusData.transaction_id ?? payment.transaction_id,
      transaction_status:
        statusData.transaction_status ?? payment.transaction_status,
      fraud_status: statusData.fraud_status ?? payment.fraud_status,
      payment_type: statusData.payment_type ?? payment.payment_type,
      status_code: statusData.status_code ?? payment.status_code,
      status_message: statusData.status_message ?? payment.status_message,
      raw_response: statusData,
    };

    const { data: updated, error: updateError } = await admin
      .from('payments')
      .update(updatePayload)
      .eq('id', payment.id)
      .select('*')
      .single();
    if (updateError) {
      return json({ error: 'Status pembayaran gagal disimpan.' }, 500);
    }

    await admin
      .from('payment_attempts')
      .update({
        ...updatePayload,
        raw_response: statusData,
      })
      .eq('order_id', payment.order_id);

    if (mappedStatus === 'refunded' || mappedStatus === 'cancelled') {
      await admin
        .from('refund_requests')
        .update({
          status: mappedStatus === 'refunded' ? 'refunded' : 'cancelled',
          transaction_status: transactionStatus,
          status_message:
            statusData.status_message ??
            (mappedStatus === 'refunded'
              ? 'Refund telah diproses.'
              : 'Transaksi telah dibatalkan.'),
          processed_at: now,
          raw_response: statusData,
        })
        .eq('payment_id', payment.id)
        .in('status', ['requested', 'processing', 'manual_review']);

      await admin
        .from('jobs')
        .update({ status: 'cancelled' })
        .eq('id', job.id)
        .eq('status', 'accepted');
    }

    await notifyTransition(
      admin,
      job,
      previousStatus,
      mappedStatus,
      payment.order_id,
    );

    return json({ success: true, payment: updated });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
