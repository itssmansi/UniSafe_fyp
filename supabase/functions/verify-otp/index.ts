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

function normalizeIndianPhone(phone: string): {
  authPhone: string;
  profilePhone: string;
} | null {
  const cleaned = phone
    .replace(/\s+/g, "")
    .replace(/-/g, "");

  if (/^\d{10}$/.test(cleaned)) {
    return {
      authPhone: `+91${cleaned}`,
      profilePhone: cleaned,
    };
  }

  if (/^\+91\d{10}$/.test(cleaned)) {
    return {
      authPhone: cleaned,
      profilePhone: cleaned.substring(3),
    };
  }

  return null;
}

async function hashOtp(
  otp: string,
  pepper: string,
): Promise<string> {
  const data = new TextEncoder().encode(
    `${otp}:${pepper}`,
  );

  const hashBuffer = await crypto.subtle.digest(
    "SHA-256",
    data,
  );

  return Array.from(
    new Uint8Array(hashBuffer),
  )
    .map(
      (byte) =>
        byte.toString(16).padStart(2, "0"),
    )
    .join("");
}

export default {
  fetch: withSupabase(
    { auth: "publishable" },

    async (req, ctx) => {
      try {
        if (req.method === "OPTIONS") {
          return new Response("ok", {
            headers: corsHeaders,
          });
        }

        if (req.method !== "POST") {
          return jsonResponse(
            {
              success: false,
              message:
                "Only POST requests are allowed.",
            },
            405,
          );
        }

        const body = await req.json();

        const phoneInput =
          String(body.phone ?? "");

        const otp =
          String(body.otp ?? "").trim();

        const name =
          String(body.name ?? "").trim();

        // Ensure Aadhaar is cleanly trimmed and capped to 32 chars
        let aadhaar =
          String(body.aadhaar ?? "").trim();
        if (aadhaar.length > 32) {
          aadhaar = aadhaar.substring(0, 32);
        }

        const address =
          String(body.address ?? "").trim();

        const gender =
          String(body.gender ?? "").trim();

        const email =
          String(body.email ?? "")
            .trim()
            .toLowerCase();

        const username =
          String(body.username ?? "").trim();

        const password =
          String(body.password ?? "");

        const phone =
          normalizeIndianPhone(phoneInput);

        if (!phone) {
          return jsonResponse(
            {
              success: false,
              message:
                "Invalid Indian phone number.",
            },
            400,
          );
        }

        if (!/^\d{6}$/.test(otp)) {
          return jsonResponse(
            {
              success: false,
              message:
                "OTP must contain 6 digits.",
            },
            400,
          );
        }

        if (
          !name ||
          !aadhaar ||
          !address ||
          !gender ||
          !email ||
          !username ||
          !password
        ) {
          return jsonResponse(
            {
              success: false,
              message:
                "Required registration details are missing.",
            },
            400,
          );
        }

        if (password.length < 6) {
          return jsonResponse(
            {
              success: false,
              message:
                "Password must be at least 6 characters.",
            },
            400,
          );
        }

        const otpPepper =
          Deno.env.get("OTP_PEPPER");

        if (!otpPepper) {
          console.error(
            "OTP_PEPPER is missing.",
          );

          return jsonResponse(
            {
              success: false,
              message:
                "Server configuration is incomplete.",
            },
            500,
          );
        }

        const supabaseAdmin =
          ctx.supabaseAdmin;

        // ----------------------------------------------------
        // GET LATEST VALID PHONE OTP
        // ----------------------------------------------------

        const {
          data: otpRecord,
          error: otpRecordError,
        } = await supabaseAdmin
          .from("phone_otp_verifications")
          .select("*")
          .eq("phone", phone.authPhone)
          .eq("verified", false)
          .gt(
            "expires_at",
            new Date().toISOString(),
          )
          .order("created_at", {
            ascending: false,
          })
          .limit(1)
          .maybeSingle();

        if (otpRecordError) {
          console.error(
            "OTP lookup error:",
            otpRecordError,
          );

          return jsonResponse(
            {
              success: false,
              message:
                "Could not verify OTP.",
            },
            500,
          );
        }

        if (!otpRecord) {
          return jsonResponse(
            {
              success: false,
              message:
                "OTP is invalid or has expired. Please request a new OTP.",
            },
            400,
          );
        }

        if (
          (otpRecord.attempts ?? 0) >= 5
        ) {
          return jsonResponse(
            {
              success: false,
              message:
                "Too many incorrect OTP attempts. Please request a new OTP.",
            },
            429,
          );
        }

        // VERIFY PHONE OTP
        const submittedHash =
          await hashOtp(
            otp,
            otpPepper,
          );

        if (
          submittedHash !==
          otpRecord.otp_hash
        ) {
          await supabaseAdmin
            .from(
              "phone_otp_verifications",
            )
            .update({
              attempts:
                (otpRecord.attempts ?? 0) +
                1,
            })
            .eq(
              "id",
              otpRecord.id,
            );

          return jsonResponse(
            {
              success: false,
              message:
                "Incorrect phone verification OTP code.",
            },
            400,
          );
        }

        // CHECK DUPLICATE USERNAME
        const {
          data: existingUsername,
        } = await supabaseAdmin
          .from("citizens")
          .select("id, email")
          .eq(
            "username",
            username,
          )
          .maybeSingle();

        if (existingUsername && existingUsername.email !== email) {
          return jsonResponse(
            {
              success: false,
              message:
                "Username already exists. Please choose a different username.",
            },
            409,
          );
        }

        // CHECK DUPLICATE PHONE
        const {
          data: existingPhone,
        } = await supabaseAdmin
          .from("citizens")
          .select("id, email")
          .eq(
            "phone",
            phone.profilePhone,
          )
          .maybeSingle();

        if (existingPhone && existingPhone.email !== email) {
          return jsonResponse(
            {
              success: false,
              message:
                "Phone number is already registered.",
            },
            409,
          );
        }

        // FIND OR CREATE AUTH USER
        const {
          data: usersData,
          error: usersError,
        } =
          await supabaseAdmin.auth.admin
            .listUsers({
              page: 1,
              perPage: 1000,
            });

        if (usersError) {
          console.error(
            "Could not list Auth users:",
            usersError,
          );

          return jsonResponse(
            {
              success: false,
              message:
                "Could not access Auth accounts.",
            },
            500,
          );
        }

        const authUser =
          usersData.users.find(
            (user: { email?: string }) =>
              user.email?.toLowerCase() ===
              email,
          );

        let authUserId: string;

        if (!authUser) {
          const { data: createdUserData, error: createError } =
            await supabaseAdmin.auth.admin.createUser({
              email: email,
              password: password,
              phone: phone.authPhone,
              phone_confirm: true,
              email_confirm: true,
              user_metadata: {
                name: name,
                username: username,
                user_type: "citizen",
                role: "citizen",
              },
              app_metadata: {
                user_type: "citizen",
                role: "citizen",
              },
            });

          if (createError || !createdUserData.user) {
            console.error("Auth user create error:", createError);
            return jsonResponse(
              {
                success: false,
                message:
                  createError?.message ??
                  "Could not complete Supabase account setup.",
              },
              409,
            );
          }

          authUserId = createdUserData.user.id;
        } else {
          authUserId = authUser.id;

          const {
            data: updatedUserData,
            error: updateUserError,
          } =
            await supabaseAdmin.auth.admin
              .updateUserById(
                authUserId,
                {
                  password: password,
                  phone: phone.authPhone,
                  phone_confirm: true,
                  email_confirm: true,
                  user_metadata: {
                    ...(authUser.user_metadata ?? {}),
                    name: name,
                    username: username,
                    user_type: "citizen",
                    role: "citizen",
                  },
                  app_metadata: {
                    ...(authUser.app_metadata ?? {}),
                    user_type: "citizen",
                    role: "citizen",
                  },
                },
              );

          if (
            updateUserError ||
            !updatedUserData.user
          ) {
            console.error(
              "Auth user update error:",
              updateUserError,
            );

            return jsonResponse(
              {
                success: false,
                message:
                  updateUserError?.message ??
                  "Could not complete Supabase account setup.",
              },
              409,
            );
          }
        }

        // CREATE OR UPDATE CITIZEN PROFILE (UPSERT ON auth_user_id)
        const {
          error: citizenError,
        } = await supabaseAdmin
          .from("citizens")
          .upsert({
            auth_user_id: authUserId,
            name: name,
            phone: phone.profilePhone,
            email: email,
            username: username,
            address: address,
            gender: gender,
            aadhaar_number: aadhaar,
            aadhaar_verified: true,
            phone_verified: true,
            verification_status: "verified",
            role: "citizen",
          }, { onConflict: "auth_user_id" });

        if (citizenError) {
          console.error(
            "Citizen profile creation error:",
            citizenError,
          );

          return jsonResponse(
            {
              success: false,
              message:
                `Could not save citizen profile: ${citizenError.message}`,
            },
            500,
          );
        }

        // MARK PHONE OTP VERIFIED
        await supabaseAdmin
          .from("phone_otp_verifications")
          .update({
            verified: true,
          })
          .eq("id", otpRecord.id);

        return jsonResponse({
          success: true,
          message: "Account created successfully.",
          user_id: authUserId,
        });
      } catch (error) {
        console.error(
          "verify-otp error:",
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
