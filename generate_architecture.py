import html
import os

def create_drawio():
    cells = []
    cell_id = 100

    def get_id():
        nonlocal cell_id
        cell_id += 1
        return f"cell_{cell_id}"

    def escape(s):
        return html.escape(s, quote=True)

    # 1. Canvas / Main Layout bounds
    # Main content: X = -1900 to X = 500 (Width = 2400)
    # Legend: X = 540 to X = 1020 (Width = 480)
    # Top Y = -740 to Y = 1000

    # ==========================================
    # 1. CLIENT / PRESENTATION LAYER (Top Blue)
    # ==========================================
    client_layer_id = get_id()
    cells.append(f'''<mxCell id="{client_layer_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;strokeWidth=3;arcSize=6;verticalAlign=top;spacingTop=15;" value="" vertex="1">
      <mxGeometry x="-1900" y="-740" width="2400" height="500" as="geometry" />
    </mxCell>''')

    # Main Client Layer Title
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=40;fontStyle=1;fontColor=#1d3557;" value="CLIENT / PRESENTATION LAYER" vertex="1">
      <mxGeometry x="-1900" y="-730" width="2400" height="45" as="geometry" />
    </mxCell>''')

    # --- SUB-CONTAINER 1: Citizen Mobile App (Flutter) ---
    mobile_sub_id = get_id()
    cells.append(f'''<mxCell id="{mobile_sub_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#EFF6FC;strokeColor=#6c8ebf;strokeWidth=2;arcSize=8;verticalAlign=top;spacingTop=12;" value="" vertex="1">
      <mxGeometry x="-1870" y="-675" width="1150" height="415" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=26;fontStyle=1;fontColor=#1d3557;" value="📱 Citizen Mobile Application (Flutter / Dart)" vertex="1">
      <mxGeometry x="-1870" y="-668" width="1150" height="35" as="geometry" />
    </mxCell>''')

    # 6 Mobile Cards (3x2 Grid)
    # Row 1: Y = -620, Height = 160. Width = 360 each. Gap = 15.
    # Col 1: X = -1855, Col 2: X = -1480, Col 3: X = -1105
    mob_cards = [
        # (title, subtitle, col, row)
        ("🔐 Auth & Onboarding", "• Phone OTP Login & Signup<br/>• Sandbox.co.in e-KYC (DigiLocker)<br/>• Secure Session & Local Storage", 0, 0),
        ("🗺️ Interactive Civic Map", "• Geotagged Pothole/Civic Issues<br/>• Camera Capture & Categorization<br/>• Google 360° Street View & Clusters", 1, 0),
        ("🤝 2-Way Resolution Verify", "• 100m GPS Geofence Proximity<br/>• Real-Time Camera Remediation Audit<br/>• Direct Done / Not Done Feedback", 2, 0),
        ("🛡️ Women Safety Suite", "• Safe Journey Live Route Tracking<br/>• 5-Min Inactivity Haptic Alarm<br/>• One-Tap SOS Emergency Broadcast", 0, 1),
        ("🔍 Missing Person Hub", "• Report Missing Person from Phone<br/>• Crowdsourced Camera Sightings<br/>• Instant Sighting Telemetry Upload", 1, 1),
        ("🔔 Push & In-App Alerts", "• Firebase Cloud Messaging (FCM)<br/>• Real-Time Ticket Status Updates<br/>• Emergency Geo-Safety Alerts", 2, 1)
    ]

    for title, desc, c, r in mob_cards:
        x = -1855 + c * 370
        y = -620 + r * 175
        val = f"&lt;b style=&quot;font-size:22px;color:#1d3557;&quot;&gt;{escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;div style=&quot;font-size:16px;color:#333;margin-top:6px;line-height:1.3;&quot;&gt;{escape(desc)}&lt;/div&gt;"
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#6c8ebf;strokeWidth=1.5;arcSize=10;align=center;verticalAlign=middle;spacing=8;" value="{val}" vertex="1">
          <mxGeometry x="{x}" y="{y}" width="355" height="160" as="geometry" />
        </mxCell>''')

    # --- SUB-CONTAINER 2: Authority Web Portal (React + Vite) ---
    web_sub_id = get_id()
    cells.append(f'''<mxCell id="{web_sub_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#EFF6FC;strokeColor=#6c8ebf;strokeWidth=2;arcSize=8;verticalAlign=top;spacingTop=12;" value="" vertex="1">
      <mxGeometry x="-680" y="-675" width="1150" height="415" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=26;fontStyle=1;fontColor=#1d3557;" value="💻 Authority Command Portal (React + Vite)" vertex="1">
      <mxGeometry x="-680" y="-668" width="1150" height="35" as="geometry" />
    </mxCell>''')

    # 6 Web Cards (3x2 Grid)
    # Col 1: X = -665, Col 2: X = -290, Col 3: X = 85
    web_cards = [
        ("🏢 Authority Login & RBAC", "• Role-Based Access Control (RBAC)<br/>• BMC Municipal Officers & Ward Staff<br/>• Police Station Department Access", 0, 0),
        ("📊 Executive Dashboard", "• Real-Time City-Wide KPI Cards<br/>• Complaint Volumes & Resolution Rate<br/>• Priority Escalation Tracker", 1, 0),
        ("📋 4-Stage BMC Kanban", "• Reported → Assigned → In Progress → Resolved<br/>• Drag-and-Drop Ticket Flow<br/>• Mandatory Work-Done Photo Proof", 2, 0),
        ("👷 Workforce Dispatch", "• Field Officer Roster & Directory<br/>• Automated Ward-Level Routing<br/>• Workload Balancing & Assignment", 0, 1),
        ("🗺️ Spatial Analytics Heatmap", "• Civic Hazard Clustering Density<br/>• Police Crime & Theft Heatmaps<br/>• Temporal Night Patrol Optimization", 1, 1),
        ("🚨 Missing Person Portal", "• Register Missing Persons (Police)<br/>• AI Vector Match Review (≥85%)<br/>• Sighting Telemetry & Photo Audit", 2, 1)
    ]

    for title, desc, c, r in web_cards:
        x = -665 + c * 370
        y = -620 + r * 175
        val = f"&lt;b style=&quot;font-size:22px;color:#1d3557;&quot;&gt;{escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;div style=&quot;font-size:16px;color:#333;margin-top:6px;line-height:1.3;&quot;&gt;{escape(desc)}&lt;/div&gt;"
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#6c8ebf;strokeWidth=1.5;arcSize=10;align=center;verticalAlign=middle;spacing=8;" value="{val}" vertex="1">
          <mxGeometry x="{x}" y="{y}" width="355" height="160" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 2. MIDDLE LAYER: SUPABASE (Left Green)
    # ==========================================
    supabase_id = get_id()
    cells.append(f'''<mxCell id="{supabase_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=3;arcSize=6;verticalAlign=top;spacingTop=15;" value="" vertex="1">
      <mxGeometry x="-1900" y="-180" width="1360" height="720" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=38;fontStyle=1;fontColor=#274e13;" value="⚡ Supabase Cloud Platform (Backend as a Service)" vertex="1">
      <mxGeometry x="-1900" y="-170" width="1360" height="40" as="geometry" />
    </mxCell>''')

    # 6 Supabase Horizontal Cards
    # Width = 1290, Height = 95, X = -1865
    supa_cards = [
        ("🔑 Auth & Security (GoTrue JWT)", "Citizen & Authority authentication, Role-Based Access Control (RBAC), Row-Level Security (RLS) policies, and JWT token sessions.", -115),
        ("🗄️ PostgreSQL 15+ Relational Database", "Structured relational schema: citizens (with fcm_token), authorities, incident_reports, missing_persons, sightings, and audit_logs.", -5),
        ("📐 pgvector Biometric Vector Store", "Native 512-dimensional facial embedding vector storage with HNSW index for sub-second cosine similarity searches.", 105),
        ("🪣 Cloud Object Storage Buckets", "Secure encrypted storage: complaint-images (evidence), verification-proofs (field officers), missing-portraits, and sighting-captures.", 215),
        ("🔄 Realtime Sync Engine (WebSockets CDC)", "PostgreSQL Change Data Capture (CDC) streaming live Kanban state changes, new complaints, and verification updates to web and mobile.", 325),
        ("⚙️ Serverless Edge Functions (Deno Runtime)", "Event-driven serverless functions: automated OTP generation, AI vector pipeline dispatch, and external notification webhooks.", 435)
    ]

    for title, desc, y_pos in supa_cards:
        val = f"&lt;b style=&quot;font-size:22px;color:#274e13;&quot;&gt;{escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;span style=&quot;font-size:16px;color:#333;&quot;&gt;{escape(desc)}&lt;/span&gt;"
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F4FFF2;strokeColor=#82b366;strokeWidth=1.5;arcSize=10;align=left;verticalAlign=middle;spacingLeft=25;spacingRight=20;" value="{val}" vertex="1">
          <mxGeometry x="-1865" y="{y_pos}" width="1290" height="98" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 3. MIDDLE LAYER: AI BIOMETRICS (Right Orange)
    # ==========================================
    ai_id = get_id()
    cells.append(f'''<mxCell id="{ai_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;strokeWidth=3;arcSize=6;verticalAlign=top;spacingTop=15;" value="" vertex="1">
      <mxGeometry x="-500" y="-180" width="1000" height="720" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=38;fontStyle=1;fontColor=#b45f06;" value="🤖 AI Facial Biometric Microservice" vertex="1">
      <mxGeometry x="-500" y="-170" width="1000" height="40" as="geometry" />
    </mxCell>''')

    # 5 AI Horizontal Cards
    # Width = 930, Height = 105, X = -465
    ai_cards = [
        ("📷 Face Detection & Alignment (MTCNN / RetinaFace)", "Automated facial bounding box localization, 5-point facial landmark detection, and pose/perspective normalization.", -105),
        ("🧬 512-d Deep Embedding Extraction (InsightFace)", "Deep Convolutional Neural Network backbone extracting normalized 512-dimensional vector representations from cropped facial images.", 20),
        ("🎯 Cosine Similarity Matching Engine", "High-performance vector distance evaluation: Similarity = (A · B) / (||A|| ||B||) with match threshold score ≥ 0.85.", 145),
        ("📍 Spatial Telemetry & Geo-Verification", "Correlates crowdsourced sighting coordinates with police incident perimeters, timestamp logs, and camera metadata.", 270),
        ("🚨 Ranked Match Output & Alert Dispatch", "Generates ranked candidate matches and triggers instant high-priority alerts to the Police Authority web portal.", 395)
    ]

    for title, desc, y_pos in ai_cards:
        val = f"&lt;b style=&quot;font-size:22px;color:#b45f06;&quot;&gt;{escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;span style=&quot;font-size:16px;color:#333;&quot;&gt;{escape(desc)}&lt;/span&gt;"
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFF4E8;strokeColor=#d79b00;strokeWidth=1.5;arcSize=10;align=left;verticalAlign=middle;spacingLeft=25;spacingRight=20;" value="{val}" vertex="1">
          <mxGeometry x="-465" y="{y_pos}" width="930" height="105" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 4. EXTERNAL SERVICES LAYER (Bottom Purple)
    # ==========================================
    ext_id = get_id()
    cells.append(f'''<mxCell id="{ext_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=3;arcSize=6;verticalAlign=top;spacingTop=15;" value="" vertex="1">
      <mxGeometry x="-1900" y="600" width="2400" height="380" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=38;fontStyle=1;fontColor=#4a154b;" value="🌐 External Services &amp; Cloud Gateways" vertex="1">
      <mxGeometry x="-1900" y="615" width="2400" height="40" as="geometry" />
    </mxCell>''')

    # 4 External Services Cards (Side-by-side)
    # Width = 555, Height = 265, Gap = 25
    # X1 = -1865, X2 = -1285, X3 = -705, X4 = -125, Y = 680
    ext_cards = [
        ("🆔 Sandbox.co.in API", "• Official DigiLocker Session Handler<br/>• Real-Time Aadhaar OTP e-KYC<br/>• Verified Citizen Identity Trust Score<br/>• Prevents Fake / Spam Civic Reports", -1865),
        ("🔔 Firebase Cloud Messaging (FCM)", "• Push Notification Delivery to Devices<br/>• Background &amp; Headless Wakeup Alarms<br/>• 2-Way Resolution Verification Prompts<br/>• Missing Person Urgent Broadcasts", -1285),
        ("📱 Pingram SMS Gateway", "• Multi-Recipient Emergency SOS Broadcasts<br/>• Automated SMS with Live /track Link<br/>• Low-Latency Carrier Gateway (GSM)<br/>• Fallback when Mobile Data Fails", -705),
        ("🗺️ OpenStreetMap &amp; Street View", "• MapLibre / OSM GIS Tile Rendering<br/>• Safe Journey Routing Optimization<br/>• Reverse Geocoding &amp; Ward Boundaries<br/>• Google 360° Panoramic Context", -125)
    ]

    for title, desc, x_pos in ext_cards:
        val = f"&lt;b style=&quot;font-size:22px;color:#4a154b;&quot;&gt;{escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;div style=&quot;font-size:16px;color:#333;margin-top:10px;line-height:1.4;&quot;&gt;{escape(desc)}&lt;/div&gt;"
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F8EFFE;strokeColor=#9673a6;strokeWidth=1.5;arcSize=10;align=center;verticalAlign=middle;spacing=12;" value="{val}" vertex="1">
          <mxGeometry x="{x_pos}" y="675" width="555" height="275" as="geometry" />
        </mxCell>''')

    # ==========================================
    # 5. LEGEND & SPECIFICATIONS CONTAINER (Grey Right)
    # ==========================================
    legend_id = get_id()
    cells.append(f'''<mxCell id="{legend_id}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;strokeWidth=3;arcSize=6;verticalAlign=top;spacingTop=20;" value="" vertex="1">
      <mxGeometry x="540" y="-740" width="480" height="1720" as="geometry" />
    </mxCell>''')

    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;rounded=0;fontSize=32;fontStyle=1;fontColor=#333333;" value="SYSTEM ARCHITECTURE LEGEND" vertex="1">
      <mxGeometry x="540" y="-715" width="480" height="40" as="geometry" />
    </mxCell>''')

    # Flow Types Section Header
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=24;fontStyle=1;fontColor=#111111;" value="1. Communication Flows" vertex="1">
      <mxGeometry x="570" y="-640" width="420" height="30" as="geometry" />
    </mxCell>''')

    # Solid line example
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#333333;strokeWidth=1;" value="" vertex="1">
      <mxGeometry x="570" y="-595" width="420" height="90" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="shape=singleArrow;direction=east;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#000000;" value="" vertex="1">
      <mxGeometry x="590" y="-565" width="70" height="25" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=18;" value="&lt;b&gt;Synchronous Flow&lt;/b&gt;&lt;br/&gt;RESTful HTTPS / Direct SQL Query" vertex="1">
      <mxGeometry x="680" y="-580" width="300" height="60" as="geometry" />
    </mxCell>''')

    # Dashed line example
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#333333;strokeWidth=1;" value="" vertex="1">
      <mxGeometry x="570" y="-485" width="420" height="90" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="shape=singleArrow;direction=east;whiteSpace=wrap;html=1;fillColor=#333333;strokeColor=#333333;dashed=1;dashPattern=6 6;" value="" vertex="1">
      <mxGeometry x="590" y="-455" width="70" height="25" as="geometry" />
    </mxCell>''')
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=18;" value="&lt;b&gt;Asynchronous Flow&lt;/b&gt;&lt;br/&gt;WebSocket Pub/Sub / Push Alarms" vertex="1">
      <mxGeometry x="680" y="-470" width="300" height="60" as="geometry" />
    </mxCell>''')

    # Color Tiers Section Header
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=24;fontStyle=1;fontColor=#111111;" value="2. Architectural Tiers" vertex="1">
      <mxGeometry x="570" y="-355" width="420" height="30" as="geometry" />
    </mxCell>''')

    # Color blocks
    tiers = [
        ("Presentation / Client Tier", "#dae8fc", "#6c8ebf", "Flutter Mobile App &amp; React Web Portal", -305),
        ("Backend Services (Supabase)", "#d5e8d4", "#82b366", "PostgreSQL, pgvector, Auth, Storage, Edge", -205),
        ("AI Biometric Microservices", "#ffe6cc", "#d79b00", "InsightFace, Cosine Distance, Match Alerts", -105),
        ("External Services &amp; APIs", "#e1d5e7", "#9673a6", "Sandbox.co.in, FCM, Pingram, OSM", -5)
    ]

    for title, fill, stroke, sub, y_b in tiers:
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};strokeWidth=2;" value="" vertex="1">
          <mxGeometry x="570" y="{y_b}" width="70" height="70" as="geometry" />
        </mxCell>''')
        cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=18;" value="&lt;b&gt;{escape(title)}&lt;/b&gt;&lt;br/&gt;&lt;span style=&quot;font-size:14px;color:#555;&quot;&gt;{escape(sub)}&lt;/span&gt;" vertex="1">
          <mxGeometry x="660" y="{y_b}" width="340" height="70" as="geometry" />
        </mxCell>''')

    # Specs Card
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="text;html=1;whiteSpace=wrap;strokeColor=none;fillColor=none;align=left;verticalAlign=middle;rounded=0;fontSize=24;fontStyle=1;fontColor=#111111;" value="3. Technical Stack Specs" vertex="1">
      <mxGeometry x="570" y="115" width="420" height="30" as="geometry" />
    </mxCell>''')

    spec_val = (
        "&lt;div style=&quot;line-height:1.7;font-size:16px;&quot;&gt;"
        "&lt;b&gt;• Mobile Client:&lt;/b&gt; Flutter (Dart 3)&lt;br/&gt;"
        "&lt;b&gt;• Web Portal:&lt;/b&gt; React 18, Vite, Tailwind CSS&lt;br/&gt;"
        "&lt;b&gt;• Cloud BaaS:&lt;/b&gt; Supabase Cloud Platform&lt;br/&gt;"
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
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#666666;strokeWidth=1.5;align=left;verticalAlign=top;spacing=20;" value="{spec_val}" vertex="1">
      <mxGeometry x="570" y="165" width="420" height="390" as="geometry" />
    </mxCell>''')

    # Security & Compliance note
    sec_val = (
        "&lt;div style=&quot;line-height:1.5;font-size:15px;color:#333;&quot;&gt;"
        "&lt;b style=&quot;color:#b45f06;font-size:17px;&quot;&gt;🔒 Zero-Trust Privacy:&lt;/b&gt;&lt;br/&gt;"
        "All biometric vectors and civic telemetry are protected by PostgreSQL Row-Level Security (RLS) policies. Civilian facial data is isolated from public access."
        "&lt;/div&gt;"
    )
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;strokeWidth=1.5;align=left;verticalAlign=top;spacing=15;" value="{sec_val}" vertex="1">
      <mxGeometry x="570" y="580" width="420" height="150" as="geometry" />
    </mxCell>''')

    # Two-Way Verification Handshake note
    v_handshake = (
        "&lt;div style=&quot;line-height:1.5;font-size:15px;color:#333;&quot;&gt;"
        "&lt;b style=&quot;color:#1d3557;font-size:17px;&quot;&gt;🤝 Two-Way Verification:&lt;/b&gt;&lt;br/&gt;"
        "Field officer must upload work-done proof photo. Ticket cannot close until reporting citizen completes on-site camera re-audit within 100m GPS radius."
        "&lt;/div&gt;"
    )
    cells.append(f'''<mxCell id="{get_id()}" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#EFF6FC;strokeColor=#6c8ebf;strokeWidth=1.5;align=left;verticalAlign=top;spacing=15;" value="{v_handshake}" vertex="1">
      <mxGeometry x="570" y="755" width="420" height="175" as="geometry" />
    </mxCell>''')


    # ==========================================
    # 6. CONNECTOR ARROWS (Clean & Professional)
    # ==========================================

    # Arrow 1: Mobile App -> Supabase (Sync HTTPS Requests)
    cells.append(f'''<mxCell id="{get_id()}" edge="1" parent="1" source="{mobile_sub_id}" target="{supabase_id}" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;entryX=0.25;entryY=0;entryDx=0;entryDy=0;strokeWidth=3;strokeColor=#1d3557;endArrow=classic;endFill=1;">
      <mxGeometry relative="1" as="geometry" />
    </mxCell>''')

    # Arrow 2: Supabase -> Mobile App (Async Realtime CDC & Push updates)
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
          <mxPoint x="-1940" y="790" />
          <mxPoint x="-1940" y="-468" />
        </Array>
      </mxGeometry>
    </mxCell>''')

    # Build full XML
    xml_content = f'''<mxfile host="app.diagrams.net">
  <diagram name="UniSafe-System-Architecture" id="UniSafeFullSystemArch">
    <mxGraphModel dx="2800" dy="1600" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="0" pageScale="1" pageWidth="850" pageHeight="1100" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        {"".join(cells)}
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>'''

    # Save to project
    proj_path = r"c:\projects\Unisafe\unisafe_system_architecture.drawio"
    with open(proj_path, "w", encoding="utf-8") as f:
        f.write(xml_content)
    print(f"Saved to: {proj_path}")

    # Also save to Downloads for direct opening
    downloads_path = os.path.expanduser(r"~\Downloads\unisafe_system_architecture.drawio")
    try:
        with open(downloads_path, "w", encoding="utf-8") as f:
            f.write(xml_content)
        print(f"Saved to Downloads: {downloads_path}")
    except Exception as e:
        print(f"Downloads write skipped: {e}")

if __name__ == "__main__":
    create_drawio()
