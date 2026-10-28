import type { CSSProperties, ReactNode } from 'react'
import { DashboardSidebar } from './sidebar'
import { DashboardTopbar } from './topbar'
import { SidebarProvider } from '@/components/ui/sidebar'
import './dashboard.css'

type DashboardLayoutProps = {
  children: ReactNode
  authority?: any
  onLogout?: () => void
  searchQuery?: string
  setSearchQuery?: (query: string) => void
}

export default function DashboardLayout({
  children,
  authority,
  onLogout,
  searchQuery,
  setSearchQuery,
}: DashboardLayoutProps) {
  return (
    <SidebarProvider
      defaultOpen
      className="unisafe-authority-dashboard h-svh overflow-hidden no-scrollbar bg-background text-foreground"
      style={
        {
          '--sidebar-width': '16.5rem',
          '--sidebar-width-icon': '4rem',
        } as CSSProperties
      }
    >
      <DashboardSidebar authority={authority} onLogout={onLogout} />

      <main className="flex min-w-0 flex-1 flex-col overflow-hidden bg-background p-0 md:p-2 md:pl-0">
        <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden bg-card border border-border/50 md:rounded-xl shadow-xs">
          <DashboardTopbar searchQuery={searchQuery} setSearchQuery={setSearchQuery} />
          <div className="flex-1 overflow-y-auto no-scrollbar">{children}</div>
        </div>
      </main>
    </SidebarProvider>
  )
}
