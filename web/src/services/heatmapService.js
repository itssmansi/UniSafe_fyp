import { apiRequest } from './api';
import { supabase } from './supabase';

/**
 * Client-side DBSCAN-style centroid clustering fallback.
 * Groups real complaints within ~500m into hotspot zones when the backend ML worker hasn't populated heatmap_zones.
 */
function clusterComplaintsIntoZones(complaints) {
  const valid = complaints.filter(
    (c) => c.latitude && c.longitude && !isNaN(Number(c.latitude)) && !isNaN(Number(c.longitude))
  );

  if (valid.length === 0) return [];

  const clusters = [];
  const visited = new Set();

  for (let i = 0; i < valid.length; i++) {
    if (visited.has(i)) continue;
    const c1 = valid[i];
    const group = [c1];
    visited.add(i);

    const lat1 = Number(c1.latitude);
    const lng1 = Number(c1.longitude);

    for (let j = i + 1; j < valid.length; j++) {
      if (visited.has(j)) continue;
      const c2 = valid[j];
      const lat2 = Number(c2.latitude);
      const lng2 = Number(c2.longitude);

      const dLat = (lat1 - lat2) * 111000;
      const dLng = (lng1 - lng2) * 105000;
      const distMeters = Math.sqrt(dLat * dLat + dLng * dLng);

      if (distMeters <= 600) {
        group.push(c2);
        visited.add(j);
      }
    }

    const avgLat = group.reduce((s, c) => s + Number(c.latitude), 0) / group.length;
    const avgLng = group.reduce((s, c) => s + Number(c.longitude), 0) / group.length;

    const catCounts = {};
    group.forEach((c) => {
      const cat = c.category || 'infrastructure';
      catCounts[cat] = (catCounts[cat] || 0) + 1;
    });
    let dominantCat = group[0].category || 'infrastructure';
    let maxC = 0;
    for (const [k, v] of Object.entries(catCounts)) {
      if (v > maxC) {
        maxC = v;
        dominantCat = k;
      }
    }

    const count = group.length;
    let severity = 'LOW';
    let risk_score = Math.min(30 + count * 8, 98);
    if (count >= 5 || group.some((c) => (c.upvote_count || 0) >= 3)) {
      severity = 'HIGH';
      risk_score = Math.min(75 + count * 4, 99);
    } else if (count >= 2) {
      severity = 'MEDIUM';
      risk_score = Math.min(50 + count * 6, 85);
    }

    clusters.push({
      id: `zone-cluster-${i}-${group[0].id || i}`,
      zone_type: dominantCat,
      severity,
      complaint_count: count,
      radius_meters: Math.min(180 + count * 40, 500),
      latitude: avgLat,
      longitude: avgLng,
      risk_score,
      assigned_authority_id: group[0].assigned_officer_id || null,
      complaints: group
    });
  }

  // Sort HIGH severity first, then by complaint count
  const severityOrder = { HIGH: 1, MEDIUM: 2, LOW: 3 };
  clusters.sort((a, b) => {
    const sDiff = (severityOrder[a.severity] || 4) - (severityOrder[b.severity] || 4);
    if (sDiff !== 0) return sDiff;
    return (b.complaint_count || 0) - (a.complaint_count || 0);
  });

  return clusters;
}

export async function fetchHeatmapData() {
  let zones = [];
  let complaints = [];

  // 1. Try Flask API if available
  try {
    const [heatmapRes, complaintsRes] = await Promise.allSettled([
      apiRequest('/heatmap'),
      apiRequest('/complaints')
    ]);

    if (heatmapRes.status === 'fulfilled' && heatmapRes.value?.status === 'success') {
      zones = heatmapRes.value.zones || [];
    }

    if (complaintsRes.status === 'fulfilled' && Array.isArray(complaintsRes.value)) {
      complaints = complaintsRes.value;
    }
  } catch (err) {
    console.warn('Backend API not responding, will use Supabase direct query:', err);
  }

  // 2. Direct Supabase query if complaints were not retrieved from API
  if (!complaints || complaints.length === 0) {
    try {
      const { data, error } = await supabase
        .from('complaints')
        .select('*')
        .order('created_at', { ascending: false });

      if (!error && Array.isArray(data)) {
        complaints = data;
      }
    } catch (err) {
      console.error('Error fetching complaints directly from Supabase:', err);
    }
  }

  // 3. Direct Supabase query for heatmap_zones if zones not retrieved from API
  if (!zones || zones.length === 0) {
    try {
      const { data, error } = await supabase
        .from('heatmap_zones')
        .select('*');

      if (!error && Array.isArray(data) && data.length > 0) {
        zones = data;
      }
    } catch (err) {
      console.error('Error fetching heatmap_zones directly from Supabase:', err);
    }
  }

  // 4. If zones still empty, dynamically cluster real complaints into hotspots
  if ((!zones || zones.length === 0) && complaints.length > 0) {
    zones = clusterComplaintsIntoZones(complaints);
  }

  // 5. Format points for Leaflet.heat
  const complaintPoints = complaints
    .filter((c) => c.latitude && c.longitude && !isNaN(Number(c.latitude)) && !isNaN(Number(c.longitude)))
    .map((c) => {
      const upvotes = Number(c.upvote_count) || 0;
      const weight = Math.min(0.4 + upvotes * 0.1, 0.9);
      return [Number(c.latitude), Number(c.longitude), weight, c];
    });

  const zonePoints = zones
    .filter((z) => z.latitude && z.longitude && !isNaN(Number(z.latitude)) && !isNaN(Number(z.longitude)))
    .map((z) => {
      const count = Number(z.complaint_count) || 0;
      let weight = 0.55;
      if (z.severity === 'HIGH') weight = 0.95;
      else if (z.severity === 'MEDIUM') weight = 0.75;
      else weight = 0.45;

      if (count >= 10) weight = Math.min(weight + 0.1, 1.0);

      return [Number(z.latitude), Number(z.longitude), weight, z];
    });

  return {
    zones,
    complaints,
    complaintPoints,
    zonePoints
  };
}
