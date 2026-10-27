import { apiRequest } from './api';

export async function fetchHeatmapData() {
  try {
    const data = await apiRequest('/heatmap');
    if (data && data.status === 'success') {
      return data.zones || [];
    }
    return [];
  } catch (error) {
    console.error('Error fetching heatmap data from backend:', error);
    throw error;
  }
}
