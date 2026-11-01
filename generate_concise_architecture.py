import html
import os
import base64
import xml.etree.ElementTree as ET

def get_badge_icon(svg_inner, bg_color="#1d3557", stroke="#ffffff", size=48):
    """Creates a base64 encoded SVG badge icon with rounded corners."""
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="{size}" height="{size}">
  <rect width="48" height="48" rx="10" fill="{bg_color}"/>
  <g transform="translate(12, 12) scale(1.0)" fill="none" stroke="{stroke}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
    {svg_inner}
  </g>
</svg>'''
    b64 = base64.b64encode(svg.encode('utf-8')).decode('utf-8')
    return f"data:image/svg+xml;base64,{b64}"

# Icon definitions (Lucide SVG standard paths)
ICONS = {
    # Client Mobile (Blue theme #1d3557)
    "phone": ('<rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/>', "#1d3557"),
    "auth": ('<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>', "#1d3557"),
    "map": ('<path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>', "#1d3557"),
    "verify": ('<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>', "#1d3557"),
    "safety": ('<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>', "#1d3557"),
    "missing": ('<circle cx="10" cy="8" r="4"/><path d="M2 20v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2"/><circle cx="18" cy="18" r="3"/><line x1="20.5" y1="20.5" x2="23" y2="23"/>', "#1d3557"),
    "fcm": ('<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>', "#1d3557"),

    # Client Web (Navy / Slate theme #0f172a)
    "web": ('<rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/>', "#0f172a"),
    "rbac": ('<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><polyline points="17 11 19 13 23 9"/>', "#0f172a"),
    "kpi": ('<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>', "#0f172a"),
    "kanban": ('<rect x="3" y="3" width="5" height="18" rx="1"/><rect x="10" y="3" width="5" height="12" rx="1"/><rect x="17" y="3" width="5" height="15" rx="1"/>', "#0f172a"),
    "workforce": ('<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>', "#0f172a"),
    "heatmap": ('<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>', "#0f172a"),
    "police": ('<circle cx="12" cy="12" r="10"/><line x1="22" y1="12" x2="18" y2="12"/><line x1="6" y1="12" x2="2" y2="12"/><line x1="12" y1="6" x2="12" y2="2"/><line x1="12" y1="22" x2="12" y2="18"/>', "#0f172a"),

    # Supabase (Emerald / Green theme #15803d)
    "jwt": ('<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>', "#15803d"),
    "db": ('<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>', "#15803d"),
    "vector": ('<circle cx="6" cy="6" r="3"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="18" r="3"/><line x1="8.5" y1="8.5" x2="15.5" y2="15.5"/><line x1="18" y1="9" x2="18" y2="15"/><line x1="9" y1="6" x2="15" y2="6"/>', "#15803d"),
    "storage": ('<path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/>', "#15803d"),
    "sync": ('<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>', "#15803d"),
    "edge": ('<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>', "#15803d"),

    # AI Microservice (Amber / Orange theme #b45309)
    "face": ('<path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><circle cx="9" cy="10" r="1"/><circle cx="15" cy="10" r="1"/><path d="M10 15c.5.5 1.5.5 2 0"/>', "#b45309"),
    "embedding": ('<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/>', "#b45309"),
    "cosine": ('<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>', "#b45309"),
    "telemetry": ('<polygon points="3 11 22 2 13 21 11 13 3 11"/>', "#b45309"),
    "dispatch": ('<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>', "#b45309"),

    # External Services (Purple theme #6b21a8)
    "kyc": ('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><line x1="15" y1="8" x2="17" y2="8"/><line x1="15" y1="12" x2="17" y2="12"/><line x1="7" y1="16" x2="17" y2="16"/>', "#6b21a8"),
    "push": ('<path d="M4.93 4.93a10 10 0 0 1 14.14 0"/><path d="M7.76 7.76a6 6 0 0 1 8.48 0"/><circle cx="12" cy="12" r="2"/><path d="M12 14v8"/>', "#6b21a8"),
    "sms": ('<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><line x1="8" y1="9" x2="16" y2="9"/><line x1="8" y1="13" x2="13" y2="13"/>', "#6b21a8"),
    "osm": ('<circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1 4-10z"/>', "#6b21a8")
}

def build_concise_card_html(icon_key, title, bullets, title_color="#1d3557"):
    path_d, bg_col = ICONS[icon_key]
    badge_data = get_badge_icon(path_d, bg_col, size=46)
    
    desc_html = "".join([f'<div style="margin-top:6px;font-size:16px;color:#2c3e50;font-weight:500;">• {b}</div>' for b in bullets])
    
    html_content = (
        f'<table style="width:100%;border-collapse:collapse;text-align:left;">'
        f'<tr>'
        f'<td style="width:48px;vertical-align:top;padding-top:2px;">'
        f'<img src="{badge_data}" width="44" height="44" style="display:block;border-radius:9px;"/>'
        f'</td>'
        f'<td style="vertical-align:top;padding-left:12px;">'
        f'<div style="font-size:20px;font-weight:bold;color:{title_color};line-height:1.2;">{title}</div>'
        f'{desc_html}'
        f'</td>'
        f'</tr>'
        f'</table>'
    )
    return html.escape(html_content, quote=True)

def build_concise_horizontal_html(icon_key, title, tagline, title_color="#15803d"):
    path_d, bg_col = ICONS[icon_key]
    badge_data = get_badge_icon(path_d, bg_col, size=46)
    
    html_content = (
        f'<table style="width:100%;border-collapse:collapse;text-align:left;">'
        f'<tr>'
        f'<td style="width:48px;vertical-align:middle;">'
        f'<img src="{badge_data}" width="44" height="44" style="display:block;border-radius:9px;"/>'
        f'</td>'
        f'<td style="vertical-align:middle;padding-left:14px;">'
        f'<div style="font-size:21px;font-weight:bold;color:{title_color};line-height:1.2;">{title}</div>'
        f'<div style="font-size:16px;color:#333;margin-top:3px;font-weight:500;">{tagline}</div>'
        f'</td>'
        f'</tr>'
        f'</table>'
    )
    return html.escape(html_content, quote=True)

def build_concise_ext_html(icon_key, title, bullets, title_color="#4a154b"):
    path_d, bg_col = ICONS[icon_key]
    badge_data = get_badge_icon(path_d, bg_col, size=48)
    
    desc_html = "".join([f'<div style="margin-top:7px;font-size:16px;color:#2c3e50;font-weight:500;text-align:left;">• {b}</div>' for b in bullets])
    
    html_content = (
        f'<div style="text-align:center;padding:2px;">'
        f'<img src="{badge_data}" width="46" height="46" style="display:inline-block;border-radius:10px;margin-bottom:6px;"/>'
        f'<div style="font-size:21px;font-weight:bold;color:{title_color};margin-bottom:6px;line-height:1.2;">{title}</div>'
        f'<div style="padding-left:15px;padding-right:5px;">{desc_html}</div>'
        f'</div>'
    )
    return html.escape(html_content, quote=True)


def create_clean_drawio():
    cells = []
    cell_id = 100

    def get_id():
        nonlocal cell_id
        cell_id += 1
        return f"cell_{cell_id}"

    # ==========================================
    # 1. CLIENT / PRESENTATION LAYER (Top Blue)
    # ==========================================
    client_layer_id = get_id()
    cells.append(f'''<mxCell id="{client_layer_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;strokeWidth=2.5;arcSize=6;verticalAlign=top;spacingTop=12;" value="" vertex="1">
      <mxGeometry x="-1900" y="-740" width="2400" height="490" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=36;fontStyle=1;fontColor=#1d3557;" value="CLIENT / PRESENTATION TIER" vertex="1">
      <mxGeometry x="-1900" y="-734" width="2400" height="42" as="geometry" />
    </mxCell>''')

    # --- SUB-CONTAINER 1: Citizen Mobile App (Flutter) ---
    mobile_sub_id = get_id()
    cells.append(f'''<mxCell id="{mobile_sub_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#EFF6FC;strokeColor=#6c8ebf;strokeWidth=1.5;arcSize=8;verticalAlign=top;spacingTop=10;" value="" vertex="1">
      <mxGeometry x="-1870" y="-680" width="1150" height="415" as="geometry" />
    </mxCell>''')

    mob_title_badge = get_badge_icon(ICONS["phone"][0], "#1d3557", size=32)
    mob_title_val = html.escape(f'<div style="font-size:25px;font-weight:bold;color:#1d3557;"><img src="{mob_title_badge}" width="28" height="28" style="vertical-align:middle;margin-right:8px;"/>Citizen Mobile App (Flutter / Dart)</div>', quote=True)
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;" value="{mob_title_val}" vertex="1">
      <mxGeometry x="-1870" y="-674" width="1150" height="35" as="geometry" />
    </mxCell>''')

    mob_cards_data = [
        ("auth", "Auth & Onboarding", ["Phone OTP Verification", "Sandbox.co.in e-KYC (DigiLocker)"], 0, 0),
        ("map", "Interactive Civic Map", ["Geotagged Issue Reporting", "Google 360° Street View & Clusters"], 1, 0),
        ("verify", "2-Way Verification", ["100m GPS Proximity Check", "On-Site Camera Re-Audit"], 2, 0),
        ("safety", "Women Safety Suite", ["Safe Journey Live Route Tracking", "5-Min Inactivity Haptic Alarm & SOS"], 0, 1),
        ("missing", "Missing Person Hub", ["Report Missing Person from Phone", "Crowdsourced Camera Sighting Upload"], 1, 1),
        ("fcm", "Push & In-App Alerts", ["FCM Instant Push Notifications", "Real-Time Ticket Status Prompts"], 2, 1)
    ]

    for icon_k, title, bullets, c, r in mob_cards_data:
        x = -1855 + c * 370
        y = -628 + r * 175
        val = build_concise_card_html(icon_k, title, bullets, "#1d3557")
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#6c8ebf;strokeWidth=1.2;arcSize=10;align=left;verticalAlign=middle;spacing=12;" value="{val}" vertex="1">
          <mxGeometry x="{x}" y="{y}" width="355" height="155" as="geometry" />
        </mxCell>''')

    # --- SUB-CONTAINER 2: Authority Web Portal (React + Vite) ---
    web_sub_id = get_id()
    cells.append(f'''<mxCell id="{web_sub_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#EFF6FC;strokeColor=#6c8ebf;strokeWidth=1.5;arcSize=8;verticalAlign=top;spacingTop=10;" value="" vertex="1">
      <mxGeometry x="-680" y="-680" width="1150" height="415" as="geometry" />
    </mxCell>''')

    web_title_badge = get_badge_icon(ICONS["web"][0], "#0f172a", size=32)
    web_title_val = html.escape(f'<div style="font-size:25px;font-weight:bold;color:#0f172a;"><img src="{web_title_badge}" width="28" height="28" style="vertical-align:middle;margin-right:8px;"/>Authority Command Portal (React + Vite)</div>', quote=True)
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;" value="{web_title_val}" vertex="1">
      <mxGeometry x="-680" y="-674" width="1150" height="35" as="geometry" />
    </mxCell>''')

    web_cards_data = [
        ("rbac", "Authority Login & RBAC", ["Role-Based Access Control", "BMC Ward & Police Login Levels"], 0, 0),
        ("kpi", "Executive Dashboard", ["Real-Time City-Wide KPI Cards", "Priority Escalation Log Tracker"], 1, 0),
        ("kanban", "4-Stage BMC Kanban", ["Reported → Assigned → Progress → Resolved", "Mandatory Work-Done Photo Proof"], 2, 0),
        ("workforce", "Workforce Dispatch", ["Field Officer Workforce Roster", "Automated Ward Routing & Allocation"], 0, 1),
        ("heatmap", "Spatial Heatmaps", ["Civic Hazard Density Clusters", "Crime & Night Patrol Route Heatmaps"], 1, 1),
        ("police", "Police Missing Portal", ["FIR Registration & Photo Embeddings", "AI Vector Match Review (Score ≥ 85%)"], 2, 1)
    ]

    for icon_k, title, bullets, c, r in web_cards_data:
        x = -665 + c * 370
        y = -628 + r * 175
        val = build_concise_card_html(icon_k, title, bullets, "#0f172a")
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#6c8ebf;strokeWidth=1.2;arcSize=10;align=left;verticalAlign=middle;spacing=12;" value="{val}" vertex="1">
          <mxGeometry x="{x}" y="{y}" width="355" height="155" as="geometry" />
        </mxCell>''')


    # ==========================================
    # 2. MIDDLE LAYER: SUPABASE (Left Green)
    # ==========================================
    supabase_id = get_id()
    cells.append(f'''<mxCell id="{supabase_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2.5;arcSize=6;verticalAlign=top;spacingTop=12;" value="" vertex="1">
      <mxGeometry x="-1900" y="-200" width="1360" height="730" as="geometry" />
    </mxCell>''')

    supa_title_badge = get_badge_icon(ICONS["db"][0], "#15803d", size=36)
    supa_title_val = html.escape(f'<div style="font-size:32px;font-weight:bold;color:#15803d;"><img src="{supa_title_badge}" width="32" height="32" style="vertical-align:middle;margin-right:10px;"/>Supabase Cloud Platform (Backend as a Service)</div>', quote=True)
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;" value="{supa_title_val}" vertex="1">
      <mxGeometry x="-1900" y="-192" width="1360" height="40" as="geometry" />
    </mxCell>''')

    supa_cards_data = [
        ("jwt", "Auth & Security (GoTrue JWT)", "Role-Based Access (RBAC) & Row-Level Security (RLS) Policies", -135),
        ("db", "PostgreSQL 15+ Relational Database", "Citizens, Authorities, Complaints, Missing Persons, Sightings & Audit Logs", -25),
        ("vector", "pgvector Biometric Vector Store", "512-Dimensional Face Embeddings & HNSW Fast Cosine Similarity Index", 85),
        ("storage", "Cloud Object Storage Buckets", "Encrypted Buckets: Complaint Evidence, Verification Proofs & Sighting Photos", 195),
        ("sync", "Realtime Sync Engine (WebSockets CDC)", "PostgreSQL Change Data Capture Streaming Live Kanban & Status Updates", 305),
        ("edge", "Serverless Edge Functions (Deno Runtime)", "Automated OTP Generation, AI Pipeline Triggers & Notification Webhooks", 415)
    ]

    for icon_k, title, tagline, y_pos in supa_cards_data:
        val = build_concise_horizontal_html(icon_k, title, tagline, "#15803d")
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F4FFF2;strokeColor=#82b366;strokeWidth=1.2;arcSize=10;align=left;verticalAlign=middle;spacingLeft=16;spacingRight=16;" value="{val}" vertex="1">
          <mxGeometry x="-1865" y="{y_pos}" width="1290" height="96" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 3. MIDDLE LAYER: AI BIOMETRICS (Right Orange)
    # ==========================================
    ai_id = get_id()
    cells.append(f'''<mxCell id="{ai_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;strokeWidth=2.5;arcSize=6;verticalAlign=top;spacingTop=12;" value="" vertex="1">
      <mxGeometry x="-500" y="-200" width="1000" height="730" as="geometry" />
    </mxCell>''')

    ai_title_badge = get_badge_icon(ICONS["face"][0], "#b45309", size=36)
    ai_title_val = html.escape(f'<div style="font-size:32px;font-weight:bold;color:#b45309;"><img src="{ai_title_badge}" width="32" height="32" style="vertical-align:middle;margin-right:10px;"/>AI Facial Biometric Microservice</div>', quote=True)
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;" value="{ai_title_val}" vertex="1">
      <mxGeometry x="-500" y="-192" width="1000" height="40" as="geometry" />
    </mxCell>''')

    ai_cards_data = [
        ("face", "Face Detection & Alignment", "MTCNN / RetinaFace Bounding Box Localization & Landmark Normalization", -125),
        ("embedding", "512-d Deep Embedding Extraction", "InsightFace Deep CNN Backbone Generating Normalized Biometric Vectors", -5),
        ("cosine", "Cosine Similarity Matching Engine", "High-Speed Vector Comparison Evaluating Threshold Score ≥ 0.85", 115),
        ("telemetry", "Spatial Telemetry & Geo-Verification", "Correlating Sighting GPS & Timestamp with Police Incident Perimeters", 235),
        ("dispatch", "Ranked Match Output & Dispatch", "Automated High-Priority Match Alerts Dispatched to Police Portal", 355)
    ]

    for icon_k, title, tagline, y_pos in ai_cards_data:
        val = build_concise_horizontal_html(icon_k, title, tagline, "#b45309")
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFF4E8;strokeColor=#d79b00;strokeWidth=1.2;arcSize=10;align=left;verticalAlign=middle;spacingLeft=16;spacingRight=16;" value="{val}" vertex="1">
          <mxGeometry x="-465" y="{y_pos}" width="930" height="102" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 4. EXTERNAL SERVICES LAYER (Bottom Purple)
    # ==========================================
    ext_id = get_id()
    cells.append(f'''<mxCell id="{ext_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2.5;arcSize=6;verticalAlign=top;spacingTop=12;" value="" vertex="1">
      <mxGeometry x="-1900" y="580" width="2400" height="370" as="geometry" />
    </mxCell>''')

    ext_title_badge = get_badge_icon(ICONS["osm"][0], "#6b21a8", size=36)
    ext_title_val = html.escape(f'<div style="font-size:32px;font-weight:bold;color:#4a154b;"><img src="{ext_title_badge}" width="32" height="32" style="vertical-align:middle;margin-right:10px;"/>External Services &amp; Cloud Gateways</div>', quote=True)
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;" value="{ext_title_val}" vertex="1">
      <mxGeometry x="-1900" y="590" width="2400" height="40" as="geometry" />
    </mxCell>''')

    ext_cards_data = [
        ("kyc", "Sandbox.co.in API", ["DigiLocker Session Handler", "Aadhaar OTP e-KYC Verification", "Citizen Anti-Fraud Screening"], -1865),
        ("push", "Firebase Cloud Messaging", ["Mobile Background Push Delivery", "Two-Way Verification Prompts", "Missing Person Urgent Geo-Alerts"], -1285),
        ("sms", "Pingram SMS Gateway", ["Multi-Recipient Emergency SOS", "Automated SMS with Live /track Link", "Zero-Data GSM Cellular Fallback"], -705),
        ("osm", "OpenStreetMap & Street View", ["MapLibre Vector GIS Tiles & Geocoding", "Safe Journey Route Optimization", "Google 360° Street View Context"], -125)
    ]

    for icon_k, title, bullets, x_pos in ext_cards_data:
        val = build_concise_ext_html(icon_k, title, bullets, "#4a154b")
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F8EFFE;strokeColor=#9673a6;strokeWidth=1.2;arcSize=10;align=center;verticalAlign=middle;spacing=10;" value="{val}" vertex="1">
          <mxGeometry x="{x_pos}" y="650" width="555" height="265" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 5. LEGEND & SPECIFICATIONS CONTAINER (Grey Right)
    # ==========================================
    legend_id = get_id()
    cells.append(f'''<mxCell id="{legend_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;strokeWidth=2.5;arcSize=6;verticalAlign=top;spacingTop=16;" value="" vertex="1">
      <mxGeometry x="540" y="-740" width="480" height="1690" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=28;fontStyle=1;fontColor=#222222;" value="SYSTEM ARCHITECTURE LEGEND" vertex="1">
      <mxGeometry x="540" y="-720" width="480" height="38" as="geometry" />
    </mxCell>''')

    # 1. Flow Types
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=22;fontStyle=1;fontColor=#111111;" value="1. Communication Flows" vertex="1">
      <mxGeometry x="570" y="-650" width="420" height="30" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#333333;strokeWidth=1;" value="" vertex="1">
      <mxGeometry x="570" y="-605" width="420" height="85" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="shape=singleArrow;direction=east;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#000000;" value="" vertex="1">
      <mxGeometry x="590" y="-575" width="65" height="25" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=18;fontColor=#111;" value="&lt;b&gt;Synchronous Flow&lt;/b&gt;&lt;br/&gt;RESTful HTTPS / Direct SQL Query" vertex="1">
      <mxGeometry x="675" y="-590" width="305" height="55" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#333333;strokeWidth=1;" value="" vertex="1">
      <mxGeometry x="570" y="-505" width="420" height="85" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="shape=singleArrow;direction=east;whiteSpace=wrap;html=1;fillColor=#333333;strokeColor=#333333;dashed=1;dashPattern=6 6;" value="" vertex="1">
      <mxGeometry x="590" y="-475" width="65" height="25" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=18;fontColor=#111;" value="&lt;b&gt;Asynchronous Flow&lt;/b&gt;&lt;br/&gt;WebSocket Pub/Sub / Push Alarms" vertex="1">
      <mxGeometry x="675" y="-490" width="305" height="55" as="geometry" />
    </mxCell>''')

    # 2. Color Tiers
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=22;fontStyle=1;fontColor=#111111;" value="2. Architectural Tiers" vertex="1">
      <mxGeometry x="570" y="-385" width="420" height="30" as="geometry" />
    </mxCell>''')

    tiers = [
        ("Presentation / Client Tier", "#dae8fc", "#6c8ebf", "Flutter Mobile App &amp; React Web Portal", -340),
        ("Backend Services (Supabase)", "#d5e8d4", "#82b366", "PostgreSQL, pgvector, Auth, Storage, Edge", -245),
        ("AI Biometric Microservices", "#ffe6cc", "#d79b00", "InsightFace, Cosine Distance, Match Alerts", -150),
        ("External Services &amp; APIs", "#e1d5e7", "#9673a6", "Sandbox.co.in, FCM, Pingram, OSM", -55)
    ]

    for title, fill, stroke, sub, y_b in tiers:
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};strokeWidth=2;" value="" vertex="1">
          <mxGeometry x="570" y="{y_b}" width="65" height="65" as="geometry" />
        </mxCell>''')
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=18;fontColor=#111;" value="&lt;b&gt;{html.escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;span style=&quot;font-size:14px;color:#444;&quot;&gt;{html.escape(sub)}&lt;/span&gt;" vertex="1">
          <mxGeometry x="655" y="{y_b}" width="345" height="65" as="geometry" />
        </mxCell>''')

    # 3. Technical Stack Specs
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=22;fontStyle=1;fontColor=#111111;" value="3. Technical Stack Specs" vertex="1">
      <mxGeometry x="570" y="55" width="420" height="30" as="geometry" />
    </mxCell>''')

    spec_val = (
        "&lt;div style=&quot;line-height:1.7;font-size:16px;color:#111;&quot;&gt;"
        "&lt;b&gt;• Mobile Client:&lt;/b&gt; Flutter (Dart 3)&lt;br/&gt;"
        "&lt;b&gt;• Web Portal:&lt;/b&gt; React 18, Vite, Tailwind CSS&lt;br/&gt;"
        "&lt;b&gt;• Cloud BaaS:&lt;/b&gt; Supabase Platform&lt;br/&gt;"
        "&lt;b&gt;• Relational DB:&lt;/b&gt; PostgreSQL 15.1+&lt;br/&gt;"
        "&lt;b&gt;• Vector Index:&lt;/b&gt; pgvector (512-d HNSW)&lt;br/&gt;"
        "&lt;b&gt;• Face Biometrics:&lt;/b&gt; InsightFace / FaceNet&lt;br/&gt;"
        "&lt;b&gt;• Match Threshold:&lt;/b&gt; Cosine Similarity ≥ 0.85&lt;br/&gt;"
        "&lt;b&gt;• Identity e-KYC:&lt;/b&gt; Sandbox.co.in (DigiLocker)&lt;br/&gt;"
        "&lt;b&gt;• Push Delivery:&lt;/b&gt; Firebase Cloud Messaging&lt;br/&gt;"
        "&lt;b&gt;• Emergency SMS:&lt;/b&gt; Pingram Gateway API&lt;br/&gt;"
        "&lt;b&gt;• Geospatial GIS:&lt;/b&gt; OpenStreetMap &amp; MapLibre&lt;br/&gt;"
        "&lt;b&gt;• Security Model:&lt;/b&gt; JWT + Row-Level Security"
        "&lt;/div&gt;"
    )
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#666666;strokeWidth=1.5;align=left;verticalAlign=top;spacing=15;" value="{spec_val}" vertex="1">
      <mxGeometry x="570" y="100" width="420" height="380" as="geometry" />
    </mxCell>''')

    # 4. Security Note
    sec_val = (
        "&lt;div style=&quot;line-height:1.45;font-size:15px;color:#222;&quot;&gt;"
        "&lt;b style=&quot;color:#b45309;font-size:17px;&quot;&gt;Zero-Trust Data Isolation:&lt;/b&gt;&lt;br/&gt;"
        "All biometric vectors, Aadhaar e-KYC tokens, and civic telemetry are guarded by PostgreSQL Row-Level Security (RLS) policies."
        "&lt;/div&gt;"
    )
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=1.5;align=left;verticalAlign=top;spacing=14;" value="{sec_val}" vertex="1">
      <mxGeometry x="570" y="505" width="420" height="135" as="geometry" />
    </mxCell>''')

    # 5. Handshake Note
    v_handshake = (
        "&lt;div style=&quot;line-height:1.45;font-size:15px;color:#222;&quot;&gt;"
        "&lt;b style=&quot;color:#1d3557;font-size:17px;&quot;&gt;Two-Way Verification Protocol:&lt;/b&gt;&lt;br/&gt;"
        "Field officers must upload work-done proof photos. Ticket closes only after citizen conducts on-site camera re-audit within 100m GPS radius."
        "&lt;/div&gt;"
    )
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#EFF6FC;strokeColor=#6c8ebf;strokeWidth=1.5;align=left;verticalAlign=top;spacing=14;" value="{v_handshake}" vertex="1">
      <mxGeometry x="570" y="665" width="420" height="150" as="geometry" />
    </mxCell>''')

    # ==========================================
    # 6. CONNECTOR ARROWS
    # ==========================================
    # Arrow 1: Mobile App -> Supabase (Sync HTTPS Requests)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{mobile_sub_id}" target="{supabase_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;entryX=0.25;entryY=0;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#1d3557;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 2: Supabase -> Mobile App (Async Realtime CDC updates)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{supabase_id}" target="{mobile_sub_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=0.15;exitY=0;exitDx=0;exitDy=0;entryX=0.15;entryY=1;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#555555;dashed=1;dashPattern=8 8;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 3: Web Portal -> Supabase (Sync Status & Officer dispatch)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{web_sub_id}" target="{supabase_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;entryX=0.85;entryY=0;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#1d3557;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 4: Supabase -> Web Portal (Async Realtime Kanban updates)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{supabase_id}" target="{web_sub_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=0.92;exitY=0;exitDx=0;exitDy=0;entryX=0.25;entryY=1;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#555555;dashed=1;dashPattern=8 8;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 5: Supabase <-> AI Microservice (Bidirectional Vector Processing)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{supabase_id}" target="{ai_id}" style="edgeStyle=none;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeWidth=4;strokeColor=#d79b00;startArrow=classic;startFill=1;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 6: AI Microservice -> Web Portal (Ranked Match Sighting Feed - Async)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{ai_id}" target="{web_sub_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=0.65;exitY=0;exitDx=0;exitDy=0;entryX=0.75;entryY=1;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#d79b00;dashed=1;dashPattern=8 8;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 7: Supabase -> External Services (Edge Functions Invoking External APIs)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{supabase_id}" target="{ext_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=0.35;exitY=1;exitDx=0;exitDy=0;entryX=0.35;entryY=0;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#4a154b;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 8: External Services (FCM & SMS) -> Citizen Mobile (Push Alerts & SMS - Async)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{ext_id}" target="{mobile_sub_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=0;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#4a154b;dashed=1;dashPattern=8 8;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry">
        <Array as="points">
          <mxPoint x="-1940" y="765" />
          <mxPoint x="-1940" y="-472" />
        </Array>
      </mxGeometry>
    </mxCell>''')

    # Build full XML with explicit background="#ffffff" (Forces Light Canvas)
    xml_content = f'''<mxfile host="app.diagrams.net">
  <diagram name="UniSafe-System-Architecture" id="UniSafeFullSystemArch">
    <mxGraphModel dx="2800" dy="1600" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="0" pageScale="1" pageWidth="850" pageHeight="1100" math="0" shadow="0" background="#ffffff">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        {"".join(cells)}
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>'''

    proj_path = r"c:\projects\Unisafe\unisafe_system_architecture.drawio"
    with open(proj_path, "w", encoding="utf-8") as f:
        f.write(xml_content)
    print(f"Updated concise drawio file: {proj_path}")

if __name__ == "__main__":
    create_clean_drawio()
