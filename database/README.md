Purpose: Contains database-related files and setup instructions.

Files: 
schema.sql
sample_data.sql
supabase_setup.md

## Automatic complaint routing

Apply `006_complaint_location_routing.sql` after the existing schema. The
deployed project must contain `citizens.auth_user_id` and
`authorities.auth_user_id`; both are referenced by the current app but are not
declared in `000_schema.sql`. The migration adds complaint assignment metadata,
authority-scoped complaint read/update policies, and an atomic complaint plus
audit-log RPC. Review the effective deployed RLS policies before applying it,
since this repository does not include the complete production schema.

Deploy the `submit-complaint` Supabase Edge Function after applying the
migration. It authenticates the caller, resolves the caller's citizen record,
and writes through the service role on the server. Configure the service role
key only in Supabase's server-side function environment. Citizen submissions
must use this function; direct client inserts do not perform routing.

The function matches each approved subcategory against its parent category
before determining the department. Unlisted subcategories, including `Other`,
are not automatically routed. Both boundary files use WGS84 with coordinate
order `[longitude, latitude]`; boundary points count as contained. Police
subcategories are Open Manholes, Non-Existent Footpath, Women Safety, Illegal
Parking, Theft / Robbery, Harassment / Eve-Teasing, Assault / Violence, Poor
Street Lighting, Fire Hazard, Electrical Hazard, Exposed Wires, Child Safety
Concern, Stray Animal Threat, and Missing Person. They route against the 91
polygons in `geo/mumbai_police_jurisdictions.geojson` and require exactly one
Police record with a linked `auth_user_id`. Police ranks such as Constable and
Inspector are stored in `role`, so the router does not require the literal role
`Authority`. The roster's broad Andheri and Bandra names are matched using
explicit aliases for Andheri Police Station, MIDC Police Station, and Bandra
Police Station. Other station names need an authority record with that exact
jurisdiction and remain in manual review when none exists.

Greenery subcategories are Waste Dumping in Green Area, Poor Landscape
Maintenance, Watering Required for Plants, Encroachment on Green Spaces, Pest
or Insect Infestation, Overgrown Vegetation, Need Tree Plantation, Illegal Tree
Cutting, and Public Problems on Greenery. Infrastructure subcategories are
Nonfunctional Street Lights, Potholes, Water Logging, Prolonged Road Work, and
Drainage. Sanitation subcategories are Garbage Scattered on the Road, Public
Washrooms Not Clean, Garbage at Beach/River, and Untimely Garbage
Collection/Overflowing. They route against the BMC ward polygons in
`geo/mumbai_bmc_wards.geojson` and require exactly one BMC authority (`role =
Ward Officer`) with a linked `auth_user_id` whose `ward_code` matches the
polygon's `NAME`. K/W also matches the existing Andheri Ward Officer record,
which has `jurisdiction = Andheri` and no `ward_code`. No Bandra BMC Ward
Officer record currently exists, so H/E and H/W complaints remain in manual
review until matching ward records are provisioned. Pending `verification_status`
values are present in the current dummy roster; the application does not
currently define or enforce verification-status semantics, so routing leaves
those values unchanged and requires the account to be linked for dashboard
visibility.

Missing Person reports require a non-empty description, a stored HTTPS image
URL, and valid coordinates; their status is saved as `pending`. Flutter uploads
attached photos to the existing `complaint_images` Supabase Storage bucket
before submitting. That bucket must exist and allow citizen uploads. The web
dashboard displays its public image URL like other complaint evidence. Invalid
or incomplete missing-person submissions are rejected. Other unresolved
category/location/authority cases remain `manual_review`.

For example, the same Andheri coordinate can resolve to the Andheri Police
Station polygon for a police subcategory and to K/East or K/West for a BMC
subcategory, depending on which BMC ward polygon contains that coordinate.
“Andheri” is an area, not one universal jurisdiction name across both
departments. Outside, overlapping, missing/invalid-coordinate, and
unmatched-authority cases are saved as `manual_review` with a reason.

The KML contains 182 named placemarks/aliases but 91 polygon geometries; each
polygon coordinate ring matches one GeoJSON outer ring. GeoJSON `name` is the
routing key because KML names include aliases and repeats.

### BMC ward data provenance

The bundled BMC layer was retrieved from the official
[MCGM GIS Wards service, layer 238](https://prsrvgisapp.mcgm.gov.in/server/rest/services/mcgm/MCGMGIS_Departments_Master_All_Layers/MapServer/238).
It has 24 polygons, WGS84 coordinates, and ward codes in `NAME` (for example
`K/E` and `K/W`). However, BMC's 2026 Civic Diary lists a separate K-North ward,
while this GIS layer has no K/N polygon. The function therefore holds all
points landing in the layer's K/E polygon for manual review rather than risk
assigning K-North complaints to K/E. Other BMC points route only when their
polygon code has exactly one matching `Ward Officer` record, with the explicit
K/W to Andheri-jurisdiction fallback described above. Do not infer ward codes
from police station names.

The [BMC Civic Diary 2026](https://portal.mcgm.gov.in/irj/go/km/docs/documents/HomePage%20Data/BMC%20Diary/BMC_English%20Diary_2026.pdf)
lists K-East, K-West, and K-North ward offices; the included GIS layer must be
refreshed before those Andheri/Jogeshwari areas can all be assigned
automatically.

The [final 2025 BMC prabhag map](https://portal.mcgm.gov.in/irj/go/km/docs/documents/MCGM%20Department%20List/Assessment%20And%20Collection%20%28Election%29/Docs/Election%20Department/BMC%20General%20Election%202025/Ward%20Formation/Final/Final%20Prabhag%20Maps%202025/BMC%20All%20Final%20Prabhag%20in%20One%20Map_2025.pdf)
is an official map, not a machine-readable administrative K-North polygon. To
enable K-North routing, obtain from MCGM the current K-North boundary geometry
and revised K-East geometry in a geospatial format, with the authority-approved
ward-code crosswalk. Do not derive the boundary from the PDF or guess it from
addresses.

The official BMC ward-office list distinguishes K/East and K/West, and the
official K/East map includes Andheri localities. Check the
[BMC ward-office list](https://portal.mcgm.gov.in/irj/portal/anonymous?NavigationTarget=navurl%3A%2F%2F7ac4ae5411dc6459e978dfac972f988c)
and [K/East ward map](https://dm.mcgm.gov.in/assets/pdf/All%20Maps/KE.pdf)
when reviewing the authority ward-code roster. Obtain updated K/East and
K-North boundary polygons from MCGM before enabling automatic routing for those
areas.

Suggested routing spot-checks (coordinates are longitude, latitude):

| Point `[longitude, latitude]` | Police polygon | BMC ward |
| --- | --- |
| `[72.861119, 19.106124]` (Andheri East) | Andheri Police Station | K/E (held for review) |
| `[72.846, 19.119]` (Andheri West) | DN Nagar Police Station | K/W |
| `[72.823, 19.054]` (Bandra West) | Bandra Police Station | H/W |
| `[72.846, 19.059]` (Bandra East) | Nirmalnagar Police Station | H/E |
| `[0, 0]` | Outside | Outside |

These sample points are used for routing spot-checks against the supplied
polygon rings and current authority roster. They do not replace full live
submission testing.
Safety subcategories unknown to the routing rules, including `Illegal parking`
and custom `Other` text, remain in manual review. A known safety subcategory
sent with a different parent category is also held for review.
