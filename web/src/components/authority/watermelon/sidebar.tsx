import {
  BookOpenIcon,
  ChevronRight,
  HomeIcon,
  LogOutIcon,
  MessageCircleIcon,
  MoonIcon,
  SunIcon,
} from 'lucide-react'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
} from '@/components/ui/avatar'
import { UniSafeLogo } from './logo'
import { SidebarCollapseIcon } from './icons'
import { DashboardLink, useDashboardNavigation } from './navigation'
import { useTheme } from './theme-provider'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuBadge,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
  useSidebar,
} from '@/components/ui/sidebar'
import { currentUser, navigationGroups, type NavigationItem } from './data'
import { cn } from '@/lib/utils'

const sidebarGroupLabelClassName =
  'h-auto px-2 py-1 text-[11px] font-bold uppercase tracking-wider text-muted-foreground/70 select-none'

function NavItem({ item }: { item: NavigationItem }) {
  const { pathname } = useDashboardNavigation()
  const { isMobile, setOpenMobile, state } = useSidebar()
  const isCollapsed = !isMobile && state === 'collapsed'

  const isActive =
    item.href === '/'
      ? pathname === '/'
      : pathname === item.href || pathname.startsWith(`${item.href}/`)

  return (
    <SidebarMenuButton
      asChild
      tooltip={isCollapsed ? item.name : undefined}
      className={cn(
        'relative h-10 w-full rounded-lg bg-transparent py-0 px-2 text-sm font-medium text-muted-foreground transition-colors duration-150 select-none overflow-hidden',
        'hover:!bg-sidebar-accent hover:text-foreground',
        'aria-[current=page]:!bg-primary/10 aria-[current=page]:font-semibold aria-[current=page]:text-primary'
      )}
    >
      <DashboardLink
        href={item.href}
        aria-current={isActive ? 'page' : undefined}
        className="flex h-full w-full items-center text-left"
        onClick={() => {
          if (isMobile) setOpenMobile(false)
        }}
      >
        {/* Fixed 32px slot: never moves, perfectly centered in both 64px rail and full width */}
        <div className="flex size-8 shrink-0 items-center justify-center">
          <item.icon className="size-4.5 shrink-0" />
        </div>

        {/* Text container: fades out without moving the icon or wrapping */}
        <div
          className={cn(
            'ml-2.5 flex flex-1 min-w-0 items-center justify-between overflow-hidden whitespace-nowrap transition-all duration-200 ease-linear',
            isCollapsed
              ? 'max-w-0 opacity-0 pointer-events-none'
              : 'max-w-[180px] opacity-100'
          )}
        >
          <span className="truncate text-left font-medium">{item.name}</span>
          {item.badge ? (
            <SidebarMenuBadge className="shrink-0 ml-1">
              {item.badge}
            </SidebarMenuBadge>
          ) : null}
        </div>
      </DashboardLink>
    </SidebarMenuButton>
  )
}

