import React, { useState, useMemo, useRef } from 'react';
import {
  Building2,
  UserPlus,
  Search,
  Phone,
  MapPin,
  Trash2,
  Edit3,
  X,
  Check,
  ShieldCheck,
  Layers,
  Sparkles,
  AlertTriangle,
  RefreshCw,
  Briefcase,
  Upload,
  Camera,
  Image as ImageIcon
} from 'lucide-react';
import { supabase } from '../services/supabase';
import { upsertBmcOfficer, deleteBmcOfficer } from '../services/authorityService';

const BMC_DEPARTMENTS = [
  'Roads & Infrastructure',
  'Solid Waste Management',
  'Water Supply & Sewage',
  'Stormwater Drainage',
  'Street Lighting & Electrical',
  'Public Health',
  'Gardens & Greenery',
  'Civic Administration & Triage'
];

const MUMBAI_WARDS = [
  'Ward K-West (Andheri West, Juhu, Versova)',
  'Ward K-East (Andheri East, Chakala, Marol)',
  'Ward H-West (Bandra West, Khar West)',
  'Ward H-East (Santacruz East, Vakola)',
  'Ward R-North (Dahisar)',
  'Ward R-Central (Borivali)',
  'Ward R-South (Kandivali)',
  'Ward P-North (Malad)',
  'Ward G-North (Dharavi, Dadar, Mahim)',
  'Ward G-South (Worli, Lower Parel)',
  'Ward F-South (Parel, Sewri)',
  'Ward A (Colaba, Fort, Marine Drive)'
];

const DEPARTMENT_COLORS = {
  'Roads & Infrastructure': 'bg-amber-50 text-amber-800 border-amber-200',
  'Solid Waste Management': 'bg-emerald-50 text-emerald-800 border-emerald-200',
  'Water Supply & Sewage': 'bg-cyan-50 text-cyan-800 border-cyan-200',
  'Stormwater Drainage': 'bg-blue-50 text-blue-800 border-blue-200',
  'Street Lighting & Electrical': 'bg-purple-50 text-purple-800 border-purple-200',
  'Public Health': 'bg-rose-50 text-rose-800 border-rose-200',
  'Gardens & Greenery': 'bg-teal-50 text-teal-800 border-teal-200',
  default: 'bg-slate-100 text-slate-800 border-slate-200'
};

