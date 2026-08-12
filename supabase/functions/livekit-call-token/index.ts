import { createClient } from 'npm:@supabase/supabase-js@2.112.2';
import { AccessToken, TrackSource } from 'npm:livekit-server-sdk@2.17.0';

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
    const livekitUrl = Deno.env.get('LIVEKIT_URL');
    const livekitApiKey = Deno.env.get('LIVEKIT_API_KEY');
    const livekitApiSecret = Deno.env.get('LIVEKIT_API_SECRET');

    if (
      !supabaseUrl ||
      !anonKey ||
      !serviceRoleKey ||
      !livekitUrl ||
      !livekitApiKey ||
      !livekitApiSecret
    ) {
      return json({ error: 'Konfigurasi panggilan belum lengkap.' }, 500);
    }

    const authorization = req.headers.get('Authorization') ?? '';
    const accessToken = authorization.replace(/^Bearer\s+/i, '').trim();
    if (!accessToken) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } =
      await callerClient.auth.getUser(accessToken);
    const user = authData.user;
    if (authError || !user) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const callId = typeof body.call_id === 'string' ? body.call_id.trim() : '';
    if (!callId) {
      return json({ error: 'call_id wajib diisi.' }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: call, error: callError } = await admin
      .from('voice_calls')
      .select('id, livekit_room_name, caller_id, callee_id, status, expires_at')
      .eq('id', callId)
      .maybeSingle();

    if (callError) {
      return json({ error: callError.message }, 500);
    }
    if (!call) {
      return json({ error: 'Panggilan tidak ditemukan.' }, 404);
    }
    if (user.id !== call.caller_id && user.id !== call.callee_id) {
      return json({ error: 'Kamu tidak memiliki akses ke panggilan ini.' }, 403);
    }
    if (!['accepted', 'ongoing'].includes(call.status)) {
      return json({ error: 'Panggilan belum diterima atau sudah berakhir.' }, 409);
    }

    const tokenBuilder = new AccessToken(
      livekitApiKey,
      livekitApiSecret,
      {
        identity: user.id,
        ttl: '10m',
      },
    );

    tokenBuilder.addGrant({
      roomJoin: true,
      room: call.livekit_room_name,
      canPublish: true,
      canSubscribe: true,
      canPublishData: false,
      canPublishSources: [TrackSource.MICROPHONE],
    });

    const participantToken = await tokenBuilder.toJwt();

    return json(
      {
        server_url: livekitUrl,
        participant_token: participantToken,
      },
      201,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('livekit-call-token error:', error);
    return json({ error: message }, 500);
  }
});
