import React from 'react';

export default function LogoIcon({ className = "w-8 h-8" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 32 32"
      className={className}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <circle cx="16" cy="16" r="14" fill="#059669" />
      <circle cx="16" cy="16" r="11.5" fill="#FB7185" />
      <circle cx="16" cy="16" r="9.5" fill="#F43F5E" />
      <ellipse cx="12.5" cy="13.5" rx="1.2" ry="1.8" fill="#1E293B" transform="rotate(-15 12.5 13.5)" />
      <ellipse cx="19.5" cy="13.5" rx="1.2" ry="1.8" fill="#1E293B" transform="rotate(15 19.5 13.5)" />
      <ellipse cx="16" cy="19" rx="1.2" ry="1.8" fill="#1E293B" />
    </svg>
  );
}
