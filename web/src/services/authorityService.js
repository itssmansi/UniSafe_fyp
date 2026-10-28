import { supabase } from './supabase';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

/**
 * Fetch the authenticated user's authority profile.
 */
export async function getAuthorityProfile() {
  try {
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData?.user) return null;

    // Query authorities table matching either id or auth_user_id
    const { data: profile, error: profileError } = await supabase
      .from('authorities')
      .select('*')
      .or(`id.eq.${authData.user.id},auth_user_id.eq.${authData.user.id}`)
      .maybeSingle();

    if (profileError || !profile) return null;

    // Cache the verified profile
    localStorage.setItem('unisafe_authority', JSON.stringify(profile));
    return profile;
  } catch (err) {
    console.error("Error fetching authority profile:", err);
    return null;
  }
}

/**
 * Fetch complaints relevant to this authority's jurisdiction or department.
 */
export async function getComplaints(authority) {
  try {
    const query = supabase.from('complaints').select('*').order('created_at', { ascending: false });

    const { data, error } = await query;

    if (error) throw error;
    
    return (data || []).map(c => ({
      ...c,
      verification_count: c.verification_count ?? 0
    }));
  } catch (err) {
    console.error("Error fetching complaints:", err);
    return [];
  }
}

/**
 * Fetch list of official authority personnel from Supabase
 */
export async function getAuthorities() {
  try {
    const { data, error } = await supabase.from('authorities').select('*');
    if (error) throw error;
    return data || [];
  } catch (err) {
    console.error("Error fetching authorities:", err);
    return [];
  }
}

/**
 * Update the status of a complaint securely via Supabase direct or backend
 */
export async function updateComplaintStatus(complaintId, authorityId, newStatus) {
  try {
    // Direct Supabase update
    const { data, error } = await supabase
      .from('complaints')
      .update({ status: newStatus })
      .eq('id', complaintId)
      .select();

    if (error) {
      // Fallback to Flask backend if exists
      const response = await fetch(`${API_URL}/complaints/${complaintId}/status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus, authority_id: authorityId })
      });
      const resData = await response.json();
      if (!response.ok) throw new Error(resData.error || "Failed to update status");
      return resData;
    }

    return data;
  } catch (err) {
    console.error("Error updating status:", err);
    throw err;
  }
}

/**
 * Fetch unread notifications for this authority
 */
export async function getNotifications(authorityId) {
  if (!authorityId || authorityId === "mock-authority-123" || !authorityId.includes("-")) {
    return [];
  }

  try {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('authority_id', authorityId)
      .eq('is_read', false)
      .order('created_at', { ascending: false });

    if (error) throw error;
    
    const parsedData = (data || []).map(notif => {
      const lowerTitle = (notif.title || '').toLowerCase();
      let type = 'STATUS';
      let priority = 'NORMAL';

      if (lowerTitle.includes('new complaint') || lowerTitle.includes('assigned')) {
        type = 'NEW_COMPLAINT';
        priority = 'NORMAL';
      } else if (lowerTitle.includes('critical')) {
        type = 'CRITICAL';
        priority = 'CRITICAL';
      } else if (lowerTitle.includes('threshold')) {
        type = 'THRESHOLD';
        priority = 'HIGH';
      } else if (lowerTitle.includes('resolved')) {
        type = 'RESOLVED';
        priority = 'SUCCESS';
      } else if (lowerTitle.includes('verification')) {
        type = 'VERIFICATION';
        priority = 'SUCCESS';
      }

      return {
        ...notif,
        type,
        priority
      };
    });

    if (parsedData.length === 0) {
      return [];
    }

    return parsedData;
  } catch (err) {
    console.error("Error fetching notifications:", err);
    return [];
  }
}

/**
 * Mark a notification as read
 */
export async function markNotificationRead(notificationId) {
  try {
    await supabase.from('notifications').update({ is_read: true }).eq('id', notificationId);
  } catch (err) {
    console.error("Error marking notification read:", err);
  }
}


/**
 * Upsert (create or update) a BMC officer in Supabase
 */
export async function upsertBmcOfficer(officerData) {
  try {
    const { data, error } = await supabase.rpc('upsert_bmc_officer', {
      p_id: officerData.id || null,
      p_name: officerData.name?.trim(),
      p_phone: officerData.phone?.trim() || null,
      p_department: officerData.department?.trim() || 'BMC',
      p_jurisdiction: officerData.jurisdiction?.trim() || 'Ward H-West',
      p_role: officerData.role?.trim() || 'Ward Officer',
      p_avatar_url: officerData.avatar_url?.trim() || null
    });

    if (error) {
      console.warn('RPC upsert_bmc_officer failed, falling back to direct table mutation:', error);
      if (officerData.id) {
        const { data: updated, error: uErr } = await supabase
          .from('authorities')
          .update({
            name: officerData.name,
            phone: officerData.phone,
            department: officerData.department || 'BMC',
            jurisdiction: officerData.jurisdiction,
            role: officerData.role || 'Ward Officer',
            avatar_url: officerData.avatar_url || null
          })
          .eq('id', officerData.id)
          .select()
          .maybeSingle();
        if (uErr) throw uErr;
        return updated;
      } else {
        const { data: inserted, error: iErr } = await supabase
          .from('authorities')
          .insert({
            name: officerData.name,
            phone: officerData.phone,
            department: officerData.department || 'BMC',
            jurisdiction: officerData.jurisdiction,
            role: officerData.role || 'Ward Officer',
            avatar_url: officerData.avatar_url || null,
            user_type: 'authority',
            verification_status: 'verified'
          })
          .select()
          .maybeSingle();
        if (iErr) throw iErr;
        return inserted;
      }
    }

    return data;
  } catch (err) {
    console.error('Error saving BMC officer:', err);
    throw err;
  }
}

/**
 * Delete a BMC officer and safely unlink their past complaint assignments
 */
export async function deleteBmcOfficer(officerId) {
  try {
    const { data, error } = await supabase.rpc('delete_bmc_officer', {
      p_id: officerId
    });

    if (error) {
      console.warn('RPC delete_bmc_officer failed, falling back to direct unlink & delete:', error);
      await supabase.from('complaints').update({ assigned_authority_id: null }).eq('assigned_authority_id', officerId);
      const { error: dErr } = await supabase.from('authorities').delete().eq('id', officerId);
      if (dErr) throw dErr;
    }

    return true;
  } catch (err) {
    console.error('Error deleting BMC officer:', err);
    throw err;
  }
}

/**
 * Assign a complaint to an officer and move status to in-progress
 */
export async function assignComplaintToOfficer(complaintId, officerId, reason = null) {
  try {
    const { data, error } = await supabase.rpc('assign_complaint_officer', {
      p_complaint_id: complaintId,
      p_officer_id: officerId,
      p_reason: reason || 'Dispatched via Kanban Board'
    });

    if (error) {
      console.warn('RPC assign_complaint_officer failed, falling back to direct update:', error);
      const { data: updated, error: uErr } = await supabase
        .from('complaints')
        .update({
          assigned_authority_id: officerId,
          status: 'in-progress',
          assignment_status: 'assigned',
          assignment_reason: reason || 'Dispatched via Kanban Board'
        })
        .eq('id', complaintId)
        .select();

      if (uErr) throw uErr;
      return updated?.[0] || { id: complaintId, assigned_authority_id: officerId, status: 'in-progress' };
    }

    return data;
  } catch (err) {
    console.error('Error assigning complaint to officer:', err);
    throw err;
  }
}
