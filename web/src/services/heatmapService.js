import { supabase } from './supabase.js';

/**
 * Category Pillar Classifications
 */
export const CATEGORY_GROUPS = {
  CIVIC: 'civic',
  SAFETY: 'safety',
  MISSING_PERSON: 'missing_person',
};

export const CIVIC_SUBTYPES = [
  'greenery',
  'infrastructure',
  'sanitation',
  'garbage',
  'road',
  'potholes',
  'drainage',
  'water',
  'water logging',
  'streetlight',
  'nonfunctional street lights',
  'road damage',
  'garbage scattered on road',
  'public washroom cleanliness',
  'open manholes',
  'non-existent footpath',
  'garbage dumping near beach/river',
  'poor landscape maintenance',
];

export const SAFETY_SUBTYPES = [
  'safety',
  'theft',
  'theft / robbery',
  'assault / violence',
  'harassment / eve-teasing',
  'women safety',
  'stray animal threat',
  'illegal parking',
];

/**
 * Helper to extract main display category
 */
export function extractMainCategory(item) {
  if (!item) return 'Infrastructure';
  const c = (item.category || '').toString().trim().toLowerCase();
  if (c === 'missing_person' || c === 'missing person') return 'Missing Persons';
  if (c.includes('greenery')) return 'Greenery';
  if (c.includes('sanitation') || c.includes('garbage')) return 'Sanitation';
  if (c.includes('safety') || SAFETY_SUBTYPES.some((s) => c.includes(s))) return 'Safety';
  return 'Infrastructure';
}

/**
 * Helper to extract sub-category name
 */
export function extractSubCategory(item) {
  if (!item) return 'General';
  const text = `${item.title || ''} ${item.description || ''} ${item.category || ''}`.toLowerCase();
  
  // Infrastructure subcategories
  if (text.includes('pothole') || text.includes('road damage') || text.includes('potholes')) return 'Roads & Potholes';
  if (text.includes('water log') || text.includes('flood')) return 'Water Logging';
  if (text.includes('drainage') || text.includes('manhole') || text.includes('open manholes')) return 'Drainage';
  if (text.includes('water supply') || text.includes('pipeline') || text.includes('pipe burst')) return 'Water Supply';
  if (text.includes('street light') || text.includes('streetlights') || text.includes('lighting') || text.includes('dark spot')) return 'Streetlights';
  if (text.includes('footpath') || text.includes('sidewalk')) return 'Footpaths & Walkways';
  
  // Sanitation subcategories
  if (text.includes('toilet') || text.includes('washroom')) return 'Public Washrooms';
  if (text.includes('dump') || text.includes('beach') || text.includes('river')) return 'Garbage Dumping';
  if (text.includes('garbage') || text.includes('waste')) return 'Garbage Scattered on Road';
  
  // Greenery subcategories
  if (text.includes('encroach') || text.includes('cutting')) return 'Encroachment on Green Spaces';
  if (text.includes('fallen tree') || text.includes('branch') || text.includes('tree trimming')) return 'Tree Trimming / Fallen Trees';
  if (text.includes('landscape') || text.includes('garden')) return 'Park & Landscape Maintenance';
  
  // Safety subcategories
  if (text.includes('assault') || text.includes('violence') || text.includes('fight')) return 'Assault / Violence';
  if (text.includes('theft') || text.includes('robbery') || text.includes('snatching')) return 'Theft / Robbery';
  if (text.includes('harass') || text.includes('eve-teasing') || text.includes('stalking')) return 'Harassment / Eve-Teasing';
  if (text.includes('child')) return 'Child Safety Concern';
  if (text.includes('women')) return 'Women Safety';
  if (text.includes('animal') || text.includes('dog threat') || text.includes('stray')) return 'Stray Animal Threat';
  if (text.includes('parking') || text.includes('illegal parking')) return 'Illegal Parking';
  if (text.includes('wire') || text.includes('electrical')) return 'Electrical Hazard';
  
  // Missing persons
  if (text.includes('missing')) return 'Active Cases';

  // Fallback to first line or generic
  const firstLine = (item.description || '').trim().split('\n')[0].trim();
  if (firstLine && firstLine.length >= 3 && firstLine.length <= 30) {
    return firstLine;
  }
  return 'General Infrastructure';
}