export function DashboardSidebar({
  authority,
  onLogout,
}: {
  authority?: any
  onLogout?: () => void
}) {
  const { resolvedTheme, setTheme } = useTheme()
  const { state, toggleSidebar, isMobile } = useSidebar()
  const isDark = resolvedTheme === 'dark'
  const isCollapsed = !isMobile && state === 'collapsed'

  const activeUser = {
    name: authority?.name || currentUser.name,
    email: authority?.email || currentUser.email,
    department: authority?.department || currentUser.department,
    jurisdiction: authority?.jurisdiction || currentUser.jurisdiction,
    avatar: currentUser.avatar,
  }

  return (
    <Sidebar collapsible="icon" className="border-r border-border/50 select-none">
      <SidebarHeader className="relative h-16 flex flex-row items-center px-2">
        <div className="flex items-center w-full min-w-0">
          {/* Logo container: fixed 32px slot */}
          <div
            className={cn(
              'flex size-8 shrink-0 items-center justify-center cursor-pointer transition-transform hover:scale-105',
              isCollapsed && 'cursor-pointer'
            )}
            onClick={isCollapsed ? toggleSidebar : undefined}
            title={isCollapsed ? 'Click to expand sidebar' : undefined}
          >
            <UniSafeLogo className="size-7.5 shrink-0" />
          </div>

          {/* Header Title: fades out smoothly */}
          <div
            className={cn(
              'ml-2.5 flex flex-col min-w-0 overflow-hidden whitespace-nowrap transition-all duration-200 ease-linear flex-1',
              isCollapsed
                ? 'max-w-0 opacity-0 pointer-events-none'
                : 'max-w-[140px] opacity-100'
            )}
          >
            <span className="truncate text-sm font-bold tracking-tight text-foreground select-none">
              UniSafe Authority
            </span>
            <span className="text-[10px] text-muted-foreground truncate uppercase font-semibold tracking-wider select-none">
              {activeUser.department ? activeUser.department.slice(0, 20) : 'Civic Operations'}
            </span>
          </div>

          {/* Toggle Button */}
          {!isCollapsed && (
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleSidebar}
              aria-label="Collapse sidebar"
              className="size-8 rounded-lg hover:bg-sidebar-accent shrink-0 ml-auto"
            >
              <SidebarCollapseIcon className="size-4" />
            </Button>
          )}
        </div>
      </SidebarHeader>

      {/* Expand button row when collapsed */}
      {isCollapsed && (
        <div className="flex h-8 items-center justify-center px-2 mb-1">
          <Button
            variant="ghost"
            size="icon"
            onClick={toggleSidebar}
            aria-label="Expand sidebar"
            className="size-8 rounded-lg hover:bg-sidebar-accent text-muted-foreground hover:text-foreground"
          >
            <SidebarCollapseIcon className="size-4 rotate-180" />
          </Button>
        </div>
      )}

      <SidebarContent className="gap-2 px-2 py-1">
        {navigationGroups.map((group) => {
          return (
            <SidebarGroup key={group.label} className="gap-1 p-0">
              <div
                className={cn(
                  'overflow-hidden whitespace-nowrap transition-all duration-200 ease-linear',
                  isCollapsed
                    ? 'max-h-0 opacity-0 pointer-events-none mb-0'
                    : 'max-h-7 opacity-100 mb-0.5'
                )}
              >
                <SidebarGroupLabel className={sidebarGroupLabelClassName}>
                  {group.label}
                </SidebarGroupLabel>
              </div>

              <SidebarGroupContent>
                <SidebarMenu className="gap-0.5">
                  {group.items.map((item) => (
                    <SidebarMenuItem key={item.name}>
                      <NavItem item={item} />
                    </SidebarMenuItem>
                  ))}
                </SidebarMenu>
              </SidebarGroupContent>
            </SidebarGroup>
          )
        })}
      </SidebarContent>

      <SidebarFooter className="px-2 py-2 border-t border-border/40">
        <SidebarGroup className="gap-0 p-0">
          <div
            className={cn(
              'overflow-hidden whitespace-nowrap transition-all duration-200 ease-linear',
              isCollapsed
                ? 'max-h-0 opacity-0 pointer-events-none mb-0'
                : 'max-h-7 opacity-100 mb-0.5'
            )}
          >
            <SidebarGroupLabel className={sidebarGroupLabelClassName}>
              Officer In Charge
            </SidebarGroupLabel>
          </div>
          <SidebarMenu className="gap-0">
            <SidebarMenuItem>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <SidebarMenuButton
                    tooltip={isCollapsed ? activeUser.name : undefined}
                    className="relative h-11 w-full rounded-lg bg-transparent py-0 px-2 text-sm font-medium text-muted-foreground transition-colors duration-150 select-none overflow-hidden hover:!bg-sidebar-accent hover:text-foreground"
                  >
                    <div className="flex h-full w-full items-center text-left">
                      {/* Avatar: fixed 32px slot */}
                      <div className="flex size-8 shrink-0 items-center justify-center">
                        <Avatar size="sm" className="size-8 border border-primary/30 ring-1 ring-primary/20 shrink-0">
                          <AvatarImage
                            src={activeUser.avatar}
                            alt={activeUser.name}
                          />
                          <AvatarFallback>
                            {activeUser.name.slice(0, 2)}
                          </AvatarFallback>
                        </Avatar>
                      </div>

                      {/* Profile text: fades out without moving avatar */}
                      <div
                        className={cn(
                          'ml-2.5 flex flex-col text-left truncate min-w-0 transition-all duration-200 ease-linear overflow-hidden whitespace-nowrap flex-1',
                          isCollapsed
                            ? 'max-w-0 opacity-0 pointer-events-none'
                            : 'max-w-[140px] opacity-100'
                        )}
                      >
                        <span className="truncate text-xs font-semibold text-foreground select-none">
                          {activeUser.name}
                        </span>
                        <span className="truncate text-[10px] text-muted-foreground select-none">
                          {activeUser.jurisdiction || 'Mumbai Head Office'}
                        </span>
                      </div>
                    </div>
                  </SidebarMenuButton>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                  side="top"
                  align="start"
                  className="w-60"
                >
                  <DropdownMenuLabel className="font-normal">
                    <div className="leading-tight">
                      <p className="text-sm font-semibold text-foreground">
                        {activeUser.name}
                      </p>
                      <p className="text-xs text-muted-foreground truncate">
                        {activeUser.email}
                      </p>
                    </div>
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  <DropdownMenuGroup>
                    <DropdownMenuItem
                      onClick={() => setTheme(isDark ? 'light' : 'dark')}
                    >
                      {isDark ? <SunIcon className="size-4" /> : <MoonIcon className="size-4" />}
                      <span>{isDark ? 'Light Theme' : 'Dark Theme'}</span>
                    </DropdownMenuItem>
                    <DropdownMenuItem asChild>
                      <a href="/home">
                        <HomeIcon className="size-4" />
                        <span>Citizen Portal (Home)</span>
                      </a>
                    </DropdownMenuItem>
                    <DropdownMenuItem asChild>
                      <a
                        href="#handbook"
                        onClick={(e) => { e.preventDefault(); alert('Opening UniSafe Official SOP Guidelines'); }}
                      >
                        <BookOpenIcon className="size-4" />
                        <span>SOP & Guidelines</span>
                      </a>
                    </DropdownMenuItem>
                    <DropdownMenuItem asChild>
                      <a
                        href="#support"
                        onClick={(e) => { e.preventDefault(); alert('Connecting to Central Municipal Control Room: 1916'); }}
                      >
                        <MessageCircleIcon className="size-4" />
                        <span>Control Room (1916)</span>
                      </a>
                    </DropdownMenuItem>
                  </DropdownMenuGroup>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    variant="destructive"
                    onClick={() => {
                      if (onLogout) onLogout()
                    }}
                  >
                    <LogOutIcon className="size-4" />
                    <span>Log out</span>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </SidebarMenuItem>
          </SidebarMenu>
        </SidebarGroup>
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
