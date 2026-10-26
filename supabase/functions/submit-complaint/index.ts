import { createClient } from "npm:@supabase/supabase-js@2";
import { booleanPointInPolygon, point } from "npm:@turf/turf@7";
import policeJurisdictions from "../_shared/mumbai_police_jurisdictions.json" with { type: "json" };
import bmcWards from "../_shared/mumbai_bmc_wards.json" with { type: "json" };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const normalizeKey = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");

const policeCategories = new Set([
  "Open Manholes", "Non-Existent Footpath", "Women Safety", "Illegal Parking",
  "Theft / Robbery", "Harassment / Eve-Teasing", "Assault / Violence",
  "Poor Street Lighting", "Fire Hazard", "Electrical Hazard", "Exposed Wires",
  "Child Safety Concern", "Stray Animal Threat", "Missing Person",
].map(normalizeKey));

// These are explicit roster-to-boundary aliases: the roster stores broad
// locality names, while the police GeoJSON stores station names.
const policeJurisdictionFallbacks: Record<string, string> = {
  "Andheri Police Station": "Andheri",
  "Bandra Police Station": "Bandra",
  "MIDC Police Station": "Andheri",
};

// The existing BMC roster has one Ward Officer whose saved jurisdiction is
// Andheri and no ward_code. The verified K/W polygon is Andheri West; K/E is
// intentionally held for review because the source layer predates K/North.
const bmcJurisdictionFallbacks: Record<string, string> = {
  "K/W": "Andheri",
};

