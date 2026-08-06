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

function sanitizeReason(value: unknown): string {
  return String(value ?? '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 255);
}

async function midtransRequest(
  endpoint: string,
  serverKey: string,
  init?: RequestInit,
): Promise<{ response: Response; data: Record<string, any> }> {
  const response = await fetch(endpoint, {
    ...init,
    headers: {
      Authorization: `Basic ${btoa(`${serverKey}:`)}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });
  const raw = await response.json().catch(() => ({}));
  const data = raw && typeof raw === 'object' ? raw : { value: raw };
  return { response, data };
}

async function enqueueNotification(
  admin: ReturnType<typeof createClient>,
  params: {
    userId: string;
    title: string;
    body: string;
    type: string;
    jobId: string;
    data?: Record<string, unknown>;
  },
) {
  const { error } = await admin.rpc('enqueue_notification', {
    p_user_id: params.userId,
    p_title: params.title,
    p_body: params.body,
    p_type: params.type,
    p_job_id: params.jobId,
    p_data: params.data ?? {},
  });
  if (error) console.warn('Notification enqueue skipped:', error.message);
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
      return json({ error: 'Konfigurasi refund belum lengkap.' }, 500);
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
    const reason = sanitizeReason(body.reason);
    if (!jobId) return json({ error: 'job_id wajib diisi.' }, 400);
    if (reason.length < 10) {
      return json({ error: 'Alasan refund minimal 10 karakter.' }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: job, error: jobError } = await admin
      .from('jobs')
      .select('id, title, status, customer_id, mitra_id')
      .eq('id', jobId)
      .maybeSingle();
    if (jobError || !job) return json({ error: 'Pekerjaan tidak ditemukan.' }, 404);
    if (job.customer_id !== authData.user.id) {
      return json({ error: 'Hanya customer pemilik job yang dapat mengajukan refund.' }, 403);
    }

    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .maybeSingle();
    if (paymentError || !payment) {
      return json({ error: 'Data pembayaran tidak ditemukan.' }, 404);
    }
    if (!payment.order_id) {
      return json({ error: 'Transaksi Midtrans belum pernah dibuat.' }, 409);
    }
    if (String(payment.status) === 'refunded') {
      const { data: existingRefund } = await admin
        .from('refund_requests')
        .select('*')
        .eq('payment_id', payment.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      return json({ success: true, reused: true, refund: existingRefund });
    }

    const { data: activeRefund } = await admin
      .from('refund_requests')
      .select('*')
      .eq('payment_id', payment.id)
      .in('status', ['requested', 'processing', 'manual_review'])
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (activeRefund) {
      return json({ success: true, reused: true, refund: activeRefund });
    }

    const totalAmount =
      Number(payment.amount ?? 0) + Number(payment.service_fee ?? 0);
    if (!Number.isFinite(totalAmount) || totalAmount <= 0) {
      return json({ error: 'Nominal transaksi tidak valid.' }, 409);
    }

    const refundKey = `AYO-REF-${jobId.replace(/-/g, '').slice(0, 12)}-${Date.now()}`;
    const { data: refundRow, error: refundInsertError } = await admin
      .from('refund_requests')
      .insert({
        payment_id: payment.id,
        job_id: jobId,
        customer_id: authData.user.id,
        amount: totalAmount,
        reason,
        status: 'processing',
        provider: 'midtrans',
        provider_refund_key: refundKey,
        status_message: 'Memeriksa status transaksi Midtrans.',
      })
      .select('*')
      .single();
    if (refundInsertError || !refundRow) {
      return json({ error: 'Permintaan refund gagal disimpan.' }, 500);
    }

    // Pekerjaan yang sudah berjalan membutuhkan pemeriksaan/dispute manual.
    if (['on_progress', 'completed'].includes(String(job.status))) {
      const message =
        'Pekerjaan sudah berjalan atau selesai. Permintaan masuk pemeriksaan manual.';
      const { data: updated } = await admin
        .from('refund_requests')
        .update({
          status: 'manual_review',
          status_message: message,
          processed_at: null,
        })
        .eq('id', refundRow.id)
        .select('*')
        .single();
      await enqueueNotification(admin, {
        userId: authData.user.id,
        title: 'Refund Perlu Ditinjau',
        body: `Permintaan refund ${job.title} perlu ditinjau karena pekerjaan sudah berjalan.`,
        type: 'refund_manual_review',
        jobId,
        data: { refund_id: refundRow.id },
      });
      return json({ success: true, manual_review: true, refund: updated });
    }

    const apiBase = isProduction
      ? 'https://api.midtrans.com'
      : 'https://api.sandbox.midtrans.com';
    const statusIdentifier = encodeURIComponent(String(payment.order_id));
    const statusResult = await midtransRequest(
      `${apiBase}/v2/${statusIdentifier}/status`,
      serverKey,
      { method: 'GET' },
    );
    const transactionStatus = String(
      statusResult.data.transaction_status ?? payment.transaction_status ?? '',
    ).toLowerCase();

    if (!statusResult.response.ok) {
      const message =
        String(statusResult.data.status_message ?? '') ||
        'Status transaksi Midtrans tidak dapat diperiksa.';
      const { data: updated } = await admin
        .from('refund_requests')
        .update({
          status: 'failed',
          transaction_status: transactionStatus || null,
          status_message: message,
          processed_at: new Date().toISOString(),
          raw_response: statusResult.data,
        })
        .eq('id', refundRow.id)
        .select('*')
        .single();
      return json({ error: message, refund: updated }, 502);
    }

    if (['refund', 'partial_refund'].includes(transactionStatus)) {
      const refundedAmount = Number(statusResult.data.refund_amount ?? totalAmount);
      const localStatus = transactionStatus === 'refund' ? 'refunded' : 'partially_refunded';
      const { data: updated } = await admin
        .from('refund_requests')
        .update({
          status: localStatus,
          transaction_status: transactionStatus,
          provider_refund_id:
            statusResult.data.refund_chargeback_id?.toString() ?? null,
          status_message: statusResult.data.status_message ?? 'Refund sudah diproses.',
          processed_at: new Date().toISOString(),
          raw_response: statusResult.data,
        })
        .eq('id', refundRow.id)
        .select('*')
        .single();
      await admin
        .from('payments')
        .update({
          status: 'refunded',
          refund_status: transactionStatus,
          refunded_amount: refundedAmount,
          refunded_at: new Date().toISOString(),
          payment_required: false,
        })
        .eq('id', payment.id);
      return json({ success: true, refund: updated });
    }

    let operation: 'cancel' | 'refund';
    if (['pending', 'authorize', 'capture'].includes(transactionStatus)) {
      operation = 'cancel';
    } else if (transactionStatus === 'settlement') {
      operation = 'refund';
    } else if (['cancel', 'expire', 'deny', 'failure'].includes(transactionStatus)) {
      const { data: updated } = await admin
        .from('refund_requests')
        .update({
          status: 'cancelled',
          transaction_status: transactionStatus,
          status_message: 'Transaksi tidak lagi memiliki dana yang perlu direfund.',
          processed_at: new Date().toISOString(),
          raw_response: statusResult.data,
        })
        .eq('id', refundRow.id)
        .select('*')
        .single();
      await admin
        .from('payments')
        .update({
          status: transactionStatus === 'expire' ? 'expired' : 'cancelled',
          payment_required: false,
          transaction_status: transactionStatus,
        })
        .eq('id', payment.id);
      if (String(job.status) === 'accepted') {
        await admin.from('jobs').update({ status: 'cancelled' }).eq('id', jobId);
      }
      return json({ success: true, refund: updated });
    } else {
      const message = `Status transaksi ${transactionStatus || 'tidak dikenal'} perlu ditinjau manual.`;
      const { data: updated } = await admin
        .from('refund_requests')
        .update({
          status: 'manual_review',
          transaction_status: transactionStatus || null,
          status_message: message,
          raw_response: statusResult.data,
        })
        .eq('id', refundRow.id)
        .select('*')
        .single();
      return json({ success: true, manual_review: true, refund: updated });
    }

    const identifier = encodeURIComponent(
      String(
        statusResult.data.transaction_id ??
          payment.transaction_id ??
          payment.order_id,
      ),
    );
    const operationUrl = `${apiBase}/v2/${identifier}/${operation}`;
    const operationResult = await midtransRequest(
      operationUrl,
      serverKey,
      operation === 'refund'
        ? {
            method: 'POST',
            body: JSON.stringify({
              refund_key: refundKey,
              amount: Math.round(totalAmount),
              reason,
            }),
          }
        : { method: 'POST', body: JSON.stringify({}) },
    );

    if (!operationResult.response.ok) {
      const message =
        String(operationResult.data.status_message ?? '') ||
        (Array.isArray(operationResult.data.error_messages)
          ? operationResult.data.error_messages.join(', ')
          : '') ||
        `Midtrans menolak proses ${operation}.`;
      const manualReview = operation === 'refund';
      const { data: updated } = await admin
        .from('refund_requests')
        .update({
          status: manualReview ? 'manual_review' : 'failed',
          transaction_status: transactionStatus,
          status_message: message,
          processed_at: manualReview ? null : new Date().toISOString(),
          raw_response: operationResult.data,
        })
        .eq('id', refundRow.id)
        .select('*')
        .single();
      await enqueueNotification(admin, {
        userId: authData.user.id,
        title: manualReview ? 'Refund Perlu Ditinjau' : 'Refund Gagal',
        body: message,
        type: manualReview ? 'refund_manual_review' : 'refund_failed',
        jobId,
        data: { refund_id: refundRow.id },
      });
      return json(
        { success: manualReview, manual_review: manualReview, refund: updated, error: message },
        manualReview ? 200 : 502,
      );
    }

    const responseTransactionStatus = String(
      operationResult.data.transaction_status ??
        (operation === 'refund' ? 'refund' : 'cancel'),
    ).toLowerCase();
    const requestStatus = operation === 'refund' ? 'refunded' : 'cancelled';
    const now = new Date().toISOString();
    const refundedAmount = operation === 'refund'
      ? Number(operationResult.data.refund_amount ?? totalAmount)
      : 0;

    const { data: updatedRefund } = await admin
      .from('refund_requests')
      .update({
        status: requestStatus,
        transaction_status: responseTransactionStatus,
        provider_refund_id:
          operationResult.data.refund_chargeback_id?.toString() ?? null,
        status_message:
          operationResult.data.status_message ??
          (operation === 'refund'
            ? 'Refund berhasil diproses.'
            : 'Transaksi berhasil dibatalkan.'),
        processed_at: now,
        raw_response: operationResult.data,
      })
      .eq('id', refundRow.id)
      .select('*')
      .single();

    const paymentUpdate = operation === 'refund'
      ? {
          status: 'refunded',
          payment_required: false,
          refund_status: responseTransactionStatus,
          refunded_amount: refundedAmount,
          refunded_at: now,
          transaction_status: responseTransactionStatus,
          status_message: operationResult.data.status_message,
        }
      : {
          status: 'cancelled',
          payment_required: false,
          transaction_status: responseTransactionStatus,
          status_message: operationResult.data.status_message,
        };

    await admin.from('payments').update(paymentUpdate).eq('id', payment.id);
    await admin
      .from('payment_attempts')
      .update(paymentUpdate)
      .eq('order_id', payment.order_id);

    if (String(job.status) === 'accepted') {
      await admin.from('jobs').update({ status: 'cancelled' }).eq('id', jobId);
      await admin.from('job_timelines').insert({
        job_id: jobId,
        status: 'cancelled',
        description:
          operation === 'refund'
            ? 'Pekerjaan dibatalkan setelah pembayaran direfund.'
            : 'Pekerjaan dibatalkan dan transaksi pembayaran dibatalkan.',
      });
    }

    await enqueueNotification(admin, {
      userId: authData.user.id,
      title: operation === 'refund' ? 'Refund Disetujui' : 'Transaksi Dibatalkan',
      body:
        operation === 'refund'
          ? `Pengembalian dana untuk ${job.title} telah disetujui Midtrans.`
          : `Pembayaran ${job.title} berhasil dibatalkan.`,
      type: operation === 'refund' ? 'refund_success' : 'payment_cancelled',
      jobId,
      data: { refund_id: refundRow.id, order_id: payment.order_id },
    });
    if (job.mitra_id) {
      await enqueueNotification(admin, {
        userId: job.mitra_id,
        title: 'Pekerjaan Dibatalkan',
        body: `Customer membatalkan pekerjaan ${job.title}.`,
        type: 'job_cancelled',
        jobId,
        data: { refund_id: refundRow.id },
      });
    }

    return json({ success: true, refund: updatedRefund });
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
