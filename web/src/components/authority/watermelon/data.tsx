import type { ComponentType, SVGProps } from 'react'
import {
  CalendarDotsIcon,
  HomeIcon,
  SearchIcon,
  UserIcon,
  ClockIcon,
} from './icons'
import {
  AlertCircle,
  BarChart3,
  Building2,
  CheckCircle2,
  Flame,
  Kanban,
  MapPin,
  ShieldCheck,
  Truck,
  Wrench,
  Zap,
} from 'lucide-react'

export type NavIcon = ComponentType<SVGProps<SVGSVGElement>> | ComponentType<{ className?: string }>

export type NavigationItem = {
  name: string
  href: string
  icon: NavIcon
  badge?: string | number
}

export type NavigationGroup = {
  label: string
  collapsible?: boolean
  items: NavigationItem[]
}

export const navigationGroups: NavigationGroup[] = [
  {
    label: 'Civic Operations',
    items: [
      { name: 'Operations Hub', href: '/', icon: HomeIcon },
      { name: 'Dispatch Kanban', href: '/kanban', icon: Kanban },
      { name: 'Heatmap & Hotspots', href: '/heatmap', icon: Flame, badge: 'ML' },
    ],
  },
  {
    label: 'Oversight & Verification',
    collapsible: true,
    items: [
      { name: 'Resolution Tracking', href: '/verification', icon: CheckCircle2 },
      { name: 'Department SLA', href: '/performance', icon: BarChart3 },
      { name: 'Critical Escalations', href: '/escalations', icon: AlertCircle, badge: 'Alert' },
    ],
  },
  {
    label: 'System & Jurisdiction',
    items: [
      { name: 'BMC Officers', href: '/bmc-officers', icon: Building2 },
      { name: 'Ward & Profile', href: '/settings', icon: UserIcon },
    ],
  },
]

export const currentUser = {
  name: 'Inspector Rajesh Kadam',
  email: 'r.kadam@unisafe.mumbai.gov.in',
  role: 'Sr. Inspector & Zonal Head',
  department: 'Mumbai Police & Civic Vigilance',
  jurisdiction: 'Zone 4 (Bandra - Khar - Santa Cruz)',
  avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
}

export const dashboardMetrics = [
  {
    title: 'Active Complaints',
    value: '248',
    change: '+12.4%',
    changeType: 'increase',
    period: 'vs last week',
    lastSixDays: [32, 45, 28, 54, 48, 41],
  },
  {
    title: 'Avg. Resolution SLA',
    value: '4.2 hrs',
    change: '-18.5%',
    changeType: 'decrease',
    period: 'turnaround time',
    lastSixDays: [6.1, 5.4, 4.8, 5.0, 4.4, 4.2],
  },
  {
    title: 'Citizen Verification',
    value: '96.8%',
    change: '+3.8%',
    changeType: 'increase',
    period: 'satisfaction rate',
    lastSixDays: [91, 92, 94, 95, 96, 97],
  },
  {
    title: 'Active ML Hotspots',
    value: '14 Zones',
    change: '-2 clusters',
    changeType: 'decrease',
    period: 'DBSCAN clustered',
    lastSixDays: [19, 18, 17, 16, 15, 14],
  },
] as const

export const dashboardTimelineRanges = [
  { label: 'Past 7 Days', value: '7D' },
  { label: 'Past 14 Days', value: '14D' },
  { label: 'Past 30 Days', value: '30D' },
  { label: 'Past 90 Days', value: '90D' },
] as const

export type DashboardTimelineRange = (typeof dashboardTimelineRanges)[number]['value']

export const dashboardTimelineData: Record<
  DashboardTimelineRange,
  Array<{
    date: string
    scheduled: number
    completed: number
    noShow: number
  }>
