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

function sanitizeText(value: unknown, fallback: string, maxLength: number) {
  const result = String(value ?? '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return (result || fallback).slice(0, maxLength);
}

function normalizePhone(value: unknown): string | undefined {
  const digits = String(value ?? '').replace(/\D/g, '');
  if (!digits) return undefined;
  if (digits.startsWith('0')) return `+62${digits.slice(1)}`;
  if (digits.startsWith('62')) return `+${digits}`;
  return digits.startsWith('8') ? `+62${digits}` : `+${digits}`;
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

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: 'Konfigurasi Supabase Edge Function belum lengkap.' }, 500);
    }
    if (!serverKey) {
      return json({
        error:
          'MIDTRANS_SERVER_KEY belum diatur. Gunakan Server Key Sandbox setelah akun Midtrans tersedia.',
      }, 503);
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
    const { data: job, error: jobError } = await admin
      .from('jobs')
      .select('id, title, description, status, customer_id, mitra_id, budget')
      .eq('id', jobId)
      .maybeSingle();

    if (jobError || !job) return json({ error: 'Pekerjaan tidak ditemukan.' }, 404);
    if (job.customer_id !== authData.user.id) {
      return json({ error: 'Hanya customer pemilik job yang dapat membayar.' }, 403);
    }
    if (!job.mitra_id) {
      return json({ error: 'Pilih mitra terlebih dahulu sebelum membayar.' }, 409);
    }
    if (!['accepted', 'on_progress', 'completed'].includes(String(job.status))) {
      return json({ error: 'Pekerjaan belum siap dibayar.' }, 409);
    }

    const { data: bid, error: bidError } = await admin
      .from('bids')
      .select('id, price')
      .eq('job_id', jobId)
      .eq('status', 'accepted')
      .maybeSingle();
    if (bidError || !bid) {
      return json({ error: 'Penawaran mitra terpilih tidak ditemukan.' }, 409);
    }

    const { data: customer, error: customerError } = await admin
      .from('users')
      .select('id, email, fullname, phone')
      .eq('id', authData.user.id)
      .maybeSingle();
    if (customerError || !customer) {
      return json({ error: 'Profil customer tidak ditemukan.' }, 409);
    }

    const { data: existing } = await admin
      .from('payments')
      .select('*')
      .eq('job_id', jobId)
      .maybeSingle();

    if (existing?.status === 'paid') {
      return json({ success: true, reused: true, payment: existing });
    }
    if (
      existing?.payment_required === true &&
      existing?.status === 'pending' &&
      existing?.redirect_url &&
      existing?.snap_token
    ) {
      return json({ success: true, reused: true, payment: existing });
    }

    const baseAmount = Math.round(Number(bid.price ?? job.budget ?? 0));
    if (!Number.isFinite(baseAmount) || baseAmount <= 0) {
      return json({ error: 'Nominal pembayaran tidak valid.' }, 409);
    }

    const feePercent = Math.max(
      0,
      Number.parseFloat(Deno.env.get('MIDTRANS_SERVICE_FEE_PERCENT') ?? '0') ||
        0,
    );
    const serviceFee = Math.round((baseAmount * feePercent) / 100);
    const grossAmount = baseAmount + serviceFee;
    const compactJobId = jobId.replace(/-/g, '').slice(0, 14);
    const orderId = `AYO-${compactJobId}-${Date.now()}`.slice(0, 50);

    const itemDetails: Record<string, unknown>[] = [
      {
        id: `JOB-${compactJobId}`.slice(0, 50),
        price: baseAmount,
        quantity: 1,
        name: sanitizeText(job.title, 'Jasa AyoSuruh', 50),
      },
    ];
    if (serviceFee > 0) {
      itemDetails.push({
        id: `FEE-${compactJobId}`.slice(0, 50),
        price: serviceFee,
        quantity: 1,
        name: 'Biaya layanan AyoSuruh',
      });
    }

    const customerDetails: Record<string, unknown> = {
      first_name: sanitizeText(customer.fullname, 'Customer AyoSuruh', 50),
    };
    const email = String(customer.email ?? authData.user.email ?? '').trim();
    if (email) customerDetails.email = email.slice(0, 255);
    const phone = normalizePhone(customer.phone);
    if (phone) customerDetails.phone = phone;

    const snapBody = {
      transaction_details: {
        order_id: orderId,
        gross_amount: grossAmount,
      },
      item_details: itemDetails,
      customer_details: customerDetails,
      credit_card: { secure: true },
      custom_field1: jobId,
      custom_field2: String(job.mitra_id),
    };

    const endpoint = isProduction
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
    const midtransResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${btoa(`${serverKey}:`)}`,
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(snapBody),
    });
    const midtransData = await midtransResponse.json().catch(() => ({}));

    if (!midtransResponse.ok) {
      console.error('Midtrans Snap create failed', midtransData);
      return json(
        {
          error:
            midtransData?.error_messages?.join?.(', ') ??
            midtransData?.status_message ??
            'Midtrans menolak pembuatan Snap Token.',
        },
        midtransResponse.status >= 400 && midtransResponse.status < 500
          ? 400
          : 502,
      );
    }

    const snapToken = String(midtransData.token ?? '').trim();
    const redirectUrl = String(midtransData.redirect_url ?? '').trim();
    if (!snapToken || !redirectUrl) {
      return json({ error: 'Respons Midtrans tidak memuat token pembayaran.' }, 502);
    }

    const paymentPayload = {
      job_id: jobId,
      amount: baseAmount,
      service_fee: serviceFee,
      provider: 'midtrans',
      payment_required: true,
      status: 'pending',
      paid_at: null,
      order_id: orderId,
      snap_token: snapToken,
      redirect_url: redirectUrl,
      transaction_id: null,
      transaction_status: 'pending',
      fraud_status: null,
      payment_type: null,
      status_code: null,
      status_message: null,
      expires_at: null,
      raw_response: midtransData,
    };

    const { data: payment, error: paymentError } = await admin
      .from('payments')
      .upsert(paymentPayload, { onConflict: 'job_id' })
      .select('*')
      .single();
    if (paymentError) {
      console.error('Payment upsert failed', paymentError);
      return json({ error: 'Snap Token dibuat, tetapi transaksi gagal disimpan.' }, 500);
    }

    return json({ success: true, reused: false, payment }, 201);
  } catch (error) {
    console.error(error);
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});
