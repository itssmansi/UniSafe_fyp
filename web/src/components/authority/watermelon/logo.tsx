import type { SVGProps } from 'react'

export function UniSafeLogo(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      viewBox="0 0 28 28"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect width="28" height="28" rx="8" fill="#1E3A5F" />
      <path
        d="M14 5.5L20.5 8.5V14.2C20.5 18.2 17.7 21.8 14 22.8C10.3 21.8 7.5 18.2 7.5 14.2V8.5L14 5.5Z"
        fill="#10B981"
        fillOpacity="0.25"
        stroke="#10B981"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <path
        d="M11.5 13.8L13.2 15.5L16.8 11.5"
        stroke="#FFFFFF"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

export const MedeskLogo = UniSafeLogo
