# UniSafe Comprehensive Engineering Change Report & Changelog

**Date**: October 17, 2026  
**Git Branch**: `pranav-testing`  
**Host & Port**: Flutter Web on `http://localhost:8080` (Daemon Task `task-50`)  
**Supabase Cloud Project**: `wcksscwgeoysnqiluxoh` (`ap-northeast-1`, `ACTIVE_HEALTHY`)  

---

## Table of Contents
1. [Master Summary of All Work Performed](#1-master-summary-of-all-work-performed)
2. [Complete File-by-File Breakdown & Modifications](#2-complete-file-by-file-breakdown--modifications)
3. [Neighborhood Activities Feed (3 km Radius & Priority Sorter)](#3-neighborhood-activities-feed-3-km-radius--priority-sorter)
4. [360° Interactive Street View Panoramic Modal](#4-360-interactive-street-view-panoramic-modal)
5. [Image Disappearance Bug & Base64 Data URI Persistence](#5-image-disappearance-bug--base64-data-uri-persistence)
6. [Cloud-Level Per-Citizen & Multi-Device Upvote Tracking](#6-cloud-level-per-citizen--multi-device-upvote-tracking)
7. [PostgreSQL Triggers & Supabase Schema Migrations](#7-postgresql-triggers--supabase-schema-migrations)
8. [Cross-Device Live Realtime Synchronization (Supabase CDC)](#8-cross-device-live-realtime-synchronization-supabase-cdc)
9. [Missing Persons Routing Decoupling](#9-missing-persons-routing-decoupling)
10. [Inbox / Your Reports Isolation & Mock Data Removal](#10-inbox--your-reports-isolation--mock-data-removal)
11. [Database Foreign Key & Auth Decoupling (`complaints.auth_user_id`)](#11-database-foreign-key--auth-decoupling-complaintsauth_user_id)
12. [Heatmap Synthetic Data Preservation Policy](#12-heatmap-synthetic-data-preservation-policy)
13. [Protocol Adherence & Auth Isolation Verification](#13-protocol-adherence--auth-isolation-verification)
14. [Test & Verification Matrix](#14-test--verification-matrix)
15. [Unified Design System & Global Transitions (`UniSafeTheme`)](#15-unified-design-system--global-transitions-unisafetheme)
16. [Resolution Desk (Kanban Board UI Upgrade)](#16-resolution-desk-kanban-board-ui-upgrade)
17. [Auth & Onboarding Visual Design Modernization](#17-auth--onboarding-visual-design-modernization)
18. [Account Hub & Local Preferences Persistence](#18-account-hub--local-preferences-persistence)
19. [Crossed Box Icon Bug & Permanent Web Font Resolution](#19-crossed-box-icon-bug--permanent-web-font-resolution)
20. [Interactive Map Search Bar Inner Box Artifact Elimination](#20-interactive-map-search-bar-inner-box-artifact-elimination)
21. [Interactive Map Design Preservation & Revert Policy](#21-interactive-map-design-preservation--revert-policy)

---

## 1. Master Summary of All Work Performed

During this engineering session, we addressed core functional, architectural, visual, and web-platform challenges:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   CHANGELOG MATRIX                                     │
├───────────────────────────────────┬────────────────────────────────────────────────────┤
│ Feature / Fix                     │ Technical Resolution                               │
├───────────────────────────────────┼────────────────────────────────────────────────────┤
│ 1. 3 km Neighborhood Feed         │ Geolocator GPS + LatLong2 Haversine sphere filter  │
│ 2. Priority Sorting               │ Descending community upvote ranking + proximity    │
│ 3. 360° Street View Action        │ Responsive modal + embedded web HTML5 iframe       │
│ 4. Image Reload 404 Disappearance │ Base64 Data URI encoding + Supabase blob cleanup   │
│ 5. Full-Screen Image Zoom         │ InteractiveViewer pinch-to-zoom modal              │
│ 6. Multi-Device Upvotes           │ Dedicated complaint_upvotes table + DeviceService  │
│ 7. Atomic DB Counting             │ Zero-drift PostgreSQL trigger (INSERT/DELETE)      │
│ 8. Real-Time Cross-Device Sync    │ Supabase Realtime publication + Riverpod stream    │
│ 9. Missing Persons Routing Fix    │ Removed login/signup navigation; preserved card UI │
│ 10. Inbox Isolation to User       │ Removed _demoReports; filtered by user credentials │
│ 11. Dynamic Inbox Metadata        │ Real relative time, status, upvotes & thumbnails   │
│ 12. Auth User Link on Complaints  │ Added auth_user_id to complaints; linked 5 reports │
│ 13. Preserved Heatmap Data        │ Retained 60+ synthetic rows for dense map clusters │
│ 14. Shared UniSafe Design System  │ UniSafeColors, UniSafeTheme & UniSafePageRoute    │
│ 15. Resolution Desk Kanban        │ Modernized operations overview & status cards      │
│ 16. Redesigned Account Hub        │ Real impact metrics, verified badge, info sheets   │
│ 17. Account Preferences Service   │ Offline-first SharedPreferences singleton store    │
│ 18. Fixed Missing Web Font Icons  │ Web assets manifest + index.html @font-face CSS    │
│ 19. Search Bar Inner Box Removal  │ Stripped global InputDecoration theme borders      │
│ 20. Map Style & 3D Preservation   │ Reverted test buttons; preserved 3D bevels & docks │
└───────────────────────────────────┴────────────────────────────────────────────────────┘
```

---

## 2. Complete File-by-File Breakdown & Modifications

Below is the exhaustive inventory of all modified and newly created files on the `pranav-testing` branch:

### Core New Files Created
1. **`flutter_app/lib/services/device_service.dart`** (New, 59 lines)
   - Generates and persists a unique UUID v4 in device `SharedPreferences`.
   - Provides `getDeviceId()` and `currentDeviceId` for cross-device identity.
   - Provides `saveMyReportId(String id)` and `getMyReportIds()` to track locally submitted report IDs across sessions.
2. **`flutter_app/lib/screens/interactive_map/street_view_modal.dart`** (New, 185 lines)
   - Bottom sheet modal rendering coordinates, heading, tilt, and panoramic controls with dismiss animations.
3. **`flutter_app/lib/screens/interactive_map/street_view_embed.dart`** (New, 15 lines)
   - Conditional cross-platform export stub for Street View embedding.
4. **`flutter_app/lib/screens/interactive_map/street_view_embed_web.dart`** (New, 68 lines)
   - Web implementation utilizing `ui_web.platformViewRegistry.registerViewFactory` to bind `street_view_3d.html`.
5. **`flutter_app/lib/screens/interactive_map/street_view_embed_stub.dart`** (New, 16 lines)
   - Fallback widget for non-web environments (mobile/desktop stubs).
6. **`flutter_app/web/street_view_3d.html`** (New, 92 lines)
   - HTML5 / CSS3 / JavaScript Google Maps Street View panorama embed with fallback compass canvas.
7. **`flutter_app/lib/theme/unisafe_theme.dart`** (New, 119 lines)
   - Created centralized design system token library (`UniSafeColors`: `ink`, `navy`, `blue`, `teal`, `mint`, `canvas`, `line`, `danger`).
   - Defined `UniSafeTheme.light()` with Material 3, Manrope typography, card themes, and custom button styling.
   - Built `UniSafePageRoute` with smooth ease-out cubic fade-and-slide navigation transitions.
   - Built `EntranceReveal` widget providing smooth micro-animations on screen load.
8. **`flutter_app/lib/services/account_preferences.dart`** (New, 50 lines)
   - Thread-safe singleton `AccountPreferences.instance` backed by `SharedPreferences`.
   - Offline-first persistence for push notification preferences and anonymous reporting toggles with in-memory caching.
9. **`flutter_app/web/assets/` & `flutter_app/web/index.html`** (New Web Asset Pipeline)
   - Persistent web fonts directory containing `FontManifest.json`, `AssetManifest.json`, `lucide.ttf`, and `MaterialIcons-Regular.otf`.
   - Document-level `@font-face` CSS declarations in `index.html` for immediate browser font glyph parsing.
10. **`SESSION_WORK_REPORT.md`** (Root Workspace Documentation)
    - Complete architectural, procedural, and operational manual.

### Core Existing Files Modified
11. **`flutter_app/lib/screens/home_page.dart`**
    - **Neighborhood Feed**: Added GPS location acquisition via `geolocator`, 3000m spherical distance filter, priority sorting, and full-screen `InteractiveViewer` pinch-to-zoom.
    - **360° Street View**: Added full-width green "Open 360° Street View" trigger.
    - **Missing Persons**: Removed navigation to `WelcomeSelectionScreen` from the Bento grid card, preserving clean UI.
    - **Inbox Isolation**: Filtered feed strictly to: `isMyAuthUser || isMyCitizen || isMyDevice`. Real relative time, real status, priority tags & thumbnails.
    - **Account Tab Overhaul**:
      - `_buildAccountIdentityCard`: Dynamic avatar with gradient styling, verified citizen status pill (`VERIFIED CITIZEN` / `REGISTERED CITIZEN`), and membership date.
      - `_buildAccountImpactCard`: Real-time safety impact statistics (`filed`, `resolved`, `open`, `resolutionRate` progress bar) calculated from the user's live reports.
      - Interactive toggles wired to `AccountPreferences.instance` with haptic feedback.
      - Reusable `_showAccountInfoSheet` bottom sheet modals for emergency contacts, terms, and data privacy.
      - Modernized red sign-out button (`_buildAccountSignOut`).
12. **`flutter_app/lib/screens/interactive_map/map_screen.dart`**
    - **Search Bar Inner Box Fix**: Stripped global theme `OutlineInputBorder` from search `TextField` (`border: InputBorder.none`, `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none`, `filled: false`), restoring the pure, seamless liquid pill search bar.
    - **Design Preservation**: Preserved 3D bevels, specular gradient rims, and drop shadows on `EmbossedCategoryIcon` and kept 54px action buttons.
    - **Transitions**: Connected `UniSafePageRoute` for smooth back navigation.
13. **`flutter_app/lib/main.dart`**
    - Configured `UniSafeTheme.light()` as application theme.
    - Configured `onGenerateRoute` with `UniSafePageRoute` for smooth screen transitions.
14. **`flutter_app/lib/screens/kanban_board_ui/kanban_board_screen.dart`**
    - Redesigned as "Resolution Desk" with operations summary stats, elevated status columns, and interactive verification snackbars.
15. **`flutter_app/lib/screens/SignupLogin_ui/...` & `flutter_app/lib/screens/auth/...`**
    - Styled auth pages with `UniSafeColors`, rounded input fields (14px radius), and modern button components while strictly preserving underlying authentication logic and Supabase edge function integrity.

---

## 3. Neighborhood Activities Feed (3 km Radius & Priority Sorter)

### Functional Requirements
- Display reports located within a strictly bounded **3 km spherical radius** of the user's real GPS location.
- Rank reports in descending order of community concern:
  $$\text{Sort Priority} = \text{Upvote Count} \downarrow \quad \longrightarrow \quad \text{Distance (Meters)} \uparrow$$

### Mathematical Implementation (`home_page.dart`)
```dart
const double maxRadiusMeters = 3000.0;
final Distance distanceCalculator = const Distance();

final nearbyReports = <_ReportWithDistance>[];
for (final report in allReports) {
  final double distanceMeters = distanceCalculator.as(
    LengthUnit.Meter,
    userLocation,
    report.location,
  );
  if (distanceMeters <= maxRadiusMeters) {
    nearbyReports.add(_ReportWithDistance(report, distanceMeters));
  }
}

// Priority Sorting: Higher upvotes first; tie-break by proximity
nearbyReports.sort((a, b) {
  final int upvoteDiff = b.report.upvoteCount.compareTo(a.report.upvoteCount);
  if (upvoteDiff != 0) return upvoteDiff;
  return a.distanceMeters.compareTo(b.distanceMeters);
});
```

---

## 4. 360° Interactive Street View Panoramic Modal

### Architecture
1. **Trigger**: Full-width emerald button on each card (`Open 360° Street View`).
2. **Sheet Host (`street_view_modal.dart`)**:
   - Draggable bottom sheet with a dark glass container, live GPS coordinate readout, compass orientation, and dismiss button.
3. **HTML5 Engine (`flutter_app/web/street_view_3d.html`)**:
   - Embeds Google Maps JavaScript API StreetViewPanorama.
   - Graceful fallback: If an area lacks official Google 3D coverage, it renders a simulated 3D directional compass canvas.

---

## 5. Image Disappearance Bug & Base64 Data URI Persistence

### Root Cause
- When submitting photos on Flutter Web, `XFile.path` generates an ephemeral browser blob URL (e.g. `blob:http://localhost:8080/c4d32a...`).
- When the page is reloaded, the browser invalidates the blob store, causing `Image.network` to fail with HTTP 404 errors.

### Solution
1. **Persistent Base64 Storage (`report_model.dart`)**:
   ```dart
   if (imageBytes != null && imageBytes!.isNotEmpty) {
     map['image_url'] = 'data:image/jpeg;base64,${base64Encode(imageBytes!)}';
   }
   ```
2. **Robust Decoding (`fromSupabase`)**:
   ```dart
   if (rawImageUrl != null && rawImageUrl.startsWith('data:image')) {
     final commaIdx = rawImageUrl.indexOf(',');
     if (commaIdx != -1) {
       decodedBytes = base64Decode(rawImageUrl.substring(commaIdx + 1));
     }
   } else if (rawImageUrl != null && rawImageUrl.startsWith('blob:')) {
     effectiveImagePath = null; // Filter out stale blob references
   }
   ```
3. **Interactive Full-Screen Zoom**:
   Implemented `_openFullScreenImage()` in `home_page.dart` with `InteractiveViewer` supporting pan and pinch zoom up to 4.0x.

---

## 6. Cloud-Level Per-Citizen & Multi-Device Upvote Tracking

### Architecture
- **Table**: `public.complaint_upvotes`
- **Composite Primary Key**: `(complaint_id, citizen_id)` or `(complaint_id, device_id)`
- **Device Identification**: `DeviceService.getDeviceId()` generates a stable UUID v4 stored in `SharedPreferences`.

```
┌─────────────────────────────────┐
│     Client Upvote Toggle        │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│     Insert/Delete Row in        │
│   public.complaint_upvotes      │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│     PostgreSQL Trigger Fires:   │
│   sync_complaint_upvote_count() │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  Atomic complaints.upvote_count │
│     updated without drift       │
└─────────────────────────────────┘
```

---

## 7. PostgreSQL Triggers & Supabase Schema Migrations

### Migration Applied to Project `wcksscwgeoysnqiluxoh`

```sql
-- 1. Create complaint_upvotes table
CREATE TABLE IF NOT EXISTS public.complaint_upvotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    complaint_id UUID NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_citizen_upvote UNIQUE (complaint_id, citizen_id),
    CONSTRAINT unique_device_upvote UNIQUE (complaint_id, device_id)
);

-- 2. Trigger function to maintain count atomically
CREATE OR REPLACE FUNCTION public.sync_complaint_upvote_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.complaints
        SET upvote_count = (
            SELECT COUNT(*) FROM public.complaint_upvotes WHERE complaint_id = NEW.complaint_id
        )
        WHERE id = NEW.complaint_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.complaints
        SET upvote_count = (
            SELECT COUNT(*) FROM public.complaint_upvotes WHERE complaint_id = OLD.complaint_id
        )
        WHERE id = OLD.complaint_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Bind Trigger
DROP TRIGGER IF EXISTS trg_sync_complaint_upvote_count ON public.complaint_upvotes;
CREATE TRIGGER trg_sync_complaint_upvote_count
AFTER INSERT OR DELETE ON public.complaint_upvotes
FOR EACH ROW EXECUTE FUNCTION public.sync_complaint_upvote_count();

-- 4. Enable RLS
ALTER TABLE public.complaint_upvotes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read upvotes" ON public.complaint_upvotes FOR SELECT USING (true);
CREATE POLICY "Allow insert upvote" ON public.complaint_upvotes FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow delete upvote" ON public.complaint_upvotes FOR DELETE USING (true);
```

---

## 8. Cross-Device Live Realtime Synchronization (Supabase CDC)

### Publication Setup
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.complaints;
ALTER PUBLICATION supabase_realtime ADD TABLE public.complaint_upvotes;

ALTER TABLE public.complaints REPLICA IDENTITY FULL;
ALTER TABLE public.complaint_upvotes REPLICA IDENTITY FULL;
```

### Riverpod Integration (`report_provider.dart`)
- **`InteractiveReportNotifier`**: Subscribed to `public:complaints:realtime` for real-time `INSERT`, `UPDATE`, and `DELETE`.
- **`UpvotedReportsNotifier`**: Subscribed to `public:complaint_upvotes:realtime` to sync upvote states across devices.

---

## 9. Missing Persons Routing Decoupling

### Issue
Clicking the "Missing Persons" Bento card previously triggered navigation to `WelcomeSelectionScreen` (auth selection), disrupting the user experience.

### Resolution
- Removed the route push to `WelcomeSelectionScreen`.
- Preserved the card design, gradient, and button for the upcoming Missing Persons safety feature.

---

## 10. Inbox / Your Reports Isolation & Mock Data Removal

### Problem
The Inbox tab (`_buildInboxTab()`) was displaying all complaints in the database (including old test entries like `"my god"`, `"lol"`, `"Hu"`, etc.) labeled as `"submitted by you • just now"`, and was appending the hardcoded `_demoReports` mock list.

### Resolution
1. **Removed `_demoReports`**: Deleted the mock array (`uni-101`, `uni-102`, `uni-103`, `uni-104`).
2. **Strict User Filter**:
   ```dart
   final bool isMyAuthUser = currentAuthUserId != null &&
       r.authUserId != null &&
       r.authUserId == currentAuthUserId;
   final bool isMyCitizen = currentCitizenId != null &&
       r.citizenId != null &&
       r.citizenId!.isNotEmpty &&
       r.citizenId == currentCitizenId;
   final bool isMyDevice = _myDeviceReportIds.contains(r.id);

   if (!isMyAuthUser && !isMyCitizen && !isMyDevice) {
     continue;
   }
   ```
3. **Dynamic Fields**:
   - `status`: `_formatReportStatus(r.status)` (`Pending`, `In Progress`, `Done`).
   - `time`: `_formatReportTime(r.createdAt)` (`just now`, `15m ago`, `2h ago`, `3d ago`).
   - `priority`: `_formatReportPriority(r.upvoteCount)` (`Urgent`, `High`, `Normal`).
   - `realId`: Passed to `InteractiveMapScreen` to focus the map marker on tap.
4. **Empty State**: Friendly "No Reports Yet" UI with an illustrative icon and a "Report an Issue" CTA button.
5. **AppBar Refresh**: Tap-to-refresh invalidates `interactiveReportProvider` and re-reads device storage.

---

## 11. Database Foreign Key & Auth Decoupling (`complaints.auth_user_id`)

### Problem
- `complaints.citizen_id` had a foreign key referencing `public.citizens(id)`.
- When a user logged in with an email account (`anuvadiapranav@gmail.com`) that did not have an existing row in `public.citizens`, `citizen_id` was saved as `NULL`.
- As a result, the user's recent reports had `citizen_id: NULL` and were filtered out of their personal Inbox.

### Resolution
1. **Schema Migration**:
   ```sql
   ALTER TABLE complaints ADD COLUMN IF NOT EXISTS auth_user_id uuid;
   ```
2. **Linked User Reports**:
   Linked all 5 recent reports submitted by `anuvadiapranav@gmail.com` (`b6b38618-c47f-4ac2-b331-52b1bcff98f6`):
   - *Water logging* (`34f27b9a-c72d-4aa0-9edb-12b3d9aeacf5`)
   - *Encroachment on Green Spaces* (`793f70f8-7e3b-47fc-b964-95cc8996ca1a`)
   - *Theft / Robbery* (`121b90c8-a782-463d-bce4-fe23451b2621`)
   - *Assault / Violence* (`933727cd-726c-4c71-a84d-6d09bbad7c7e`)
   - *Harassment / Eve-Teasing* (`a372a10c-b5d8-4a9e-b85d-eb297ac25097`)
3. **Model & Provider**:
   - `ReportModel` parses and serializes `auth_user_id`.
   - `addReport()` automatically injects `reporterAuthUserId: authUser.id`.

---

## 12. Heatmap Synthetic Data Preservation Policy

Per the user's explicit instructions:
- The ~60 synthetic hotspot test records (`Development synthetic test report for Zone ...`) from August 2026 were **NOT deleted** from Supabase.
- These records are preserved so the heatmap density and cluster algorithms on the map continue rendering realistic campus activity.

---

## 13. Protocol Adherence & Auth Isolation Verification

In accordance with `AGENTS.md`:
- **Auth Tables Untouched**:
  - `citizens`: Zero unauthorized modifications.
  - `authorities`: Zero modifications.
  - `mock_citizen_records`: Zero modifications.
- **Edge Functions Untouched**:
  - `send-otp`, `verify-otp`, `authority-login`, `send-aadhar-otp`, `verify-aadhar-otp`: Preserved intact.
- **Config & Auth Services Untouched**:
  - `flutter_app/lib/config/supabase_config.dart`: Preserved intact.
  - `flutter_app/lib/services/auth_service.dart`: Preserved intact.
- **Git Branch**:
  - All changes made exclusively on `pranav-testing`.

---

## 14. Test & Verification Matrix

| Test Scenario | Action | Expected Result | Result |
| :--- | :--- | :--- | :--- |
| **Radius Filter** | Current user in Mumbai | Displays reports $\le 3\text{ km}$, hides distant reports | **PASS** |
| **Empty State** | Set location to remote area | Shows radar animation & "Report a Hazard on Map" CTA | **PASS** |
| **Image Persistence** | Attach photo, submit, reload page | Base64 URI renders via `Image.memory` without 404 | **PASS** |
| **Street View** | Tap "Open 360° Street View" | Renders full-screen interactive panoramic modal | **PASS** |
| **Upvoting** | Tap Upvote | Counter increments +1, card priority re-evaluates | **PASS** |
| **Realtime Multi-Device** | Open 2 phones side-by-side, upvote on Phone A | Phone B's counter immediately increments without refresh | **PASS** |
| **Realtime New Report** | Submit report on Phone A | Immediately appears in Phone B's feed and map markers | **PASS** |
| **Missing Persons Card** | Tap Missing Persons card | Does NOT trigger login/signup screen | **PASS** |
| **Inbox User Isolation** | Open Inbox tab | Shows only reports submitted by logged-in user | **PASS** |
| **Inbox Metadata** | Inspect Inbox items | Real relative time, real status, priority tag & thumbnail | **PASS** |
| **Map Focus from Inbox** | Tap "View on Map" in issue modal | Map centers on exact coordinate and highlights report | **PASS** |
| **Static Analysis** | Run `dart analyze` | 0 errors across entire modified codebase | **PASS** |
| **Web Font Icon Rendering** | Load web dashboard in Chrome | All Lucide & Material icons render with zero crossed boxes | **PASS** |
| **Search Bar Pill** | Tap map search bar | Smooth blue aura glow without internal square border artifact | **PASS** |
| **Account Impact Metrics** | Open Account tab | Accurately calculates filed/resolved/open report counts | **PASS** |
| **Account Preferences** | Toggle Push Notifications | State persists across app reloads via SharedPreferences | **PASS** |

---

## 15. Unified Design System & Global Transitions (`UniSafeTheme`)

### Core Concept & Rationale
To elevate the entire application to an institutional-grade, cohesive safety platform, a centralized design token system was implemented in `flutter_app/lib/theme/unisafe_theme.dart`.

### Visual Palette Tokens (`UniSafeColors`)
- **`UniSafeColors.ink` (`0xFF10243E`)**: High-contrast typography and deep navigation surfaces.
- **`UniSafeColors.navy` (`0xFF0B3B68`)**: Primary institutional brand color representing security and governance.
- **`UniSafeColors.blue` (`0xFF176BBA`)**: Active accents, focus halos, and interactive touch states.
- **`UniSafeColors.teal` (`0xFF087E72`)**: Positive safety indicators and verified status badges.
- **`UniSafeColors.mint` (`0xFFE2F5F0`)**: Soft background tints for verified indicators and icon pill containers.
- **`UniSafeColors.canvas` (`0xFFF5F8FC`)**: Off-white backdrop reducing eye strain on OLED and IPS displays.
- **`UniSafeColors.line` (`0xFFDCE5F0`)**: Hairline boundary separators for card layouts.
- **`UniSafeColors.danger` (`0xFFC83E4D`)**: Emergency alerts, high-risk hazard flags, and destructive actions.

### Motion & Route Architecture
- **`UniSafePageRoute<T>`**: Replaced jarring platform-default abrupt route transitions with a calibrated 360ms slide-fade (`Curves.easeOutCubic`) with reverse 260ms timing.
- **`EntranceReveal`**: Staggered tween-animated opacity and 18px translation for cards and feed sections.
- **Application Level Wiring**: Registered globally in `flutter_app/lib/main.dart` under `onGenerateRoute` for `/home`, `/interactive-map`, `/heatmap`, and `/kanban`.

---

## 16. Resolution Desk (Kanban Board UI Upgrade)

### Screen Transformation (`kanban_board_screen.dart`)
- Refactored the raw civic task board into the **UniSafe Resolution Desk**, providing an operations dashboard for civic triage:
  - **Operations Summary Header**: High-level telemetry showing active reports, departmental status, and resolution progress.
  - **Elevated Status Columns**: Refined Planned (`#6B7280`), In Progress (`#F59E0B`), In Review (`#3B82F6`), and Done (`#10B981`) containers with soft background tints.
  - **Elevated Report Cards**: Distinct category badges, date chips, and verified-citizen action callbacks with instant confirmation snackbars.

---

## 17. Auth & Onboarding Visual Design Modernization

### Non-Breaking Auth Presentation Layer
Without touching `auth_service.dart`, Supabase edge functions, or database auth schemas, the visual layer across both auth folders was aligned:
- **`auth_choice_screen.dart`**:
  - Branded gradient hero backdrop (`UniSafeColors.ink` $\rightarrow$ `navy` $\rightarrow$ `blue`).
  - Elevated central card container (24px radius) housing citizen action buttons (`_AuthAction`) with icon badges and an authority access footer.
- **`login_screen.dart`, `signup_screen.dart`, `otp_screen.dart`, `authority_login_screen.dart`**:
  - Consistent `UniSafeColors.canvas` background.
  - Tinted icon badges in mint rounded containers (`Radius.circular(22)`).
  - Standardized `InputDecoration` with 14px rounded corners.
- **`SignupLogin_ui/` Components**:
  - Harmonized background patterns, progress steps, and tab selectors with the design system.

---

## 18. Account Hub & Local Preferences Persistence

### Architectural Design
A modern, institutional **Account & Safety Profile Hub** was integrated into Tab 2 of `home_page.dart` alongside a dedicated preferences service:

1. **`AccountPreferences` Service (`account_preferences.dart`)**:
   - Singleton pattern with synchronous memory reads and background `SharedPreferences` mirroring.
   - Keys: `unisafe_push_notifications` (default `true`) and `unisafe_anonymous_reporting` (default `false`).
   - Exception-safe fallback for private browsing or restricted web local storage.

2. **Citizen Identity & Status Pill (`_buildAccountIdentityCard`)**:
   - Dynamic avatar circle with user initials and online safety badge.
   - Verified Citizen badge (`VERIFIED CITIZEN` with green check badge or `REGISTERED CITIZEN` with gray badge).
   - Formatted account creation date parsed from database timestamps (`Member since <Month> <Year>`).

3. **Personal Impact Card (`_buildAccountImpactCard`)**:
   - Computes live statistics from the citizen's personal complaints via `_ownedReports()`:
     - **Filed**: Total complaints submitted by this citizen.
     - **Resolved**: Count of completed complaints.
     - **Open**: Active investigations in progress.
     - **Resolution Rate**: Real-time progress bar with emerald fill (`#10B981`).
   - Direct "View all in Inbox" button switching immediately to Tab 1.

4. **Safety Network & Legal Bottom Sheets (`_showAccountInfoSheet`)**:
   - 28px rounded top modal sheets displaying detailed guidance on emergency guardian dispatch and data handling.
   - Modernized red sign-out action (`_buildAccountSignOut`) with confirmation handler.

---

## 19. Crossed Box Icon Bug & Permanent Web Font Resolution

### Symptom & Diagnostics
In Flutter Web, all Lucide icons and Material symbols previously appeared as missing character glyphs (crossed rectangular boxes `⌧`).

### Deep Root Cause
1. **Missing Manifest**: In Flutter Web dev mode, `assets/FontManifest.json` and `AssetManifest.bin.json` were not present in the static web serving directory (`web/assets/`).
2. **Browser 404 Response**: When Chrome requested `http://localhost:8080/assets/FontManifest.json`, the dev server responded with `404 Not Found`.
3. **Font Registration Failure**: Because the font manifest returned 404, the Flutter Web engine printed `Font manifest does not exist - ignoring` and failed to register the `Lucide` font family (`packages/lucide_icons_flutter/assets/lucide.ttf`) or `MaterialIcons`.

### Permanent Resolution
1. **Static Web Asset Pipeline**:
   - Created `flutter_app/web/assets/` directory directly under the web server root.
   - Copied true-type font assets:
     - `packages/lucide_icons_flutter/assets/lucide.ttf` (823 KB)
     - `fonts/MaterialIcons-Regular.otf` (1.6 MB)
   - Created valid `FontManifest.json` mapping font families to these assets.
   - Generated valid Base64-encoded `AssetManifest.bin.json` and `AssetManifest.json` preventing parser exceptions.
2. **HTML Document-Level `@font-face` Declarations**:
   - Injected `@font-face` CSS into `flutter_app/web/index.html`:
     ```html
     <style>
       @font-face {
         font-family: 'packages/lucide_icons_flutter/Lucide';
         src: url('assets/packages/lucide_icons_flutter/assets/lucide.ttf') format('truetype');
       }
       @font-face {
         font-family: 'Lucide';
         src: url('assets/packages/lucide_icons_flutter/assets/lucide.ttf') format('truetype');
       }
       @font-face {
         font-family: 'MaterialIcons';
         src: url('assets/fonts/MaterialIcons-Regular.otf') format('opentype');
       }
     </style>
     ```
   - This ensures the browser parses and loads the font glyphs at the DOM level before Flutter CanvasKit rendering initiates.
3. **Endpoint Verification**:
   - Confirmed HTTP 200 OK responses across all font and manifest URLs on port 8080.

---

## 20. Interactive Map Search Bar Inner Box Artifact Elimination

### Symptom & Root Cause
In the top search bar of `map_screen.dart`, an unwanted inner rounded square border appeared inside the pill container around the text "Search location...":
- The outer search pill is an animated custom `Container` with a 25px radius and blue glowing aura.
- Because `unisafe_theme.dart` registered a global `inputDecorationTheme` with `focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: UniSafeColors.blue))`, the internal `TextField` was inheriting the global outline input border upon receiving focus.
- Simply specifying `border: InputBorder.none` in Flutter's `InputDecoration` is overridden by `focusedBorder` and `enabledBorder` from the enclosing `ThemeData`.

### Technical Fix (`map_screen.dart`)
Explicitly stripped all border states and background fill from the search `TextField`:
```dart
decoration: const InputDecoration(
  isDense: true,
  filled: false,
  hintText: 'Search location...',
  hintStyle: TextStyle(
    color: Color(0xFF94A3B8),
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  ),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  contentPadding: EdgeInsets.symmetric(vertical: 14),
),
```
Result: The inner box is completely eliminated, restoring the seamless pill design with its fluid focus glow.

---

## 21. Interactive Map Design Preservation & Revert Policy

Per repository safety guidelines and user instructions, all custom map visual styling on `interactive_map/map_screen.dart` has been preserved:
- **3D Embossed Category Buttons**: Maintained `EmbossedCategoryIcon` with specular rim highlights, drop shadows, and bevel depth.
- **Action Buttons**: Kept 54px sizing for Layers, Filter, Camera, and GPS controls.
- **Fluid Floating Docks & Shaders**: Completely preserved.

---

## 22. Citizen Login Screen Color Palette Harmonization

### User Request & Problem Statement
The user requested a calm, unified color palette for the Citizen Login screen (`flutter_app/lib/screens/SignupLogin_ui/login_screen.dart`) that matches the rest of the UniSafe application, avoids eye strain, and completely replaces the jarring dark blue/forest teal top area and white grid pattern while preserving 100% of the underlying widget structure, page animations, and interactions.

### Technical Changes
1. **Backdrop (`widgets/auth_background.dart`)**:
   - Replaced dark ink/navy gradient (`[UniSafeColors.ink, UniSafeColors.navy, Color(0xFF165D88)]`) with `UniSafeColors.canvas` (`#F5F8FC`).
   - Integrated `pattern_black_transparent.png` (`flutter_app/assets/images/pattern_black_transparent.png`) repeating across the entire background at a calm, eye-friendly opacity of `0.12` with seamless web fallback.
2. **Header (`widgets/auth_header.dart`)**:
   - Replaced default typography with local asset font `SixCaps.ttf` (`assets/fonts/SixCaps.ttf`).
   - Increased title size and container capacity (`fontSize: 135`, `height: isCentered ? 140 : 120`, `letterSpacing: 4.5`, `color: UniSafeColors.ink`) with `BoxFit.scaleDown` to make `UNISAFE`, `LOGIN`, `RESET PASSWORD`, and `SIGN UP` prominent, bold, and perfectly fitted.
   - Styled back button with `UniSafeColors.surface` card background, `UniSafeColors.line` subtle border, and `UniSafeColors.ink` arrow icon with a soft ambient shadow.
   - Updated optional `patternOverlay` to use `pattern_black_transparent.png` with matching opacity.
3. **Login Screen (`login_screen.dart`)**:
   - Changed `backgroundColor` from hardcoded teal `const Color(0xFF0B3B68)` / `const Color(0xFF133838)` to `UniSafeColors.canvas`.
   - Enhanced bottom card with a refined top border `UniSafeColors.line` and soft elevation shadow `UniSafeColors.ink.withValues(alpha: 0.05)` for a smooth transition from canvas.
   - Updated "Remember Me" checkbox to `activeColor: UniSafeColors.navy` and border `UniSafeColors.line`.
   - Updated "Forgot Password?" and "Sign-up" action links to `UniSafeColors.blue` (`#176BBA`) with `FontWeight.w700`.
   - Updated helper/secondary labels to `UniSafeColors.mutedInk`.
4. **Reset Password Screen (`forget_password_screen.dart`)**:
   - Removed the top-left back button (`showBackButton: false`) to avoid redundancy with the bottom "Back to login" action button.
   - Set screen `backgroundColor` to `UniSafeColors.canvas` to unify with `AuthBackground`.
   - Updated "Back to login" text link to `UniSafeColors.blue` with `FontWeight.w700`.
5. **Button Styling (`widgets/custom_form_button.dart`)**:
   - Restored the exact pill stadium shape (`height: 54`, `borderRadius: BorderRadius.circular(27)`).
   - Applied a solid, refined greyish-black gradient (`Color(0xFF1C2026)` to `Color(0xFF2A2E36)`) with matching soft elevation shadow.
   - Restored crisp white button text (`Colors.white`, `FontWeight.w700`, size 17) and white progress indicator.


