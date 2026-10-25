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
        
      const res = await fetch(`/api/kanban/tasks/${task.id}/resolve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ authority_image_url: urlData.publicUrl })
      });
      
      if (res.ok) {
        onSuccess(urlData.publicUrl);
      } else {
        alert("Failed to submit resolution");
      }
    } catch (err) {
      alert("Error: " + err.message);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="fixed inset-0 zP[10000] bg-black/50 flex/items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 max-w-sm w-full shadow-2xl">
        <h3 className="text-xl font-bold mb-2">Upload Resolution</h3>
        <p className="text-sm text-gray-500 mb-4">
          Please upload a photo showing that the issue "{task.title}" has been resolved.
        </p>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <input 
            type="file" 
            accept="image/*" 
            onChange={(e) => setFile(e.target.files[0])}
            className="block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
          />
          <div className="flex justify-end gap-2 mt-2">
            <button type="button" onClick={onClose} className="px-4 py-2 text-gray-600 font-medium rounded-lg hover:bg-gray-100">Cancel</button>
            <button type="submit" disabled={!file || uploading} className="px-4 py-2 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 disabled:opacity-50">
              {uploading ? "Uploading..." : "Submit"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}