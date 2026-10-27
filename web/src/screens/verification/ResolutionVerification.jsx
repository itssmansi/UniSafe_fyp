import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../../services/supabase';

export default function ResolutionVerification() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [zone, setZone] = useState(null);
  const [loading, setLoading] = useState(true);
  const [file, setFile] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [text, setText] = useState("");

  useEffect(() => {
    const fetchZone = async () => {
      try {
        const { data, error } = await supabase
          .from('heatmap_zones')
          .select('*')
          .eq('id', id)
          .single();
        
        if (error) throw error;
        setZone(data);
      } catch (err) {
        console.error("Cannot fetch zone: ", err);
      } finally {
        setLoading(false);
      }
    };
    fetchZone();
  }, [id]);

  const handleAction = async (actionType) => {
    if (!file) {
      alert("Please upload a photo for verification"
      ); return; 
    }
    setSubmitting(true);

    try {
      const fileExt = file.name.split('.').pop();
      const fileName = `public_${Math.random()}.${fileExt}`;
      const filePath = `kanban_verifications/${fileName}`;
      
      const { error: uploadError } = await supabase.storage
        .from('complaint_images')
        .upload(filePath, file);
        
      if (uploadError) throw uploadError;
      
      const { data: urlData } = supabase.storage
        .from('complaint_images')
        .getPublicUrl(filePath);
      
      const endpoint = actionType === 'verify' 
        ? `/api/kanban/tasks/${id}/verify`
        : `/api/kanban/tasks/${id}/reject`;

      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ image_url: urlData.publicUrl })
      });

      if (res.ok) {
        setText(actionType === 'verify' ? "Saved as Done!" : "Issue Rejected and sent back! Thank you.");
      } else {
        alert("Failed to submit");
      }
    } catch (err) {
      alert("Error: " + err.message);
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) return <div className="p-8 text-center">Loading...</div>;
  

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col items-center py-12 px-4">
      <div className="max-w-md w-full bg-white rounded-2xl shadow-xl overflow-hidden">
        
        <div className="p-6 border-b border-gray-100 bg-gray-800 text-white">
          <h2 className="text-2xl font-bold">Resolution Verification</h2>
          <p className="opacity-80 text-sm mt-1">Please confirm if this issue is fixed.</p>
        </div>

        <div className="p-6">
          <div className="mb-6">
            <h3 className="text-gray-500 text-sm font-semibold uppercase">Issue Details</h3>
            <p className="font-bold text-lg text-gray-900">{zone?.zone_type || 'Unknown Zone'}</p>
          </div>

          {zone?.authority_image_url && (
            <div className="mb-6">
              <h3 className="text-gray-500 text-sm font-semibold uppercase mb-2">Authority's Photo</h3>
              <img src={zone.authority_image_url} alt="Authority Resolution" className="w-full h-48 object-cover rounded-lg border " />
            </div>
          )}

          {text ? (
            <div className="p-4 bg-green-50 text-green-800 rounded-lg font-medium text-center">
              {text}
              <button onClick={()=>navigate('/')} className="mt-4 block w-full py-2 bg-white rounded-md border border-green-200">Go Home</button>
            </div>
          ) : (
            <div>
              <h3 className="text-gray-500 text-sm font-semibold uppercase mb-2">Your Verification Photo</h3>
              <input 
                type="file" 
                accept="image/*" 
                capture="environment"
                onChange={(e) => setFile(e.target.files[0])}
                className="block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 mb-6"
              />
              
              <div className="flex gap-3">
                <button 
                  onClick={() => handleAction('reject')}
                  disabled={!file || submitting}
                  className="flex-1 py-3 border-2 border-red-600 text-red-600 font-bold rounded-xl hover:bg-red-50 disabled:opacity-50">
                  Report Not Fixed
                </button>
                <button 
                  onClick={() => handleAction('verify')}
                  disabled={!file || submitting}
                  className="flex-1 py-3 bg-green-600 text-white font-bold rounded-xl hover:bg-green-700 disabled:opacity-50">
                  Verify Fixed
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}