import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

export default function VerificationHub() {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchTasks = async () => {
      try {
        const res = await fetch('/api/kanban/tasks');
        const data = await res.json();
        if (Array.isArray(data)) {
          // Filter only tasks that are 'in-review' (authority has fixed, needs public verification)
          setTasks(data.filter(t => t.status === 'in-review'));
        }
      } catch (err) {
        console.error("Failed to fetch tasks:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchTasks();
  }, []);

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-3xl mx-auto">
        <div className="mb-8">
          <h2 className="text-3xl font-bold text-gray-900">Citizen Verification Hub</h2>
          <p className="mt-2 text-gray-600">
            Help maintain transparency! These issues have been marked as resolved by authorities. We need citizens like you to confirm the fixes on-site.
          </p>
        </div>

        {loading ? (
          <div className="text-center py-12 text-gray-500">Loading issues...</div>
        ) : tasks.length === 0 ? (
          <div className="bg-white rounded-2xl shadow-sm p-12 text-center">
            <div className="w-16 h-16 bg-green-50 text-green-500 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7"></path></svg>
            </div>
            <h3 className="text-xl font-bold text-gray-900">All Caught Up!</h3>
            <p className="text-gray-500 mt-2">There are currently no issues that need public verification.</p>
            <Link to="/" className="inline-block mt-6 px-6 py-2 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700">
              Return Home
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {tasks.map(task => (
              <Link 
                key={task.id}
                to={/verify/}
                className="bg-white rounded-2xl shadow-sm overflow-hidden hover:shadow-md transition-all border border-gray-100"
              >
                <div className="h-48 bg-gray-100 relative">
                  <img src={task.authority_image_url} alt="Authority Fix" className="w-full h-full object-cover" />
                  <div className="absolute top-3 right-3 bg-blue-500 text-white text-xs font-bold px-3 py-1 rounded-full">
                    Needs Verification
                  </div>
                </div>
                <div className="p-5">
                  <h3 className="font-bold text-lg text-gray-900 mb-1">{task.zone_type || 'Unknown Zone'}</h3>
                  <p className="text-sm text-gray-500">Reported on {new Date(task.created_at).toLocaleDateString()}</p>
                  <div className="mt-4 flex items-center text-blue-600 font-semibold text-sm">
                    Verify Now
                    <svg className="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7 -7 7"></path></svg>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
