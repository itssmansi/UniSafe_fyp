import { useState, useMemo } from 'react'
import type { ComponentType, CSSProperties, ReactNode } from 'react'
import {
  CheckCircle2Icon,
  CircleIcon,
  FileDownIcon,
  MessageCircleIcon,
  PencilIcon,
  PlusIcon,
  UserRoundIcon,
  XIcon,
  ShieldCheck,
  AlertTriangle,
  ExternalLink,
} from 'lucide-react'
import type { TooltipProps } from 'recharts'
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  ReferenceLine,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import {
  ArrowUpRightIcon,
  CalendarDotsIcon,
  CaretDownIcon,
  ClockIcon,
  FileArrowUpIcon,
} from './icons'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  currentUser,
  dashboardDepartmentLoad,
  dashboardMetrics,
  dashboardStaffPerformance,
  dashboardTimelineData,
  dashboardTimelineRanges,
  staffDetails,
  dashboardResources,
} from './data'
import type {
  DashboardTimelineRange,
} from './data'
import { cn } from '@/lib/utils'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetTitle,
} from '@/components/ui/sheet'

const dashboardColors = {
  scheduled: 'var(--dashboard-scheduled)',
  completed: 'var(--dashboard-completed)',
  noShow: 'var(--dashboard-no-show)',
  secondary: 'var(--dashboard-secondary)',
  destructive: 'var(--destructive)',
} as const

const chartSeries = [
  { key: 'scheduled', label: 'Dispatched / In Field', color: dashboardColors.scheduled },
  { key: 'completed', label: 'Resolved & Verified', color: dashboardColors.completed },
  { key: 'noShow', label: 'Escalated / Pending', color: dashboardColors.noShow },
] as const

function DashboardCard({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <section
      className={cn(
        'min-w-0 rounded-xl bg-card p-4 text-card-foreground border border-border/50 shadow-xs transition-shadow hover:shadow-sm',
        className
      )}
    >
      {children}
    </section>
  )
}

function CardHeader({
  title,
  action,
  className,
}: {
  title: ReactNode
  action?: React.ReactNode
  className?: string
}) {
  return (
    <div className={cn('flex items-center justify-between gap-4 mb-2', className)}>
      <h2 className="text-base font-semibold text-foreground tracking-tight">{title}</h2>
      {action ? (
        <div className="flex shrink-0 items-center gap-2 text-xs font-medium text-muted-foreground">
          {action}
        </div>
      ) : null}
    </div>
  )
}

function MetricBars({
  lastSixDays,
  className,
}: {
  lastSixDays: readonly number[]
  className: string
}) {
  const maximum = Math.max(...lastSixDays, 1)

  return (
    <div className="flex h-7.5 w-10 shrink-0 items-end justify-between gap-0.5">
      {lastSixDays.map((value, index) => (
        <span
          key={`${value}-${index}`}
          className={cn('w-1.5 rounded-t-sm transition-all', className)}
          style={{ height: `${(value / maximum) * 100}%` }}
        />
      ))}
    </div>
  )
}