export default function BmcOfficersPage({
  officers = [],
  complaints = [],
  onRefresh = () => {}
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedDept, setSelectedDept] = useState('ALL');
  const [selectedWard, setSelectedWard] = useState('ALL');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingOfficer, setEditingOfficer] = useState(null);
  const [deletingOfficer, setDeletingOfficer] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false);
  const [formError, setFormError] = useState('');
  const fileInputRef = useRef(null);

  // Form State
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    department: 'Roads & Infrastructure',
    jurisdiction: 'Ward K-West (Andheri West, Juhu, Versova)',
    role: 'Ward Officer',
    avatar_url: ''
  });

  // Filter officers: Only real BMC officers (exclude Police and simulated test accounts)
  const bmcOfficers = useMemo(() => {
    const list = officers.filter(o => {
      const dep = (o.department || '').toUpperCase();
      const name = (o.name || '').toLowerCase();
      return dep !== 'POLICE' && !name.includes('police') && !name.includes('simulated');
    });
    // Fallback: if list is empty, show all non-police officers
    if (list.length === 0) {
      return officers.filter(o => !o.name?.toLowerCase().includes('simulated'));
    }
    return list;
  }, [officers]);

  // Compute workload stats per officer
  const officersWithWorkload = useMemo(() => {
    return bmcOfficers.map(officer => {
      const assigned = complaints.filter(c => c.assigned_authority_id === officer.id);
      const solved = assigned.filter(c =>
        ['resolved', 'closed', 'verified'].includes(String(c.status || '').toLowerCase())
      ).length;
      const active = assigned.length - solved;
      return {
        ...officer,
        assignedCount: assigned.length,
        activeCount: active,
        solvedCount: solved
      };
    });
  }, [bmcOfficers, complaints]);

  // Filtered view
  const filteredOfficers = useMemo(() => {
    return officersWithWorkload.filter(officer => {
      const matchesSearch =
        officer.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        officer.phone?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        officer.jurisdiction?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        officer.role?.toLowerCase().includes(searchTerm.toLowerCase());

      const matchesDept =
        selectedDept === 'ALL' ||
        officer.department?.toLowerCase() === selectedDept.toLowerCase();

      const matchesWard =
        selectedWard === 'ALL' ||
        officer.jurisdiction?.toLowerCase().includes(selectedWard.toLowerCase());

      return matchesSearch && matchesDept && matchesWard;
    });
  }, [officersWithWorkload, searchTerm, selectedDept, selectedWard]);

  // Unique wards for filter dropdown
  const uniqueWards = useMemo(() => {
    const set = new Set();
    officersWithWorkload.forEach(o => {
      if (o.jurisdiction) set.add(o.jurisdiction);
    });
    return Array.from(set);
  }, [officersWithWorkload]);

  const handleOpenAdd = () => {
    setEditingOfficer(null);
    setFormData({
      name: '',
      phone: '',
      department: 'Roads & Infrastructure',
      jurisdiction: 'Ward K-West (Andheri West, Juhu, Versova)',
      role: 'Ward Officer',
      avatar_url: ''
    });
    setFormError('');
    setIsModalOpen(true);
  };

  const handleOpenEdit = (officer) => {
    setEditingOfficer(officer);
    setFormData({
      name: officer.name || '',
      phone: officer.phone || '',
      department: officer.department || 'Roads & Infrastructure',
      jurisdiction: officer.jurisdiction || 'Ward K-West (Andheri West, Juhu, Versova)',
      role: officer.role || 'Ward Officer',
      avatar_url: officer.avatar_url || ''
    });
    setFormError('');
    setIsModalOpen(true);
  };

  // Device File Upload Handler
  const handlePhotoFileChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setFormError('Please select a valid image file (PNG, JPG, or WEBP).');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setFormError('Image size should be under 5MB.');
      return;
    }

    setIsUploadingPhoto(true);
    setFormError('');

    try {
      // 1. Try uploading to Supabase storage bucket
      const fileExt = file.name.split('.').pop() || 'png';
      const filePath = `officers/${Date.now()}_${Math.random().toString(36).substring(2, 7)}.${fileExt}`;

      const { data: uploadData, error: uploadErr } = await supabase.storage
        .from('complaint_images')
        .upload(filePath, file, { upsert: true });

      if (!uploadErr && uploadData) {
        const { data: publicUrlData } = supabase.storage
          .from('complaint_images')
          .getPublicUrl(filePath);

        if (publicUrlData?.publicUrl) {
          setFormData(prev => ({ ...prev, avatar_url: publicUrlData.publicUrl }));
          setIsUploadingPhoto(false);
          return;
        }
      }

      // 2. Fallback: Base64 data URL
      const reader = new FileReader();
      reader.onload = (event) => {
        setFormData(prev => ({ ...prev, avatar_url: event.target.result }));
        setIsUploadingPhoto(false);
      };
      reader.onerror = () => {
        setFormError('Failed to read image file.');
        setIsUploadingPhoto(false);
      };
      reader.readAsDataURL(file);
    } catch (err) {
      console.warn('Storage upload error, using local data URL:', err);
      const reader = new FileReader();
      reader.onload = (event) => {
        setFormData(prev => ({ ...prev, avatar_url: event.target.result }));
        setIsUploadingPhoto(false);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      setFormError('Please enter the officer name.');
      return;
    }
    if (!formData.phone.trim()) {
      setFormError('Please enter an official phone number for field dispatch.');
      return;
    }

    setIsSubmitting(true);
    setFormError('');

    try {
      await upsertBmcOfficer({
        id: editingOfficer?.id,
        ...formData
      });
      setIsModalOpen(false);
      onRefresh();
    } catch (err) {
      console.error('Failed to save officer:', err);
      setFormError(err.message || 'Failed to save officer. Please verify details.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!deletingOfficer) return;
    setIsSubmitting(true);
    try {
      await deleteBmcOfficer(deletingOfficer.id);
      setDeletingOfficer(null);
      onRefresh();
    } catch (err) {
      console.error('Failed to delete officer:', err);
      alert('Could not delete officer: ' + (err.message || 'Database error'));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="p-4 sm:p-6 max-w-[1600px] mx-auto space-y-6 text-slate-900">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2.5 mb-1">
            <div className="size-9 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-700 font-bold">
              <Building2 className="size-5" />
            </div>
            <h1 className="text-2xl font-bold tracking-tight text-slate-900">
              BMC Field Officers & Engineering Roster
            </h1>
          </div>
          <p className="text-xs text-slate-500">
            Manage municipal department engineers, ward leads, and assignees for civic dispatch.
          </p>
        </div>

        <div className="flex items-center gap-2.5 shrink-0">
          <button
            type="button"
            onClick={onRefresh}
            title="Refresh list"
            className="p-2.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-600 hover:text-slate-900 transition-colors cursor-pointer shadow-2xs"
          >
            <RefreshCw className="size-4" />
          </button>
          <button
            type="button"
            onClick={handleOpenAdd}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs transition-all cursor-pointer"
          >
            <UserPlus className="size-4" />
            Add BMC Officer
          </button>
        </div>
      </div>

      {/* KPI Stats Strip - Pure Light */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
        <div className="p-4 rounded-xl bg-white border border-slate-200 shadow-2xs flex items-center gap-3.5">
          <div className="size-11 rounded-xl bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-800 font-bold">
            <Building2 className="size-5 text-slate-700" />
          </div>
          <div>
            <p className="text-[10px] font-bold uppercase tracking-wider text-slate-500">BMC Staff</p>
            <p className="text-2xl font-extrabold text-slate-900">{bmcOfficers.length}</p>
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white border border-slate-200 shadow-2xs flex items-center gap-3.5">
          <div className="size-11 rounded-xl bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-700 font-bold">
            <Briefcase className="size-5" />
          </div>
          <div>
            <p className="text-[10px] font-bold uppercase tracking-wider text-slate-500">Active Dispatches</p>
            <p className="text-2xl font-extrabold text-slate-900">
              {officersWithWorkload.reduce((sum, o) => sum + o.activeCount, 0)}
            </p>
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white border border-slate-200 shadow-2xs flex items-center gap-3.5">
          <div className="size-11 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-700 font-bold">
            <ShieldCheck className="size-5" />
          </div>
          <div>
            <p className="text-[10px] font-bold uppercase tracking-wider text-slate-500">Cases Resolved</p>
            <p className="text-2xl font-extrabold text-slate-900">
              {officersWithWorkload.reduce((sum, o) => sum + o.solvedCount, 0)}
            </p>
          </div>
        </div>

        <div className="p-4 rounded-xl bg-white border border-slate-200 shadow-2xs flex items-center gap-3.5">
          <div className="size-11 rounded-xl bg-sky-50 border border-sky-200 flex items-center justify-center text-sky-700 font-bold">
            <MapPin className="size-5" />
          </div>
          <div>
            <p className="text-[10px] font-bold uppercase tracking-wider text-slate-500">Wards Covered</p>
            <p className="text-2xl font-extrabold text-slate-900">{uniqueWards.length || 1}</p>
          </div>
        </div>
      </div>

      {/* Filter and Search Bar - Pure Light */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3 p-3.5 rounded-xl bg-white border border-slate-200 shadow-2xs">
        <div className="relative flex-1">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 size-4 text-slate-400" />
          <input
            type="text"
            placeholder="Search by name, phone, designation, or ward..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-xs rounded-lg bg-slate-50 border border-slate-200 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500"
          />
        </div>

        <div className="flex items-center gap-2">
          <select
            value={selectedDept}
            onChange={(e) => setSelectedDept(e.target.value)}
            className="px-3 py-2 text-xs rounded-lg bg-slate-50 border border-slate-200 text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 cursor-pointer"
          >
            <option value="ALL">All Departments</option>
            {BMC_DEPARTMENTS.map(dept => (
              <option key={dept} value={dept}>{dept}</option>
            ))}
          </select>

          <select
            value={selectedWard}
            onChange={(e) => setSelectedWard(e.target.value)}
            className="px-3 py-2 text-xs rounded-lg bg-slate-50 border border-slate-200 text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 cursor-pointer max-w-[200px] truncate"
          >
            <option value="ALL">All Wards</option>
            {MUMBAI_WARDS.map(w => (
              <option key={w} value={w}>{w.split(' ')[1] || w}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Officers Grid - Clean White Cards matching Dashboard */}
      {filteredOfficers.length === 0 ? (
        <div className="p-12 text-center rounded-2xl border border-dashed border-slate-300 bg-white">
          <Building2 className="size-10 mx-auto text-slate-400 mb-3" />
          <h3 className="text-sm font-semibold text-slate-900">No BMC officers found</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
            {searchTerm || selectedDept !== 'ALL' || selectedWard !== 'ALL'
              ? 'Try adjusting your search query or department filter.'
              : 'Get started by adding your first municipal engineer or ward lead.'}
          </p>
          <button
            type="button"
            onClick={handleOpenAdd}
            className="mt-4 inline-flex items-center gap-2 px-4 py-2 text-xs font-bold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white transition-colors cursor-pointer"
          >
            <UserPlus className="size-3.5" />
            Add First Officer
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredOfficers.map(officer => {
            const deptColor = DEPARTMENT_COLORS[officer.department] || DEPARTMENT_COLORS.default;
            return (
              <div
                key={officer.id}
                className="group relative flex flex-col justify-between p-5 rounded-2xl bg-white border border-slate-200 hover:border-emerald-500/50 hover:shadow-md transition-all duration-200"
              >
                <div>
                  {/* Top Row: Avatar & Actions */}
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div className="flex items-center gap-3 min-w-0">
                      {officer.avatar_url ? (
                        <img
                          src={officer.avatar_url}
                          alt={officer.name}
                          className="size-12 rounded-xl object-cover border border-slate-200 shrink-0"
                          onError={(e) => {
                            e.currentTarget.style.display = 'none';
                            if (e.currentTarget.nextSibling) {
                              e.currentTarget.nextSibling.style.display = 'flex';
                            }
                          }}
                        />
                      ) : null}
                      <div
                        className="size-12 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-800 font-bold text-sm uppercase shrink-0"
                        style={{ display: officer.avatar_url ? 'none' : 'flex' }}
                      >
                        {officer.name?.slice(0, 2) || 'OF'}
                      </div>

                      <div className="min-w-0">
                        <h3 className="text-sm font-bold text-slate-900 truncate group-hover:text-emerald-700 transition-colors">
                          {officer.name}
                        </h3>
                        <p className="text-xs text-slate-500 font-medium truncate">
                          {officer.role || 'Ward Officer'}
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-1 opacity-70 group-hover:opacity-100 transition-opacity">
                      <button
                        type="button"
                        onClick={() => handleOpenEdit(officer)}
                        title="Edit officer details"
                        className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-500 hover:text-slate-900 transition-colors cursor-pointer"
                      >
                        <Edit3 className="size-3.5" />
                      </button>
                      <button
                        type="button"
                        onClick={() => setDeletingOfficer(officer)}
                        title="Delete officer"
                        className="p-1.5 rounded-lg hover:bg-rose-50 text-slate-400 hover:text-rose-600 transition-colors cursor-pointer"
                      >
                        <Trash2 className="size-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Department Badge */}
                  <div className="mb-3">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold border ${deptColor}`}>
                      <Layers className="size-3" />
                      {officer.department || 'BMC Operations'}
                    </span>
                  </div>

                  {/* Details List */}
                  <div className="space-y-1.5 text-xs text-slate-600">
                    <div className="flex items-center gap-2 truncate">
                      <MapPin className="size-3.5 text-emerald-600 shrink-0" />
                      <span className="truncate">{officer.jurisdiction || 'Ward H-West (Bandra)'}</span>
                    </div>

                    <div className="flex items-center gap-2">
                      <Phone className="size-3.5 text-sky-600 shrink-0" />
                      {officer.phone ? (
                        <a
                          href={`tel:${officer.phone}`}
                          className="hover:underline text-slate-900 font-medium"
                        >
                          {officer.phone}
                        </a>
                      ) : (
                        <span className="text-slate-400 italic">No phone linked</span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Bottom Workload Strip */}
                <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-3">
                    <div>
                      <span className="text-slate-900 font-bold">{officer.activeCount}</span>
                      <span className="text-slate-500 ml-1 text-[11px]">Active</span>
                    </div>
                    <div>
                      <span className="text-emerald-700 font-bold">{officer.solvedCount}</span>
                      <span className="text-slate-500 ml-1 text-[11px]">Solved</span>
                    </div>
                  </div>

                  <span className="text-[10px] font-semibold text-slate-500 uppercase tracking-wider">
                    {officer.assignedCount === 0 ? 'Ready for Dispatch' : `${officer.assignedCount} Assigned`}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Add / Edit Officer Modal - 100% Solid Pure Light with Device File Upload */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/50 backdrop-blur-xs">
          <div className="w-full max-w-lg bg-white rounded-2xl border border-slate-200 shadow-2xl overflow-hidden">
            {/* Modal Header */}
            <div className="px-6 py-4.5 border-b border-slate-100 flex items-center justify-between bg-slate-50/80">
              <div className="flex items-center gap-2.5">
                <div className="size-8 rounded-lg bg-emerald-50 border border-emerald-200 flex items-center justify-center text-emerald-700 font-bold">
                  {editingOfficer ? <Edit3 className="size-4" /> : <UserPlus className="size-4" />}
                </div>
                <h3 className="text-base font-bold text-slate-900">
                  {editingOfficer ? 'Edit BMC Officer' : 'Add New BMC Field Officer'}
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setIsModalOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-200/60 transition-colors cursor-pointer"
              >
                <X className="size-4" />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSave} className="p-6 space-y-4.5 bg-white">
              {formError && (
                <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-medium flex items-center gap-2">
                  <AlertTriangle className="size-4 shrink-0" />
                  <span>{formError}</span>
                </div>
              )}

              {/* Photo Upload from Device */}
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-2 uppercase tracking-wider">
                  Officer Photo / Avatar
                </label>
                <input
                  type="file"
                  ref={fileInputRef}
                  accept="image/*"
                  onChange={handlePhotoFileChange}
                  className="hidden"
                />

                <div className="flex items-center gap-4 p-3.5 rounded-xl border border-dashed border-slate-300 bg-slate-50/60">
                  {/* Photo Preview Circle */}
                  <div className="relative shrink-0">
                    {formData.avatar_url ? (
                      <img
                        src={formData.avatar_url}
                        alt="Preview"
                        className="size-16 rounded-xl object-cover border-2 border-emerald-500 shadow-xs"
                      />
                    ) : (
                      <div className="size-16 rounded-xl bg-slate-200 border border-slate-300 flex flex-col items-center justify-center text-slate-500">
                        <Camera className="size-6 text-slate-400 mb-0.5" />
                        <span className="text-[9px] font-bold uppercase">No Photo</span>
                      </div>
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-slate-800">
                      {formData.avatar_url ? 'Photo Selected' : 'Upload Officer Photo'}
                    </p>
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      Choose a JPEG, PNG, or WEBP photo from your computer (max 5MB).
                    </p>

                    <div className="flex items-center gap-2 mt-2">
                      <button
                        type="button"
                        onClick={() => fileInputRef.current?.click()}
                        disabled={isUploadingPhoto}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 rounded-lg shadow-2xs transition-colors cursor-pointer"
                      >
                        <Upload className="size-3.5 text-emerald-600" />
                        <span>{isUploadingPhoto ? 'Uploading...' : formData.avatar_url ? 'Change Photo' : 'Choose Photo File'}</span>
                      </button>

                      {formData.avatar_url && (
                        <button
                          type="button"
                          onClick={() => setFormData(prev => ({ ...prev, avatar_url: '' }))}
                          className="text-[11px] font-semibold text-rose-600 hover:underline cursor-pointer px-1 py-1"
                        >
                          Remove
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                  Full Name <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Sunil Deshmukh"
                  value={formData.name}
                  onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-white border border-slate-300 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                    Official Phone <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="tel"
                    required
                    placeholder="e.g. +91 98201 12345"
                    value={formData.phone}
                    onChange={(e) => setFormData(prev => ({ ...prev, phone: e.target.value }))}
                    className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-white border border-slate-300 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                    Role / Designation
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. Assistant Engineer"
                    value={formData.role}
                    onChange={(e) => setFormData(prev => ({ ...prev, role: e.target.value }))}
                    className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-white border border-slate-300 text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                  Department
                </label>
                <select
                  value={formData.department}
                  onChange={(e) => setFormData(prev => ({ ...prev, department: e.target.value }))}
                  className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-white border border-slate-300 text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 cursor-pointer"
                >
                  {BMC_DEPARTMENTS.map(dept => (
                    <option key={dept} value={dept}>{dept}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wider">
                  Ward / Jurisdiction
                </label>
                <select
                  value={formData.jurisdiction}
                  onChange={(e) => setFormData(prev => ({ ...prev, jurisdiction: e.target.value }))}
                  className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-white border border-slate-300 text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 cursor-pointer"
                >
                  {MUMBAI_WARDS.map(ward => (
                    <option key={ward} value={ward}>{ward}</option>
                  ))}
                </select>
              </div>

              {/* Actions */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || isUploadingPhoto}
                  className="flex items-center gap-1.5 px-5 py-2.5 text-xs font-bold bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl transition-colors shadow-xs cursor-pointer disabled:opacity-50"
                >
                  {isSubmitting ? (
                    <>
                      <RefreshCw className="size-3.5 animate-spin" />
                      Saving...
                    </>
                  ) : (
                    <>
                      <Check className="size-3.5" />
                      {editingOfficer ? 'Update Officer' : 'Save Officer'}
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Dialog - 100% Solid Pure Light */}
      {deletingOfficer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/50 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white rounded-2xl border border-rose-200 shadow-2xl p-6 space-y-4">
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-xl bg-rose-50 border border-rose-200 flex items-center justify-center text-rose-600 shrink-0">
                <Trash2 className="size-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900">Remove BMC Officer?</h3>
                <p className="text-xs text-slate-500">This action will delete the officer from the system.</p>
              </div>
            </div>

            <p className="text-xs text-slate-700 bg-slate-50 p-3.5 rounded-xl border border-slate-200 leading-relaxed">
              Are you sure you want to delete <span className="font-bold text-slate-900">{deletingOfficer.name}</span> ({deletingOfficer.department})? Any currently assigned tickets will be safely unlinked to prevent errors.
            </p>

            <div className="flex items-center justify-end gap-2.5 pt-2">
              <button
                type="button"
                onClick={() => setDeletingOfficer(null)}
                className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleDelete}
                disabled={isSubmitting}
                className="px-4 py-2 text-xs font-bold bg-rose-600 hover:bg-rose-700 text-white rounded-xl transition-colors shadow-xs cursor-pointer disabled:opacity-50"
              >
                {isSubmitting ? 'Deleting...' : 'Delete Officer'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
