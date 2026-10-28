import React, { useState } from 'react';
import { supabase } from '../../services/supabase';

export default function ResolutionModal({ task, onClose, onSuccess }) {
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!file) return;
    setUploading(true);
    
    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `res_${Math.random()}.${fileExt}`;
      const filePath = `resolutions/${fileName}`;
      
      const { error: uploadError } = await supabase.storage
        .from('complaint_images')
        .upload(filePath, file);
        
      if (uploadError) throw uploadError;
      
      const { data: urlData } = supabase.storage
        .from('complaint_images')
        .getPublicUrl(filePath);
        
      let apiSuccess = false;
      try {
        const res = await fetch(`/api/kanban/tasks/${task.id}/resolve`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ authority_image_url: urlData.publicUrl })
        });
        if (res.ok) apiSuccess = true;
      } catch (apiErr) {
        // Fall back to direct Supabase update
      }

      if (!apiSuccess) {
        await supabase.from('complaints').update({
          authority_image_url: urlData.publicUrl,
          status: 'in-review'
        }).eq('id', task.id);
      }
      
      onSuccess(urlData.publicUrl);
    } catch (err) {
      alert("Error: " + err.message);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[99999] bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-2xl relative z-10 animate-in fade-in zoom-in-95 duration-200">
        <h3 className="text-xl font-bold mb-2 text-[#0B192C]">Upload Resolution</h3>
        <p className="text-sm text-gray-500 mb-4">
          Please upload a photo showing that the issue "{task.title}" has been resolved.
        </p>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <input 
            type="file" 
            accept="image/*" 
            onChange={(e) => setFile(e.target.files[0])}
            className="block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 cursor-pointer"
          />
          <div className="flex justify-end gap-2 mt-2">
            <button type="button" onClick={onClose} className="px-4 py-2 text-gray-600 font-medium rounded-lg hover:bg-gray-100 cursor-pointer">Cancel</button>
            <button type="submit" disabled={!file || uploading} className="px-4 py-2 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 disabled:opacity-50 cursor-pointer">
              {uploading ? "Uploading..." : "Submit"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}