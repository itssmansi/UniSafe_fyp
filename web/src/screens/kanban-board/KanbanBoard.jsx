import React, { useState, useEffect, useRef, useMemo, memo } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../services/supabase';
import { useSmartBack } from '../../hooks/useSmartBack';
import ResolutionModal from './ResolutionModal';
import AssignOfficerModal from './AssignOfficerModal';
import { assignComplaintToOfficer } from '../../services/authorityService';
import {
  Search,
  X,
  Clock,
  CheckCircle2,
  Eye,
  Flame,
  AlertTriangle,
  RefreshCw,
  MapPin,
  ListFilter,
  Layers,
  Copy,
  ArrowUp,
  Check,
  ChevronDown,
  Sparkles,
  ArrowUpDown,
  Filter,
  Shield,
  Tag,
  UserCheck
} from 'lucide-react';

// --- Column Configuration (Solid, Clean, Modern SaaS Styling) ---
const COLUMNS = [
  {
    id: 'planned',
    title: 'Planned',
    subtitle: 'Triage & Backlog Queue',
    dotColor: '#475569',
    badge: 'bg-slate-100 text-slate-700 border-slate-200',
    headerBg: 'bg-slate-100/90 border-b border-slate-200',
    columnBg: 'bg-slate-50/70 border border-slate-200/90',
    topStripe: 'bg-slate-500',
    icon: ListFilter,
  },
  {
    id: 'in-progress',
    title: 'In Progress',
    subtitle: 'Units Dispatched to Field',
    dotColor: '#D97706',
    badge: 'bg-amber-100 text-amber-800 border-amber-200',
    headerBg: 'bg-amber-50/90 border-b border-amber-200',
    columnBg: 'bg-amber-50/30 border border-amber-200/80',
    topStripe: 'bg-amber-500',
    icon: Clock,
  },
  {
    id: 'in-review',
    title: 'In Review',
    subtitle: 'Awaiting Citizen Verification',
    dotColor: '#2563EB',
    badge: 'bg-blue-100 text-blue-800 border-blue-200',
    headerBg: 'bg-blue-50/90 border-b border-blue-200',
    columnBg: 'bg-blue-50/30 border border-blue-200/80',
    topStripe: 'bg-blue-500',
    icon: Eye,
  },
  {
    id: 'done',
    title: 'Done & Verified',
    subtitle: 'Closed with Citizen Proof',
    dotColor: '#059669',
    badge: 'bg-emerald-100 text-emerald-800 border-emerald-200',
    headerBg: 'bg-emerald-50/90 border-b border-emerald-200',
    columnBg: 'bg-emerald-50/30 border border-emerald-200/80',
    topStripe: 'bg-emerald-500',
    icon: CheckCircle2,
  },
];

// --- Helpers: Formatting & Categorization ---
const getCategoryStyle = (category) => {
  const cat = (category || '').toLowerCase();
  if (cat.includes('water') || cat.includes('pipeline') || cat.includes('drainage') || cat.includes('sewage')) {
    return {
      bg: 'bg-sky-50',
      text: 'text-sky-800',
      border: 'border-sky-200',
      icon: '💧',
      label: 'Water & Drainage'
    };
  }
  if (cat.includes('garbage') || cat.includes('waste') || cat.includes('dump') || cat.includes('debris') || cat.includes('cleanliness')) {
    return {
      bg: 'bg-emerald-50',
      text: 'text-emerald-800',
      border: 'border-emerald-200',
      icon: '🗑️',
      label: 'Solid Waste'
    };
  }
  if (cat.includes('road') || cat.includes('pothole') || cat.includes('traffic') || cat.includes('manhole')) {
    return {
      bg: 'bg-orange-50',
      text: 'text-orange-800',
      border: 'border-orange-200',
      icon: '🚧',
      label: 'Road Infrastructure'
    };
  }
  if (cat.includes('light') || cat.includes('lamp') || cat.includes('electric') || cat.includes('power')) {
    return {
      bg: 'bg-amber-50',
      text: 'text-amber-800',
      border: 'border-amber-200',
      icon: '💡',
      label: 'Street Lighting'
    };
  }
  if (cat.includes('zone') || cat.includes('hotspot') || cat.includes('cluster')) {
    return {
      bg: 'bg-purple-50',
      text: 'text-purple-800',
      border: 'border-purple-200',
      icon: '📍',
      label: 'Cluster Hotspot'
    };
  }
  return {
    bg: 'bg-slate-100',
    text: 'text-slate-800',
    border: 'border-slate-200',
    icon: '📋',
    label: category || 'Civic Issue'
  };
};

const formatTitle = (title, category) => {
  if (!title) return 'Civic Issue';
  const t = title.trim();
  if (t.toLowerCase() === 'water') return 'Water Pipeline & Pressure Leakage';
  if (t.toLowerCase() === 'drainage') return 'Drainage & Sewage Overflow';
  if (t.toLowerCase() === 'garbage') return 'Solid Waste Dumping & Overflowing Bin';
  if (t.toLowerCase() === 'roads' || t.toLowerCase() === 'road') return 'Severe Crater Pothole & Road Hazard';
  if (t.toLowerCase().startsWith('zone:')) {
    return t.replace(/^zone:\s*/i, 'Cluster Hotspot: ');
  }
  if (t === t.toLowerCase()) {
    return t.replace(/\b\w/g, c => c.toUpperCase());
  }
  return t;
};

