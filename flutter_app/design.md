# Apple Design System & UniSafe Platform Guidelines
*Grounded in Apple Developer Design & Human Interface Guidelines (HIG) — https://developer.apple.com/design/*
*Aligned with UniSafe Software Requirements Specification (SRS v1.0 — AI-Powered Civic Intelligence & Public Safety Platform)*

---

## 1. Platform Purpose & Scope (From SRS)

UniSafe is an **AI-Powered Civic Intelligence & Smart Public Safety Platform** designed for entire municipalities, citizens, and public safety authorities. It is **not** a campus-only application. 

### Core Functional Pillars (SRS 1.2, 2.2, 3.1–3.8):
1. **Civic Issue Reporting**: Geo-tagged reporting across 4 civic categories:
   - **Infrastructure** (e.g. road damage, water pipeline ruptures, streetlight outages)
   - **Sanitation** (e.g. overflowing garbage bins, illegal dumping, drain clogging)
   - **Greenery** (e.g. fallen tree branches, park maintenance)
   - **Safety** (e.g. hazardous wiring, dark walkways, danger spots)
2. **Community Verification (Upvote Mechanism)**:
   - Citizens upvote/confirm or dispute pending reports.
   - Once threshold (5 net upvotes) is reached, status updates to `Verified` and auto-routes to municipal departments.
3. **Municipal Kanban Workflow**:
   - Authority and department staff manage verified complaints across real-time Kanban columns: `To Do` → `In Progress` → `Resolved`.
4. **AI-Assisted Missing-Person Facial Recognition**:
   - Citizens file missing-person cases with a face-visible reference photo.
   - AI facial recognition computes face embeddings and surfaces candidate matches for mandatory Admin manual review.
5. **Emergency Risk Heatmaps**:
   - Visualizes aggregated risk zones: **Accident-prone**, **Flood-prone**, **Crime-prone**, and **High-complaint** zones.
6. **Women Safety Module**:
   - Inactivity detection during active safety sessions, triggering cancellable countdowns and automated live location sharing with emergency contacts.

---

## 2. Core Principles of Apple iOS Design

Apple's design philosophy is built upon three foundational tenets:

1. **Clarity**:
   - Text is legible at every size, icons are precise and lucid, and adornments are subtle and purposeful.
   - Negative space (whitespace), color, typography, and interface elements subtly highlight critical civic alerts.
2. **Deference**:
   - Fluid motion and a crisp, light interface help people understand and interact with civic and safety information without distraction.
   - Clean system backgrounds with subtle elevation and depth.
3. **Depth**:
   - Visual layers and realistic motion impart vitality.
   - Touchable squircle elements provide instant tactile clarity.

---

## 3. Light Mode Foundations & System Palette

The platform strictly operates in an elegant iOS Light Mode architecture:

### Surfaces & Backgrounds
| Token | Hex Value | Semantic Usage |
| :--- | :--- | :--- |
| `System Background` | `#F2F2F7` | iOS grouped background for the entire screen canvas |
| `Secondary System Background` | `#FFFFFF` | Pure white cards, bento tiles, and interactive surfaces |
| `Tertiary System Fill` | `#E5E5EA` | Hairline dividers, subtle card borders (`1.0px`), and inactive tracks |
| `Quaternary System Fill` | `#F8F9FA` | Inner chip wells, pill backdrops, and search inputs |

### Typography & Label Hierarchy
Following SF Pro typographic scale:
| Role | Weight | Size / Line Height | Color | Usage |
| :--- | :--- | :--- | :--- | :--- |
| `Large Title` | Bold (700) | 26pt / 32pt | `#1C1C1E` | Screen greetings & primary headers |
| `Title 2` | Bold (700) | 20pt / 26pt | `#1C1C1E` | Card section titles & Hero stats |
| `Headline` | Bold (800) | 15pt / 20pt | `#1C1C1E` | Bento card titles |
| `Body` | Regular (400) | 13pt / 18pt | `#3A3A3C` | Descriptions & status text |
| `Subhead` | Bold (700) | 10pt / 14pt | `#8E8E93` | Uppercase category eyebrows (0.6–0.8 tracking) |
| `Footnote` | Medium (500) | 11pt / 15pt | `#8E8E93` | Metadata, timestamps, and secondary info |

### Apple System Accent Palette
- **System Blue** (`#007AFF`): Interactive Civic Map, geo-tagged reporting, primary navigation.
- **System Emerald** (`#34C759`): "All Clear" status, resolved civic complaints, verified safe status, AI-verified cases.
- **System Amber / Orange** (`#FF9500`): Risk heatmaps, flood/crime warnings, hazard reports.
- **System Purple** (`#AF52DE`): Municipal Kanban triage, dispatch workflows, tasks.
- **System Coral / Red** (`#FF3B30`): Urgent SOS, women safety emergency alerts.

