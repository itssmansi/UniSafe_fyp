import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '../../services/supabase';
import {
  Building2,
  UserCheck,
  Search,
  Phone,
  MapPin,
  X,
  Check,
  Sparkles,
  Layers,
  Clock,
  AlertCircle
} from 'lucide-react';

export default function AssignOfficerModal({
  task,
  officers: propOfficers = [],
  onClose,
  onAssign
}) {
  const [internalOfficers, setInternalOfficers] = useState(propOfficers);
  const [selectedOfficerId, setSelectedOfficerId] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDept, setSelectedDept] = useState('ALL');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Sync prop officers or fetch directly if empty
  useEffect(() => {
    if (propOfficers && propOfficers.length > 0) {
      setInternalOfficers(propOfficers);
    } else {
      supabase.from('authorities').select('*').then(({ data, error }) => {
        if (!error && data && data.length > 0) {
          setInternalOfficers(data);
        }
      });
    }
  }, [propOfficers]);

  const officers = internalOfficers;

  // Category matching helper
  const isRecommended = (officerDept, complaintCat) => {
    if (!officerDept || !complaintCat) return false;
    const cat = String(complaintCat).toLowerCase();
    const dept = String(officerDept).toLowerCase();

    if ((cat.includes('road') || cat.includes('infra') || cat.includes('pothole')) && (dept.includes('road') || dept.includes('infra'))) return true;
    if ((cat.includes('garbage') || cat.includes('waste')) && (dept.includes('waste') || dept.includes('swm') || dept.includes('solid'))) return true;
    if ((cat.includes('water') || cat.includes('leak') || cat.includes('drain')) && (dept.includes('water') || dept.includes('drainage') || dept.includes('sewage'))) return true;
    if ((cat.includes('light') || cat.includes('elect')) && (dept.includes('light') || dept.includes('elect'))) return true;
    if ((cat.includes('green') || cat.includes('tree') || cat.includes('park')) && (dept.includes('garden') || dept.includes('green'))) return true;
    if (dept.includes('triage') || dept.includes('bmc')) return true;
    return false;
  };

  // Filter out police accounts from BMC dispatch
  const bmcOfficers = useMemo(() => {
    return officers.filter(o => {
      const dep = (o.department || '').toUpperCase();
      const name = (o.name || '').toLowerCase();
      return dep !== 'POLICE' && !name.includes('police') && !name.includes('simulated');
    });
  }, [officers]);

  // Sort: Recommended department matches first, then alphabetical
  const sortedOfficers = useMemo(() => {
    const list = [...bmcOfficers];
    list.sort((a, b) => {
      const aRec = isRecommended(a.department, task?.category);
      const bRec = isRecommended(b.department, task?.category);
      if (aRec && !bRec) return -1;
      if (!aRec && bRec) return 1;
      return (a.name || '').localeCompare(b.name || '');
    });
    return list;
  }, [bmcOfficers, task?.category]);

  const filteredOfficers = useMemo(() => {
    return sortedOfficers.filter(o => {
      const matchesSearch =
        o.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        o.jurisdiction?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        o.department?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        o.role?.toLowerCase().includes(searchTerm.toLowerCase());

      const matchesDept =
        selectedDept === 'ALL' ||
        o.department?.toLowerCase().includes(selectedDept.toLowerCase());

      return matchesSearch && matchesDept;
    });
  }, [sortedOfficers, searchTerm, selectedDept]);

  // Unique departments for filter
  const departments = useMemo(() => {
    const set = new Set();
    bmcOfficers.forEach(o => {
      if (o.department) set.add(o.department);
    });
    return Array.from(set);
  }, [bmcOfficers]);

  const selectedOfficer = useMemo(() => {
    return bmcOfficers.find(o => o.id === selectedOfficerId);
  }, [bmcOfficers, selectedOfficerId]);

  const handleConfirm = async () => {
    if (!selectedOfficer) return;
    setIsSubmitting(true);
    try {
      await onAssign(selectedOfficer);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!task) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/50 backdrop-blur-xs">
      <div className="w-full max-w-2xl bg-white rounded-2xl border border-slate-200 shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="px-6 py-4.5 border-b border-slate-100 flex items-center justify-between bg-slate-50/80">
          <div className="flex items-center gap-3">
            <div className="size-10 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-700 shrink-0">
              <UserCheck className="size-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900 tracking-tight">
                Dispatch Case to BMC Field Officer
              </h3>
              <p className="text-xs text-slate-500">
                Select an engineer or ward lead who will handle and resolve this ticket.
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 transition-colors cursor-pointer"
          >
            <X className="size-4.5" />
          </button>
        </div>

        {/* Ticket Summary Banner */}
        <div className="px-6 py-3.5 bg-amber-50/70 border-b border-amber-200/60 flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs">
          <div className="flex items-center gap-2 min-w-0">
            <span className="font-mono font-bold text-amber-900 px-2 py-0.5 rounded bg-amber-100/90 shrink-0">
              #{task.id?.slice(0, 8)}
            </span>
            <span className="font-semibold text-slate-800 truncate">
              {task.title || `${task.category?.toUpperCase()} Incident`}
            </span>
          </div>
          <div className="flex items-center gap-2 text-[11px] text-slate-600 shrink-0">
            <span className="capitalize font-bold text-amber-800">
              {task.category || 'Civic'}
            </span>
            <span>•</span>
            <span className="truncate max-w-[200px]">
              {task.address || 'Mumbai Ward Area'}
            </span>
          </div>
        </div>

        {/* Search & Department Filter */}
        <div className="p-4 border-b border-slate-100 space-y-2.5 bg-slate-50/40">
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 size-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search BMC officers by name, ward, or designation..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 text-xs rounded-xl bg-white border border-slate-200 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600"
            />
          </div>

          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs no-scrollbar">
            <button
              type="button"
              onClick={() => setSelectedDept('ALL')}
              className={`px-3 py-1 rounded-lg font-medium text-[11px] transition-colors cursor-pointer shrink-0 ${
                selectedDept === 'ALL'
                  ? 'bg-slate-900 text-white font-bold'
                  : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-100'
              }`}
            >
              All Departments ({bmcOfficers.length})
            </button>
            {departments.map(dept => (
              <button
                key={dept}
                type="button"
                onClick={() => setSelectedDept(dept)}
                className={`px-3 py-1 rounded-lg font-medium text-[11px] transition-colors cursor-pointer shrink-0 ${
                  selectedDept === dept
                    ? 'bg-slate-900 text-white font-bold'
                    : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-100'
                }`}
              >
                {dept}
              </button>
            ))}
          </div>
        </div>

        {/* Officers List */}
        <div className="p-4 overflow-y-auto space-y-2.5 flex-1 max-h-[380px] bg-slate-50/30">
          {filteredOfficers.length === 0 ? (
            <div className="p-8 text-center text-slate-500 bg-white rounded-xl border border-dashed border-slate-200">
              <Building2 className="size-8 mx-auto mb-2 text-slate-400" />
              <p className="text-xs font-semibold">No BMC officers match your filter.</p>
              <p className="text-[11px] text-slate-400 mt-0.5">
                Add new officers from the System & Jurisdiction menu.
              </p>
            </div>
          ) : (
            filteredOfficers.map(officer => {
              const isSelected = selectedOfficerId === officer.id;
              const rec = isRecommended(officer.department, task?.category);

              return (
                <div
                  key={officer.id}
                  onClick={() => setSelectedOfficerId(officer.id)}
                  className={`p-3.5 rounded-xl border transition-all cursor-pointer flex items-center justify-between gap-3 ${
                    isSelected
                      ? 'border-emerald-600 bg-emerald-50/40 ring-2 ring-emerald-500/20 shadow-xs'
                      : 'border-slate-200 hover:border-slate-300 bg-white'
                  }`}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {/* Avatar */}
                    {officer.avatar_url ? (
                      <img
                        src={officer.avatar_url}
                        alt={officer.name}
                        className="size-11 rounded-xl object-cover border border-slate-200 shrink-0"
                        onError={(e) => {
                          e.currentTarget.style.display = 'none';
                          if (e.currentTarget.nextSibling) {
                            e.currentTarget.nextSibling.style.display = 'flex';
                          }
                        }}
                      />
                    ) : null}
                    <div
                      className="size-11 rounded-xl bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-800 font-bold text-xs uppercase shrink-0"
                      style={{ display: officer.avatar_url ? 'none' : 'flex' }}
                    >
                      {officer.name?.slice(0, 2) || 'OF'}
                    </div>

                    {/* Info */}
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-sm text-slate-900 truncate">
                          {officer.name}
                        </span>
                        {rec && (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 border border-emerald-200 shrink-0">
                            <Sparkles className="size-2.5" />
                            Recommended
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-2 text-xs text-slate-500 mt-0.5 truncate">
                        <span className="font-semibold text-slate-700 truncate">
                          {officer.role || 'Ward Officer'}
                        </span>
                        <span>•</span>
                        <span className="truncate">{officer.department || 'BMC'}</span>
                      </div>

                      <div className="flex items-center gap-3 text-[11px] text-slate-500 mt-1">
                        <span className="flex items-center gap-1 truncate">
                          <MapPin className="size-3 text-emerald-600 shrink-0" />
                          <span className="truncate">{officer.jurisdiction || 'Mumbai'}</span>
                        </span>
                        {officer.phone && (
                          <span className="flex items-center gap-1 shrink-0">
                            <Phone className="size-3 text-sky-600 shrink-0" />
                            <span>{officer.phone}</span>
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Radio Selection State */}
                  <div className="shrink-0">
                    <div
                      className={`size-5 rounded-full border flex items-center justify-center transition-all ${
                        isSelected
                          ? 'border-emerald-600 bg-emerald-600 text-white'
                          : 'border-slate-300 bg-white'
                      }`}
                    >
                      {isSelected && <Check className="size-3 stroke-[3]" />}
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-slate-100 bg-slate-50/80 flex items-center justify-between">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-200/60 rounded-xl transition-colors cursor-pointer"
          >
            Cancel (Keep in Planned)
          </button>

          <button
            type="button"
            disabled={!selectedOfficer || isSubmitting}
            onClick={handleConfirm}
            className="flex items-center gap-2 px-5 py-2.5 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl shadow-xs transition-all cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {isSubmitting ? (
              <span>Assigning...</span>
            ) : (
              <>
                <Check className="size-3.5 stroke-[3]" />
                <span>
                  {selectedOfficer
                    ? `Dispatch to ${selectedOfficer.name.split(' ')[0]}`
                    : 'Select an Officer'}
                </span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