> = {
  '7D': [
    { date: 'Aug 29', scheduled: 28, completed: 34, noShow: 4 },
    { date: 'Aug 30', scheduled: 35, completed: 38, noShow: 6 },
    { date: 'Aug 31', scheduled: 42, completed: 45, noShow: 5 },
    { date: 'Sep 01', scheduled: 38, completed: 50, noShow: 7 },
    { date: 'Sep 02', scheduled: 46, completed: 52, noShow: 4 },
    { date: 'Sep 03', scheduled: 51, completed: 58, noShow: 8 },
    { date: 'Sep 04', scheduled: 48, completed: 62, noShow: 3 },
  ],
  '14D': [
    { date: 'Aug 22', scheduled: 24, completed: 28, noShow: 3 },
    { date: 'Aug 24', scheduled: 31, completed: 33, noShow: 5 },
    { date: 'Aug 26', scheduled: 29, completed: 36, noShow: 4 },
    { date: 'Aug 28', scheduled: 38, completed: 41, noShow: 6 },
    { date: 'Aug 30', scheduled: 35, completed: 38, noShow: 6 },
    { date: 'Sep 01', scheduled: 38, completed: 50, noShow: 7 },
    { date: 'Sep 04', scheduled: 48, completed: 62, noShow: 3 },
  ],
  '30D': [
    { date: 'Aug 05', scheduled: 120, completed: 145, noShow: 18 },
    { date: 'Aug 12', scheduled: 140, completed: 160, noShow: 22 },
    { date: 'Aug 19', scheduled: 165, completed: 180, noShow: 25 },
    { date: 'Aug 26', scheduled: 180, completed: 210, noShow: 20 },
    { date: 'Sep 02', scheduled: 205, completed: 235, noShow: 19 },
  ],
  '90D': [
    { date: 'Jun W1', scheduled: 450, completed: 510, noShow: 65 },
    { date: 'Jun W3', scheduled: 520, completed: 580, noShow: 72 },
    { date: 'Jul W1', scheduled: 610, completed: 670, noShow: 80 },
    { date: 'Jul W3', scheduled: 640, completed: 710, noShow: 88 },
    { date: 'Aug W1', scheduled: 710, completed: 800, noShow: 79 },
    { date: 'Aug W3', scheduled: 780, completed: 890, noShow: 85 },
  ],
}

export const dashboardDepartmentLoad = [
  {
    name: 'Roads & Infrastructure',
    code: 'BMC-RD',
    percentage: 84,
    color: 'var(--dashboard-scheduled)',
    total: 48,
    completed: 40,
  },
  {
    name: 'Solid Waste Management',
    code: 'BMC-SWM',
    percentage: 68,
    color: 'var(--dashboard-completed)',
    total: 38,
    completed: 26,
  },
  {
    name: 'Water & Sewage Supply',
    code: 'BMC-WTR',
    percentage: 76,
    color: 'var(--dashboard-no-show)',
    total: 25,
    completed: 19,
  },
  {
    name: 'Police Civic Vigilance',
    code: 'MUM-POL',
    percentage: 92,
    color: 'var(--dashboard-scheduled)',
    total: 50,
    completed: 46,
  },
  {
    name: 'Street Lighting & Power',
    code: 'BMC-ELE',
    percentage: 48,
    color: 'var(--dashboard-secondary)',
    total: 21,
    completed: 10,
  },
] as const

export const dashboardAppointmentStats = [
  { label: 'Dispatched Today', value: '48', change: '+14%', status: 'scheduled' },
  { label: 'Resolved & Closed', value: '62', change: '+22%', status: 'completed' },
  { label: 'Escalated / Pending', value: '3', change: '-40%', status: 'noShow' },
] as const

export const dashboardAppointmentVolume = [
  { day: 'Mon', scheduled: 32, completed: 36, noShow: 4 },
  { day: 'Tue', scheduled: 38, completed: 42, noShow: 5 },
  { day: 'Wed', scheduled: 41, completed: 48, noShow: 3 },
  { day: 'Thu', scheduled: 45, completed: 52, noShow: 6 },
  { day: 'Fri', scheduled: 50, completed: 58, noShow: 4 },
  { day: 'Sat', scheduled: 36, completed: 44, noShow: 2 },
  { day: 'Sun', scheduled: 28, completed: 35, noShow: 1 },
] as const

export type DashboardAppointmentStatus = 'In progress' | 'Waiting' | 'Confirmed' | 'Done'

