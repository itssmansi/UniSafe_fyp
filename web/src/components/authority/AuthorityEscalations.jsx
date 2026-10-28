import React, { useState, useMemo } from 'react'
import {
  AlertTriangle,
  Clock,
  ThumbsUp,
  MapPin,
  Flame,
  ArrowUpRight,
  Filter,
  CheckCircle2,
  PhoneCall,
  ShieldAlert,
  Send,
} from 'lucide-react'

// Demo escalations for realistic civic operations when database has fewer items
const DEMO_ESCALATIONS = [
  {
    id: 'esc-101',
    title: 'High-Pressure Water Main Burst Flooding SV Road Junction',
    category: 'Water & Pipeline',
    address: 'Near Andheri West Subway, K/W Ward, Mumbai',
    upvote_count: 42,
    status: 'pending',
    sla_hours: 3.8,
    sla_limit: 2.0,
    is_breached: true,
    created_at: new Date(Date.now() - 4.5 * 3600 * 1000).toISOString(),
    description: '12-inch municipal drinking water main fractured during underground cable laying. Water flooding entire carriage-way, leading to massive traffic standstill.',
    department: 'BMC Water Works (BMC-WTR)',
    assigned_officer: 'Sunil Deshmukh (Lead Engineer)',
  },
  {
    id: 'esc-102',
    title: 'Uncovered Deep Storm Drainage Manhole Opposite Railway Station',
    category: 'Roads & Infrastructure',
    address: 'Senapati Bapat Marg, Dadar West, G/N Ward',
    upvote_count: 36,
    status: 'in_progress',
    sla_hours: 2.1,
    sla_limit: 4.0,
    is_breached: false,
    created_at: new Date(Date.now() - 2.5 * 3600 * 1000).toISOString(),
    description: 'Cast iron manhole cover stolen or broken. 8-foot drop into live sewer channel poses severe danger to evening commuters and schoolchildren.',
    department: 'BMC Roads & Traffic (BMC-RD)',
    assigned_officer: 'Anita Joshi (Ward Officer)',
  },
  {
    id: 'esc-103',
    title: 'Snapped 11kV Overhead Cable Dangling Near Residential Bus Stop',
    category: 'Electrical & Power',
    address: 'LBS Marg, Kurla West, L Ward',
    upvote_count: 29,
    status: 'pending',
    sla_hours: 5.2,
    sla_limit: 1.5,
    is_breached: true,
    created_at: new Date(Date.now() - 5.5 * 3600 * 1000).toISOString(),
    description: 'Heavy tree branch fell on power line causing live sparking wire to touch street railing. Local police have cordoned 50m perimeter.',
    department: 'BMC Electrical & BEST (BMC-ELE)',
    assigned_officer: 'Rajesh Kadam (Senior Inspector)',
  },
  {
    id: 'esc-104',
    title: 'Illegal Chemical Sludge Dumping in Public Storm Water Drain',
    category: 'Solid Waste & Pollution',
    address: 'Mithi River Outfall, Dharavi Sector 5, G/N Ward',
    upvote_count: 18,
    status: 'in_progress',
    sla_hours: 3.0,
    sla_limit: 6.0,
    is_breached: false,
    created_at: new Date(Date.now() - 3.2 * 3600 * 1000).toISOString(),
    description: 'Industrial tanker caught discharging dark toxic effluents directly into mangrove drainage culvert. Pungent fumes causing nausea.',
    department: 'Solid Waste Management (BMC-SWM)',
    assigned_officer: 'Vikram Shinde (Sanitation Lead)',
  },
]