---

## 4. Strict Bento Grid Symmetry Rule (Equal Square Geometry)

> [!IMPORTANT]
> **MANDATORY DESIGN RULE: ALL 4 BENTO CARDS MUST BE IDENTICAL IN SIZE.**
>
> In the 2×2 Bento Grid:
> 1. Every card MUST have the **exact same width** and **exact same height** (1:1 square aspect ratio or strictly uniform dimensions).
> 2. Flutter implementation MUST use `GridView.count(crossAxisCount: 2, childAspectRatio: 1.0, crossAxisSpacing: 14, mainAxisSpacing: 14)` or an equivalent mathematically constrained layout.
> 3. Individual cards MUST NOT rely on unconstrained column heights. Unequal content (such as bar charts vs pills vs progress bars) must be constrained to a uniform fixed-height content slot (`height: 24.0`).
> 4. Action labels at the bottom of cards (e.g. `Open Map ›`, `View Zones ›`, `Open Board ›`, `View Cases ›`) MUST be anchored via `Spacer()` so their baselines are pixel-perfect across all four quadrants.
> 5. Never let one card expand taller or shorter than its neighbors.

---

## 5. Screen Hierarchy & Header Architecture

### Top Navigation Header
- **Clean Greeting Only**:
  - Top eyebrow: Current date in uppercase 11.5pt bold tracking (`THURSDAY, OCT 1`).
  - Headline: Citizen greeting (`Welcome, Annette` in 26pt bold SF typography).
- **NO Redundant Buttons**:
  - Notification bells and profile avatars **must not** appear in the top header.
  - The bottom Apple Liquid Glass dock already provides dedicated tabs for **Inbox (Tab 1)** and **Account (Tab 2)**. Duplicating them at the top introduces visual clutter and violates Apple HIG minimalism.

### Hero Card: Public Safety Index
- **Visual Centerpiece**: An Apple Activity-style **Safety Ring Gauge** (at 94%):
  - Badge: `CIVIC INTELLIGENCE` with green live pulse dot.
  - Metric: `94% SAFE` inside sweep-gradient emerald arc.
  - Subhead: `12 Wards Monitored • All Clear`.
  - Footer: `Live City Shield Active • 0 High-Risk Alerts`.

### Quick Civic Actions Row
Single-tap action pills routing directly to the core SRS flows:
1. ⚠️ **Report Issue** (Infrastructure, Sanitation, Greenery, Safety)
2. 👥 **Missing Person** (AI Facial Recognition Case Flow)
3. 🛡️ **Women Safety** (Inactivity Guardian & Live SOS)
4. 🔥 **Risk Heatmaps** (Accident, Flood & Crime Zones)

### 2×2 Equal-Sized Bento Box Grid
Four 1:1 square cards with identical dimensions:
1. **Civic Map (System Blue `#007AFF`)**:
   - Eyebrow: `CIVIC MAP`
   - Title: `Live Incidents`
   - Subhead: `Active geo-tagged reports`
   - Indicator: Mini activity bars (24px height slot)
   - Action: `Open Map ›`
2. **Emergency Heatmaps (System Orange `#FF9500`)**:
   - Eyebrow: `HEATMAPS`
   - Title: `Risk Zones`
   - Subhead: `Accident • Flood • Crime`
   - Indicator: `Low Risk (0.02)` status pill (24px height slot)
   - Action: `View Zones ›`
3. **Municipal Kanban (System Purple `#AF52DE`)**:
   - Eyebrow: `KANBAN`
   - Title: `Triage Board`
   - Subhead: `4 In Progress • 2 Done`
   - Indicator: Segmented status bar (24px height slot)
   - Action: `Open Board ›`
4. **Missing Persons & AI Face-Match (System Emerald `#34C759`)**:
   - Eyebrow: `AI MATCH`
   - Title: `Missing Persons`
   - Subhead: `Face Match Active`
   - Indicator: `1 Match Verified` badge (24px height slot)
   - Action: `View Cases ›`

### Municipal & Civic Dispatch Feed
Real-time verified reports synchronised with the municipal backend:
- Infrastructure updates (e.g. water pipeline repairs).
- Sanitation verifications (e.g. waste clearance verified by 9 citizen votes).
- Missing person alerts (e.g. admin-confirmed AI matches).

### Apple Liquid Glass Floating Dock
- Floating capsule above `#F2F2F7` background.
- Translucent white glass body with `18px` backdrop blur.
- Liquid Glass magnifying selector pill with 1.0px hairline specular gradient outline and 3% crystal glass refraction.
