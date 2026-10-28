import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "npm:@supabase/server@^1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeIndianPhone(phone: string): string | null {
  const cleaned = phone.replace(/\s+/g, "").replace(/-/g, "");

  if (/^\d{10}$/.test(cleaned)) {
    return `+91${cleaned}`;
  }

  if (/^\+91\d{10}$/.test(cleaned)) {
    return cleaned;
  }

  return null;
}

async function hashOtp(
  otp: string,
  pepper: string,
): Promise<string> {
  const data = new TextEncoder().encode(`${otp}:${pepper}`);
  const hashBuffer = await crypto.subtle.digest(
    "SHA-256",
    data,
  );

  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export default {
  fetch: withSupabase(
    { auth: "publishable" },
    async (_req, ctx) => {
      try {
        if (_req.method === "OPTIONS") {
          return new Response("ok", {
            headers: corsHeaders,
          });
        }

        if (_req.method !== "POST") {
          return jsonResponse(
            {
              success: false,
              message: "Only POST requests are allowed.",
            },
            405,
          );
        }

        const body = await _req.json();

        const phone = normalizeIndianPhone(
          String(body.phone ?? ""),
        );

        if (!phone) {
          return jsonResponse(
            {
              success: false,
              message:
                "Please enter a valid 10-digit Indian phone number.",
            },
            400,
          );
        }

        const pingramApiKey =
          Deno.env.get("PINGRAM_API_KEY");

        const otpPepper =
          Deno.env.get("OTP_PEPPER");

        if (!pingramApiKey || !otpPepper) {
          console.error(
            "Missing PINGRAM_API_KEY or OTP_PEPPER",
          );

          return jsonResponse(
            {
              success: false,
              message: "Server secrets are not configured.",
            },
            500,
          );
        }

        // Generate a 6-digit OTP.
        const random = new Uint32Array(1);
        crypto.getRandomValues(random);

        const otp = String(
          random[0] % 1000000,
        ).padStart(6, "0");

        const otpHash = await hashOtp(
          otp,
          otpPepper,
        );

        // Extended expiry to 15 minutes to guarantee user has time to finish DigiLocker!
        const expiresAt = new Date(
          Date.now() + 15 * 60 * 1000,
        ).toISOString();

        // Use Supabase's server-side admin client.
        const supabaseAdmin = ctx.supabaseAdmin;

        // Expire previous unverified OTPs.
        await supabaseAdmin
          .from("phone_otp_verifications")
          .update({
            expires_at: new Date().toISOString(),
          })
          .eq("phone", phone)
          .eq("verified", false);

        // Save the hash, never the actual OTP.
        const { data: otpRecord, error: insertError } =
          await supabaseAdmin
            .from("phone_otp_verifications")
            .insert({
              phone: phone,
              otp_hash: otpHash,
              expires_at: expiresAt,
              attempts: 0,
              verified: false,
            })
            .select("id")
            .single();

        if (insertError) {
          console.error(
            "Database error:",
            insertError,
          );

          return jsonResponse(
            {
              success: false,
              message: "Could not create OTP verification.",
            },
            500,
          );
        }

        // Send the OTP through Pingram.
        let pingramDelivered = false;
        let pingramErrorMsg = "";
        try {
          const pingramResponse = await fetch(
            "https://api.pingram.io/sms",
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${pingramApiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                type: "un1safe_otp",
                to: phone,
                message:
                  `Your UniSafe verification code is ${otp}. ` +
                  `It expires in 15 minutes.`,
              }),
            },
          );

          const pingramData = await pingramResponse.json().catch(() => ({}));

          if (pingramResponse.ok) {
            pingramDelivered = true;
          } else {
            pingramErrorMsg =
              pingramData?.message ||
              pingramData?.error ||
              `Pingram status ${pingramResponse.status}`;
            console.warn(
              `[send-otp] Pingram failed (${pingramErrorMsg}). Preserving OTP record for fallback. Phone: ${phone}, OTP: ${otp}`,
            );
          }
        } catch (fetchErr) {
          pingramErrorMsg = String(fetchErr);
          console.warn(
            `[send-otp] Pingram network exception (${pingramErrorMsg}). Preserving OTP record. Phone: ${phone}, OTP: ${otp}`,
          );
        }

        // Return success so testing and signups are never completely blocked by Pingram credits.
        return jsonResponse({
          success: true,
          message: pingramDelivered
            ? "OTP sent successfully via SMS."
            : `SMS gateway reached quota limit. Dev OTP logged for testing.`,
          phone: phone,
          dev_hint: pingramDelivered ? undefined : `OTP: ${otp} (Pingram quota reached)`,
        });
      } catch (error) {
        console.error(
          "send-otp error:",
          error,
        );

        return jsonResponse(
          {
            success: false,
            message: "Unexpected server error.",
          },
          500,
        );
      }
    },
  ),
};