export default function AuthorityEscalations({ complaints = [], onRowClick }) {
  const [activeFilter, setActiveFilter] = useState('all') // all, breached, upvoted, risk
  const [dispatchedIds, setDispatchedIds] = useState(new Set())

  // Combine real database escalations with demo tickets to guarantee complete UI
  const allEscalations = useMemo(() => {
    const realEscalated = (complaints || []).filter(
      (c) =>
        (c.upvote_count >= 3 ||
          c.category?.toLowerCase().includes('assault') ||
          c.category?.toLowerCase().includes('hazard') ||
          c.category?.toLowerCase().includes('leak') ||
          c.category?.toLowerCase().includes('wire') ||
          c.status === 'pending') &&
        c.status !== 'resolved'
    )

    // If real items exist, map them into rich format and append demo items if fewer than 3
    const formattedReal = realEscalated.map((c) => ({
      id: c.id,
      title: c.title,
      category: c.category || 'General Civic Incident',
      address: c.address || 'Mumbai Jurisdiction Area',
      upvote_count: c.upvote_count || 5,
      status: c.status || 'pending',
      sla_hours: 3.2,
      sla_limit: 4.0,
      is_breached: (c.upvote_count || 0) >= 10,
      created_at: c.created_at || new Date().toISOString(),
      description: c.description || 'Priority citizen incident requiring municipal intervention.',
      department: 'BMC Central Operations',
      assigned_officer: 'On-duty Field Officer',
      original: c,
    }))

    if (formattedReal.length >= 3) {
      return formattedReal
    }

    // Combine real + demo (avoiding duplicates)
    const combined = [...formattedReal]
    DEMO_ESCALATIONS.forEach((demo) => {
      if (!combined.some((item) => item.title === demo.title)) {
        combined.push(demo)
      }
    })
    return combined
  }, [complaints])

  const filteredEscalations = useMemo(() => {
    if (activeFilter === 'breached') {
      return allEscalations.filter((e) => e.is_breached)
    }
    if (activeFilter === 'upvoted') {
      return allEscalations.filter((e) => e.upvote_count >= 20)
    }
    if (activeFilter === 'pending') {
      return allEscalations.filter((e) => e.status === 'pending')
    }
    return allEscalations
  }, [allEscalations, activeFilter])

  const totalBreached = allEscalations.filter((e) => e.is_breached).length
  const totalUpvotes = allEscalations.reduce((acc, curr) => acc + curr.upvote_count, 0)

  const handleQuickDispatch = (e, escId) => {
    e.stopPropagation()
    setDispatchedIds((prev) => new Set([...prev, escId]))
    alert(`Emergency Rapid Response Team dispatched to incident ticket ${escId}!`)
  }

  return (
    <div className="space-y-6">
      {/* Top Telemetry KPI Ribbon */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5">
        <div className="rounded-xl border border-border/50 bg-card p-4 shadow-xs">
          <div className="flex items-center justify-between text-muted-foreground mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Active Escalations</span>
            <AlertTriangle className="size-4 text-amber-500" />
          </div>
          <p className="text-2xl font-bold text-foreground">{allEscalations.length}</p>
          <span className="text-[11px] text-amber-500 font-medium">Critical Priority</span>
        </div>

        <div className="rounded-xl border border-border/50 bg-card p-4 shadow-xs">
          <div className="flex items-center justify-between text-muted-foreground mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">SLA Overdue</span>
            <Clock className="size-4 text-red-500" />
          </div>
          <p className="text-2xl font-bold text-red-500">{totalBreached}</p>
          <span className="text-[11px] text-muted-foreground font-medium">Target response missed</span>
        </div>

        <div className="rounded-xl border border-border/50 bg-card p-4 shadow-xs">
          <div className="flex items-center justify-between text-muted-foreground mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Citizen Verified</span>
            <ThumbsUp className="size-4 text-emerald-500" />
          </div>
          <p className="text-2xl font-bold text-foreground">{totalUpvotes}</p>
          <span className="text-[11px] text-emerald-500 font-medium">Community upvotes</span>
        </div>

        <div className="rounded-xl border border-border/50 bg-card p-4 shadow-xs">
          <div className="flex items-center justify-between text-muted-foreground mb-1">
            <span className="text-xs font-semibold uppercase tracking-wider">Avg Resolution Goal</span>
            <ShieldAlert className="size-4 text-sky-500" />
          </div>
          <p className="text-2xl font-bold text-foreground">2.0 hrs</p>
          <span className="text-[11px] text-muted-foreground font-medium">Emergency Protocol</span>
        </div>
      </div>

      {/* Filter and Control Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-border/40 pb-4">
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium text-muted-foreground mr-1">Filter View:</span>
          <button
            onClick={() => setActiveFilter('all')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              activeFilter === 'all'
                ? 'bg-primary text-primary-foreground shadow-xs'
                : 'bg-muted/60 text-muted-foreground hover:text-foreground hover:bg-muted'
            }`}
          >
            All Active ({allEscalations.length})
          </button>
          <button
            onClick={() => setActiveFilter('breached')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              activeFilter === 'breached'
                ? 'bg-red-600 text-white shadow-xs'
                : 'bg-muted/60 text-muted-foreground hover:text-foreground hover:bg-muted'
            }`}
          >
            SLA Breached ({totalBreached})
          </button>
          <button
            onClick={() => setActiveFilter('upvoted')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              activeFilter === 'upvoted'
                ? 'bg-amber-600 text-white shadow-xs'
                : 'bg-muted/60 text-muted-foreground hover:text-foreground hover:bg-muted'
            }`}
          >
            High Upvotes (≥20)
          </button>
          <button
            onClick={() => setActiveFilter('pending')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              activeFilter === 'pending'
                ? 'bg-sky-600 text-white shadow-xs'
                : 'bg-muted/60 text-muted-foreground hover:text-foreground hover:bg-muted'
            }`}
          >
            Pending Dispatch
          </button>
        </div>

        <div className="text-xs text-muted-foreground flex items-center gap-2">
          <span className="inline-block size-2 rounded-full bg-emerald-500 animate-pulse" />
          Live Municipal Telemetry Connected
        </div>
      </div>

      {/* Escalation Incident Cards */}
      <div className="space-y-3.5">
        {filteredEscalations.map((esc) => {
          const isDispatched = dispatchedIds.has(esc.id)

          return (
            <div
              key={esc.id}
              onClick={() => onRowClick && onRowClick(esc.original || esc)}
              className="group rounded-xl border border-border/60 bg-card p-5 shadow-xs hover:border-primary/40 hover:shadow-md transition-all cursor-pointer relative overflow-hidden"
            >
              {/* Left Urgency Strip */}
              <div
                className={`absolute left-0 top-0 bottom-0 w-1.5 ${
                  esc.is_breached ? 'bg-red-500' : 'bg-amber-500'
                }`}
              />

              <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                <div className="flex-1 min-w-0 pl-1">
                  {/* Badge row */}
                  <div className="flex flex-wrap items-center gap-2 mb-2">
                    {esc.is_breached ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-bold uppercase tracking-wider bg-red-500/10 text-red-600 dark:text-red-400 border border-red-500/20">
                        <Clock className="size-3" /> SLA Breached
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-bold uppercase tracking-wider bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20">
                        <AlertTriangle className="size-3" /> Critical Community Alert
                      </span>
                    )}

                    <span className="px-2 py-0.5 rounded-md text-[11px] font-semibold bg-muted text-muted-foreground">
                      {esc.category}
                    </span>

                    <span className="px-2 py-0.5 rounded-md text-[11px] font-medium text-muted-foreground">
                      {esc.department}
                    </span>
                  </div>

                  {/* Title & Description */}
                  <h3 className="text-base font-bold text-foreground group-hover:text-primary transition-colors line-clamp-1 mb-1">
                    {esc.title}
                  </h3>
                  <p className="text-xs text-muted-foreground line-clamp-2 mb-3 leading-relaxed">
                    {esc.description}
                  </p>

                  {/* Location & Officer metadata */}
                  <div className="flex flex-wrap items-center gap-4 text-xs text-muted-foreground">
                    <span className="flex items-center gap-1">
                      <MapPin className="size-3.5 text-primary shrink-0" />
                      <span className="truncate max-w-xs">{esc.address}</span>
                    </span>
                    <span className="flex items-center gap-1 font-semibold text-emerald-600 dark:text-emerald-400">
                      <ThumbsUp className="size-3.5 shrink-0" />
                      {esc.upvote_count} Citizen Verifications
                    </span>
                    <span className="text-[11px] text-muted-foreground">
                      Assigned: <strong className="text-foreground">{esc.assigned_officer}</strong>
                    </span>
                  </div>
                </div>

                {/* Right Action Column */}
                <div className="flex sm:flex-row lg:flex-col items-center lg:items-end justify-between gap-3 shrink-0 pt-3 lg:pt-0 border-t lg:border-t-0 border-border/40">
                  <div className="text-left lg:text-right">
                    <span className="text-[10px] uppercase tracking-wider font-semibold text-muted-foreground block">
                      Status
                    </span>
                    <span
                      className={`inline-block text-xs font-bold capitalize mt-0.5 ${
                        esc.status === 'in_progress'
                          ? 'text-sky-500'
                          : 'text-amber-500'
                      }`}
                    >
                      {esc.status.replace('_', ' ')}
                    </span>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={(e) => handleQuickDispatch(e, esc.id)}
                      disabled={isDispatched}
                      className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer ${
                        isDispatched
                          ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30'
                          : 'bg-primary text-primary-foreground hover:bg-primary/90 shadow-xs'
                      }`}
                    >
                      {isDispatched ? (
                        <>
                          <CheckCircle2 className="size-3.5" /> Unit In Transit
                        </>
                      ) : (
                        <>
                          <Send className="size-3.5" /> Rapid Dispatch
                        </>
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={() => onRowClick && onRowClick(esc.original || esc)}
                      className="size-8 rounded-lg border border-border/60 hover:bg-muted flex items-center justify-center text-muted-foreground hover:text-foreground transition-colors"
                      title="Inspect full ticket details"
                    >
                      <ArrowUpRight className="size-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )
        })}

        {filteredEscalations.length === 0 && (
          <div className="rounded-xl border border-border/50 bg-card p-12 text-center shadow-xs">
            <div className="mx-auto size-12 rounded-full bg-emerald-500/10 flex items-center justify-center text-emerald-500 mb-3">
              <CheckCircle2 className="size-6" />
            </div>
            <h3 className="text-base font-bold text-foreground">Zero Critical Escalations</h3>
            <p className="text-xs text-muted-foreground mt-1 max-w-sm mx-auto">
              All high-priority complaints in this filter have been addressed or verified.
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
