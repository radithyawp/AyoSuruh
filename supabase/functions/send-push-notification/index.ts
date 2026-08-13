import { createClient } from "npm:@supabase/supabase-js@2.112.2";

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

type NotificationRecord = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type: string | null;
};

type WebhookPayload = {
  type?: string;
  record?: NotificationRecord;
};

const encoder = new TextEncoder();

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {"Content-Type": "application/json"},
  });
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);

  return Uint8Array.from(
    binary,
    (character) => character.charCodeAt(0),
  );
}

function encodeBase64Url(value: string | Uint8Array): string {
  const bytes = typeof value === "string"
    ? encoder.encode(value)
    : value;

  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

async function createAccessToken(
  account: ServiceAccount,
): Promise<string> {
  const issuedAt = Math.floor(Date.now() / 1000);

  const header = encodeBase64Url(
    JSON.stringify({
      alg: "RS256",
      typ: "JWT",
    }),
  );

  const claims = encodeBase64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: issuedAt,
      exp: issuedAt + 3600,
    }),
  );

  const unsignedJwt = `${header}.${claims}`;

  const privateKeyBytes = decodeBase64(
    account.private_key
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s/g, ""),
  );

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      privateKey,
      encoder.encode(unsignedJwt),
    ),
  );

  const assertion =
    `${unsignedJwt}.${encodeBase64Url(signature)}`;

  const response = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type:
          "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );

  const result = await response.json() as {
    access_token?: string;
    error?: string;
    error_description?: string;
  };

  if (!response.ok || !result.access_token) {
    throw new Error(
      `Google OAuth gagal (${response.status}): ${
        JSON.stringify(result)
      }`,
    );
  }

  return result.access_token;
}

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return jsonResponse(
        {error: "Method not allowed"},
        405,
      );
    }

    const payload = await request.json() as WebhookPayload;

    if (payload.type && payload.type !== "INSERT") {
      return jsonResponse({
        ok: true,
        ignored: true,
      });
    }

    const notification = payload.record;

    if (
      !notification?.id ||
      !notification.user_id ||
      !notification.title ||
      !notification.body
    ) {
      return jsonResponse(
        {error: "Payload notifications tidak valid"},
        400,
      );
    }

    const firebaseSecret = Deno.env.get(
      "FIREBASE_SERVICE_ACCOUNT_BASE64",
    );

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

    if (!firebaseSecret || !supabaseUrl || !serviceRoleKey) {
      throw new Error(
        "Secret Edge Function belum lengkap",
      );
    }

    const account = JSON.parse(
      new TextDecoder().decode(
        decodeBase64(firebaseSecret),
      ),
    ) as ServiceAccount;

    if (
      !account.project_id ||
      !account.client_email ||
      !account.private_key
    ) {
      throw new Error(
        "Firebase service account tidak valid",
      );
    }

    const supabase = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    );

    const {data: devices, error: tokenError} =
      await supabase
        .from("device_tokens")
        .select("token")
        .eq("user_id", notification.user_id);

    if (tokenError) {
      throw tokenError;
    }

    const tokens: string[] = (
      (devices ?? []) as Array<{token: string}>
    )
      .map((device) => device.token)
      .filter((token) => token.length > 0);

    if (tokens.length === 0) {
      return jsonResponse({
        ok: true,
        sent: 0,
        reason: "no_device_tokens",
      });
    }

    const accessToken = await createAccessToken(account);
    const isVoiceCall = notification.type === "voice_call_incoming";

    const endpoint =
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

    const results = await Promise.all(
      tokens.map(async (token) => {
        try {
          const response = await fetch(endpoint, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: {
                  title: notification.title,
                  body: notification.body,
                },
                data: {
                  notification_id: notification.id,
                  type: notification.type ?? "general",
                },
                android: {
                  priority: "high",
                  restricted_package_name:
                    "com.ayosuruh.app",
                  notification: {
                    channel_id: isVoiceCall
                      ? "ayosuruh_calls"
                      : "ayosuruh_high_importance",
                    sound: "default",
                  },
                },
              },
            }),
          });

          const responseText = await response.text();

          const unregistered =
            !response.ok &&
            responseText.includes('"UNREGISTERED"');

          if (!response.ok) {
            console.error(
              `FCM gagal (${response.status}): ${responseText}`,
            );
          }

          return {
            ok: response.ok,
            token,
            unregistered,
          };
        } catch (error) {
          console.error("Request FCM gagal:", error);

          return {
            ok: false,
            token,
            unregistered: false,
          };
        }
      }),
    );

    const invalidTokens = results
      .filter((result) => result.unregistered)
      .map((result) => result.token);

    if (invalidTokens.length > 0) {
      const {error: deleteError} = await supabase
        .from("device_tokens")
        .delete()
        .in("token", invalidTokens);

      if (deleteError) {
        console.error(
          "Gagal membersihkan token:",
          deleteError,
        );
      }
    }

    const sent = results.filter(
      (result) => result.ok,
    ).length;

    return jsonResponse({
      ok: sent === results.length,
      sent,
      failed: results.length - sent,
      removed_invalid_tokens: invalidTokens.length,
    });
  } catch (error) {
    console.error(
      "send-push-notification error:",
      error,
    );

    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : String(error),
      },
      500,
    );
  }
});