/**
 * Helper to classify category into pillar
 */
export function classifyCategoryGroup(category) {
  if (!category) return CATEGORY_GROUPS.CIVIC;
  const c = category.toString().trim().toLowerCase();
  if (c === 'missing_person' || c === 'missing person') return CATEGORY_GROUPS.MISSING_PERSON;
  if (SAFETY_SUBTYPES.some((s) => c.includes(s) || s.includes(c))) return CATEGORY_GROUPS.SAFETY;
  return CATEGORY_GROUPS.CIVIC;
}

/**
 * Haversine distance in meters
 */
export function calculateHaversineDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371008.8; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Deterministic Severity Scoring Algorithm (from Hackathon backend)
 * 1. Density Score: up to 40 pts (20+ items reaches max 40)
 * 2. Upvote Score: up to 25 pts (150+ upvotes reaches max 25)
 * 3. Unresolved Status: up to 20 pts (open/pending ratio * 20)
 * 4. Recency Score: up to 15 pts (<=7d: 1.0, <=14d: 0.8, <=30d: 0.5, >30d: 0.2)
 * Total: 0–100. Severity: HIGH (>=60), MEDIUM (>=30), LOW (<30)
 */
export function calculateClusterSeverity(items, referenceDate = new Date()) {
  const count = items.length;
  if (count === 0) {
    return {
      riskScore: 0,
      severity: 'LOW',
      breakdown: { density: 0, upvotes: 0, unresolved: 0, recency: 0 },
    };
  }

  // 1. Density (max 40)
  const densityScore = Math.min(count / 20.0, 1.0) * 40.0;

  // 2. Upvotes (max 25)
  const totalUpvotes = items.reduce(
    (sum, item) => sum + (Number(item.upvote_count) || 0),
    0
  );
  const upvoteScore = Math.min(totalUpvotes / 150.0, 1.0) * 25.0;

  // 3. Unresolved / Open status (max 20)
  const unresolvedCount = items.filter((item) => {
    const s = (item.status || 'open').toString().toLowerCase();
    return ['open', 'pending', 'in_progress', 'manual_review', 'investigating', 'missing'].includes(s);
  }).length;
  const unresolvedScore = (unresolvedCount / count) * 20.0;

  // 4. Recency (max 15)
  let recencyFactors = [];
  for (const item of items) {
    const dateStr = item.created_at || item.last_seen_date;
    if (!dateStr) {
      recencyFactors.push(0.5);
      continue;
    }
    const daysDiff = (referenceDate - new Date(dateStr)) / (1000 * 3600 * 24);
    if (daysDiff <= 7) recencyFactors.push(1.0);
    else if (daysDiff <= 14) recencyFactors.push(0.8);
    else if (daysDiff <= 30) recencyFactors.push(0.5);
    else recencyFactors.push(0.2);
  }
  const avgRecency = recencyFactors.reduce((a, b) => a + b, 0) / count;
  const recencyScore = avgRecency * 15.0;

  const totalScore = Math.round((densityScore + upvoteScore + unresolvedScore + recencyScore) * 100) / 100;

  let severity = 'LOW';
  if (totalScore >= 60.0) severity = 'HIGH';
  else if (totalScore >= 30.0) severity = 'MEDIUM';

  return {
    riskScore: totalScore,
    severity,
    breakdown: {
      density: Math.round(densityScore * 10) / 10,
      upvotes: Math.round(upvoteScore * 10) / 10,
      unresolved: Math.round(unresolvedScore * 10) / 10,
      recency: Math.round(recencyScore * 10) / 10,
      count,
      totalUpvotes,
      unresolvedCount,
    },
  };
}

/**
 * Fast DBSCAN clustering on spatial coordinates
 */
