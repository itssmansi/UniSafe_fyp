import React, { useState, useEffect, useRef } from 'react';
import ResolutionModal from './ResolutionModal';

// --- Configuration & Data ---
const COLUMNS = [
  { id: 'planned', title: 'Planned', dot: '#6B7280', bg: '#F3F4F6', border: '#E5E7EB' },
  { id: 'in-progress', title: 'In Progress', dot: '#F59E0B', bg: '#FDF8F0', border: '#F3E8D6' },
  { id: 'in-review', title: 'In Review', dot: '#3B82F6', bg: '#EFF6FF', border: '#DBEAFE' },
  { id: 'done', title: 'Done', dot: '#10B98V', bg: '#F0FDF4', border: '#D1FAE5' },
];

// --- Subcomponents ---
const Card = ({ task, isDragging, onPointerDown }) => (
  <div 
    className={`bg-white rounded-[12px] p-3 md:p-4 shadow-[0_2px_8px_rgba(0,0,0,0.04)] border border-gray-100 cursor-grab active:cursor-grabbing select-none transition-opacity ${isDragging ? 'opacity-30' : 'opacity-100 hover:shadow-[0_6px_16px_rgba(0,0,0,0.06)]'}`}
    onPointerDown={onPointerDown}
  >
    <div className="flex justify-between items-start mb-3 md:mb-4">
      <h4 className="font-medium text-[#111827] text-[12.5px] md:text-[15px] leading-snug pr-2 md:pr-4">
        {task.title}
      </h4>
      <div className="w-[18px] h-[18px] md:w-[24px] md:h-[24px] rounded-full bg-gray-200 shrink-0"></div>
    </div>
    <div className="flex justify-between items-center mt-2">
      <p className="text-[9px] md:text-[12px] font-medium text-gray-400">
        {task.date}
      </p>
      {task.column === 'in-review' && (
        <a 
          href={`/verify/${task.id}`} 
          target="_blank" 
          rel="noreferrer"
          className="text-[10px] md:text-[11px] font-bold bg-blue-50 text-blue-600 px-2 py-1 rounded-md hover:bg-blue-100"
          onPointerDown={(e) => e.stopPropagation()}
        >
          Verify
        </a>
      )}
    </div>
  </div>
);

