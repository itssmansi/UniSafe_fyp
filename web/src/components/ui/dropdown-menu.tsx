import * as React from 'react';
import { cn } from '@/lib/utils';
import { Check } from 'lucide-react';

interface DropdownMenuContextType {
  open: boolean;
  setOpen: React.Dispatch<React.SetStateAction<boolean>>;
}

const DropdownMenuContext = React.createContext<DropdownMenuContextType | null>(null);

export function DropdownMenu({
  children,
  open: controlledOpen,
  onOpenChange,
}: {
  children: React.ReactNode;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
}) {
  const [uncontrolledOpen, setUncontrolledOpen] = React.useState(false);
  const isControlled = controlledOpen !== undefined;
  const open = isControlled ? controlledOpen : uncontrolledOpen;

  const setOpen = React.useCallback(
    (value: boolean | ((prev: boolean) => boolean)) => {
      const nextOpen = typeof value === 'function' ? value(open) : value;
      if (!isControlled) {
        setUncontrolledOpen(nextOpen);
      }
      onOpenChange?.(nextOpen);
    },
    [isControlled, open, onOpenChange]
  );

  return (
    <DropdownMenuContext.Provider value={{ open, setOpen }}>
      <div className="relative inline-block text-left">{children}</div>
    </DropdownMenuContext.Provider>
  );
}

export function DropdownMenuTrigger({
  asChild,
  children,
  className,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { asChild?: boolean }) {
  const ctx = React.useContext(DropdownMenuContext);

  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
    props.onClick?.(e);
    if (!e.defaultPrevented) {
      ctx?.setOpen((prev) => !prev);
    }
  };

  if (asChild && React.isValidElement(children)) {
    return React.cloneElement(children as React.ReactElement<any>, {
      onClick: (e: any) => {
        children.props.onClick?.(e);
        if (!e.defaultPrevented) {
          ctx?.setOpen((prev) => !prev);
        }
      },
      'aria-expanded': ctx?.open,
    });
  }

  return (
    <button
      type="button"
      aria-expanded={ctx?.open}
      className={className}
      onClick={handleClick}
      {...props}
    >
      {children}
    </button>
  );
}

export function DropdownMenuContent({
  className,
  side = 'bottom',
  align = 'end',
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & {
  side?: 'top' | 'bottom' | 'left' | 'right';
  align?: 'start' | 'center' | 'end';
}) {
  const ctx = React.useContext(DropdownMenuContext);
  const ref = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        const trigger = ref.current.parentElement?.querySelector('[aria-expanded="true"]');
        if (trigger && trigger.contains(event.target as Node)) return;
        ctx?.setOpen(false);
      }
    }
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        ctx?.setOpen(false);
      }
    }
    if (ctx?.open) {
      document.addEventListener('mousedown', handleClickOutside);
      document.addEventListener('keydown', handleKeyDown);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [ctx?.open, ctx]);

  if (!ctx?.open) return null;

  const positionClasses = cn(
    'absolute z-50 min-w-[10rem] overflow-hidden rounded-md border border-border/60 bg-popover p-1 text-popover-foreground shadow-lg backdrop-blur-md',
    side === 'top' ? 'bottom-full mb-2' : 'top-full mt-2',
    align === 'start' ? 'left-0' : align === 'center' ? 'left-1/2 -translate-x-1/2' : 'right-0',
    className
  );

  return (
    <div ref={ref} className={positionClasses} {...props}>
      {children}
    </div>
  );
}

export function DropdownMenuGroup({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn('p-1', className)} {...props}>
      {children}
    </div>
  );
}

export function DropdownMenuItem({
  asChild,
  className,
  variant,
  children,
  onClick,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & {
  asChild?: boolean;
  variant?: 'default' | 'destructive';
}) {
  const ctx = React.useContext(DropdownMenuContext);

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    onClick?.(e);
    if (!e.defaultPrevented) {
      ctx?.setOpen(false);
    }
  };

  const itemClass = cn(
    'relative flex cursor-pointer select-none items-center gap-2 rounded-sm px-2.5 py-1.5 text-sm outline-none transition-colors hover:bg-accent hover:text-accent-foreground',
    variant === 'destructive' && 'text-destructive hover:bg-destructive/10 hover:text-destructive',
    className
  );

  if (asChild && React.isValidElement(children)) {
    return React.cloneElement(children as React.ReactElement<any>, {
      className: cn(itemClass, children.props.className),
      onClick: (e: any) => {
        children.props.onClick?.(e);
        if (!e.defaultPrevented) ctx?.setOpen(false);
      },
    });
  }

  return (
    <div className={itemClass} onClick={handleClick} {...props}>
      {children}
    </div>
  );
}

export function DropdownMenuLabel({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn('px-2.5 py-1.5 text-xs font-semibold uppercase tracking-wider text-muted-foreground', className)} {...props}>
      {children}
    </div>
  );
}

export function DropdownMenuSeparator({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('-mx-1 my-1 h-px bg-border/60', className)} {...props} />;
}

export function DropdownMenuRadioGroup({
  value,
  onValueChange,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & {
  value?: string;
  onValueChange?: (value: string) => void;
}) {
  return (
    <div {...props}>
      {React.Children.map(children, (child) => {
        if (React.isValidElement(child)) {
          return React.cloneElement(child as React.ReactElement<any>, {
            _selectedValue: value,
            _onSelect: onValueChange,
          });
        }
        return child;
      })}
    </div>
  );
}

export function DropdownMenuRadioItem({
  value,
  _selectedValue,
  _onSelect,
  children,
  className,
  onClick,
  ...props
}: React.HTMLAttributes<HTMLDivElement> & {
  value: string;
  _selectedValue?: string;
  _onSelect?: (value: string) => void;
}) {
  const ctx = React.useContext(DropdownMenuContext);
  const isSelected = _selectedValue === value;

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    onClick?.(e);
    _onSelect?.(value);
    ctx?.setOpen(false);
  };

  return (
    <div
      className={cn(
        'relative flex cursor-pointer select-none items-center rounded-sm py-1.5 pl-7 pr-2 text-sm outline-none transition-colors hover:bg-accent hover:text-accent-foreground',
        isSelected && 'font-medium text-foreground bg-accent/40',
        className
      )}
      onClick={handleClick}
      {...props}
    >
      <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
        {isSelected ? <Check className="h-3.5 w-3.5" /> : null}
      </span>
      {children}
    </div>
  );
}
