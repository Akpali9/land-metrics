// Edge Function "push": sends a phone notification whenever a row is added to `notifications`.
// Setup: secret FIREBASE_SERVICE_ACCOUNT (the service-account JSON), then a Database Webhook
// (table: notifications, event: INSERT) that calls this function.
import { createClient } from "jsr:@supabase/supabase-js@2";

const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const b64 = (b: ArrayBuffer | string) => btoa(typeof b === "string" ? b : String.fromCharCode(...new Uint8Array(b))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64(JSON.stringify({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 }));
  const pem = String(sa.private_key).replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claim}`));
  const r = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${head}.${claim}.${b64(sig)}` }) });
  return (await r.json()).access_token;
}

Deno.serve(async (req) => {
  if (req.headers.get("Authorization") !== `Bearer ${SERVICE}`) return new Response("forbidden", { status: 403 });
  try {
    const { record } = await req.json();
    if (!record?.body) return new Response("skip");
    const db = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE);
    let userIds: string[] = [];
    if (record.user_id) userIds = [record.user_id];
    else { const { data } = await db.from("lands").select("seller_id"); userIds = [...new Set((data ?? []).map((x: { seller_id: string }) => x.seller_id))]; }
    if (!userIds.length) return new Response("no recipients");
    const { data: toks } = await db.from("device_tokens").select("token").in("user_id", userIds);
    if (!toks?.length) return new Response("no devices");
    const at = await accessToken();
    for (const { token } of toks) {
      const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST", headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
        body: JSON.stringify({ message: { token, notification: { title: record.title ?? "LAND METRICS", body: String(record.body).slice(0, 180) }, android: { priority: "HIGH" } } }),
      });
      if (r.status === 404 || r.status === 400) await db.from("device_tokens").delete().eq("token", token);
    }
    return new Response("sent");
  } catch (_) { return new Response("error", { status: 500 }); }
});