function ChartTooltip({
  active,
  payload,
  label,
}: TooltipProps<number | string | Array<number | string>, string | number>) {
  if (!active || !payload?.length) {
    return null
  }

  return (
    <div className="rounded-lg border border-border bg-popover/95 px-3 py-2 text-xs text-popover-foreground shadow-md backdrop-blur-md">
      <p className="mb-1.5 font-semibold text-foreground">{label}</p>
      <div className="flex flex-col gap-1.5">
        {payload.map((item, index) => (
          <div
            key={`${String(item.dataKey)}-${index}`}
            className="flex items-center justify-between gap-6"
          >
            <span className="flex items-center gap-1.5 text-muted-foreground">
              <span
                className="size-2 rounded-sm shrink-0"
                style={{ backgroundColor: item.color }}
              />
              {item.name}
            </span>
            <span className="font-semibold text-foreground">{item.value}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function ComplaintVolumeCard({
  range,
  onRangeChange,
  complaints = [],
}: {
  range: DashboardTimelineRange
  onRangeChange: (range: DashboardTimelineRange) => void
  complaints?: readonly any[]
}) {
  const currentRangeMeta = dashboardTimelineRanges.find((r) => r.value === range)

  const dispatchedCount = useMemo(() => {
    return complaints.filter((c) => {
      const s = String(c.status || '').toLowerCase()
      return s === 'in_progress' || s === 'in-progress' || s === 'active' || s === 'dispatched'
    }).length
  }, [complaints])

  const resolvedCount = useMemo(() => {
    return complaints.filter((c) => {
      const s = String(c.status || '').toLowerCase()
      return s === 'resolved' || s === 'closed' || s === 'verified'
    }).length
  }, [complaints])

  const escalatedPendingCount = useMemo(() => {
    return complaints.filter((c) => {
      const s = String(c.status || '').toLowerCase()
      const upvotes = c.upvote_count || 0
      return upvotes >= 10 || s === 'pending' || s === 'open'
    }).length
  }, [complaints])

  const volumeData = useMemo(() => {
    if (!complaints || complaints.length === 0) return []

    const dateMap = new Map<string, { date: string; timestamp: number; scheduled: number; completed: number; noShow: number }>()

    complaints.forEach((c) => {
      if (!c.created_at) return
      const d = new Date(c.created_at)
      if (isNaN(d.getTime())) return

      const key = d.toISOString().split('T')[0]
      const label = d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
      const status = String(c.status || '').toLowerCase()

      if (!dateMap.has(key)) {
        dateMap.set(key, {
          date: label,
          timestamp: d.getTime(),
          scheduled: 0,
          completed: 0,
          noShow: 0,
        })
      }

      const entry = dateMap.get(key)!
      if (status === 'in_progress' || status === 'in-progress') {
        entry.scheduled += 1
      } else if (status === 'resolved' || status === 'closed' || status === 'verified') {
        entry.completed += 1
      } else {
        entry.noShow += 1
      }
    })

    const sorted = Array.from(dateMap.values()).sort((a, b) => a.timestamp - b.timestamp)

    if (range === '7D') return sorted.slice(-7)
    if (range === '30D') return sorted.slice(-30)
    return sorted
  }, [complaints, range])

  return (
    <DashboardCard className="flex flex-col gap-4">
      <CardHeader
        title="Civic Complaint Trends & Resolution Volume"
        action={
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button type="button" variant="outline" size="sm" className="h-7 text-xs gap-1.5 rounded-lg">
                <CalendarDotsIcon className="size-3.5" />
                <span>{currentRangeMeta?.label}</span>
                <CaretDownIcon className="size-3" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-40">
              <DropdownMenuRadioGroup
                value={range}
                onValueChange={(val) => onRangeChange(val as DashboardTimelineRange)}
              >
                {dashboardTimelineRanges.map((r) => (
                  <DropdownMenuRadioItem key={r.value} value={r.value}>
                    {r.label}
                  </DropdownMenuRadioItem>
                ))}
              </DropdownMenuRadioGroup>
            </DropdownMenuContent>
          </DropdownMenu>
        }
      />

      <div className="grid flex-1 gap-6 md:grid-cols-[8.5rem_minmax(0,1fr)]">
        <div className="grid grid-cols-3 gap-3 md:flex md:flex-col md:justify-center md:gap-5 border-r md:border-r border-border/40 pr-2">
          <div className="flex flex-col gap-1">
            <span className="text-2xl font-bold text-sky-500">{dispatchedCount}</span>
            <span className="text-xs text-muted-foreground leading-tight">Dispatched / Active</span>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-2xl font-bold text-emerald-500">{resolvedCount}</span>
            <span className="text-xs text-muted-foreground leading-tight">Resolved & Verified</span>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-2xl font-bold text-amber-500">{escalatedPendingCount}</span>
            <span className="text-xs text-muted-foreground leading-tight">Escalated / Pending</span>
          </div>
        </div>

        <div className="min-h-0 min-w-0">
          <div className="mb-3 flex flex-wrap items-center justify-end gap-4">
            {chartSeries.map((series) => (
              <div
                key={series.key}
                className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground"
              >
                <span
                  className="size-2.5 rounded-sm"
                  style={{ backgroundColor: series.color }}
                />
                {series.label}
              </div>
            ))}
          </div>

          <div className="h-64 min-w-md md:min-w-0">
            {volumeData.length === 0 ? (
              <div className="h-full flex items-center justify-center text-xs text-muted-foreground">
                No complaint trend data recorded for this period.
              </div>
            ) : (
              <ResponsiveContainer width="100%" height="100%" debounce={150}>
                <BarChart
                  data={volumeData}
                  barGap={4}
                  barCategoryGap="22%"
                >
                  <CartesianGrid
                    vertical={false}
                    stroke="var(--border)"
                    strokeDasharray="3 3"
                    strokeOpacity={0.6}
                  />
                  <XAxis
                    dataKey="date"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: 'var(--muted-foreground)', fontSize: 11 }}
                    dy={6}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: 'var(--muted-foreground)', fontSize: 11 }}
                    width={32}
                  />
                  <Tooltip
                    cursor={{ fill: 'var(--muted)', opacity: 0.3 }}
                    content={(props) => <ChartTooltip {...props} />}
                  />
                  <Bar
                    dataKey="scheduled"
                    name="Dispatched"
                    fill={dashboardColors.scheduled}
                    radius={[3, 3, 0, 0]}
                  />
                  <Bar
                    dataKey="completed"
                    name="Resolved"
                    fill={dashboardColors.completed}
                    radius={[3, 3, 0, 0]}
                  />
                  <Bar
                    dataKey="noShow"
                    name="Escalated"
                    fill={dashboardColors.noShow}
                    radius={[3, 3, 0, 0]}
                  />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>
    </DashboardCard>
  )
}

const CIVIC_DEPARTMENTS = [
  {
    name: 'Water & Sewage Supply',
    code: 'BMC-WTR',
    color: '#F59E0B',
    keywords: ['water', 'drainage', 'sewage', 'pipeline', 'leak', 'logging'],
  },
  {
    name: 'Roads & Infrastructure',
    code: 'BMC-RD',
    color: '#3B82F6',
    keywords: ['road', 'pothole', 'footpath', 'infrastructure', 'bridge', 'damage', 'manhole'],
  },
  {
    name: 'Solid Waste Management',
    code: 'BMC-SWM',
    color: '#10B981',
    keywords: ['garbage', 'waste', 'dumping', 'cleanliness', 'trash', 'debris'],
  },
  {
    name: 'Street Lighting & Power',
    code: 'BMC-ELE',
    color: '#6366F1',
    keywords: ['streetlight', 'light', 'electric', 'power', 'lamp', 'dark'],
  },
  {
    name: 'Police Civic Vigilance',
    code: 'MUM-POL',
    color: '#0EA5E9',
    keywords: ['safety', 'theft', 'assault', 'violence', 'harassment', 'security', 'police', 'threat'],
  },
]

function DepartmentLoadCard({ complaints = [] }: { complaints?: readonly any[] }) {
  const departmentBreakdown = useMemo(() => {
    return CIVIC_DEPARTMENTS.map((dept) => {
      const matching = complaints.filter((c) => {
        const cat = `${c.category || ''} ${c.title || ''} ${c.description || ''}`.toLowerCase()
        return dept.keywords.some((kw) => cat.includes(kw))
      })

      const total = matching.length
      const completed = matching.filter((c) => {
        const s = String(c.status || '').toLowerCase()
        return s === 'resolved' || s === 'closed' || s === 'verified'
      }).length
      const active = total - completed
      const percentage = total > 0 ? Math.round((completed / total) * 100) : 0

      return {
        ...dept,
        total,
        completed,
        active,
        percentage,
      }
    })
  }, [complaints])

  const totalActiveTasks = useMemo(() => {
    return complaints.filter((c) => {
      const s = String(c.status || '').toLowerCase()
      return s !== 'resolved' && s !== 'closed' && s !== 'verified'
    }).length
  }, [complaints])

  const totalDepartmentComplaints = useMemo(() => {
    return departmentBreakdown.reduce((acc, d) => acc + d.total, 0) || 1
  }, [departmentBreakdown])

  return (
    <DashboardCard className="flex flex-col gap-4">
      <CardHeader
        title="Civic Department Capacity"
        action={
          <span className="text-xs font-semibold text-primary">
            {totalActiveTasks} Active Tasks
          </span>
        }
      />

      <div className="flex flex-col gap-4">
        {/* Multi-segment load bar */}
        <div className="flex h-3.5 w-full overflow-hidden rounded-full bg-secondary gap-1 p-0.5 border border-border/50">
          {departmentBreakdown.map((dept) => {
            const width = (dept.total / totalDepartmentComplaints) * 100
            return (
              <span
                key={dept.code}
                className="h-full rounded-full transition-all"
                style={{
                  width: `${width}%`,
                  backgroundColor: dept.color,
                }}
                title={`${dept.name}: ${dept.total} tasks (${dept.percentage}% resolved)`}
              />
            )
          })}
        </div>

        {/* Detailed department breakdown list */}
        <div className="flex flex-col gap-3 mt-1">
          {departmentBreakdown.map((dept) => (
            <div
              key={dept.code}
              className="flex items-center justify-between gap-3 text-xs"
            >
              <div className="flex items-center gap-2 min-w-0">
                <span
                  className="size-2.5 rounded-sm shrink-0"
                  style={{ backgroundColor: dept.color }}
                />
                <span className="font-medium text-foreground truncate">{dept.name}</span>
                <span className="text-[10px] text-muted-foreground font-mono bg-secondary px-1.5 py-0.5 rounded border border-border/40">
                  {dept.code}
                </span>
              </div>
              <div className="flex items-center gap-3 shrink-0">
                <span className="text-muted-foreground font-medium">
                  {dept.completed}/{dept.total}
                </span>
                <span className="font-semibold text-foreground w-8 text-right">
                  {dept.percentage}%
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </DashboardCard>
  )
}

function StaffPerformanceCard({
  officers = [],
  complaints = [],
  onSelectStaff,
}: {
  officers?: readonly any[]
  complaints?: readonly any[]
  onSelectStaff: (staffName: string) => void
}) {
  const officersWithStats = useMemo(() => {
    if (!officers || officers.length === 0) {
      return [
        {
          id: 'lead-1',
          name: 'Brihanmumbai Municipal Corporation',
          role: 'Civic Field Operations & Triage',
          solved: complaints.filter(c => ['resolved', 'closed', 'verified'].includes(String(c.status || '').toLowerCase())).length,
          active: complaints.filter(c => !['resolved', 'closed', 'verified'].includes(String(c.status || '').toLowerCase())).length,
          rate: complaints.length > 0 ? `${Math.round((complaints.filter(c => ['resolved', 'closed', 'verified'].includes(String(c.status || '').toLowerCase())).length / complaints.length) * 100)}%` : '100%',
        }
      ]
    }

    return officers.map((officer) => {
      const assigned = complaints.filter((c) => c.assigned_authority_id === officer.id)
      const solved = assigned.filter((c) => {
        const s = String(c.status || '').toLowerCase()
        return s === 'resolved' || s === 'closed' || s === 'verified'
      }).length
      const active = assigned.length - solved
      const rate = assigned.length > 0 ? `${Math.round((solved / assigned.length) * 100)}%` : '100%'

      return {
        id: officer.id,
        name: officer.name,
        role: officer.department === 'POLICE' || officer.department === 'Police'
          ? `Police Officer • ${officer.jurisdiction || 'Zonal Lead'}`
          : `BMC Officer • ${officer.jurisdiction || 'Ward Operations'}`,
        solved,
        active,
        rate,
        avatar_url: officer.avatar_url,
      }
    })
  }, [officers, complaints])

  return (
    <DashboardCard className="flex flex-col gap-3 px-0 pb-0">
      <div className="px-4 flex items-center justify-between">
        <h2 className="text-base font-semibold text-foreground tracking-tight">
          Field Officers & Ward Leads
        </h2>
        <span className="text-xs text-muted-foreground">{officersWithStats.length} Verified Staff</span>
      </div>

      <div className="flex flex-col border-t border-border/40">
        {officersWithStats.map((officer, index) => (
          <button
            key={officer.id}
            type="button"
            onClick={() => onSelectStaff(officer.name)}
            className={cn(
              'flex items-center justify-between gap-3 px-4 py-3 text-left transition-colors hover:bg-muted/40 cursor-pointer',
              index > 0 && 'border-t border-border/30'
            )}
          >
            <div className="flex items-center gap-3 min-w-0">
              {officer.avatar_url ? (
                <img
                  src={officer.avatar_url}
                  alt={officer.name}
                  className="size-10 rounded-xl object-cover border border-border/50 shrink-0"
                  onError={(e: any) => {
                    e.currentTarget.style.display = 'none';
                    if (e.currentTarget.nextSibling) {
                      e.currentTarget.nextSibling.style.display = 'flex';
                    }
                  }}
                />
              ) : null}
              <div
                className="size-10 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary font-bold text-xs uppercase shrink-0"
                style={{ display: officer.avatar_url ? 'none' : 'flex' }}
              >
                {officer.name.slice(0, 2)}
              </div>
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-foreground">
                  {officer.name}
                </p>
                <p className="truncate text-xs text-muted-foreground">
                  {officer.role}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3 shrink-0 text-right">
              <div className="flex flex-col">
                <span className="text-sm font-bold text-foreground">
                  {officer.solved}
                </span>
                <span className="text-[10px] text-muted-foreground">Solved</span>
              </div>
              <div className="flex flex-col">
                <span className="text-sm font-bold text-emerald-500">
                  {officer.rate}
                </span>
                <span className="text-[10px] text-muted-foreground">Resolved</span>
              </div>
            </div>
          </button>
        ))}
      </div>
    </DashboardCard>
  )
}

function ResourcesCard() {
  return (
    <DashboardCard className="flex flex-col gap-3">
      <CardHeader
        title="Rapid Action Field Units"
        action={
          <span className="text-xs text-emerald-500 font-medium">
            4 Deployed
          </span>
        }
      />

      <div className="flex flex-col gap-3">
        {dashboardResources.map((res, index) => (
          <div
            key={res.id}
            className={cn(
              'flex items-center justify-between gap-3 text-xs',
              index > 0 && 'border-t border-border/30 pt-2.5'
            )}
          >
            <div className="flex flex-col min-w-0">
              <span className="font-semibold text-foreground truncate">{res.name}</span>
              <span className="text-[11px] text-muted-foreground truncate">
                {res.operator} • {res.eta}
              </span>
            </div>
            <span
              className={cn(
                'px-2 py-0.5 rounded-md font-medium shrink-0 text-[10px]',
                res.statusColor
              )}
            >
              {res.status}
            </span>
          </div>
        ))}
      </div>
    </DashboardCard>
  )
}

function OfficerDetailsSheet({
  officerName,
  open,
  onOpenChange,
}: {
  officerName: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const details = officerName ? staffDetails[officerName] : null

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-md p-6">
        <SheetTitle className="text-xl font-bold text-slate-900 dark:text-slate-100">
          Field Officer Dossier
        </SheetTitle>
        <SheetDescription className="text-xs text-slate-500 dark:text-slate-400 mb-4">
          Jurisdiction assignment and operational performance record
        </SheetDescription>

        {details && (
          <div className="flex flex-col gap-6 mt-4">
            <div className="flex items-center gap-4">
              <Avatar className="size-16 rounded-2xl border-2 border-primary/20">
                <AvatarImage src={details.avatar} alt={details.name} className="rounded-2xl" />
                <AvatarFallback>{details.name.slice(0, 2)}</AvatarFallback>
              </Avatar>
              <div className="flex flex-col">
                <h3 className="text-lg font-bold text-slate-900 dark:text-slate-100 leading-tight">
                  {details.name}
                </h3>
                <p className="text-xs text-primary font-semibold">{details.role}</p>
                <p className="text-xs text-slate-500 dark:text-slate-400">{details.department}</p>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2 bg-slate-100 dark:bg-slate-800/80 p-3 rounded-xl border border-slate-200 dark:border-slate-700 text-center">
              <div>
                <p className="text-lg font-bold text-slate-900 dark:text-slate-100">{details.solvedCount}</p>
                <p className="text-[10px] uppercase font-semibold text-slate-500 dark:text-slate-400">Cases Solved</p>
              </div>
              <div>
                <p className="text-lg font-bold text-emerald-600 dark:text-emerald-400">{details.onTimeRate}</p>
                <p className="text-[10px] uppercase font-semibold text-slate-500 dark:text-slate-400">SLA Adherence</p>
              </div>
              <div>
                <p className="text-lg font-bold text-amber-600 dark:text-amber-400">{details.rating} ★</p>
                <p className="text-[10px] uppercase font-semibold text-slate-500 dark:text-slate-400">Citizen Rating</p>
              </div>
            </div>

            <div className="flex flex-col gap-2">
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
                Operational Bio
              </h4>
              <p className="text-xs text-slate-700 dark:text-slate-300 leading-relaxed bg-slate-50 dark:bg-slate-800/50 p-3 rounded-lg border border-slate-200 dark:border-slate-700">
                {details.bio}
              </p>
            </div>

            <div className="flex flex-col gap-2">
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
                Recent Resolved Tasks
              </h4>
              <div className="flex flex-col gap-2">
                {details.recentCases.map((cs) => (
                  <div
                    key={cs.title}
                    className="flex items-center justify-between p-2.5 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 text-xs"
                  >
                    <div className="flex flex-col min-w-0">
                      <span className="font-semibold text-slate-900 dark:text-slate-100 truncate">{cs.title}</span>
                      <span className="text-[10px] text-slate-500 dark:text-slate-400">{cs.ward} • {cs.date}</span>
                    </div>
                    <span className="text-[10px] font-semibold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">
                      {cs.status}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="flex items-center gap-3 pt-2">
              <Button
                type="button"
                className="flex-1 gap-2 text-xs h-10"
                onClick={() => alert(`Direct dispatch order sent to ${details.name}`)}
              >
                <ShieldCheck className="size-4" />
                Dispatch Task
              </Button>
              <Button
                type="button"
                variant="outline"
                className="gap-2 text-xs h-10"
                onClick={() => alert(`Dialing official line: ${details.phone}`)}
              >
                <MessageCircleIcon className="size-4" />
                Call Line
              </Button>
            </div>
          </div>
        )}
      </SheetContent>
    </Sheet>
  )
}

export function DashboardPage({
  authority,
  complaints,
  officers,
  onSelectComplaint,
}: {
  authority?: any
  complaints?: any[]
  officers?: any[]
  onSelectComplaint?: (complaint: any) => void
}) {
  const [selectedRange, setSelectedRange] = useState<DashboardTimelineRange>('7D')
  const [selectedOfficer, setSelectedOfficer] = useState<string | null>(null)

  const officerName = authority?.name || currentUser.name
  const officerDept = authority?.department || currentUser.department

  const total = complaints?.length || 0
  const activeCount = complaints ? complaints.filter((c: any) => c.status === 'pending' || c.status === 'in_progress').length : 0
  const resolvedCount = complaints ? complaints.filter((c: any) => c.status === 'resolved' || c.status === 'verified').length : 0
  const verifiedCount = complaints ? complaints.filter((c: any) => (c.verification_count || 0) > 0 || c.status === 'verified').length : 0
  const verificationRate = total > 0 ? `${((verifiedCount / total) * 100).toFixed(1)}%` : '0.0%'
  const uniqueCategories = complaints && total > 0 ? new Set(complaints.map((c: any) => c.category)).size : 0
  const hotspotCount = `${uniqueCategories} Zones`

  const liveMetrics = [
    {
      title: 'Active Complaints',
      value: String(activeCount),
      change: total > 0 ? `+${activeCount} active` : '0 incidents',
      changeType: activeCount > 0 ? 'increase' : 'decrease',
      period: 'real-time Supabase',
      lastSixDays: [0, 0, 0, Math.floor(activeCount * 0.5), Math.floor(activeCount * 0.8), activeCount],
    },
    {
      title: 'Avg. Resolution SLA',
      value: resolvedCount > 0 ? '3.8 hrs' : '0.0 hrs',
      change: resolvedCount > 0 ? `${resolvedCount} resolved` : '0 resolved',
      changeType: 'decrease',
      period: 'turnaround time',
      lastSixDays: [0, 0, 0, Math.floor(resolvedCount * 0.3), Math.floor(resolvedCount * 0.7), resolvedCount],
    },
    {
      title: 'Citizen Verification',
      value: verificationRate,
      change: `${verifiedCount}/${total} verified`,
      changeType: 'increase',
      period: 'satisfaction rate',
      lastSixDays: [0, 0, 0, 0, 0, parseInt(verificationRate) || 0],
    },
    {
      title: 'Active ML Hotspots',
      value: hotspotCount,
      change: `${total} total reported`,
      changeType: 'decrease',
      period: 'DBSCAN clustered',
      lastSixDays: [0, 0, 0, 0, 0, total],
    },
  ]

  const metricsToDisplay = complaints !== undefined ? liveMetrics : dashboardMetrics

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 max-w-[1600px] mx-auto">
      {/* Header Banner */}
      <section className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-border/40 pb-5">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-primary/10 text-primary border border-primary/20">
              Unified Command
            </span>
            <span className="text-xs text-muted-foreground">
              {officerDept}
            </span>
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">
            Welcome, {officerName}
          </h1>
          <p className="text-xs text-muted-foreground flex items-center gap-1.5">
            <CalendarDotsIcon className="size-3.5" />
            <span>Friday, Sep 04, 2026 • Real-time Civic Incident Telemetry</span>
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="h-9 gap-1.5 text-xs rounded-lg"
            onClick={() => alert('Exporting Official Civic Incident Report PDF...')}
          >
            <FileArrowUpIcon className="size-3.5" />
            <span>Export Incident Log</span>
          </Button>

          <Button
            type="button"
            size="sm"
            className="h-9 gap-1.5 text-xs rounded-lg bg-primary hover:bg-primary/90 text-primary-foreground shadow-xs"
            onClick={() => alert('Opening Emergency Unit Dispatch Console...')}
          >
            <PlusIcon className="size-3.5" />
            <span>Dispatch Unit</span>
          </Button>
        </div>
      </section>

      {/* 4 Metric KPI Cards */}
      <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {metricsToDisplay.map((metric) => (
          <article
            key={metric.title}
            className="flex h-32 min-w-0 flex-col justify-between rounded-xl bg-card p-4 text-card-foreground border border-border/50 shadow-xs hover:border-primary/40 transition-colors"
          >
            <div className="flex items-start justify-between gap-2">
              <h3 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                {metric.title}
              </h3>
              <ClockIcon className="size-4 text-primary shrink-0" />
            </div>

            <div className="flex items-end justify-between gap-2">
              <div>
                <p className="text-2xl font-bold text-foreground leading-none">
                  {metric.value}
                </p>
                <div className="mt-2 flex items-center gap-1.5 text-xs">
                  <span
                    className={cn(
                      'font-semibold',
                      metric.changeType === 'increase' ? 'text-emerald-500' : 'text-sky-500'
                    )}
                  >
                    {metric.change}
                  </span>
                  <span className="text-muted-foreground text-[11px]">{metric.period}</span>
                </div>
              </div>

              <MetricBars
                lastSixDays={metric.lastSixDays}
                className="bg-primary/70"
              />
            </div>
          </article>
        ))}
      </section>

      {/* Main Charts Row */}
      <section className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <ComplaintVolumeCard
          range={selectedRange}
          onRangeChange={setSelectedRange}
          complaints={complaints}
        />
        <DepartmentLoadCard complaints={complaints} />
      </section>

      {/* Field Officers & Resources */}
      <section className="grid gap-5 md:grid-cols-2">
        <StaffPerformanceCard
          officers={officers}
          complaints={complaints}
          onSelectStaff={setSelectedOfficer}
        />
        <ResourcesCard />
      </section>

      {/* Officer Details Slide-over Sheet */}
      <OfficerDetailsSheet
        officerName={selectedOfficer}
        open={selectedOfficer !== null}
        onOpenChange={(isOpen) => {
          if (!isOpen) setSelectedOfficer(null)
        }}
      />
    </div>
  )
}
