import { createClient } from 'npm:@supabase/supabase-js@2.112.2';

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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function validPin(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9]{6}$/.test(value);
}

function strongPin(value: string): boolean {
  return !new Set([
    '000000', '111111', '222222', '333333', '444444',
    '555555', '666666', '777777', '888888', '999999',
    '123456', '654321', '112233', '121212', '123123', '101010',
  ]).has(value);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed.' }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = readNamedKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
    const serviceRoleKey = readNamedKey(
      'SUPABASE_SECRET_KEYS',
      'SUPABASE_SERVICE_ROLE_KEY',
    );
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({ error: 'Konfigurasi reset PIN belum lengkap.' }, 500);
    }

    const authorization = req.headers.get('Authorization') ?? '';
    const accessToken = authorization.replace(/^Bearer\s+/i, '').trim();
    if (!accessToken) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: callerData, error: callerError } =
      await caller.auth.getUser(accessToken);
    const callerUser = callerData.user;
    if (callerError || !callerUser) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const password = typeof body.password === 'string' ? body.password : '';
    const newPin = body.new_pin;
    if (password.length < 1) {
      return json({ error: 'Password akun wajib diisi.' }, 400);
    }
    if (!validPin(newPin)) {
      return json({ error: 'PIN baru harus terdiri dari tepat 6 angka.' }, 400);
    }
    if (!strongPin(newPin)) {
      return json({ error: 'PIN terlalu mudah ditebak. Gunakan kombinasi 6 angka yang lebih unik.' }, 400);
    }

    const email = callerUser.email?.trim();
    if (!email) {
      return json(
        { error: 'Akun ini tidak memiliki email yang dapat direautentikasi.' },
        400,
      );
    }

    // Reauthenticate independently using the account password. This is not the
    // caller's existing access token, so a stolen session alone cannot reset PIN.
    const verifier = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: signInData, error: signInError } =
      await verifier.auth.signInWithPassword({ email, password });

    if (
      signInError ||
      !signInData.user ||
      signInData.user.id !== callerUser.id
    ) {
      return json(
        {
          error:
            'Password tidak cocok. Untuk akun yang hanya menggunakan Google, reset PIN memerlukan verifikasi melalui dukungan Ayo Suruh.',
        },
        401,
      );
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: resetData, error: resetError } = await admin.rpc(
      'admin_reset_wallet_pin',
      { p_user_id: callerUser.id, p_new_pin: newPin },
    );
    if (resetError) {
      return json({ error: resetError.message }, 500);
    }

    const result = resetData && typeof resetData === 'object'
      ? resetData as Record<string, unknown>
      : {};
    if (result.ok !== true) {
      return json({ error: 'PIN belum dapat direset.' }, 409);
    }

    return json({ ok: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});