export type DashboardAppointment = {
  id: string
  patient: {
    name: string
    avatar: string
    email: string
    phone: string
  }
  doctor: {
    name: string
    department: string
    avatar: string
  }
  date: string
  time: string
  duration: string
  status: DashboardAppointmentStatus
  room: string
  notes?: string
}

export const dashboardAppointments: readonly DashboardAppointment[] = [
  {
    id: 'CMP-9481',
    patient: {
      name: 'Aarav Sharma',
      avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
      email: 'aarav.sharma@gmail.com',
      phone: '+91 98201 44521',
    },
    doctor: {
      name: 'Eng. Anita Joshi',
      department: 'BMC Roads & Infrastructure',
      avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&auto=format&fit=crop&q=80',
    },
    date: '04 Sep 2026',
    time: '09:30 AM',
    duration: 'High Priority',
    status: 'In progress',
    room: 'Ward H-West (Linking Rd)',
    notes: 'Severe crater pothole causing vehicle axle damage and traffic congestion near junction.',
  },
  {
    id: 'CMP-9476',
    patient: {
      name: 'Priya Nair',
      avatar: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=100&auto=format&fit=crop&q=80',
      email: 'priya.nair@outlook.com',
      phone: '+91 98192 33119',
    },
    doctor: {
      name: 'Ward Officer Sunil Deshmukh',
      department: 'BMC Solid Waste Management',
      avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&auto=format&fit=crop&q=80',
    },
    date: '04 Sep 2026',
    time: '10:15 AM',
    duration: 'Urgent',
    status: 'Waiting',
    room: 'Ward G-North (Dadar W)',
    notes: 'Overflowing garbage bin spilling onto pedestrian footpath near local vegetable market.',
  },
  {
    id: 'CMP-9462',
    patient: {
      name: 'Rohan Patil',
      avatar: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=100&auto=format&fit=crop&q=80',
      email: 'rohan.patil@yahoo.in',
      phone: '+91 97693 88401',
    },
    doctor: {
      name: 'Sr. Inspector Rajesh Kadam',
      department: 'Mumbai Police Traffic Division',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&auto=format&fit=crop&q=80',
    },
    date: '04 Sep 2026',
    time: '11:00 AM',
    duration: 'Standard',
    status: 'Confirmed',
    room: 'Ward K-East (Andheri E)',
    notes: 'Broken street lamp creating unsafe dark stretch near bus stop after 8:00 PM.',
  },
  {
    id: 'CMP-9450',
    patient: {
      name: 'Sunita Mehta',
      avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&auto=format&fit=crop&q=80',
      email: 'sunita.mehta@gmail.com',
      phone: '+91 98214 77209',
    },
    doctor: {
      name: 'Eng. Anita Joshi',
      department: 'BMC Water & Drainage Works',
      avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&auto=format&fit=crop&q=80',
    },
    date: '04 Sep 2026',
    time: '11:45 AM',
    duration: 'Critical',
    status: 'In progress',
    room: 'Ward F-North (Matunga)',
    notes: 'Displaced iron manhole cover adjacent to primary school gate. Hazardous hazard zone.',
  },
  {
    id: 'CMP-9438',
    patient: {
      name: 'Farhan Khan',
      avatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100&auto=format&fit=crop&q=80',
      email: 'farhan.k@gmail.com',
      phone: '+91 98335 11200',
    },
    doctor: {
      name: 'Sub-Insp. Vikram Shinde',
      department: 'Zone 4 Civic Vigilance',
      avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=100&auto=format&fit=crop&q=80',
    },
    date: '03 Sep 2026',
    time: '04:30 PM',
    duration: 'Resolved',
    status: 'Done',
    room: 'Ward H-West (Hill Rd)',
    notes: 'Illegal commercial stall encroachment cleared from walkway. Foot traffic restored.',
  },
  {
    id: 'CMP-9421',
    patient: {
      name: 'Deepak Varma',
      avatar: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100&auto=format&fit=crop&q=80',
      email: 'deepak.v@gmail.com',
      phone: '+91 98110 55432',
    },
    doctor: {
      name: 'Ward Officer Sunil Deshmukh',
      department: 'BMC Solid Waste Management',
      avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&auto=format&fit=crop&q=80',
    },
    date: '03 Sep 2026',
    time: '02:15 PM',
    duration: 'Resolved',
    status: 'Done',
    room: 'Ward G-South (Worli)',
    notes: 'Construction debris cleared from main street junction by motorized tipper unit.',
  },
] as const

