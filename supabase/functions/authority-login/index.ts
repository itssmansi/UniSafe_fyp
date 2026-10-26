import { createClient } from "npm:@supabase/supabase-js@2";
import bcrypt from "npm:bcryptjs@2.4.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeDepartment(value: unknown) {
  return String(value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function departmentMatches(requested: string, saved: unknown) {
  const value = normalizeDepartment(saved);
  return requested === "BMC"
    ? value.includes("bmc") || value.includes("municipal")
    : value.includes("police");
}

function safeEqual(left: string, right: string) {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a[i] ^ b[i];
  return mismatch === 0;
}

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function verifyPassword(password: string, storedValue: unknown) {
  if (typeof storedValue !== "string" || !storedValue) return false;

  if (/^\$2[aby]\$/.test(storedValue)) {
    try {
      return await bcrypt.compare(password, storedValue.replace(/^\$2y\$/, "$2a$"));
    } catch {
      return false;
    }
  }

  // Supports Werkzeug's pbkdf2:sha256:<iterations>$<salt>$<hex digest> format.
  const pbkdf2 = storedValue.match(/^pbkdf2:(sha256|sha512):(\d+)\$([^$]+)\$([a-f0-9]+)$/i);
  if (pbkdf2) {
    try {
      const [, algorithm, count, salt, expected] = pbkdf2;
      const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(password),
        "PBKDF2",
        false,
        ["deriveBits"],
      );
      const bits = await crypto.subtle.deriveBits({
        name: "PBKDF2",
        salt: new TextEncoder().encode(salt),
        iterations: Number(count),
        hash: algorithm.toUpperCase().replace("SHA", "SHA-"),
      }, key, expected.length * 4);
      return safeEqual(bytesToHex(new Uint8Array(bits)), expected.toLowerCase());
    } catch {
      return false;
    }
  }

  // Existing demonstration rows may store a literal test password in this legacy column.
  return safeEqual(password, storedValue);
}

async function findOrCreateSessionUser(admin: ReturnType<typeof createClient>, authority: Record<string, unknown>, password: string) {
  const authorityId = String(authority.id);
  const syntheticEmail = `authority-${authorityId}@example.com`;
  let authUser: Record<string, unknown> | null = null;
  const linkedAuthId = typeof authority.auth_user_id === "string" ? authority.auth_user_id : "";

  if (linkedAuthId) {
    const { data, error } = await admin.auth.admin.getUserById(linkedAuthId);
    if (!error && data.user) authUser = data.user as unknown as Record<string, unknown>;
  }

  if (!authUser) {
    const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
    if (error) throw new Error("Could not prepare the authority session.");
    const found = data.users.find((user) => user.email?.toLowerCase() === syntheticEmail.toLowerCase());
    if (found) authUser = found as unknown as Record<string, unknown>;
  }

  if (authUser) {
    const userId = String(authUser.id);
    const confirmation = authUser.email
      ? { email_confirm: true }
      : authUser.phone
      ? { phone_confirm: true }
      : { email_confirm: true };
    const { data, error } = await admin.auth.admin.updateUserById(userId, {
      password,
      ...confirmation,
      user_metadata: {
        ...(authUser.user_metadata as Record<string, unknown> ?? {}),
        role_type: "authority",
        authority_id: authorityId,
      },
    });
    if (error || !data.user) throw new Error("Could not prepare the authority session.");
    authUser = data.user as unknown as Record<string, unknown>;
  } else {
    const { data, error } = await admin.auth.admin.createUser({
      email: syntheticEmail,
      password,
      email_confirm: true,
      user_metadata: { role_type: "authority", authority_id: authorityId },
    });
    if (error || !data.user) throw new Error("Could not prepare the authority session.");
    authUser = data.user as unknown as Record<string, unknown>;
  }

  const userId = String(authUser.id);
  if (linkedAuthId !== userId) {
    const { error } = await admin.from("authorities").update({ auth_user_id: userId }).eq("id", authorityId);
    if (error) throw new Error("Could not link the authority login.");
  }

  const credentials = authUser.email
    ? { email: String(authUser.email) }
    : authUser.phone
    ? { phone: String(authUser.phone) }
    : { email: syntheticEmail };
  return { userId, credentials };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ success: false, message: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return response({ success: false, message: "Authentication service is not configured." }, 500);

  let input: Record<string, unknown>;
  try {
    input = await request.json();
  } catch {
    return response({ success: false, message: "A JSON login request is required." }, 400);
  }

  const name = typeof input.name === "string" ? input.name.trim() : "";
  const department = typeof input.department === "string" ? input.department.toUpperCase().trim() : "";
  const password = typeof input.password === "string" ? input.password : "";
  if (!name || !password || !["BMC", "POLICE"].includes(department)) {
    return response({ success: false, message: "Enter your authority name, department, and password." }, 400);
  }

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: candidates, error: lookupError } = await admin.from("authorities")
    .select("id,auth_user_id,name,department,jurisdiction,role,ward_code,password_hash")
    .eq("name", name)
    .limit(10);
  if (lookupError) return response({ success: false, message: "Could not verify the authority records." }, 500);

  const matching = (candidates ?? []).filter((row) => departmentMatches(department, row.department));
  if (matching.length !== 1) {
    return response({ success: false, message: matching.length > 1
      ? "More than one authority record matches. Ask an administrator to make the records unique."
      : "No authority record matches that name and department." }, 401);
  }

  const authority = matching[0] as unknown as Record<string, unknown>;
  if (!await verifyPassword(password, authority.password_hash)) {
    return response({ success: false, message: "Invalid authority name or password." }, 401);
  }

  try {
    const sessionUser = await findOrCreateSessionUser(admin, authority, password);
    const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: sessionData, error: sessionError } = await authClient.auth.signInWithPassword({
      ...sessionUser.credentials,
      password,
    });
    if (sessionError || !sessionData.session) {
      return response({ success: false, message: "Authority records matched, but the dashboard session could not be created." }, 500);
    }

    const { password_hash: _passwordHash, ...safeAuthority } = authority;
    return response({
      success: true,
      user_id: sessionUser.userId,
      authority: safeAuthority,
      access_token: sessionData.session.access_token,
      refresh_token: sessionData.session.refresh_token,
    });
  } catch (error) {
    console.error("Authority login session setup failed:", error);
    return response({ success: false, message: error instanceof Error ? error.message : "Could not create the authority session." }, 500);
  }
});
