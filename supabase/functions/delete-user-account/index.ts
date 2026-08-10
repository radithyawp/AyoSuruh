import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.112.2';

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

function cleanText(value: unknown, maxLength: number): string | null {
  const text = String(value ?? '')
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
  return text.length > 0 ? text : null;
}

async function removeStoragePrefix(
  admin: SupabaseClient,
  bucket: string,
  prefix: string,
): Promise<void> {
  const pending = [prefix.replace(/\/+$/, '')];
  const files: string[] = [];

  while (pending.length > 0) {
    const folder = pending.shift()!;
    const { data, error } = await admin.storage
      .from(bucket)
      .list(folder, { limit: 1000 });
    if (error) {
      console.warn(`Folder ${bucket}/${folder} belum dapat dibaca:`, error.message);
      return;
    }

    for (const entry of data ?? []) {
      const path = folder ? `${folder}/${entry.name}` : entry.name;
      if (entry.id == null) {
        pending.push(path);
      } else {
        files.push(path);
      }
    }
  }

  for (let index = 0; index < files.length; index += 100) {
    const chunk = files.slice(index, index + 100);
    const { error } = await admin.storage.from(bucket).remove(chunk);
    if (error) {
      console.warn(`Media pada bucket ${bucket} belum dapat dibersihkan:`, error.message);
    }
  }
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
      return json({ error: 'Konfigurasi penghapusan akun belum lengkap.' }, 500);
    }

    const authorization = req.headers.get('Authorization') ?? '';
    const accessToken = authorization.replace(/^Bearer\s+/i, '').trim();
    if (!accessToken) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${accessToken}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: authData, error: authError } =
      await userClient.auth.getUser(accessToken);
    if (authError || !authData.user) {
      return json({ error: 'Sesi login tidak valid.' }, 401);
    }

    const body = await req.json().catch(() => ({}));
    if (body.confirmation !== 'HAPUS') {
      return json(
        { error: 'Konfirmasi penghapusan harus sama persis dengan HAPUS.' },
        400,
      );
    }

    const reasonCode = cleanText(body.reason_code, 64);
    const reasonLabel = cleanText(body.reason_label, 160);
    const note = cleanText(body.note, 600);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Jika percobaan sebelumnya sudah sempat menganonimkan profil tetapi gagal
    // menghapus Auth identity, retry tidak boleh menganonimkan data dua kali.
    const { data: lifecycle, error: lifecycleError } = await admin
      .from('users')
      .select('account_state')
      .eq('id', authData.user.id)
      .maybeSingle();
    if (lifecycleError) {
      return json({ error: 'Status lifecycle akun belum dapat diverifikasi.' }, 500);
    }

    let prepared: unknown = {};
    if (lifecycle?.account_state !== 'deleted') {
      const { data, error: prepareError } = await userClient.rpc(
        'prepare_my_account_deletion',
        {
          p_reason_code: reasonCode,
          p_reason_label: reasonLabel,
          p_note: note,
        },
      );
      if (prepareError) {
        return json({ error: prepareError.message }, 409);
      }
      prepared = data;
    }

    const payload = prepared && typeof prepared === 'object'
      ? prepared as Record<string, unknown>
      : {};
    const rawPaths = Array.isArray(payload.mitra_document_paths)
      ? payload.mitra_document_paths
      : [];
    const paths = rawPaths
      .map((value) => String(value ?? '').trim())
      .filter((value) => value.length > 0);

    if (paths.length > 0) {
      const { error: storageError } = await admin.storage
        .from('mitra-documents')
        .remove(paths);
      if (storageError) {
        console.warn('Dokumen Mitra belum dapat dibersihkan:', storageError.message);
      }
    }

    const { data: avatarFiles, error: avatarListError } = await admin.storage
      .from('avatars')
      .list('', { limit: 100, search: `${authData.user.id}_` });
    if (avatarListError) {
      console.warn('Daftar avatar belum dapat dibaca:', avatarListError.message);
    } else {
      const avatarPaths = (avatarFiles ?? [])
        .map((file) => file.name)
        .filter((name) => name.startsWith(`${authData.user.id}_`));
      if (avatarPaths.length > 0) {
        const { error: avatarDeleteError } = await admin.storage
          .from('avatars')
          .remove(avatarPaths);
        if (avatarDeleteError) {
          console.warn('Avatar belum dapat dibersihkan:', avatarDeleteError.message);
        }
      }
    }

    await removeStoragePrefix(admin, 'job-images', authData.user.id);
    await removeStoragePrefix(admin, 'mitra-service-images', authData.user.id);

    const mediaPrefix = `${authData.user.id}/%`;
    const { error: jobImageRowsError } = await admin
      .from('job_images')
      .delete()
      .like('storage_path', mediaPrefix);
    if (jobImageRowsError) {
      console.warn('Metadata foto pekerjaan belum dapat dibersihkan:', jobImageRowsError.message);
    }
    const { error: serviceImageRowsError } = await admin
      .from('mitra_service_images')
      .delete()
      .like('storage_path', mediaPrefix);
    if (serviceImageRowsError) {
      console.warn('Metadata foto katalog belum dapat dibersihkan:', serviceImageRowsError.message);
    }

    const { error: feedbackPrivacyError } = await admin
      .from('app_feedback')
      .update({ allow_followup: false, contact: null })
      .eq('user_id', authData.user.id);
    if (feedbackPrivacyError) {
      console.warn('Kontak feedback belum dapat dianonimkan:', feedbackPrivacyError.message);
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(
      authData.user.id,
      false,
    );
    if (deleteError) {
      console.error('Auth user deletion failed:', deleteError.message);
      return json(
        {
          error:
            'Data akun sudah dianonimkan, tetapi identitas login belum dapat dihapus. Hubungi dukungan Ayo Suruh.',
        },
        500,
      );
    }

    return json({
      success: true,
      message: 'Akun berhasil dihapus.',
    });
  } catch (error) {
    console.error('delete-user-account error:', error);
    return json(
      {
        error: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});