export const dashboardAppointmentStatusFilters = [
  'all',
  'In progress',
  'Waiting',
  'Confirmed',
  'Done',
] as const

export type DashboardAppointmentStatusFilter =
  (typeof dashboardAppointmentStatusFilters)[number]

export function filterDashboardAppointments(
  items: readonly DashboardAppointment[],
  status: DashboardAppointmentStatusFilter,
  searchQuery: string = ''
): DashboardAppointment[] {
  return items.filter((item) => {
    const matchesStatus = status === 'all' || item.status === status
    const query = searchQuery.trim().toLowerCase()
    const matchesSearch =
      query === '' ||
      item.patient.name.toLowerCase().includes(query) ||
      item.doctor.name.toLowerCase().includes(query) ||
      item.room.toLowerCase().includes(query) ||
      (item.notes && item.notes.toLowerCase().includes(query)) ||
      item.id.toLowerCase().includes(query)
    return matchesStatus && matchesSearch
  })
}

export const dashboardStaffPerformance = [
  {
    id: 'STF-01',
    name: 'Eng. Anita Joshi',
    role: 'Executive Engineer (Roads)',
    department: 'BMC Infrastructure',
    solved: 142,
    rating: 4.9,
    onTimeRate: '98%',
    avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&auto=format&fit=crop&q=80',
    badge: 'Top Performer',
  },
  {
    id: 'STF-02',
    name: 'Ward Officer Sunil Deshmukh',
    role: 'Chief Sanitation Inspector',
    department: 'BMC Solid Waste',
    solved: 189,
    rating: 4.8,
    onTimeRate: '95%',
    avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&auto=format&fit=crop&q=80',
    badge: 'Highest Cleared',
  },
  {
    id: 'STF-03',
    name: 'Sr. Inspector Rajesh Kadam',
    role: 'Traffic & Vigilance Head',
    department: 'Mumbai Police Div',
    solved: 118,
    rating: 4.9,
    onTimeRate: '97%',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&auto=format&fit=crop&q=80',
    badge: 'Zonal Lead',
  },
  {
    id: 'STF-04',
    name: 'Sub-Insp. Vikram Shinde',
    role: 'Quick Response Squad Lead',
    department: 'Police & Vigilance',
    solved: 96,
    rating: 4.7,
    onTimeRate: '92%',
    avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=100&auto=format&fit=crop&q=80',
    badge: 'Rapid Unit',
  },
] as const

export const staffDetails: Record<
  string,
  {
    name: string
    role: string
    department: string
    phone: string
    email: string
    rating: number
    solvedCount: number
    onTimeRate: string
    avatar: string
    bio: string
    recentCases: Array<{
      title: string
      date: string
      status: string
      ward: string
    }>
  }
