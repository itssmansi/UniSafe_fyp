import React, { useState, useEffect } from 'react'
import { supabase } from '../services/supabase'
import {
  getAuthorityProfile,
  getComplaints,
  getNotifications,
  getAuthorities,
  markNotificationRead,
} from '../services/authorityService'

import DashboardLayout from '../components/authority/watermelon/dashboard-layout'
import { DashboardPage } from '../components/authority/watermelon/dashboard-content'
import {
  DashboardNavigationProvider,
  useDashboardNavigation,
} from '../components/authority/watermelon/navigation'
import { ThemeProvider } from '../components/authority/watermelon/theme-provider'

import AuthorityComplaintDetails from '../components/authority/AuthorityComplaintDetails'
import AuthorityEscalations from '../components/authority/AuthorityEscalations'
import AuthorityPerformance from '../components/authority/AuthorityPerformance'
import KanbanBoard from '../screens/kanban-board/KanbanBoard'
import Heatmap from './Heatmap'
import VerificationHub from '../screens/verification/VerificationHub'
import BmcOfficersPage from './BmcOfficersPage'
import { ShieldCheck, MapPin, Building, Phone, Mail, UserCheck } from 'lucide-react'

function DashboardRouter({
  authority,
  complaints,
  officers,
  notifications,
  onSelectComplaint,
  onUpdateComplaint,
  onLogout,
  onRefresh,
}) {
  const { pathname } = useDashboardNavigation()

  let content = null

  if (pathname === '/') {
    content = (
      <DashboardPage
        authority={authority}
        complaints={complaints}
        officers={officers}
        onSelectComplaint={onSelectComplaint}
      />
    )
  } else if (pathname === '/kanban') {
    content = (
      <div className="p-4 sm:p-6 w-full h-full min-h-[750px] animate-in fade-in duration-300">
        <div className="mb-4">
          <h2 className="text-2xl font-bold tracking-tight text-foreground">
            Field Dispatch Kanban Board
          </h2>
          <p className="text-xs text-muted-foreground">
            Track and drag field tickets by priority and resolution stage.
          </p>
        </div>
        <div className="w-full">
          <KanbanBoard hideHeader={true} initialOfficers={officers} />
        </div>
      </div>
    )
  } else if (pathname === '/heatmap' || pathname === '/map') {
    content = (
      <div className="p-4 sm:p-6 w-full animate-in fade-in duration-300">
        <Heatmap />
      </div>
    )
  } else if (pathname === '/verification') {
    content = (
      <div className="p-4 sm:p-6 w-full animate-in fade-in duration-300">
        <div className="mb-4">
          <h2 className="text-2xl font-bold tracking-tight text-foreground">
            Resolution Verification Tracking
          </h2>
          <p className="text-xs text-muted-foreground">
            Track community verification milestones and citizen review status.
          </p>
        </div>
        <VerificationHub />
      </div>
    )
  } else if (pathname === '/escalations') {
    content = (
      <div className="p-4 sm:p-6 max-w-[1600px] mx-auto animate-in fade-in duration-300">
        <div className="mb-6">
          <h2 className="text-2xl font-bold tracking-tight text-foreground">
            Critical Escalations
          </h2>
          <p className="text-xs text-muted-foreground">
            High upvote and SLA-breached complaints requiring rapid intervention.
          </p>
        </div>
        <AuthorityEscalations
          complaints={complaints}
          onRowClick={onSelectComplaint}
        />
      </div>
    )
  } else if (pathname === '/performance') {
    content = (
      <div className="p-4 sm:p-6 max-w-5xl mx-auto animate-in fade-in duration-300">
        <div className="mb-6">
          <h2 className="text-2xl font-bold tracking-tight text-foreground">
            Department Performance & SLA
          </h2>
          <p className="text-xs text-muted-foreground">
            Comparative analysis of resolution speed, verification score, and team throughput.
          </p>
        </div>
        <AuthorityPerformance />
      </div>
    )
  } else if (pathname === '/bmc-officers' || pathname === '/officers') {
    content = (
      <BmcOfficersPage
        officers={officers}
        complaints={complaints}
        onRefresh={onRefresh}
      />
    )
  } else if (pathname === '/settings') {
    content = (
      <div className="p-4 sm:p-6 max-w-3xl mx-auto animate-in fade-in duration-300">
        <div className="mb-6">
          <h2 className="text-2xl font-bold tracking-tight text-foreground">
            Authority Officer Profile & Ward
          </h2>
          <p className="text-xs text-muted-foreground">
            Official credentials, jurisdiction parameters, and department contact info.
          </p>
        </div>
        <div className="bg-card p-6 rounded-2xl border border-border/60 shadow-xs space-y-6">
          <div className="flex items-center gap-4 pb-6 border-b border-border/40">
            <div className="size-16 rounded-2xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary font-bold text-2xl">
              {authority?.name?.slice(0, 2) || 'AU'}
            </div>
            <div>
              <h3 className="text-xl font-bold text-foreground">{authority?.name}</h3>
              <p className="text-xs text-primary font-medium">{authority?.job_role || 'Zonal Authority Lead'}</p>
              <p className="text-xs text-muted-foreground">{authority?.department}</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="p-3 rounded-xl bg-secondary/50 border border-border/40 flex items-start gap-3">
              <Building className="size-5 text-primary mt-0.5 shrink-0" />
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Department</p>
                <p className="text-sm font-semibold text-foreground">{authority?.department || 'Brihanmumbai Municipal Corporation'}</p>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-secondary/50 border border-border/40 flex items-start gap-3">
              <MapPin className="size-5 text-emerald-500 mt-0.5 shrink-0" />
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Jurisdiction / Ward</p>
                <p className="text-sm font-semibold text-foreground">{authority?.jurisdiction || 'Ward H-West (Bandra - Khar)'}</p>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-secondary/50 border border-border/40 flex items-start gap-3">
              <Phone className="size-5 text-sky-500 mt-0.5 shrink-0" />
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Official Phone</p>
                <p className="text-sm font-semibold text-foreground">{authority?.phone || '+91 22 2642 1234'}</p>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-secondary/50 border border-border/40 flex items-start gap-3">
              <Mail className="size-5 text-amber-500 mt-0.5 shrink-0" />
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">Email</p>
                <p className="text-sm font-semibold text-foreground">{authority?.email || 'authority@unisafe.mumbai.gov.in'}</p>
              </div>
            </div>
          </div>

          <div className="pt-4 border-t border-border/40 flex justify-end">
            <button
              type="button"
              onClick={onLogout}
              className="px-4 py-2 text-xs font-semibold text-destructive bg-destructive/10 hover:bg-destructive/20 rounded-lg transition-colors"
            >
              Sign Out of Authority Portal
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <DashboardLayout authority={authority} onLogout={onLogout}>
      {content}
    </DashboardLayout>
  )
}

export default function AuthorityDashboard() {
  const [authority, setAuthority] = useState(null)
  const [complaints, setComplaints] = useState([])
  const [notifications, setNotifications] = useState([])
  const [officers, setOfficers] = useState([])
  const [loading, setLoading] = useState(true)
  const [selectedComplaint, setSelectedComplaint] = useState(null)

  const loadData = async () => {
    try {
      const profile = await getAuthorityProfile()
      if (profile) {
        setAuthority(profile)
        const [comps, notifs, auths] = await Promise.all([
          getComplaints(profile),
          getNotifications(profile.id),
          getAuthorities(),
        ])
        setComplaints(comps || [])
        setNotifications(notifs || [])
        setOfficers(auths || [])
      }
    } catch (err) {
      console.error('Dashboard initialization error:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadData()
  }, [])

  const handleLogout = async () => {
    await supabase.auth.signOut()
    window.location.reload()
  }

  const handleUpdateComplaint = (complaintId, newStatus) => {
    setComplaints((prev) =>
      prev.map((c) => (c.id === complaintId ? { ...c, status: newStatus } : c))
    )
    if (selectedComplaint?.id === complaintId) {
      setSelectedComplaint((prev) => ({ ...prev, status: newStatus }))
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-3 border-primary border-t-transparent rounded-full animate-spin" />
          <p className="text-xs font-medium text-muted-foreground">
            Authenticating UniSafe Authority...
          </p>
        </div>
      </div>
    )
  }

  return (
    <ThemeProvider defaultTheme="light" storageKey="unisafe-authority-theme">
      <DashboardNavigationProvider initialPath="/">
        <DashboardRouter
          onRefresh={loadData}
          authority={authority}
          complaints={complaints}
          officers={officers}
          notifications={notifications}
          onSelectComplaint={setSelectedComplaint}
          onUpdateComplaint={handleUpdateComplaint}
          onLogout={handleLogout}
        />

        {/* Selected Complaint Detail Drawer */}
        <AuthorityComplaintDetails
          complaint={selectedComplaint}
          authority={authority}
          onClose={() => setSelectedComplaint(null)}
          onUpdate={handleUpdateComplaint}
        />
      </DashboardNavigationProvider>
    </ThemeProvider>
  )
}
