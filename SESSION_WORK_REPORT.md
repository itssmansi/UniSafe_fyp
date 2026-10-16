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

---

## 1. Master Summary of All Work Performed

During this engineering session, we addressed 8 core functional challenges and deployed an end-to-end community safety, reporting, and real-time civic synchronization system:

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
7. **`SESSION_WORK_REPORT.md`** (New, Root Workspace Documentation)
   - Complete architectural and operational manual for team handoff.

### Core Existing Files Modified
8. **`flutter_app/lib/screens/home_page.dart`**
   - **Neighborhood Feed**: Added GPS location acquisition via `geolocator`, 3000m spherical distance filter, priority sorting, and full-screen `InteractiveViewer` pinch-to-zoom.
   - **360° Street View**: Added full-width green "Open 360° Street View" trigger.
   - **Missing Persons**: Removed navigation to `WelcomeSelectionScreen` from the Bento grid card, preserving clean UI.
   - **Inbox Isolation**:
     - Deleted the hardcoded `_demoReports` array (`uni-101`, `uni-102`, `uni-103`, `uni-104`).
     - Added `_myDeviceReportIds` state loaded in `initState` and refreshed on profile load.
     - Filtered feed strictly to: `isMyAuthUser || isMyCitizen || isMyDevice`.
     - Replaced hardcoded strings with real dynamic metadata: `_formatReportTime()`, `_formatReportStatus()`, `_formatReportPriority()`.
     - Added image thumbnails in list items and bottom sheet modal.
     - Connected "View on Map" to pass real database UUID (`realId`) to focus the map marker.
     - Added empty state with "Report an Issue" CTA button.
     - Updated refresh button to invalidate `interactiveReportProvider`.
9. **`flutter_app/lib/screens/interactive_map/report_provider.dart`**
   - Added `InteractiveReportNotifier` with Supabase Realtime channel subscription on `public:complaints:realtime`.
   - Real-time `INSERT`, `UPDATE`, `DELETE` handlers for instant cross-device updates.
   - Added `UpvotedReportsNotifier` managing `Set<String>` of upvoted complaint IDs.
   - Real-time `public:complaint_upvotes:realtime` subscription for cross-device multi-phone vote synchronization.
   - `addReport()`: Immediately persists report ID via `DeviceService.saveMyReportId()`, attaches `auth_user_id: authUser.id`, and saves to Supabase.
   - Preserves `authUserId` on real-time update events.
10. **`flutter_app/lib/screens/interactive_map/report_model.dart`**
    - Updated `toSupabase()` to encode raw bytes to persistent Base64 Data URI (`data:image/jpeg;base64,...`).
    - Updated `fromSupabase()` to decode Base64 strings to `Uint8List` image bytes.
    - Added filter rejecting transient `blob:` URLs to eliminate HTTP 404 reload errors.
    - Added `authUserId` property, constructor parameter, `copyWith`, `fromSupabase` JSON parser, and `toSupabase` mapping.
11. **`flutter_app/lib/screens/interactive_map/map_screen.dart`**
    - Enhanced incident report cards with persistent `imageBytes` memory rendering.
    - Connected full-screen pinch-to-zoom modal for incident photos.
    - Standardized report form submission with image bytes payload.
12. **`flutter_app/pubspec.yaml` & `pubspec.lock`**
    - Promoted `shared_preferences: ^2.5.6` from transitive to direct project dependency.
13. **`flutter_app/lib/screens/kanban_board_ui/kanban_board_screen.dart`**
    - Synchronized civic report status tracking and card formatting.
14. **`flutter_app/lib/screens/SignupLogin_ui/...`** & **`flutter_app/lib/main.dart`**
    - Refined auth screens layout, headers, and form inputs (preserving all core auth service rules).

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