export function performSpatialClustering(points, epsMeters = 500, minSamples = 2) {
  const n = points.length;
  const visited = new Array(n).fill(false);
  const clusterLabels = new Array(n).fill(-1);
  let clusterId = 0;

  for (let i = 0; i < n; i++) {
    if (visited[i]) continue;
    visited[i] = true;

    // Find neighbors within epsMeters
    const neighbors = [];
    for (let j = 0; j < n; j++) {
      const d = calculateHaversineDistanceMeters(
        points[i].latitude,
        points[i].longitude,
        points[j].latitude,
        points[j].longitude
      );
      if (d <= epsMeters) {
        neighbors.push(j);
      }
    }

    if (neighbors.length < minSamples) {
      clusterLabels[i] = -1;
    } else {
      clusterLabels[i] = clusterId;
      const queue = neighbors.filter((idx) => idx !== i);

      for (let k = 0; k < queue.length; k++) {
        const qIdx = queue[k];
        if (!visited[qIdx]) {
          visited[qIdx] = true;
          const qNeighbors = [];
          for (let j = 0; j < n; j++) {
            const d = calculateHaversineDistanceMeters(
              points[qIdx].latitude,
              points[qIdx].longitude,
              points[j].latitude,
              points[j].longitude
            );
            if (d <= epsMeters) {
              qNeighbors.push(j);
            }
          }

          if (qNeighbors.length >= minSamples) {
            for (const qn of qNeighbors) {
              if (!queue.includes(qn) && qn !== i) {
                queue.push(qn);
              }
            }
          }
        }
        if (clusterLabels[qIdx] === -1) {
          clusterLabels[qIdx] = clusterId;
        }
      }
      clusterId++;
    }
  }

  return { clusterLabels, numClusters: clusterId };
}

/**
 * Fetch and construct role-specific Heatmap data from Supabase
 *
 * @param {Object} options
 * @param {Object} [options.authority] - Authenticated authority profile (for BMC or Police dashboard)
 * @param {string} [options.role] - 'citizen' | 'authority'
 * @param {string} [options.timeRange] - 'all' | '30d' | '7d'
 * @param {string} [options.jurisdiction] - Optional ward or police station filter
 */