const formatTicketId = (id, sourceType) => {
  if (!id) return 'uni-00000000';
  if (sourceType === 'zone') {
    const clean = String(id).replace(/[^a-zA-Z0-9]/g, '');
    return `ZON-${clean.slice(0, 4).toUpperCase()}`;
  }
  const clean = String(id).toLowerCase();
  return `uni-${clean.slice(0, 8)}`;
};

const parseComplaintContent = (item) => {
  let title = item.title;
  let rawDesc = (item.description || '').replace(/\\n/g, '\n');
  let description = rawDesc;
  
  if ((!title || title.toLowerCase() === (item.category || '').toLowerCase() || title.toLowerCase() === 'civic issue') && rawDesc.includes('\n')) {
    const lines = rawDesc.split('\n');
    if (lines[0].trim()) {
      title = lines[0].trim();
      description = lines.slice(1).join('\n').trim();
    }
  }
  if (!title) {
    title = item.category || 'Civic Issue';
  }
  return { title, description };
};

// --- Subcomponent: Memoized Kanban Card (Identical in Board and Drag Clone) ---
const KanbanCard = memo(({ task, isDragging, onPointerDown, onClick }) => {
  const catStyle = getCategoryStyle(task.category);
  const formattedTitle = formatTitle(task.title, task.category);
  const ticketId = formatTicketId(task.id, task.source_type);
  const upvotes = task.upvote_count || 0;
  const isCritical = task.severity === 'HIGH' || upvotes >= 10;

  return (
    <div
      onPointerDown={onPointerDown}
      onClick={onClick}
      className={`group relative bg-white rounded-xl p-3.5 border transition-all duration-150 select-none cursor-grab active:cursor-grabbing w-full h-full flex flex-col justify-between ${
        isDragging
          ? 'opacity-30 border-2 border-dashed border-slate-300 bg-slate-50 shadow-none'
          : 'opacity-100 border-slate-200 shadow-xs hover:shadow-md hover:border-slate-300 hover:-translate-y-0.5'
      } ${isCritical && task.column !== 'done' ? 'border-l-4 border-l-rose-500' : ''}`}
    >
      <div>
        {/* Top Meta: Ticket Code + Category Pill + Upvotes / Priority */}
        <div className="flex items-center justify-between gap-1.5 mb-2.5">
          <div className="flex items-center gap-1.5 min-w-0">
            <span className="font-mono text-[10.5px] font-bold text-slate-500 bg-slate-100 border border-slate-200/90 px-1.5 py-0.5 rounded tracking-wide shrink-0">
              {ticketId}
            </span>
            <span
              className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10.5px] font-semibold border truncate max-w-[130px] ${catStyle.bg} ${catStyle.text} ${catStyle.border}`}
            >
              <span>{catStyle.icon}</span>
              <span className="truncate">{catStyle.label}</span>
            </span>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            {upvotes > 0 && (
              <span
                className="inline-flex items-center gap-0.5 text-[10.5px] font-extrabold text-rose-700 bg-rose-50 border border-rose-200 px-1.5 py-0.5 rounded-full shadow-2xs"
                title={`${upvotes} Citizen Upvotes`}
              >
                <ArrowUp className="size-2.5 stroke-[3]" />
                <span>{upvotes}</span>
              </span>
            )}

            {task.severity === 'HIGH' ? (
              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[9.5px] font-extrabold uppercase tracking-wide bg-rose-100 text-rose-800 border border-rose-200">
                <span className="size-1.5 rounded-full bg-rose-600 animate-pulse"></span>
                High
              </span>
            ) : task.severity === 'MEDIUM' ? (
              <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[9.5px] font-bold uppercase tracking-wide bg-amber-100 text-amber-800 border border-amber-200">
                Med
              </span>
            ) : (
              <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[9.5px] font-medium uppercase tracking-wide bg-slate-100 text-slate-600 border border-slate-200">
                Low
              </span>
            )}
          </div>
        </div>

        {/* Title */}
        <h4 className="font-bold text-slate-900 text-[13.5px] leading-snug line-clamp-2 group-hover:text-blue-600 transition-colors">
          {formattedTitle}
        </h4>

        {/* Description */}
        {task.description && (
          <p className="text-[12px] text-slate-600 line-clamp-2 mt-1.5 leading-relaxed font-normal">
            {task.description}
          </p>
        )}
      </div>

      {/* Footer Info Row */}
      <div className="flex items-center justify-between pt-2.5 mt-2.5 border-t border-slate-100 text-[11px] text-slate-500">
        <div className="flex items-center gap-1 text-slate-400">
          <Clock className="size-3" />
          <span>{task.date}</span>
        </div>

        {task.assigned_officer_name && (
          <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-slate-700 bg-slate-100 border border-slate-200 px-2 py-0.5 rounded-full truncate max-w-[140px]" title={"Assigned to " + task.assigned_officer_name}>
            <UserCheck className="size-2.5 text-amber-600 shrink-0" />
            <span className="truncate">{task.assigned_officer_name}</span>
          </span>
        )}

        {task.column === 'in-progress' && (
          <span className="inline-flex items-center gap-1 text-[10px] font-bold text-amber-800 bg-amber-50 border border-amber-200 px-2 py-0.5 rounded-full">
            <span className="size-1.5 rounded-full bg-amber-500 animate-ping"></span>
            In Field
          </span>
        )}

        {task.column === 'in-review' && (
          <span className="inline-flex items-center gap-1 text-[10px] font-bold text-blue-800 bg-blue-50 border border-blue-200 px-2 py-0.5 rounded-full">
            <Eye className="size-2.5" />
            Citizen Review
          </span>
        )}

        {task.column === 'done' && (
          <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-800 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
            <CheckCircle2 className="size-2.5 text-emerald-600" />
            Verified
          </span>
        )}

        {task.column === 'planned' && (
          <span className="text-[10px] text-slate-400 font-medium">
            Queued
          </span>
        )}
      </div>
    </div>
  );
});

// --- Subcomponent: Ticket Details Modal ---
const TicketDetailsModal = ({ task, onClose, onAdvanceStatus }) => {
  const [copied, setCopied] = useState(false);
  if (!task) return null;

  const catStyle = getCategoryStyle(task.category);
  const formattedTitle = formatTitle(task.title, task.category);
  const ticketId = formatTicketId(task.id, task.source_type);

  const copyId = () => {
    navigator.clipboard.writeText(ticketId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-[9999] bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in duration-150">
      <div 
        className="bg-white rounded-2xl max-w-lg w-full shadow-2xl border border-slate-200 overflow-hidden relative animate-in zoom-in-95 duration-150"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/80">
          <div className="flex items-center gap-2">
            <span className="font-mono text-xs font-bold text-slate-800 bg-white border border-slate-200 px-2.5 py-1 rounded-lg shadow-2xs">
              {ticketId}
            </span>
            <button
              onClick={copyId}
              className="text-xs text-slate-500 hover:text-slate-800 flex items-center gap-1 p-1 hover:bg-slate-200/60 rounded transition-colors cursor-pointer"
              title="Copy Ticket ID"
            >
              {copied ? <Check className="size-3 text-emerald-600" /> : <Copy className="size-3" />}
              <span>{copied ? 'Copied' : 'Copy'}</span>
            </button>
          </div>

          <button
            onClick={onClose}
            className="size-8 rounded-lg flex items-center justify-center text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors cursor-pointer"
          >
            <X className="size-4" />
          </button>
        </div>

        {/* Content */}
        <div className="p-5 space-y-4 max-h-[75vh] overflow-y-auto">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-bold border ${catStyle.bg} ${catStyle.text} ${catStyle.border}`}>
              <span>{catStyle.icon}</span>
              <span>{catStyle.label}</span>
            </span>

            <span className="text-xs font-bold uppercase tracking-wider px-2.5 py-1 rounded-full bg-slate-100 text-slate-700 border border-slate-200">
              Stage: {task.column.replace('-', ' ')}
            </span>
          </div>

          <div>
            <h3 className="text-lg font-bold text-slate-900 leading-snug">
              {formattedTitle}
            </h3>
            <p className="text-xs text-slate-500 mt-1 flex items-center gap-1.5">
              <Clock className="size-3.5" />
              <span>Reported on {task.date}</span>
            </p>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/80 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="size-8 rounded-lg bg-rose-100 text-rose-700 flex items-center justify-center font-bold">
                ▲
              </div>
              <div>
                <p className="text-xs font-bold text-slate-900">
                  {task.upvote_count || 0} Citizen Upvotes
                </p>
                <p className="text-[11px] text-slate-500">
                  Community escalation score
                </p>
              </div>
            </div>

            <span className={`px-2.5 py-1 rounded text-[10px] font-bold uppercase tracking-wider ${
              task.severity === 'HIGH' ? 'bg-rose-100 text-rose-800 border border-rose-200' : 'bg-slate-100 text-slate-700 border border-slate-200'
            }`}>
              {task.severity || 'LOW'} Severity
            </span>
          </div>

          <div>
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-1.5">
              Incident Description
            </h4>
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 leading-relaxed whitespace-pre-wrap">
              {task.description || 'No detailed description provided.'}
            </div>
          </div>

          {task.authority_image_url && (
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                Resolution Proof Photo
              </h4>
              <div className="rounded-xl overflow-hidden border border-slate-200">
                <img 
                  src={task.authority_image_url} 
                  alt="Resolution proof" 
                  className="w-full h-48 object-cover hover:scale-105 transition-transform duration-300" 
                />
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-4 border-t border-slate-100 flex items-center justify-between bg-slate-50/80">
          <button
            type="button"
            onClick={onClose}
            className="px-3.5 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-200/60 rounded-lg transition-colors cursor-pointer"
          >
            Close
          </button>

          <div className="flex items-center gap-2">
            {task.column === 'planned' && (
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onAdvanceStatus(task.id, 'assign-officer', task);
                }}
                className="px-4 py-2 bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold rounded-lg shadow-xs transition-colors cursor-pointer flex items-center gap-1.5"
              >
                <Clock className="size-3.5" />
                <span>Dispatch to Field</span>
              </button>
            )}

            {task.column === 'in-progress' && (
              <button
                type="button"
                onClick={() => {
                  onClose();
                  onAdvanceStatus(task.id, 'in-review-modal', task);
                }}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow-xs transition-colors cursor-pointer flex items-center gap-1.5"
              >
                <Eye className="size-3.5" />
                <span>Submit for Citizen Review</span>
              </button>
            )}

            {task.column === 'in-review' && (
              <span className="text-xs text-blue-700 font-bold flex items-center gap-1 bg-blue-50 px-3 py-1.5 rounded-lg border border-blue-200">
                <Eye className="size-3.5" />
                <span>Awaiting Citizen Verification</span>
              </span>
            )}

            {task.column === 'done' && (
              <span className="text-xs text-emerald-700 font-bold flex items-center gap-1 bg-emerald-50 px-3 py-1.5 rounded-lg border border-emerald-200">
                <CheckCircle2 className="size-3.5 text-emerald-600" />
                <span>Verified & Closed</span>
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

// --- Main Kanban Board Component ---
export default function KanbanBoard({ hideHeader = false, initialOfficers = [] }) {
  const navigate = useNavigate();
  const goBack = useSmartBack('/authority');
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Search & Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [severityFilter, setSeverityFilter] = useState('ALL');
  const [categoryFilter, setCategoryFilter] = useState('ALL');
  const [sortBy, setSortBy] = useState('UPVOTES');

  // Drag & Drop State
  const [draggingTask, setDraggingTask] = useState(null);
  const [cloneStyle, setCloneStyle] = useState({ width: 0, height: 0 });
  const [hoveredCol, setHoveredCol] = useState(null);
  const [resolutionModalTask, setResolutionModalTask] = useState(null);
  const [assigningTask, setAssigningTask] = useState(null);
  const [officers, setOfficers] = useState(initialOfficers);
  const [selectedTask, setSelectedTask] = useState(null);

  // Sync officers
  useEffect(() => {
    if (initialOfficers && initialOfficers.length > 0) {
      setOfficers(initialOfficers);
    } else {
      supabase.from('authorities').select('*').then(({ data }) => {
        if (data && data.length > 0) setOfficers(data);
      });
    }
  }, [initialOfficers]);

  // Performance refs
  const draggingTaskRef = useRef(null);
  const hoveredColRef = useRef(null);
  const startPos = useRef({ x: 0, y: 0 });
  const offsetRef = useRef({ x: 0, y: 0 });
  const columnBoundsRef = useRef({});
  const cloneRef = useRef(null);
  const hasDraggedRef = useRef(false);

  useEffect(() => { draggingTaskRef.current = draggingTask; }, [draggingTask]);
  useEffect(() => { hoveredColRef.current = hoveredCol; }, [hoveredCol]);

  // Initial clone position
  useEffect(() => {
    if (draggingTask && cloneRef.current) {
      const x = startPos.current.x - offsetRef.current.x;
      const y = startPos.current.y - offsetRef.current.y;
      cloneRef.current.style.transform = `translate3d(${x}px, ${y}px, 0) rotate(2deg) scale(1.02)`;
    }
  }, [draggingTask]);

  // Fetch tasks
  const fetchTasks = async () => {
    setLoading(true);
    try {
      let data = null;
      try {
        const res = await fetch('/api/kanban/tasks');
        if (res.ok) {
          data = await res.json();
        }
      } catch (apiErr) {
        // Fall back to direct Supabase query
      }

      if (!Array.isArray(data)) {
        const mapToKanbanStatus = (st) => {
          if (!st) return 'planned';
          const s = String(st).trim().toLowerCase().replace('_', '-');
          if (['pending', 'open', 'planned'].includes(s)) return 'planned';
          if (['in-progress', 'inprogress', 'active'].includes(s)) return 'in-progress';
          if (['in-review', 'inreview', 'review'].includes(s)) return 'in-review';
          if (['resolved', 'done', 'closed', 'verified'].includes(s)) return 'done';
          return 'planned';
        };

        const { data: authData } = await supabase.from('authorities').select('*');
        if (authData) setOfficers(authData);
        const officersMap = {};
        (authData || []).forEach(o => { officersMap[o.id] = o; });

        const { data: compData } = await supabase
          .from('complaints')
          .select('*')
          .order('upvote_count', { ascending: false });

        data = (compData || []).map(c => {
          const upvotes = c.upvote_count || 0;
          return {
            id: c.id,
            title: c.title || c.category || 'Civic Issue',
            description: c.description || '',
            category: c.category || 'General',
            status: mapToKanbanStatus(c.status),
            upvote_count: upvotes,
            severity: upvotes >= 10 ? 'HIGH' : upvotes >= 5 ? 'MEDIUM' : 'LOW',
            created_at: c.created_at,
            authority_image_url: c.authority_image_url || c.image_url,
            assigned_authority_id: c.assigned_authority_id,
            assigned_officer_name: officersMap[c.assigned_authority_id]?.name || null,
            source_type: 'complaint'
          };
        });
      }

      if (Array.isArray(data)) {
        const formattedTasks = data.map(item => {
          const parsed = parseComplaintContent(item);
          return {
            id: item.id,
            title: parsed.title,
            description: parsed.description,
            category: item.category || 'General',
            date: item.created_at && !isNaN(new Date(item.created_at).getTime())
              ? new Date(item.created_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
              : 'Recent',
            created_at: item.created_at,
            column: item.status || 'planned',
            upvote_count: item.upvote_count || 0,
            severity: item.severity || 'LOW',
            authority_image_url: item.authority_image_url || item.image_url,
            source_type: item.source_type || 'complaint',
            original: item
          };
        });
        setTasks(formattedTasks);
      }
    } catch (err) {
      console.error("Failed to fetch kanban tasks:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTasks();
  }, []);

  const updateTaskStatus = async (taskId, newColumn) => {
    setTasks(prev => prev.map(t => t.id === taskId ? { ...t, column: newColumn } : t));
    try {
      await fetch(`/api/kanban/tasks/${taskId}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newColumn })
      });
    } catch (err) {
      // Backend not running, direct Supabase update
    }
    try {
      const complaintStatus =
        newColumn === 'in-progress' ? 'in-progress' :
        newColumn === 'in-review' ? 'in-review' :
        newColumn === 'done' ? 'resolved' : 'pending';
      await supabase.from('complaints').update({ status: complaintStatus }).eq('id', taskId);
    } catch (dbErr) {
      console.error("Supabase status update error:", dbErr);
    }
  };

  // 60/120 FPS Zero-Lag Pointermove & Pointerup
  useEffect(() => {
    const handleMove = (e) => {
      const dist = Math.hypot(e.clientX - startPos.current.x, e.clientY - startPos.current.y);
      if (dist > 6) {
        hasDraggedRef.current = true;
      }

      if (draggingTaskRef.current) {
        e.preventDefault();

        // Direct hardware-accelerated GPU transform (0 React re-renders during motion)
        if (cloneRef.current) {
          const x = e.clientX - offsetRef.current.x;
          const y = e.clientY - offsetRef.current.y;
          cloneRef.current.style.transform = `translate3d(${x}px, ${y}px, 0) rotate(2deg) scale(1.02)`;
        }

        // Geometric column check (0 DOM reflows)
        const clientX = e.clientX;
        const clientY = e.clientY;
        let matchedCol = null;

        for (const [colId, rect] of Object.entries(columnBoundsRef.current)) {
          if (
            clientX >= rect.left &&
            clientX <= rect.right &&
            clientY >= rect.top &&
            clientY <= rect.bottom
          ) {
            matchedCol = colId;
            break;
          }
        }

        if (matchedCol !== hoveredColRef.current) {
          hoveredColRef.current = matchedCol;
          setHoveredCol(matchedCol);
        }
      }
    };

    const handleUp = () => {
      const currentTask = draggingTaskRef.current;
      const targetCol = hoveredColRef.current;

      if (currentTask && targetCol && targetCol !== currentTask.column) {
        if (targetCol === 'done') {
          alert("Only citizens can verify and close resolutions. Move the task to 'In Review' with photo proof to request citizen verification.");
        } else if (targetCol === 'in-review') {
          setResolutionModalTask(currentTask);
        } else if (targetCol === 'in-progress' && (currentTask.column === 'planned' || currentTask.column === 'pending' || !currentTask.column)) {
          setAssigningTask(currentTask);
        } else {
          updateTaskStatus(currentTask.id, targetCol);
        }
      }
      setDraggingTask(null);
      draggingTaskRef.current = null;
      setHoveredCol(null);
      hoveredColRef.current = null;
    };

    window.addEventListener('pointermove', handleMove, { passive: false });
    window.addEventListener('pointerup', handleUp);
    window.addEventListener('pointercancel', handleUp);

    return () => {
      window.removeEventListener('pointermove', handleMove);
      window.removeEventListener('pointerup', handleUp);
      window.removeEventListener('pointercancel', handleUp);
    };
  }, []);

  const handlePointerDown = (e, task) => {
    if (e.button !== 0 && e.pointerType !== 'mouse') return;

    const cardEl = e.currentTarget;
    const rect = cardEl.getBoundingClientRect();
    const offsetX = e.clientX - rect.left;
    const offsetY = e.clientY - rect.top;
    
    startPos.current = { x: e.clientX, y: e.clientY };
    offsetRef.current = { x: offsetX, y: offsetY };
    hasDraggedRef.current = false;

    // Cache column bounding boxes once at pickup
    const colMap = {};
    document.querySelectorAll('[data-column-container]').forEach(el => {
      const id = el.getAttribute('data-column-container');
      if (id) colMap[id] = el.getBoundingClientRect();
    });
    columnBoundsRef.current = colMap;

    setCloneStyle({ width: rect.width, height: rect.height });
    draggingTaskRef.current = task;
    setDraggingTask(task);
  };

  const handleCardClick = (task) => {
    if (!hasDraggedRef.current) {
      setSelectedTask(task);
    }
  };

  // Unique categories
  const availableCategories = useMemo(() => {
    const set = new Set();
    tasks.forEach(t => {
      if (t.category) set.add(t.category);
    });
    return Array.from(set).sort();
  }, [tasks]);

  // Filtered & Sorted Tasks
  const filteredTasks = useMemo(() => {
    let result = tasks;

    // Search query
    if (searchQuery.trim()) {
      const rawQ = searchQuery.toLowerCase().trim();
      const cleanQ = rawQ.replace(/^uni-/, '');
      result = result.filter(t => {
        const titleMatch = (t.title || '').toLowerCase().includes(rawQ);
        const descMatch = (t.description || '').toLowerCase().includes(rawQ);
        const catMatch = (t.category || '').toLowerCase().includes(rawQ);
        const idMatch = String(t.id || '').toLowerCase().includes(cleanQ);
        const ticketCode = formatTicketId(t.id, t.source_type).toLowerCase();
        return titleMatch || descMatch || catMatch || idMatch || ticketCode.includes(rawQ) || ticketCode.includes(cleanQ);
      });
    }

    // Severity filter
    if (severityFilter === 'HIGH') {
      result = result.filter(t => t.severity === 'HIGH' || (t.upvote_count || 0) >= 10);
    } else if (severityFilter === 'MEDIUM') {
      result = result.filter(t => t.severity === 'MEDIUM');
    } else if (severityFilter === 'LOW') {
      result = result.filter(t => t.severity === 'LOW' && (t.upvote_count || 0) < 5);
    }

    // Category filter
    if (categoryFilter !== 'ALL') {
      result = result.filter(t => t.category === categoryFilter);
    }

    // Sort order
    return [...result].sort((a, b) => {
      if (sortBy === 'UPVOTES') {
        const upvoteDiff = (b.upvote_count || 0) - (a.upvote_count || 0);
        if (upvoteDiff !== 0) return upvoteDiff;
        return new Date(b.created_at || 0) - new Date(a.created_at || 0);
      }
      if (sortBy === 'NEWEST') {
        return new Date(b.created_at || 0) - new Date(a.created_at || 0);
      }
      if (sortBy === 'SEVERITY') {
        const score = { HIGH: 3, MEDIUM: 2, LOW: 1 };
        return (score[b.severity] || 0) - (score[a.severity] || 0);
      }
      return 0;
    });
  }, [tasks, searchQuery, severityFilter, categoryFilter, sortBy]);

  // Statistics
  const stats = useMemo(() => {
    const total = tasks.length;
    const critical = tasks.filter(t => t.severity === 'HIGH' || (t.upvote_count || 0) >= 10).length;
    const inReview = tasks.filter(t => t.column === 'in-review').length;
    const done = tasks.filter(t => t.column === 'done').length;
    return { total, critical, inReview, done };
  }, [tasks]);

  return (
    <div className="w-full flex flex-col select-none space-y-4">
      <style dangerouslySetInnerHTML={{__html: `
        .kanban-scroll::-webkit-scrollbar {
          width: 5px;
        }
        .kanban-scroll::-webkit-scrollbar-track {
          background: transparent;
        }
        .kanban-scroll::-webkit-scrollbar-thumb {
          background: #cbd5e1;
          border-radius: 9999px;
        }
        .kanban-scroll::-webkit-scrollbar-thumb:hover {
          background: #94a3b8;
        }
      `}} />

      {/* Standalone Route Header */}
      {!hideHeader && (
        <div className="flex items-center justify-between py-3 px-4 sm:px-6 bg-white border border-slate-200 rounded-xl mb-1 shadow-xs">
          <button 
            onClick={() => goBack('/authority')} 
            className="p-2 hover:bg-slate-100 rounded-lg transition-colors flex items-center gap-1 text-xs font-bold text-slate-700 cursor-pointer"
          >
            ← Back to Authority
          </button>
          <div className="text-center">
            <h1 className="text-base font-bold text-slate-900">Field Dispatch Kanban</h1>
            <p className="text-xs text-slate-500">Live community grievances triage board</p>
          </div>
          <button 
            onClick={() => navigate('/authority')} 
            className="bg-slate-900 hover:bg-slate-800 text-white px-3.5 py-1.5 rounded-lg text-xs font-bold transition-colors cursor-pointer"
          >
            Dashboard
          </button>
        </div>
      )}

      {/* Top Search & Filter Bar */}
      <div className="bg-white rounded-2xl p-4 border border-slate-200/90 shadow-xs space-y-3.5">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3">
          {/* Search Input */}
          <div className="relative flex-1 max-w-xl">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 size-4 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by complaint title, category, description, or Ticket ID..."
              className="w-full h-10 pl-10 pr-9 text-xs sm:text-sm bg-slate-50 border border-slate-200 rounded-xl outline-none focus:bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-100 text-slate-900 transition-all placeholder:text-slate-400"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 p-0.5 rounded-full hover:bg-slate-200 cursor-pointer"
              >
                <X className="size-3.5" />
              </button>
            )}
          </div>

          {/* KPI Chips */}
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <div className="px-3 py-1.5 rounded-lg bg-slate-100 text-slate-700 font-semibold border border-slate-200 flex items-center gap-1.5">
              <Layers className="size-3.5 text-slate-500" />
              <span>{filteredTasks.length} {filteredTasks.length === 1 ? 'Ticket' : 'Tickets'}</span>
            </div>

            <div className="px-3 py-1.5 rounded-lg bg-rose-50 text-rose-700 border border-rose-200 font-bold flex items-center gap-1.5">
              <Flame className="size-3.5 text-rose-600" />
              <span>{stats.critical} Critical</span>
            </div>

            <div className="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-800 border border-emerald-200 font-bold flex items-center gap-1.5">
              <CheckCircle2 className="size-3.5 text-emerald-600" />
              <span>{stats.done} Verified</span>
            </div>

            <button
              onClick={fetchTasks}
              disabled={loading}
              title="Refresh Live Data"
              className="p-2 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-200 transition-colors cursor-pointer"
            >
              <RefreshCw className={`size-3.5 ${loading ? 'animate-spin text-blue-600' : ''}`} />
            </button>
          </div>
        </div>

        {/* Filters Row: Priority pills, Category dropdown, and Sort */}
        <div className="flex flex-wrap items-center justify-between gap-2.5 pt-2 border-t border-slate-100">
          <div className="flex flex-wrap items-center gap-1.5">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 mr-1 flex items-center gap-1">
              <Filter className="size-3" />
              Priority:
            </span>
            {[
              { id: 'ALL', label: 'All Issues' },
              { id: 'HIGH', label: '🔥 Critical / High' },
              { id: 'MEDIUM', label: '⚠️ Medium' },
              { id: 'LOW', label: 'Low Priority' }
            ].map(pill => (
              <button
                key={pill.id}
                onClick={() => setSeverityFilter(pill.id)}
                className={`px-3 py-1 text-xs rounded-lg font-semibold transition-all cursor-pointer ${
                  severityFilter === pill.id
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'bg-slate-100 hover:bg-slate-200 text-slate-700 border border-slate-200/80'
                }`}
              >
                {pill.label}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1">
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="h-8 px-2.5 text-xs bg-white border border-slate-200 rounded-lg text-slate-700 font-semibold outline-none cursor-pointer focus:border-blue-500 shadow-2xs"
              >
                <option value="ALL">All Categories</option>
                {availableCategories.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>

            <div className="flex items-center gap-1">
              <ArrowUpDown className="size-3 text-slate-400" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="h-8 px-2.5 text-xs bg-white border border-slate-200 rounded-lg text-slate-700 font-semibold outline-none cursor-pointer focus:border-blue-500 shadow-2xs"
              >
                <option value="UPVOTES">Most Upvoted</option>
                <option value="NEWEST">Newest First</option>
                <option value="SEVERITY">Highest Severity</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* 4 Column Kanban Board */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4 items-start w-full">
        {COLUMNS.map(col => {
          const columnTasks = filteredTasks.filter(t => t.column === col.id);
          const isHovered = hoveredCol === col.id;
          const ColIcon = col.icon;

          return (
            <div
              key={col.id}
              data-column-container={col.id}
              className={`w-full flex flex-col rounded-2xl transition-all duration-150 overflow-hidden shadow-xs relative ${
                isHovered
                  ? 'ring-2 ring-blue-500/70 shadow-md bg-blue-50/20 border border-blue-300'
                  : `${col.columnBg}`
              }`}
            >
              {/* Top Solid Accent Stripe */}
              <div className={`h-1.5 w-full ${col.topStripe}`}></div>

              {/* Column Header */}
              <div className={`p-3.5 px-4 flex items-center justify-between ${col.headerBg}`}>
                <div className="flex items-center gap-2.5 min-w-0">
                  <div 
                    className="size-7 rounded-lg flex items-center justify-center shrink-0 shadow-2xs border border-white/60"
                    style={{ backgroundColor: `${col.dotColor}18`, color: col.dotColor }}
                  >
                    <ColIcon className="size-3.5" />
                  </div>
                  <div className="truncate">
                    <h3 className="font-bold text-slate-900 text-xs sm:text-sm tracking-tight truncate">
                      {col.title}
                    </h3>
                    <p className="text-[10px] text-slate-500 font-medium truncate">
                      {col.subtitle}
                    </p>
                  </div>
                </div>

                <span className={`px-2 py-0.5 rounded-full text-xs font-bold border shadow-2xs shrink-0 ${col.badge}`}>
                  {columnTasks.length}
                </span>
              </div>

              {/* Column Body / Tasks list */}
              <div
                className="p-3 flex flex-col gap-2.5 min-h-[580px] max-h-[calc(100vh-270px)] overflow-y-auto kanban-scroll"
              >
                {/* Drop Slot Indicator at the top if hovered and empty */}
                {isHovered && draggingTask && columnTasks.length === 0 && (
                  <div
                    className="rounded-xl border-2 border-dashed border-blue-400 bg-blue-50/60 flex flex-col items-center justify-center gap-1 text-xs font-bold text-blue-600 transition-all my-2 shrink-0 animate-pulse"
                    style={{ height: cloneStyle.height || 120 }}
                  >
                    <span className="text-xs font-bold">Drop here to move</span>
                    <span className="text-[10.5px] font-medium text-blue-500">Stage: {col.title}</span>
                  </div>
                )}

                {columnTasks.map(task => (
                  <React.Fragment key={task.id}>
                    <KanbanCard
                      task={task}
                      isDragging={draggingTask?.id === task.id}
                      onPointerDown={(e) => handlePointerDown(e, task)}
                      onClick={() => handleCardClick(task)}
                    />
                  </React.Fragment>
                ))}

                {/* Drop Slot Indicator when hovered on a column with tasks */}
                {isHovered && draggingTask && columnTasks.length > 0 && (
                  <div
                    className="rounded-xl border-2 border-dashed border-blue-400 bg-blue-50/60 flex flex-col items-center justify-center gap-1 text-xs font-bold text-blue-600 transition-all my-2 shrink-0 animate-pulse"
                    style={{ height: cloneStyle.height || 120 }}
                  >
                    <span className="text-xs font-bold">Drop here to move</span>
                    <span className="text-[10.5px] font-medium text-blue-500">Stage: {col.title}</span>
                  </div>
                )}

                {/* Empty State for Column (only when NOT dragging over) */}
                {columnTasks.length === 0 && (!isHovered || !draggingTask) && (
                  <div className="flex-1 flex flex-col items-center justify-center p-6 text-center border-2 border-dashed border-slate-300/80 rounded-xl my-4 bg-white/50">
                    <div 
                      className="size-10 rounded-full flex items-center justify-center mb-2"
                      style={{ backgroundColor: `${col.dotColor}15`, color: col.dotColor }}
                    >
                      <ColIcon className="size-4" />
                    </div>
                    <p className="text-xs font-bold text-slate-800">
                      No issues in {col.title}
                    </p>
                    <p className="text-[11px] text-slate-500 mt-1 max-w-[190px] leading-relaxed">
                      {col.id === 'in-review' 
                        ? 'Drag resolved tickets here to submit photo proof for citizen review.'
                        : col.id === 'in-progress'
                        ? 'Drag tickets here when field units are assigned.'
                        : col.id === 'done'
                        ? 'Resolved tickets verified by citizens appear here.'
                        : 'No matching queued tasks found.'}
                    </p>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Floating Drag Clone: FULL CARD DUPLICATE (Exact Match to Card, No Truncation, Soft Elevation) */}
      {draggingTask && (
        <div
          ref={cloneRef}
          id="drag-clone"
          className="fixed top-0 left-0 pointer-events-none z-[99999] origin-top-left transition-none will-change-transform rounded-xl shadow-[0_20px_50px_rgba(0,0,0,0.22)] ring-2 ring-blue-500"
          style={{
            width: cloneStyle.width,
            height: cloneStyle.height,
          }}
        >
          <KanbanCard task={draggingTask} isDragging={false} />
        </div>
      )}

      {/* Dispatch Case Assignment Modal */}
      {assigningTask && (
        <AssignOfficerModal
          task={assigningTask}
          officers={officers}
          onClose={() => setAssigningTask(null)}
          onAssign={async (officer) => {
            try {
              await assignComplaintToOfficer(assigningTask.id, officer.id);
              setTasks(prev => prev.map(t => t.id === assigningTask.id ? {
                ...t,
                column: 'in-progress',
                assigned_authority_id: officer.id,
                assigned_officer_name: officer.name
              } : t));
              setAssigningTask(null);
            } catch (err) {
              console.error('Assignment error:', err);
              alert('Failed to assign officer: ' + (err.message || 'Database error'));
            }
          }}
        />
      )}

      {/* Resolution Photo Upload Modal */}
      {resolutionModalTask && (
        <ResolutionModal
          task={resolutionModalTask}
          onClose={() => setResolutionModalTask(null)}
          onSuccess={() => {
            setTasks(prev => prev.map(t =>
              t.id === resolutionModalTask.id
                ? { ...t, column: 'in-review' }
                : t
            ));
            setResolutionModalTask(null);
          }}
        />
      )}

      {/* Interactive Card Details Modal */}
      {selectedTask && (
        <TicketDetailsModal
          task={selectedTask}
          onClose={() => setSelectedTask(null)}
          onAdvanceStatus={(taskId, newCol, taskData) => {
            if (newCol === 'in-review-modal') {
              setResolutionModalTask(taskData);
            } else if (newCol === 'assign-officer') {
              setAssigningTask(taskData);
            } else {
              updateTaskStatus(taskId, newCol);
            }
          }}
        />
      )}
    </div>
  );
}
