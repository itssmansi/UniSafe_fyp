import React from 'react';

export const Avatar = ({ children, className = "" }) => {
  return (
    <div className={`relative flex shrink-0 overflow-hidden rounded-full ${className}`}>
      {children}
    </div>
  );
};

export const AvatarImage = ({ src, alt = "" }) => {
  return <img src={src} alt={alt} className="aspect-square h-full w-full object-cover" />;
};

export const AvatarFallback = ({ children, className = "" }) => {
  return (
    <div className={`flex h-full w-full items-center justify-center rounded-full bg-slate-200 text-slate-500 text-[9px] font-medium ${className}`}>
      {children}
    </div>
  );
};
