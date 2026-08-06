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

type LocalStatus =
  | 'pending'
  | 'paid'
  | 'failed'
  | 'expired'
  | 'refunded'
  | 'cancelled';

function mapStatus(payload: Record<string, unknown>, current: string): LocalStatus {
  const transaction = String(payload.transaction_status ?? '').toLowerCase();
  const fraud = String(payload.fraud_status ?? '').toLowerCase();

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
  // Snap dapat mengirim deny untuk attempt awal, lalu sukses pada attempt berikutnya.
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
    const { data: attempt } = await admin
      .from('payment_attempts')
      .select('*')
      .eq('order_id', orderId)
      .maybeSingle();

    let payment: Record<string, any> | null = null;
    if (attempt?.payment_id) {
      const { data } = await admin
        .from('payments')
        .select('*')
        .eq('id', attempt.payment_id)
        .maybeSingle();
      payment = data;
    } else {
      const { data } = await admin
        .from('payments')
        .select('*')
        .eq('order_id', orderId)
        .maybeSingle();
      payment = data;
    }

    if (!payment) {
      return json({ received: true, ignored: true, reason: 'Payment not found.' });
    }

    const currentAttemptStatus = String(attempt?.status ?? payment.status);
    const mappedStatus = mapStatus(payload, currentAttemptStatus);
    const expectedTotal =
      Number(attempt?.amount ?? payment.amount ?? 0) +
      Number(attempt?.service_fee ?? payment.service_fee ?? 0);
    const receivedTotal = Number(grossAmount);
    if (mappedStatus === 'paid' && Math.abs(expectedTotal - receivedTotal) > 0.01) {
      return json({ error: 'Nominal webhook tidak sesuai.' }, 409);
    }

    const now = new Date().toISOString();
    const paidAt =
      mappedStatus === 'paid'
        ? attempt?.paid_at ?? payment.paid_at ?? now
        : attempt?.paid_at ?? payment.paid_at ?? null;
    const transactionStatus = String(
      payload.transaction_status ?? attempt?.transaction_status ?? '',
    ).toLowerCase();
    const refundAmount = Number(
      payload.refund_amount ?? attempt?.refunded_amount ?? payment.refunded_amount ?? 0,
    );
    const updatePayload = {
      status: mappedStatus,
      payment_required:
        mappedStatus === 'refunded' || mappedStatus === 'cancelled'
          ? false
          : payment.payment_required,
      paid_at: paidAt,
      refunded_amount:
        mappedStatus === 'refunded' && Number.isFinite(refundAmount)
          ? refundAmount
          : attempt?.refunded_amount ?? payment.refunded_amount,
      refund_status:
        mappedStatus === 'refunded'
          ? transactionStatus || 'refund'
          : attempt?.refund_status ?? payment.refund_status,
      refunded_at:
        mappedStatus === 'refunded'
          ? attempt?.refunded_at ?? payment.refunded_at ?? now
          : attempt?.refunded_at ?? payment.refunded_at,
      transaction_id: payload.transaction_id ?? attempt?.transaction_id,
      transaction_status:
        payload.transaction_status ?? attempt?.transaction_status,
      fraud_status: payload.fraud_status ?? attempt?.fraud_status,
      payment_type: payload.payment_type ?? attempt?.payment_type,
      status_code: payload.status_code ?? attempt?.status_code,
      status_message: payload.status_message ?? attempt?.status_message,
      raw_notification: payload,
    };

    if (attempt) {
      await admin
        .from('payment_attempts')
        .update(updatePayload)
        .eq('id', attempt.id);
    }

    const isCurrentOrder = String(payment.order_id ?? '') === orderId;
    const shouldUpdatePayment =
      isCurrentOrder ||
      mappedStatus === 'paid' ||
      mappedStatus === 'refunded' ||
      mappedStatus === 'cancelled';
    let updatedPayment = payment;

    if (shouldUpdatePayment) {
      const previousStatus = String(payment.status);
      const paymentPayload = {
        ...updatePayload,
        order_id:
          ['paid', 'refunded', 'cancelled'].includes(mappedStatus)
            ? orderId
            : payment.order_id,
        snap_token:
          ['paid', 'refunded', 'cancelled'].includes(mappedStatus) &&
          attempt?.snap_token
            ? attempt.snap_token
            : payment.snap_token,
        redirect_url:
          ['paid', 'refunded', 'cancelled'].includes(mappedStatus) &&
          attempt?.redirect_url
            ? attempt.redirect_url
            : payment.redirect_url,
        expires_at:
          ['paid', 'refunded', 'cancelled'].includes(mappedStatus) &&
          attempt?.expires_at
            ? attempt.expires_at
            : payment.expires_at,
      };
      const { data, error: updateError } = await admin
        .from('payments')
        .update(paymentPayload)
        .eq('id', payment.id)
        .select('*')
        .single();
      if (updateError) {
        return json({ error: 'Status transaksi gagal disimpan.' }, 500);
      }
      updatedPayment = data;

      const { data: job } = await admin
        .from('jobs')
        .select('id, title, customer_id, mitra_id, status')
        .eq('id', payment.job_id)
        .maybeSingle();
      if (job) {
        if (mappedStatus === 'refunded' || mappedStatus === 'cancelled') {
          await admin
            .from('refund_requests')
            .update({
              status: mappedStatus === 'refunded' ? 'refunded' : 'cancelled',
              transaction_status: transactionStatus,
              provider_refund_id:
                payload.refund_chargeback_id?.toString() ?? null,
              status_message:
                payload.status_message ??
                (mappedStatus === 'refunded'
                  ? 'Refund telah diproses.'
                  : 'Transaksi telah dibatalkan.'),
              processed_at: now,
              raw_notification: payload,
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
          orderId,
        );
      }
    }

    return json({ received: true, payment: updatedPayment });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
