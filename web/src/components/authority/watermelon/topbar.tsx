import { useEffect, useRef, useState } from 'react'
import { CloseIcon, CommandIcon, SearchIcon } from './icons'
import { useDashboardNavigation } from './navigation'
import { Button } from '@/components/ui/button'
import {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from '@/components/ui/input-group'
import { SidebarTrigger } from '@/components/ui/sidebar'
import { navigationGroups } from './data'

export function DashboardTopbar({
  searchQuery,
  setSearchQuery,
}: {
  searchQuery?: string
  setSearchQuery?: (query: string) => void
}) {
  const { pathname } = useDashboardNavigation()
  const [localSearchQuery, setLocalSearchQuery] = useState('')
  const [isMobileSearchOpen, setIsMobileSearchOpen] = useState(false)

  const activeQuery = searchQuery !== undefined ? searchQuery : localSearchQuery
  const handleQueryChange = (val: string) => {
    if (setSearchQuery) setSearchQuery(val)
    setLocalSearchQuery(val)
  }

  const searchInputRef = useRef<HTMLInputElement>(null)
  const mobileSearchInputRef = useRef<HTMLInputElement>(null)

  const currentPage =
    navigationGroups
      .flatMap((group) => group.items)
      .find((item) => item.href === pathname) ?? navigationGroups[0].items[0]

  const CurrentPageIcon = currentPage.icon

  const openMobileSearch = () => {
    setIsMobileSearchOpen(true)
    requestAnimationFrame(() => {
      mobileSearchInputRef.current?.focus()
    })
  }

  const closeMobileSearch = () => {
    setIsMobileSearchOpen(false)
  }

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()

        if (window.matchMedia('(max-width: 767px)').matches) {
          setIsMobileSearchOpen(true)
          requestAnimationFrame(() => {
            mobileSearchInputRef.current?.focus()
          })
          return
        }

        searchInputRef.current?.focus()
      }

      if (event.key === 'Escape') {
        setIsMobileSearchOpen(false)
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [])

  return (
    <header className="flex h-18 shrink-0 items-center justify-between gap-4 px-5 md:px-6 border-b border-border/40 bg-background/80 backdrop-blur-md">
      {isMobileSearchOpen ? (
        <div className="flex w-full items-center gap-2 md:hidden">
          <InputGroup className="h-9 flex-1 rounded-lg border border-border/60 bg-secondary/80 py-1 pr-2 pl-3">
            <InputGroupAddon className="pl-0 text-muted-foreground">
              <SearchIcon className="size-4" />
            </InputGroupAddon>
            <InputGroupInput
              ref={mobileSearchInputRef}
              className="h-full p-0 px-1.5 text-sm leading-5 tracking-tight placeholder:text-muted-foreground"
              aria-label="Search civic complaints and officers"
              placeholder="Search complaints, wards, officers..."
              value={activeQuery}
              onChange={(event) => handleQueryChange(event.target.value)}
            />
          </InputGroup>
          <Button
            type="button"
            variant="outline"
            size="icon"
            className="shrink-0 rounded-lg"
            aria-label="Close search"
            onClick={closeMobileSearch}
          >
            <CloseIcon />
          </Button>
        </div>
      ) : (
        <>
          <div className="flex min-w-0 items-center gap-2">
            <SidebarTrigger
              className="shrink-0 md:hidden [&_svg]:size-5"
            />
            <div className="hidden items-center gap-4 md:flex">
              <div className="flex h-6 items-center gap-2.5">
                <CurrentPageIcon className="size-4 text-primary" />
                <span className="text-lg leading-6.5 font-semibold text-foreground tracking-tight">
                  {currentPage.name}
                </span>
              </div>
              <div className="flex h-6 items-center gap-1.5">
                <span className="size-2 rounded-full bg-emerald-500 animate-pulse" />
                <span className="text-xs text-muted-foreground">
                  Live Dispatch: <span className="text-foreground/90 font-medium">Active</span>
                </span>
              </div>
            </div>
          </div>

          <InputGroup className="hidden h-9 w-72 shrink-0 rounded-lg border border-border/50 bg-secondary/60 py-1 pr-2 pl-2.5 md:flex focus-within:border-primary/50 focus-within:bg-background transition-all">
            <InputGroupAddon className="gap-1.5 p-0 text-muted-foreground">
              <SearchIcon className="size-3.5" />
            </InputGroupAddon>
            <InputGroupInput
              ref={searchInputRef}
              className="h-full p-0 px-1 text-xs placeholder:text-muted-foreground"
              aria-label="Search complaints and staff"
              placeholder="Search complaints, wards, staff..."
              value={activeQuery}
              onChange={(event) => handleQueryChange(event.target.value)}
            />
            {activeQuery === '' ? (
              <InputGroupAddon align="inline-end" className="p-0 text-muted-foreground">
                <div className="flex h-5 w-8 items-center justify-center gap-1 rounded bg-background/80 border border-border/40 p-1">
                  <CommandIcon className="size-2.5" />
                  <span className="text-[10px] font-semibold leading-none">K</span>
                </div>
              </InputGroupAddon>
            ) : null}
          </InputGroup>

          <div className="flex items-center gap-2">
            <a
              href="/home"
              title="Return to Citizen Portal"
              className="inline-flex items-center gap-1.5 h-9 px-3 rounded-lg border border-border/60 bg-secondary/50 text-xs font-semibold text-muted-foreground hover:text-foreground hover:bg-secondary transition-all"
            >
              <svg className="size-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>
              <span className="hidden sm:inline">Citizen Portal</span>
            </a>

            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="shrink-0 md:hidden"
              aria-label="Open search"
              onClick={openMobileSearch}
            >
              <SearchIcon className="size-4" />
            </Button>
          </div>
        </>
      )}
    </header>
  )
}
