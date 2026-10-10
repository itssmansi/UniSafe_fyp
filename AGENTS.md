# UniSafe Project - AI Agent Guidelines & Protocol

## 1. Auth & Supabase Isolation Rule (CRITICAL)
- **Zero Unauthorized Modifications**:
  - `flutter_app/lib/config/supabase_config.dart` (Supabase URL & API keys).
  - Existing Authentication tables in Supabase:
    - `citizens`
    - `authorities`
    - `mock_citizen_records`
  - Existing Supabase Edge Functions:
    - `send-otp`
    - `verify-otp`
    - `authority-login`
    - `send-aadhar-otp`
    - `verify-aadhar-otp`
  - `flutter_app/lib/services/auth_service.dart` and the screens in `flutter_app/lib/screens/auth/`.

## 2. Protocol If a Change Is Strictly Necessary
If an implementation or database integration absolutely cannot proceed without modifying any of the above auth files, tables, or Edge Functions:
1. **STOP immediately** before making any edits.
2. **Inform the user** clearly about the dependency.
3. **Provide a ready-to-send draft message** for the teammate explaining:
   - What needs to be changed.
   - Why it is necessary.
   - How it impacts both Auth and Map modules.
4. **Wait for explicit user approval** before touching any auth or backend configurations.

## 3. Interactive Map Scope
- Focus exclusively on:
  - Interactive map UI, routing, and location display.
  - Custom safety markers, heatmaps, and hazard/incident reports.
  - Dedicated, isolated database tables (e.g. `map_markers`, `incident_reports`, `safety_zones`).
- Keep all custom visual styling, animations, fluid docks, and shaders completely preserved.

## 4. Git Safety & Branch Rules
- **Branch Restriction (MANDATORY)**: ONLY commit and push to the `pranav-testing` branch. NEVER commit or push directly to `main` or other teammates' branches.
- Never run blind git merges (`git merge`), resets, or destructive git write commands.
- Verify working tree and preserve user-specific changes at all times.
