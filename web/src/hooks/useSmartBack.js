import { useNavigate } from "react-router-dom";

/**
 * Hook providing a smart, resilient back navigation function.
 * 
 * If the user has in-app navigation history (window.history.state.idx > 0),
 * it goes back naturally via navigate(-1).
 * 
 * If the user opened the page directly, in a new tab, or after a page reload
 * (idx is 0 or undefined), it gracefully navigates to defaultFallback (default '/home').
 *
 * @param {string} defaultFallback - Fallback route if no history exists
 * @returns {(overrideFallback?: string) => void} - Safe back function
 */
export function useSmartBack(defaultFallback = "/home") {
  const navigate = useNavigate();

  return (overrideFallback) => {
    const fallback = overrideFallback || defaultFallback;
    try {
      const idx = window.history?.state?.idx;
      if (typeof idx === "number" && idx > 0) {
        navigate(-1);
      } else {
        navigate(fallback);
      }
    } catch {
      navigate(fallback);
    }
  };
}

export default useSmartBack;