const bmcCategories = new Map<string, Set<string>>([
  ["greenery", new Set([
    "Waste Dumping in Green Area", "Poor Landscape Maintenance", "Watering Required for Plants",
    "Encroachment on Green Spaces", "Pest or Insect Infestation", "Overgrown Vegetation",
    "Need Tree Plantation", "Illegal Tree Cutting", "Public Problems on Greenery",
  ].map(normalizeKey))],
  ["infrastructure", new Set([
    "Nonfunctional Street Lights", "Potholes", "Water Logging", "Prolonged Road Work", "Drainage",
  ].map(normalizeKey))],
  ["sanitation", new Set([
    "Garbage Scattered on the Road", "Public Washrooms Not Clean", "Garbage at Beach/River",
    "Untimely Garbage Collection/Overflowing",
  ].map(normalizeKey))],
]);
const allApprovedCategories = new Set([
  ...policeCategories,
  ...Array.from(bmcCategories.values()).flatMap((categories) => Array.from(categories)),
]);

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return response({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = request.headers.get("Authorization");
  if (!url || !anonKey || !serviceKey || !authorization) return response({ error: "Unauthorized" }, 401);

  const authClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error: authError } = await authClient.auth.getUser();
  if (authError || !user) return response({ error: "Citizen authentication required" }, 401);

  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: citizen, error: citizenError } = await db.from("citizens")
    .select("id").eq("auth_user_id", user.id).maybeSingle();
  if (citizenError || !citizen) return response({ error: "Verified citizen profile not found" }, 403);

  let input: Record<string, unknown>;
  try {
    input = await request.json();
  } catch {
    return response({ error: "A JSON complaint body is required" }, 400);
  }

  const title = typeof input.title === "string" ? input.title.trim() : "";
  const category = typeof input.category === "string" ? normalizeKey(input.category) : "";
  const description = typeof input.description === "string" ? input.description.trim() : "";
  const normalizedTitle = normalizeKey(title);
  if (!title || !category) return response({ error: "Complaint title and category are required" }, 400);

  const latitude = typeof input.latitude === "number" ? input.latitude : null;
  const longitude = typeof input.longitude === "number" ? input.longitude : null;
  const hasCoordinates = latitude !== null && longitude !== null &&
    Number.isFinite(latitude) && Number.isFinite(longitude) &&
    latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  const isPolice = category === "safety" && policeCategories.has(normalizedTitle);
  const isBmcCategory = bmcCategories.get(category)?.has(normalizedTitle) ?? false;
  const isMissingPerson = isPolice && normalizedTitle === normalizeKey("Missing Person");
  const categoryMismatch = allApprovedCategories.has(normalizedTitle) && !isPolice && !isBmcCategory;
  const department: string | null = isPolice ? "Police" : isBmcCategory ? "BMC" : null;

  if (isMissingPerson) {
    const imageUrl = typeof input.image_url === "string" ? input.image_url.trim() : "";
    let validImageUrl = false;
    try {
      validImageUrl = new URL(imageUrl).protocol === "https:";
    } catch { /* Missing or invalid image URL. */ }
    if (!description || !validImageUrl || !hasCoordinates) {
      return response({ error: "Missing-person reports require a description, uploaded image, and valid location" }, 400);
    }
  }
  let jurisdiction: string | null = null;
  let assignedAuthorityId: string | null = null;
  let assignmentStatus = "manual_review";
  let assignmentReason: string | null = null;

  if (!hasCoordinates) {
    assignmentReason = input.latitude == null || input.longitude == null
      ? "missing_coordinates"
      : "invalid_coordinates";
  } else if (!department) {
    assignmentReason = categoryMismatch ? "category_subcategory_mismatch" : "unknown_or_unapproved_category";
  } else {
    const location = point([longitude, latitude]);
    const boundaryFeatures = isPolice ? policeJurisdictions.features : bmcWards.features;
    const containing = boundaryFeatures.filter((feature) =>
      booleanPointInPolygon(location, feature)
    );
    if (containing.length === 0) {
      assignmentReason = isPolice ? "outside_police_boundaries" : "outside_bmc_ward_boundaries";
    } else if (containing.length > 1) {
      assignmentReason = isPolice ? "ambiguous_police_boundaries" : "ambiguous_bmc_ward_boundaries";
    } else {
      const boundary = containing[0];
      jurisdiction = isPolice ? boundary.properties.name : boundary.properties.NAME;
      // The available 24-ward BMC layer predates the K-North split. Its K/E
      // polygon still covers K-North, so never assign those points to K/E.
      if (!isPolice && jurisdiction === "K/E") {
        assignmentReason = "bmc_k_north_boundary_missing";
      } else {
        let authorities: Array<{ id: string }> | null = null;
        let authorityError: { message: string } | null = null;
        if (isPolice) {
          // Police personnel may have ranks such as Constable or Inspector;
          // the rank is not a routing eligibility flag.
          const exactMatch = await db.from("authorities").select("id")
            .ilike("department", "%police%")
            .ilike("jurisdiction", jurisdiction)
            .not("auth_user_id", "is", null)
            .limit(2);
          authorities = exactMatch.data;
          authorityError = exactMatch.error;

          const fallbackJurisdiction = policeJurisdictionFallbacks[jurisdiction];
          if (!authorityError && !authorities?.length && fallbackJurisdiction) {
            const fallbackMatch = await db.from("authorities").select("id")
              .ilike("department", "%police%")
              .ilike("jurisdiction", fallbackJurisdiction)
              .not("auth_user_id", "is", null)
              .limit(2);
            authorities = fallbackMatch.data;
            authorityError = fallbackMatch.error;
          }
        } else {
          const bmcMatch = await db.from("authorities").select("id")
            .or("department.ilike.%bmc%,department.ilike.%municipal%")
            .ilike("role", "%ward officer%")
            .ilike("ward_code", jurisdiction)
            .not("auth_user_id", "is", null)
            .limit(2);
          authorities = bmcMatch.data;
          authorityError = bmcMatch.error;

          const fallbackJurisdiction = bmcJurisdictionFallbacks[jurisdiction];
          if (!authorityError && !authorities?.length && fallbackJurisdiction) {
            const fallbackMatch = await db.from("authorities").select("id")
              .or("department.ilike.%bmc%,department.ilike.%municipal%")
              .ilike("role", "%ward officer%")
              .ilike("jurisdiction", fallbackJurisdiction)
              .not("auth_user_id", "is", null)
              .limit(2);
            authorities = fallbackMatch.data;
            authorityError = fallbackMatch.error;
          }
        }
        if (authorityError) return response({ error: "Could not resolve responsible authority" }, 500);
        if (authorities?.length === 1) {
          assignedAuthorityId = authorities[0].id;
          assignmentStatus = "assigned";
        } else {
          assignmentReason = authorities?.length ? "multiple_matching_authorities" : "no_matching_authority";
        }
      }
    }
  }

  const payload = {
    id: typeof input.id === "string" ? input.id : undefined,
    citizen_id: citizen.id,
    title,
    description,
    category,
    latitude: hasCoordinates ? latitude : null,
    longitude: hasCoordinates ? longitude : null,
    address: typeof input.address === "string" ? input.address : null,
    image_url: typeof input.image_url === "string" ? input.image_url : null,
    status: "pending",
    department,
    jurisdiction,
    assigned_authority_id: assignedAuthorityId,
    assignment_status: assignmentStatus,
    assignment_reason: assignmentReason,
  };
  // Use the service-role client to write the routed record directly. This
  // avoids relying on a separately cached PostgREST RPC definition, which can
  // fail even when the complaints table itself is present.
  const { data: complaint, error: insertError } = await db.from("complaints")
    .insert(payload)
    .select("id,department,jurisdiction,assigned_authority_id,assignment_status,assignment_reason")
    .single();
  if (insertError) {
    console.error("Complaint insert failed:", insertError);
    return response({ error: "Complaint could not be saved", details: insertError.message }, 500);
  }

  const { error: logError } = await db.from("complaint_logs").insert({
    complaint_id: complaint.id,
    authority_id: assignedAuthorityId,
    action: assignmentStatus === "assigned" ? "automatic_assignment" : "assignment_manual_review",
    message: assignmentReason ?? `Assigned to ${jurisdiction}`,
  });
  if (logError) console.error("Complaint was saved but its routing log failed:", logError);

  return response({ complaint });
});
