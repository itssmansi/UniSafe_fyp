const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

const SANDBOX_BASE =
  Deno.env.get("SANDBOX_BASE") || "https://api.sandbox.co.in";
const SANDBOX_KEY =
  Deno.env.get("SANDBOX_KEY") || "key_live_3073becbf19c4ee78fdf0022dee8cdfe";
const SANDBOX_SECRET =
  Deno.env.get("SANDBOX_SECRET") || "secret_live_44a8d4f97be04437b87148f9cf421604";
const API_VERSION = "1.0";

async function getAccessToken(): Promise<string> {
  const res = await fetch(`${SANDBOX_BASE}/authenticate`, {
    method: "POST",
    headers: {
      "x-api-key": SANDBOX_KEY,
      "x-api-secret": SANDBOX_SECRET,
      "x-api-version": API_VERSION,
      "Content-Type": "application/json",
    },
  });
  const data = await res.json();
  const token = data?.access_token || data?.data?.access_token;
  if (!token) {
    throw new Error(data?.message || "Failed to obtain Sandbox access token");
  }
  return token;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ success: false, message: "Only POST allowed" }, 405);
  }

  try {
    const body = await req.json();
    const action = body.action;

    if (action === "init_session") {
      const token = await getAccessToken();
      const redirectUrl = body.redirect_url || "http://localhost:8080";
      const initRes = await fetch(`${SANDBOX_BASE}/kyc/digilocker/sessions/init`, {
        method: "POST",
        headers: {
          Authorization: token,
          "x-api-key": SANDBOX_KEY,
          "x-api-version": API_VERSION,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          "@entity": "in.co.sandbox.kyc.digilocker.session.request",
          flow: "signin",
          doc_types: ["aadhaar"],
          redirect_url: redirectUrl,
        }),
      });

      const initData = await initRes.json();
      const sessionData = initData?.data || initData;
      const sessionId = sessionData?.session_id;
      const authUrl = sessionData?.authorization_url;

      if (!sessionId || !authUrl) {
        return jsonResponse(
          {
            success: false,
            message: initData?.message || "Failed to initialize DigiLocker session",
            details: initData,
          },
          400,
        );
      }

      return jsonResponse({
        success: true,
        session_id: sessionId,
        authorization_url: authUrl,
      });
    }

    if (action === "check_status") {
      const sessionId = body.session_id;
      if (!sessionId) {
        return jsonResponse({ success: false, message: "Missing session_id" }, 400);
      }

      const token = await getAccessToken();
      const statusRes = await fetch(
        `${SANDBOX_BASE}/kyc/digilocker/sessions/${sessionId}/status`,
        {
          method: "GET",
          headers: {
            Authorization: token,
            "x-api-key": SANDBOX_KEY,
            "x-api-version": API_VERSION,
          },
        },
      );

      const statusData = await statusRes.json();
      const data = statusData?.data || statusData;
      return jsonResponse({
        success: true,
        status: data?.status || statusData?.status,
        data: statusData,
      });
    }

    if (action === "get_profile") {
      const sessionId = body.session_id;
      if (!sessionId) {
        return jsonResponse({ success: false, message: "Missing session_id" }, 400);
      }

      const token = await getAccessToken();
      let profile: Record<string, unknown> = {};

      try {
        const profileRes = await fetch(
          `${SANDBOX_BASE}/kyc/digilocker/sessions/${sessionId}/user/profile`,
          {
            method: "GET",
            headers: {
              Authorization: token,
              "x-api-key": SANDBOX_KEY,
              "x-api-version": API_VERSION,
            },
          },
        );
        const profileData = await profileRes.json();
        if (profileData?.data) {
          profile = profileData.data;
        } else if (profileData && typeof profileData === "object") {
          profile = profileData;
        }
      } catch (_) {}

      if (!profile || Object.keys(profile).length === 0) {
        try {
          const docRes = await fetch(
            `${SANDBOX_BASE}/kyc/digilocker/sessions/${sessionId}/documents/aadhaar`,
            {
              method: "GET",
              headers: {
                Authorization: token,
                "x-api-key": SANDBOX_KEY,
                "x-api-version": API_VERSION,
              },
            },
          );
          const docData = await docRes.json();
          if (docData?.data) {
            profile = docData.data;
          } else if (docData && typeof docData === "object") {
            profile = docData;
          }
        } catch (_) {}
      }

      return jsonResponse({
        success: true,
        profile: profile || {},
      });
    }

    return jsonResponse({ success: false, message: `Unknown action: ${action}` }, 400);
  } catch (err) {
    return jsonResponse(
      {
        success: false,
        message: err instanceof Error ? err.message : String(err),
      },
      500,
    );
  }
});
