import { useState, useEffect } from 'react';

/**
 * Isolated hook for role-based Heatmap UI adaptation.
 * 
 * Safely inspects if an authenticated user object exists in local/session storage,
 * defaulting safely to 'citizen' (read-only mode) if no role is available.
 */
export function useUserRole() {
  const [roleInfo, setRoleInfo] = useState({
    role: 'citizen',
    isAuthority: false,
    isCitizen: true,
  });

  useEffect(() => {
    try {
      // Check existing storage keys if set by auth module
      const rawUser = localStorage.getItem('user') || localStorage.getItem('unisafe_authority') || sessionStorage.getItem('user');
      let role = 'citizen';

      if (rawUser) {
        const parsed = JSON.parse(rawUser);
        if (parsed && (parsed.role || parsed.user_type || parsed.department)) {
          role = String(parsed.role || parsed.user_type || 'authority').toLowerCase();
        }
      }

      const isAuthority = role === 'authority' || role === 'admin';
      const isCitizen = !isAuthority;

      setRoleInfo({
        role: isAuthority ? 'authority' : 'citizen',
        isAuthority,
        isCitizen,
      });
    } catch {
      // Fallback safely to citizen read-only mode on any error
      setRoleInfo({
        role: 'citizen',
        isAuthority: false,
        isCitizen: true,
      });
    }
  }, []);

  return roleInfo;
}
