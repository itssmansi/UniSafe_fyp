import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

  // If already in international format starting with +
  if (/^\+\d{10,15}$/.test(cleaned)) {
    return cleaned;
  }

  return null;
}

function maskPhone(phone: string): string {
  if (phone.length <= 4) return "****";
  return phone.slice(0, 3) + "****" + phone.slice(-3);
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { success: false, message: "Only POST requests are allowed." },
      405,
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const pingramApiKey = Deno.env.get("PINGRAM_API_KEY");
    const pingramSmsType =
      Deno.env.get("PINGRAM_SMS_TYPE") || "un1safe_otp";
    const trackingBaseUrl =
      Deno.env.get("TRACKING_BASE_URL") ||
      "https://unisafe-tracking.web.app/track";

    if (!supabaseUrl || !serviceRoleKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
      return jsonResponse(
        { success: false, message: "Supabase server secrets are not configured." },
        500,
      );
    }

    if (!pingramApiKey) {
      console.error("Missing PINGRAM_API_KEY secret");
      return jsonResponse(
        { success: false, message: "Pingram SMS API key is not configured." },
        500,
      );
    }

    // 1. Authenticate caller via JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(
        { success: false, message: "Missing Authorization header." },
        401,
      );
    }

    const supabaseUser = createClient(
      supabaseUrl,
      supabaseAnonKey || serviceRoleKey,
      {
        global: { headers: { Authorization: authHeader } },
      },
    );

    const {
      data: { user },
      error: authError,
    } = await supabaseUser.auth.getUser();

    if (authError || !user) {
      return jsonResponse(
        { success: false, message: "Invalid or expired session token." },
        401,
      );
    }

    // 2. Parse request body
    const body = await req.json();
    const journeyId = body.journey_id?.toString().trim();
    const isSos = body.is_sos === true;
    const customLat = body.latitude;
    const customLng = body.longitude;

    if (!journeyId && !isSos) {
      return jsonResponse(
        { success: false, message: "journey_id is required." },
        400,
      );
    }

    // Server-side admin client for secure data querying
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // 3. Find citizen associated with authenticated user
    const { data: citizen, error: citizenError } = await supabaseAdmin
      .from("citizens")
      .select("id, name, phone")
      .eq("auth_user_id", user.id)
      .maybeSingle();

    if (citizenError || !citizen) {
      return jsonResponse(
        { success: false, message: "Citizen profile not found for authenticated user." },
        403,
      );
    }

    let journey: Record<string, any> | null = null;
    if (journeyId) {
      // 4. Verify journey exists and belongs to this citizen
      const { data: journeyData, error: journeyError } = await supabaseAdmin
        .from("journey_sessions")
        .select("id, citizen_id, destination_name, tracking_token, status, token_expires_at, latest_latitude, latest_longitude")
        .eq("id", journeyId)
        .eq("citizen_id", citizen.id)
        .maybeSingle();

      if (journeyError || !journeyData) {
        return jsonResponse(
          { success: false, message: "Journey session not found or unauthorized." },
          404,
        );
      }

      if (journeyData.status !== "active" && !isSos) {
        return jsonResponse(
          { success: false, message: `Cannot send tracking link for ${journeyData.status} journey.` },
          400,
        );
      }
      journey = journeyData;
    }

    // 5. Fetch citizen's trusted contacts
    const { data: contacts, error: contactsError } = await supabaseAdmin
      .from("trusted_contacts")
      .select("id, contact_name, contact_phone, relationship")
      .eq("citizen_id", citizen.id)
      .order("created_at", { ascending: true });

    if (contactsError) {
      console.error("Failed to fetch trusted contacts:", contactsError);
      return jsonResponse(
        { success: false, message: "Could not fetch trusted contacts." },
        500,
      );
    }

    if (!contacts || contacts.length === 0) {
      return jsonResponse({
        success: true,
        message: "No trusted contacts registered. No SMS sent.",
        total_contacts: 0,
        sent_count: 0,
        failed_count: 0,
        results: [],
      });
    }

    // 6. Construct secure message
    const citizenName = citizen.name?.trim() || "UniSafe User";
    let smsMessage = "";

    if (isSos) {
      const lat = journey?.latest_latitude ?? customLat ?? "";
      const lng = journey?.latest_longitude ?? customLng ?? "";
      const mapLink = (lat && lng) ? ` Location: https://maps.google.com/?q=${lat},${lng}` : "";
      const trackLink = journey?.tracking_token ? ` Live: ${trackingBaseUrl}?token=${encodeURIComponent(journey.tracking_token)}` : "";
      smsMessage = `EMERGENCY SOS: ${citizenName} has triggered an urgent distress alert!${mapLink}${trackLink} Please check immediately!`;
    } else {
      const trackingUrl = `${trackingBaseUrl}?token=${encodeURIComponent(journey!.tracking_token)}`;
      const destination = journey!.destination_name || "Destination";
      smsMessage =
        `UniSafe Alert: ${citizenName} has started a Safe Journey to ${destination}. ` +
        `Track live location here: ${trackingUrl}`;
    }

    console.log(
      `Dispatching ${isSos ? "SOS" : "Safe Journey"} SMS for citizen ${citizen.id} to ${contacts.length} contact(s).`,
    );

    // 7. Dispatch SMS via Pingram with per-contact error resilience
    const sendResults = await Promise.allSettled(
      contacts.map(async (contact) => {
        const rawPhone = contact.contact_phone;
        const normalized = normalizeIndianPhone(rawPhone);

        if (!normalized) {
          throw new Error(`Invalid phone number format: ${maskPhone(rawPhone)}`);
        }

        const pingramResponse = await fetch("https://api.pingram.io/sms", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${pingramApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            type: pingramSmsType,
            to: normalized,
            message: smsMessage,
          }),
        });

        const pingramData = await pingramResponse.json().catch(() => ({}));

        if (!pingramResponse.ok) {
          const errMsg =
            pingramData?.message ||
            `Pingram HTTP error status ${pingramResponse.status}`;
          throw new Error(errMsg);
        }

        return {
          contact_id: contact.id,
          name: contact.contact_name,
          phone: maskPhone(normalized),
          status: "sent",
        };
      }),
    );

    // 8. Tally success and failures
    let sentCount = 0;
    let failedCount = 0;
    const details = sendResults.map((res, index) => {
      const contact = contacts[index];
      if (res.status === "fulfilled") {
        sentCount++;
        return res.value;
      } else {
        failedCount++;
        console.warn(
          `Failed SMS to contact ${contact.id} (${maskPhone(contact.contact_phone)}):`,
          res.reason?.message,
        );
        return {
          contact_id: contact.id,
          name: contact.contact_name,
          phone: maskPhone(contact.contact_phone),
          status: "failed",
          error: res.reason?.message || "Delivery failed",
        };
      }
    });

    return jsonResponse({
      success: true,
      message: `SMS dispatch completed: ${sentCount} sent, ${failedCount} failed.`,
      total_contacts: contacts.length,
      sent_count: sentCount,
      failed_count: failedCount,
      results: details,
    });
  } catch (error) {
    console.error("send-journey-tracking-sms unexpected error:", error);
    return jsonResponse(
      {
        success: false,
        message: error instanceof Error ? error.message : "Unexpected server error.",
      },
      500,
    );
  }
});