> = {
  'Eng. Anita Joshi': {
    name: 'Eng. Anita Joshi',
    role: 'Executive Engineer (Roads & Drainage)',
    department: 'BMC Infrastructure Division',
    phone: '+91 98200 12845',
    email: 'anita.joshi@bmc.gov.in',
    rating: 4.9,
    solvedCount: 142,
    onTimeRate: '98%',
    avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80',
    bio: 'Oversees arterial road repair, pothole filling operations, and storm-water drainage maintenance across Ward H-West and Ward G-South.',
    recentCases: [
      { title: 'Emergency Pothole Patching SV Rd', date: 'Today', status: 'Completed', ward: 'Ward H-West' },
      { title: 'Culvert Desilting Pre-Monsoon', date: 'Yesterday', status: 'Verified', ward: 'Ward G-North' },
      { title: 'Manhole Concrete Ring Replacement', date: '2 days ago', status: 'Completed', ward: 'Ward H-West' },
    ],
  },
  'Ward Officer Sunil Deshmukh': {
    name: 'Ward Officer Sunil Deshmukh',
    role: 'Chief Sanitation Inspector',
    department: 'BMC Solid Waste Management',
    phone: '+91 98199 43210',
    email: 's.deshmukh@bmc.gov.in',
    rating: 4.8,
    solvedCount: 189,
    onTimeRate: '95%',
    avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
    bio: 'Leads solid waste collection, motorized compactor routing, and secondary garbage clearance in high-density residential and commercial hubs.',
    recentCases: [
      { title: 'Commercial Market Garbage Clearing', date: 'Today', status: 'Completed', ward: 'Ward G-North' },
      { title: 'Debris Removal near Railway Station', date: 'Yesterday', status: 'Verified', ward: 'Ward G-North' },
      { title: 'Community Dustbin Placement', date: '3 days ago', status: 'Completed', ward: 'Ward F-South' },
    ],
  },
  'Sr. Inspector Rajesh Kadam': {
    name: 'Sr. Inspector Rajesh Kadam',
    role: 'Traffic & Civic Vigilance Head',
    department: 'Mumbai Police & Civic Taskforce',
    phone: '+91 98210 98765',
    email: 'r.kadam@unisafe.mumbai.gov.in',
    rating: 4.9,
    solvedCount: 118,
    onTimeRate: '97%',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
    bio: 'Coordinates police patrolling units, citizen grievance escalations, street lighting security assessments, and pedestrian walkway safety.',
    recentCases: [
      { title: 'Illegal Parking Removal linking junction', date: 'Today', status: 'Resolved', ward: 'Zone 4' },
      { title: 'Night Patrol Security in Dark Alleys', date: 'Yesterday', status: 'Active', ward: 'Ward H-West' },
      { title: 'Public Obstruction Clearing at School', date: '2 days ago', status: 'Resolved', ward: 'Ward K-East' },
    ],
  },
  'Sub-Insp. Vikram Shinde': {
    name: 'Sub-Insp. Vikram Shinde',
    role: 'Quick Response Squad Lead',
    department: 'Civic Vigilance Team',
    phone: '+91 98333 77612',
    email: 'v.shinde@mumbaipolice.gov.in',
    rating: 4.7,
    solvedCount: 96,
    onTimeRate: '92%',
    avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&auto=format&fit=crop&q=80',
    bio: 'Specializes in rapid field dispatch for emergency complaints including open manholes, active hazards, and community disputes.',
    recentCases: [
      { title: 'Manhole Perimeter Barricading', date: 'Today', status: 'Completed', ward: 'Ward F-North' },
      { title: 'Encroachment Clearance Drive', date: 'Yesterday', status: 'Completed', ward: 'Ward H-West' },
    ],
  },
}

export const dashboardResources = [
  {
    id: 'RES-01',
    name: 'Rapid Pothole Jet-Patcher #04',
    type: 'Vehicle & Crew',
    operator: 'BMC Engineering',
    status: 'In Field',
    statusColor: 'text-emerald-500 bg-emerald-500/10',
    eta: 'Active in Ward H-West',
  },
  {
    id: 'RES-02',
    name: 'Sanitation Compactor Truck #12',
    type: 'Heavy Fleet',
    operator: 'Solid Waste Dept',
    status: 'En Route',
    statusColor: 'text-sky-500 bg-sky-500/10',
    eta: 'ETA 15 min Dadar W',
  },
  {
    id: 'RES-03',
    name: 'Mobile Police Patrolling Squad #07',
    type: 'Vigilance Unit',
    operator: 'Mumbai Police',
    status: 'Patrolling',
    statusColor: 'text-emerald-500 bg-emerald-500/10',
    eta: 'Zone 4 SV Road Corridor',
  },
  {
    id: 'RES-04',
    name: 'Hydraulic Suction & Jetting Rig',
    type: 'Drainage Fleet',
    operator: 'BMC Sewage Div',
    status: 'Standby',
    statusColor: 'text-amber-500 bg-amber-500/10',
    eta: 'Ready at Bandra Depot',
  },
] as const