export async function fetchHeatmapData({ authority = null, role = 'authority', timeRange = 'all', jurisdiction = null } = {}) {
  try {
    const isPolice = authority?.department?.toLowerCase().includes('police');
    const isBMC =
      authority?.department?.toLowerCase().includes('bmc') ||
      authority?.department?.toLowerCase().includes('municipal');

    // 1. Fetch complaints from Supabase
    let complaintsQuery = supabase
      .from('complaints')
      .select('id, category, title, description, latitude, longitude, address, status, upvote_count, created_at, department, jurisdiction, assigned_authority_id')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null);

    // Apply Time Range Filter
    if (timeRange === '7d') {
      const d = new Date();
      d.setDate(d.getDate() - 7);
      complaintsQuery = complaintsQuery.gte('created_at', d.toISOString());
    } else if (timeRange === '30d') {
      const d = new Date();
      d.setDate(d.getDate() - 30);
      complaintsQuery = complaintsQuery.gte('created_at', d.toISOString());
    }

    const { data: rawComplaints, error: compError } = await complaintsQuery;
    if (compError) throw compError;

    // 2. Role-based complaint filtering:
    let filteredComplaints = rawComplaints || [];

    if (isBMC) {
      // BMC sees only civic complaints: Greenery, Infrastructure, Sanitation
      filteredComplaints = filteredComplaints.filter((c) => {
        const group = classifyCategoryGroup(c.category);
        if (group !== CATEGORY_GROUPS.CIVIC) return false;
        if (c.department && c.department.toLowerCase() === 'police') return false;
        // Match authority jurisdiction if configured
        const targetJurisdiction = jurisdiction || authority?.jurisdiction;
        if (targetJurisdiction && targetJurisdiction !== 'All' && c.jurisdiction) {
          return c.jurisdiction.toLowerCase().includes(targetJurisdiction.toLowerCase());
        }
        return true;
      });
    } else if (isPolice) {
      // Police sees only safety complaints
      filteredComplaints = filteredComplaints.filter((c) => {
        const group = classifyCategoryGroup(c.category);
        if (group !== CATEGORY_GROUPS.SAFETY) return false;
        const targetJurisdiction = jurisdiction || authority?.jurisdiction;
        if (targetJurisdiction && targetJurisdiction !== 'All' && c.jurisdiction) {
          return c.jurisdiction.toLowerCase().includes(targetJurisdiction.toLowerCase());
        }
        return true;
      });
    }

    // 3. Fetch missing persons for Police and Citizen (BMC is NOT permitted)
    let missingPersons = [];
    if (!isBMC) {
      let mpQuery = supabase
        .from('missing_persons')
        .select('id, full_name, age, gender, last_seen_date, latitude, longitude, description, status, case_code, created_at')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null);

      if (timeRange === '7d') {
        const d = new Date();
        d.setDate(d.getDate() - 7);
        mpQuery = mpQuery.gte('created_at', d.toISOString());
      } else if (timeRange === '30d') {
        const d = new Date();
        d.setDate(d.getDate() - 30);
        mpQuery = mpQuery.gte('created_at', d.toISOString());
      }

      const { data: mpData, error: mpError } = await mpQuery;
      if (!mpError && mpData) {
        missingPersons = mpData.map((p) => ({
          ...p,
          category: 'Missing Person',
          categoryGroup: CATEGORY_GROUPS.MISSING_PERSON,
          title: `Missing Person Case #${p.case_code || p.id.slice(0, 6)}: ${p.full_name}`,
          upvote_count: 5,
        }));
      }
    }

    // Combine permitted dataset with rich categorization
    const combinedPoints = [
      ...filteredComplaints.map((c) => ({
        ...c,
        categoryGroup: classifyCategoryGroup(c.category),
        mainCategory: extractMainCategory(c),
        subCategory: extractSubCategory(c),
      })),
      ...missingPersons.map((p) => ({
        ...p,
        categoryGroup: CATEGORY_GROUPS.MISSING_PERSON,
        mainCategory: 'Missing Persons',
        subCategory: 'Active Cases',
      })),
    ];

    if (combinedPoints.length === 0) {
      const empty = [];
      empty.categoryHierarchy = { totalCount: 0, mainCategories: {}, subCategoriesByMain: {} };
      empty.allPoints = [];
      return empty;
    }

    // Compute Category Hierarchy and Counts for UI Layer Card
    const categoryHierarchy = {
      totalCount: combinedPoints.length,
      mainCategories: {},
      subCategoriesByMain: {},
    };

    combinedPoints.forEach((pt) => {
      const main = pt.mainCategory;
      const sub = pt.subCategory;
      categoryHierarchy.mainCategories[main] = (categoryHierarchy.mainCategories[main] || 0) + 1;
      if (!categoryHierarchy.subCategoriesByMain[main]) {
        categoryHierarchy.subCategoriesByMain[main] = {};
      }
      categoryHierarchy.subCategoriesByMain[main][sub] = (categoryHierarchy.subCategoriesByMain[main][sub] || 0) + 1;
    });

    // 4. Run Spatial DBSCAN Clustering
    const { clusterLabels } = performSpatialClustering(combinedPoints, 500, 2);

    const clusterBuckets = {};
    const unclusteredPoints = [];

    combinedPoints.forEach((point, idx) => {
      const cId = clusterLabels[idx];
      if (cId >= 0) {
        if (!clusterBuckets[cId]) clusterBuckets[cId] = [];
        clusterBuckets[cId].push(point);
      } else {
        unclusteredPoints.push(point);
      }
    });

    const zones = [];

    // Process each cluster into a Heatmap Zone
    Object.entries(clusterBuckets).forEach(([clusterId, items]) => {
      const count = items.length;
      const centerLat = items.reduce((s, it) => s + it.latitude, 0) / count;
      const centerLon = items.reduce((s, it) => s + it.longitude, 0) / count;

      // Calculate radius
      let maxDist = 0;
      for (const it of items) {
        const d = calculateHaversineDistanceMeters(centerLat, centerLon, it.latitude, it.longitude);
        if (d > maxDist) maxDist = d;
      }
      const radiusMeters = Math.max(Math.ceil(maxDist), 150);

      // Dominant category & group
      const catCounts = {};
      const groupCounts = {};
      const mainCounts = {};
      const subCounts = {};
      for (const it of items) {
        catCounts[it.category] = (catCounts[it.category] || 0) + 1;
        groupCounts[it.categoryGroup] = (groupCounts[it.categoryGroup] || 0) + 1;
        if (it.mainCategory) mainCounts[it.mainCategory] = (mainCounts[it.mainCategory] || 0) + 1;
        if (it.subCategory) subCounts[it.subCategory] = (subCounts[it.subCategory] || 0) + 1;
      }
      const dominantCategory = Object.keys(catCounts).reduce((a, b) =>
        catCounts[a] > catCounts[b] ? a : b
      );
      const dominantGroup = Object.keys(groupCounts).reduce((a, b) =>
        groupCounts[a] > groupCounts[b] ? a : b
      );
      const dominantMain = Object.keys(mainCounts).length > 0
        ? Object.keys(mainCounts).reduce((a, b) => (mainCounts[a] > mainCounts[b] ? a : b))
        : dominantCategory;
      const dominantSub = Object.keys(subCounts).length > 0
        ? Object.keys(subCounts).reduce((a, b) => (subCounts[a] > subCounts[b] ? a : b))
        : dominantCategory;

      // Severity and risk score
      const scoreResult = calculateClusterSeverity(items);

      zones.push({
        id: `cluster-${clusterId}`,
        zone_type: dominantCategory,
        main_category: dominantMain,
        sub_category: dominantSub,
        category_group: dominantGroup,
        latitude: Math.round(centerLat * 1000000) / 1000000,
        longitude: Math.round(centerLon * 1000000) / 1000000,
        radius_meters: radiusMeters,
        severity: dominantGroup === CATEGORY_GROUPS.MISSING_PERSON ? 'HIGH' : scoreResult.severity,
        risk_score: dominantGroup === CATEGORY_GROUPS.MISSING_PERSON ? 85.0 : scoreResult.riskScore,
        complaint_count: count,
        breakdown: scoreResult.breakdown,
        assigned_authority_id: items[0]?.assigned_authority_id || null,
        jurisdiction: items[0]?.jurisdiction || null,
        complaints: items.slice(0, 10).map((it) => ({
          id: it.id,
          title: it.title || `${it.category} issue`,
          category: it.category,
          main_category: it.mainCategory,
          sub_category: it.subCategory,
          status: it.status,
          created_at: it.created_at || it.last_seen_date,
          address: it.address || null,
        })),
      });
    });

    // Also include single/unclustered isolated incidents if significant
    unclusteredPoints.forEach((point, idx) => {
      const isMissingPerson = point.categoryGroup === CATEGORY_GROUPS.MISSING_PERSON;
      const scoreResult = calculateClusterSeverity([point]);

      zones.push({
        id: `single-${point.id || idx}`,
        zone_type: point.category || 'Incident',
        main_category: point.mainCategory || 'Incident',
        sub_category: point.subCategory || 'General',
        category_group: point.categoryGroup,
        latitude: point.latitude,
        longitude: point.longitude,
        radius_meters: isMissingPerson ? 200 : 120,
        severity: isMissingPerson ? 'HIGH' : scoreResult.severity,
        risk_score: isMissingPerson ? 75.0 : scoreResult.riskScore,
        complaint_count: 1,
        breakdown: scoreResult.breakdown,
        assigned_authority_id: point.assigned_authority_id || null,
        jurisdiction: point.jurisdiction || null,
        complaints: [
          {
            id: point.id,
            title: point.title || `${point.category} incident`,
            category: point.category,
            main_category: point.mainCategory,
            sub_category: point.subCategory,
            status: point.status,
            created_at: point.created_at || point.last_seen_date,
            address: point.address || null,
          },
        ],
      });
    });

    // Sort: HIGH > MEDIUM > LOW
    const order = { HIGH: 1, MEDIUM: 2, LOW: 3 };
    zones.sort((a, b) => (order[a.severity] || 4) - (order[b.severity] || 4));

    zones.categoryHierarchy = categoryHierarchy;
    zones.allPoints = combinedPoints;

    return zones;
  } catch (error) {
    console.error('Error fetching role-aware heatmap data from Supabase:', error);
    return [];
  }
}