export default function KanbanBoard() {
  const [tasks, setTasks] = useState([]);
  
  // Drag & Drop State
  const [draggingTask, setDraggingTask] = useState(null);
  const [dragPos, setDragPos] = useState({ x: 0, y: 0 });
  const [dragOffset, setDragOffset] = useState({ x: 0, y: 0 });
  const [cloneStyle, setCloneStyle] = useState({ width: 0, height: 0 });
  const [hoveredCol, setHoveredCol] = useState(null);
  const [resolutionModalTask, setResolutionModalTask] = useState(null);

  // Refs for event listeners
  const draggingTaskRef = useRef(null);
  const hoveredColRef = useRef(null);
  const longPressTimer = useRef(null);
  const startPos = useRef({x: 0, y: 0});

  useEffect(() => { draggingTaskRef.current = draggingTask; }, [draggingTask]);
  useEffect(() => { hoveredColRef.current = hoveredCol; }, [hoveredCol]);

  // Fetch tasks from backend
  const fetchTasks = async () => {
    try {
      const res = await fetch('/api/kanban/tasks');
      const data = await res.json();
      if (Array.isArray(data)) {
        const formattedTasks = data.map(zone => ({
          id: zone.id,
          title: zone.zone_type || 'Unknown Zone',
          date: new Date(zone.created_at || Date.now()).toLocaleDateString(),
          column: zone.status || 'planned',
          original: zone
        }));
        setTasks(formattedTasks);
      }
    } catch (err) {
      console.error("Failed to fetch kanban tasks:", err);
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
      console.error("Failed to update task status", err);
    }
  };

  useEffect(() => {
    const handleMove = (e) => {
      if (draggingTaskRef.current) {
        e.preventDefault();
        setDragPos({ x: e.clientX, y: e.clientY });

        const els = document.elementsFromPoint(e.clientX, e.clientY);
        const colEl = els.find(el => el && el.getAttribute && el.getAttribute('data-column-id'));
        const newCol = colEl ? colEl.getAttribute('data-column-id') : null;
        
        if (newCol !== hoveredColRef.current) {
          setHoveredCol(newCol);
        }
      } else if (longPressTimer.current) {
        const dx = Math.abs(e.clientX - startPos.current.x);
        const dy = Math.abs(e.clientY - startPos.current.y);
        if (dx > 10 || dy > 10) {
          clearTimeout(longPressTimer.current);
          longPressTimer.current = null;
        }
      }
    };

    const handleUp = (e) => {
      if (longPressTimer.current) {
        clearTimeout(longPressTimer.current);
        longPressTimer.current = null;
      }
      if (draggingTaskRef.current) {
        const targetCol = hoveredColRef.current;
        const currentTask = draggingTaskRef.current;
        
        if (targetCol && targetCol !== currentTask.column) {
          if (targetCol === 'in-review') {
            setResolutionModalTask(currentTask);
          } else {
            updateTaskStatus(currentTask.id, targetCol);
          }
        }
        setDraggingTask(null);
        setHoveredCol(null);
      }
    };

    const handleTouchMove = (e) => {
      if (draggingTaskRef.current) {
        e.preventDefault();
      }
    };

    window.addEventListener('pointermove', handleMove, { passive: false });
    window.addEventListener('pointerup', handleUp);
    window.addEventListener('pointercancel', handleUp);
    window.addEventListener('touchmove', handleTouchMove, { passive: false });

    return () => {
      window.removeEventListener('pointermove', handleMove);
      window.removeEventListener('pointerup', handleUp);
      window.removeEventListener('pointerrcancel', handleUp);
      window.removeEventListener('touchmove', handleTouchMove);
    };
  }, []);

  const handlePointerDown = (e, task) => {
    if (e.button !== 0 && e.pointerType !== 'mouse') return;

    const rect = e.currentTarget.getBoundingClientRect();
    const offsetX = e.clientX - rect.left;
    const offsetY = e.clientY - rect.top;
    
    startPos.current = { x: e.clientX, y: e.clientY };
    
    const clientX = e.clientX;
    const clientY = e.clientY;
    const pointerType = e.pointerType;

    const pickup = () => {
      setCloneStyle({ width: rect.width, height: rect.height });
      setDragOffset({ x: offsetX, y: offsetY });
      setDraggingTask(task);
      setDragPos({ x: clientX, y: clientY });
      
      if (window.navigator && window.navigator.vibrate && pointerType !== 'mouse') {
        window.navigator.vibrate(50);
      }
    };

    if (e.pointerType === 'mouse') {
      pickup();
    } else {
      longPressTimer.current = setTimeout(pickup, 250);
    }
  };

  return (
    <div className="min-h-screen w-full bg-[#F9FAFB] font-sans flex flex-col select-none">
      <style dangerouslySetInnerHTML={{__html: `
        .hide-scroll::-webkit-scrollbar { display: none; }
        .hide-scroll { -ms-overflow-style: none; scrollbar-width: none; }
      `}} />

      {/* Header matching the phone screenshot */}
      <div className="flex items-center justify-between p-4 bg-[#F9FAFB] relative md:mb-4 max-w-7xl mx-auto w-full">
        <a href="/" className="p-2 hover:bg-gray-200 rounded-full transition-colors flex items-center gap-1 text-sm font-medium text-gray-700">
          <svg className="w-5 h-5 text-gray-900" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
          <span className="hidden sm:inline">Home</span>
        </a>
        <h1 className="text-[18px] md:text-[24px] font-bold text-gray-900 absolute left-1/2 -translate-x-1/2">Kanban Board</h1>
        <a href="/verify" className="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1.5 rounded-md text-xs sm:text-sm font-semibold transition-colors">
          Verify Page
        </a>
      </div>
      
      {/* Grid Layout: 2x2 on Mobile, 4x1 Flex on Desktop */}
      <div className="grid grid-cols-2 md:flex md:flex-row gap-3 md:gap-6 overflow-x-hidden md:overflow-x-auto pb-8 flex-1 hide-scroll items-start px-3 md:px-8 max-w-7xl mx-auto w-full">
        {COLUMNS.map(col => {
          const columnTasks = tasks.filter(t => t.column === col.id);
          const isHovered = hoveredCol === col.id;

          return (
            <div 
              key={col.id} 
              className="w-full md:w-[320px] md:shrink-0 h-[45vh] md:h-[calc(100vh-140px)] flex flex-col rounded-[16px] border transition-colors duration-200" 
              style={{ backgroundColor: isHovered ? col.border : col.bg, borderColor: col.border }}
            >
              {/* Header */}
              <div className="p-2.5 md:p-4 md:px-5 flex items-center justify-between shrink-0">
                <div className="flex items-center gap-1.5 md:gap-3 overflow-hidden">
                  <div className="w-1.5 h-1.5 md:w-2.5 md:h-2.5 rounded-full shadow-sm shrink-0" style={{ backgroundColor: col.dot }}></div>
                  <h3 className="font-bold text-gray-900 text-[13px] md:text-[15px] truncate">{col.title}</h3>
                </div>
                <div className="flex items-center gap-1 md:gap-2 shrink-0 ml-1">
                  <div className="bg-white px-1.5 md:px-2 py-0.5 rounded-[6px] text-[10px] md:text-[13px] font-bold shadow-sm border border-gray-100/50 flex items-center justify-center min-w-[20px]" style={{ color: col.dot }}>
                    {columnTasks.length}
                  </div>
                </div>
              </div>
              
              {/* Body */}
              <div 
                className="flex-1 p-2 md:p-3 md:px-4 pt-0 flex flex-col gap-2 md:gap-3 overflow-y-auto hide-scroll pb-10" 
                data-column-id={col.id}
              >
                {columnTasks.map(task => (
                  <Card 
                    tey={task.id} 
                    task={task} 
                    isDragging={draggingTask?.id === task.id} 
                    onPointerDown={(e) => handlePointerDown(e, task)}
                  />
                ))}
                
                {/* Drop Target Placeholder */}
                {isHovered && draggingTask && (
                  <div 
                    className="rounded-xl border-2 border-dashed bg-white/40 transition-all" 
                    style={{ height: cloneStyle.height, borderColor: col.dot }}
                  ></div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Visually Cloned Card for Dragging */}
      {draggingTask && (
        <div 
          id="drag-clone"
          className="fixed pointer-events-none z-[9999] opacity-95 scale-[1.03] shadow-2xl transition-transform origin-top-left"
          style={{
            left: dragPos.x - dragOffset.x,
            top: dragPos.y - dragOffset.y,
            width: cloneStyle.width,
            height: cloneStyle.height,
          }}
        >
          <div className="bg-white rounded-[12px] p-3 md:p-4 shadow-xl border-[2.5px] w-full h-full flex flex-col" style={{ borderColor: COLUMNS.find(c => c.id === draggingTask.column)?.dot || '#3B82F6' }}>
            <div className="flex justify-between items-start mb-3 md:mb-4">
              <h4 className="font-medium text-[#111827] text-[12.5px] md:text-[15px] leading-snug pr-2 md:pr-4">{draggingTask.title}</h4>
              <div className="w-[18px] h-[18px] md:w-[24px] md:h-[24px] rounded-full bg-gray-200 shrink-0"></div>
            </div>
            <p className="text-[9px] md:text-[12px] font-medium text-gray-400">{draggingTask.date}</p>
          </div>
        </div>
      )}

      {/* Resolution Modal */}
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
    </div>
  );
}
