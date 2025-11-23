import React, { useState, useEffect } from 'react';
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, getDocs, query, orderBy, doc, updateDoc, deleteDoc, onSnapshot } from 'firebase/firestore';
import { BarChart, Users, MessageSquare, TrendingUp, X, CheckCircle, AlertCircle } from 'lucide-react';

const firebaseConfig = {
  apiKey: "AIzaSyBgo94NmLf_zVR6kBI5be-19anmV8L8v2k",
  authDomain: "tokentosha.firebaseapp.com",
  projectId: "tokentosha",
  storageBucket: "tokentosha.firebasestorage.app",
  messagingSenderId: "744758112717",
  appId: "1:744758112717:web:85690da928ad5bc5339484",
  measurementId: "G-FQ9YX4THEY"
};

function AdminDashboard() {
  const [activeTab, setActiveTab] = useState('users');
  const [users, setUsers] = useState([]);
  const [feedback, setFeedback] = useState([]);
  const [loading, setLoading] = useState(true);
  const [connectionStatus, setConnectionStatus] = useState('Connecting...');
  const [db, setDb] = useState(null);
  const [stats, setStats] = useState({ totalUsers: 0, totalTokens: 0, pendingFeedback: 0 });

  // Initialize Firebase (NO AUTHENTICATION)
  useEffect(() => {
    const initFirebase = async () => {
      try {
        const app = initializeApp(firebaseConfig);
        const firestore = getFirestore(app);
        
        setDb(firestore);
        setConnectionStatus('Connected');
        console.log('✅ Firebase connected successfully');
      } catch (error) {
        console.error('❌ Firebase error:', error);
        setConnectionStatus(`Error: ${error.message}`);
      }
    };
    initFirebase();
  }, []);

  // Load Users
  useEffect(() => {
    if (!db) return;
    
    const loadUsers = async () => {
      try {
        const usersRef = collection(db, 'users');
        const usersSnap = await getDocs(usersRef);
        
        const usersData = [];
        let totalTokens = 0;

        for (const userDoc of usersSnap.docs) {
          const userData = { id: userDoc.id, ...userDoc.data() };
          
          // Get tokens for each user
          const tokensRef = collection(db, `users/${userDoc.id}/tokens`);
          const tokensSnap = await getDocs(tokensRef);
          
          let userTokens = 0;
          tokensSnap.forEach(tokenDoc => {
            const amount = tokenDoc.data().amount || 0;
            userTokens += amount;
          });
          
          userData.totalTokens = userTokens;
          totalTokens += userTokens;
          usersData.push(userData);
        }

        setUsers(usersData);
        setStats(prev => ({ ...prev, totalUsers: usersData.length, totalTokens }));
        setLoading(false);
      } catch (error) {
        console.error('Error loading users:', error);
        setLoading(false);
      }
    };

    loadUsers();
  }, [db]);

  // Load Feedback with real-time updates
  useEffect(() => {
    if (!db) return;

    const feedbackRef = collection(db, 'feedback');
    const q = query(feedbackRef, orderBy('timestamp', 'desc'));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const feedbackData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        timestamp: doc.data().timestamp
      }));
      
      setFeedback(feedbackData);
      const pending = feedbackData.filter(f => f.status === 'Pending').length;
      setStats(prev => ({ ...prev, pendingFeedback: pending }));
    });

    return () => unsubscribe();
  }, [db]);

  // Update feedback status
  const updateFeedbackStatus = async (feedbackId, newStatus) => {
    try {
      const feedbackRef = doc(db, 'feedback', feedbackId);
      await updateDoc(feedbackRef, { status: newStatus });
      console.log('✅ Feedback updated');
    } catch (error) {
      console.error('Error updating feedback:', error);
    }
  };

  // Delete feedback
  const deleteFeedback = async (feedbackId) => {
    if (!confirm('Delete this feedback?')) return;
    try {
      await deleteDoc(doc(db, 'feedback', feedbackId));
      console.log('✅ Feedback deleted');
    } catch (error) {
      console.error('Error deleting feedback:', error);
    }
  };

  // Suspend/Activate User
  const toggleUserStatus = async (userId, currentStatus) => {
    try {
      const userRef = doc(db, 'users', userId);
      await updateDoc(userRef, { 
        status: currentStatus === 'active' ? 'suspended' : 'active' 
      });
      
      // Update local state
      setUsers(users.map(u => 
        u.id === userId 
          ? { ...u, status: currentStatus === 'active' ? 'suspended' : 'active' }
          : u
      ));
      console.log('✅ User status updated');
    } catch (error) {
      console.error('Error updating user:', error);
    }
  };

  const formatDate = (timestamp) => {
    if (!timestamp) return 'N/A';
    const date = new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  if (connectionStatus !== 'Connected') {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="bg-gray-800 p-8 rounded-lg shadow-xl">
          <div className="flex items-center space-x-3">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div>
            <span className="text-white text-lg">{connectionStatus}</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Header */}
      <header className="bg-gray-800 border-b border-gray-700 p-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <h1 className="text-2xl font-bold text-orange-500">TokenTosha Admin</h1>
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-400">Connected</span>
          </div>
        </div>
      </header>

      {/* Stats Cards */}
      <div className="max-w-7xl mx-auto p-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Total Users</p>
                <p className="text-3xl font-bold text-white mt-2">{stats.totalUsers}</p>
              </div>
              <Users className="w-12 h-12 text-blue-500" />
            </div>
          </div>

          <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Total Tokens</p>
                <p className="text-3xl font-bold text-white mt-2">{stats.totalTokens}</p>
              </div>
              <TrendingUp className="w-12 h-12 text-green-500" />
            </div>
          </div>

          <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Pending Feedback</p>
                <p className="text-3xl font-bold text-white mt-2">{stats.pendingFeedback}</p>
              </div>
              <MessageSquare className="w-12 h-12 text-orange-500" />
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="bg-gray-800 rounded-lg border border-gray-700">
          <div className="flex border-b border-gray-700">
            <button
              onClick={() => setActiveTab('users')}
              className={`flex-1 py-4 px-6 font-medium transition-colors ${
                activeTab === 'users'
                  ? 'bg-orange-500 text-white'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <Users className="inline mr-2 w-5 h-5" />
              Users
            </button>
            <button
              onClick={() => setActiveTab('feedback')}
              className={`flex-1 py-4 px-6 font-medium transition-colors ${
                activeTab === 'feedback'
                  ? 'bg-orange-500 text-white'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <MessageSquare className="inline mr-2 w-5 h-5" />
              Feedback
            </button>
            <button
              onClick={() => setActiveTab('reports')}
              className={`flex-1 py-4 px-6 font-medium transition-colors ${
                activeTab === 'reports'
                  ? 'bg-orange-500 text-white'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              <BarChart className="inline mr-2 w-5 h-5" />
              Reports
            </button>
          </div>

          <div className="p-6">
            {/* Users Tab */}
            {activeTab === 'users' && (
              <div>
                {loading ? (
                  <p className="text-gray-400">Loading users...</p>
                ) : users.length === 0 ? (
                  <p className="text-gray-400">No users found</p>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="text-left border-b border-gray-700">
                          <th className="pb-3 text-gray-400 font-medium">Name</th>
                          <th className="pb-3 text-gray-400 font-medium">Email</th>
                          <th className="pb-3 text-gray-400 font-medium">Meter Number</th>
                          <th className="pb-3 text-gray-400 font-medium">Tokens</th>
                          <th className="pb-3 text-gray-400 font-medium">Status</th>
                          <th className="pb-3 text-gray-400 font-medium">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {users.map((user) => (
                          <tr key={user.id} className="border-b border-gray-700">
                            <td className="py-4 text-white">{user.name || 'N/A'}</td>
                            <td className="py-4 text-gray-400">{user.email || 'N/A'}</td>
                            <td className="py-4 text-gray-400">{user.meterNumber || 'N/A'}</td>
                            <td className="py-4 text-green-400">{user.totalTokens}</td>
                            <td className="py-4">
                              <span className={`px-3 py-1 rounded-full text-xs ${
                                user.status === 'suspended' 
                                  ? 'bg-red-900 text-red-300' 
                                  : 'bg-green-900 text-green-300'
                              }`}>
                                {user.status || 'active'}
                              </span>
                            </td>
                            <td className="py-4">
                              <button
                                onClick={() => toggleUserStatus(user.id, user.status || 'active')}
                                className={`px-4 py-2 rounded text-sm ${
                                  user.status === 'suspended'
                                    ? 'bg-green-600 hover:bg-green-700'
                                    : 'bg-red-600 hover:bg-red-700'
                                }`}
                              >
                                {user.status === 'suspended' ? 'Activate' : 'Suspend'}
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}

            {/* Feedback Tab */}
            {activeTab === 'feedback' && (
              <div className="space-y-4">
                {feedback.length === 0 ? (
                  <p className="text-gray-400">No feedback yet</p>
                ) : (
                  feedback.map((item) => (
                    <div key={item.id} className="bg-gray-700 p-4 rounded-lg">
                      <div className="flex justify-between items-start mb-3">
                        <div>
                          <p className="font-medium text-white">{item.userName || 'Anonymous'}</p>
                          <p className="text-sm text-gray-400">{item.userEmail}</p>
                          <p className="text-xs text-gray-500 mt-1">{formatDate(item.timestamp)}</p>
                        </div>
                        <span className={`px-3 py-1 rounded-full text-xs ${
                          item.status === 'Resolved'
                            ? 'bg-green-900 text-green-300'
                            : item.status === 'In Progress'
                            ? 'bg-blue-900 text-blue-300'
                            : 'bg-yellow-900 text-yellow-300'
                        }`}>
                          {item.status}
                        </span>
                      </div>
                      <p className="text-gray-300 mb-4">{item.message || item.text}</p>
                      <div className="flex space-x-2">
                        {item.status !== 'Resolved' && (
                          <>
                            <button
                              onClick={() => updateFeedbackStatus(item.id, 'In Progress')}
                              className="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm flex items-center"
                            >
                              <AlertCircle className="w-4 h-4 mr-1" />
                              In Progress
                            </button>
                            <button
                              onClick={() => updateFeedbackStatus(item.id, 'Resolved')}
                              className="px-3 py-1 bg-green-600 hover:bg-green-700 rounded text-sm flex items-center"
                            >
                              <CheckCircle className="w-4 h-4 mr-1" />
                              Resolve
                            </button>
                          </>
                        )}
                        <button
                          onClick={() => deleteFeedback(item.id)}
                          className="px-3 py-1 bg-red-600 hover:bg-red-700 rounded text-sm flex items-center"
                        >
                          <X className="w-4 h-4 mr-1" />
                          Delete
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* Reports Tab */}
            {activeTab === 'reports' && (
              <div className="space-y-6">
                <div className="bg-gray-700 p-6 rounded-lg">
                  <h3 className="text-xl font-bold mb-4">Overview Statistics</h3>
                  <div className="space-y-4">
                    <div className="flex justify-between">
                      <span className="text-gray-400">Total Registered Users:</span>
                      <span className="text-white font-bold">{stats.totalUsers}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Total Tokens Purchased:</span>
                      <span className="text-green-400 font-bold">{stats.totalTokens}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Average Tokens per User:</span>
                      <span className="text-blue-400 font-bold">
                        {stats.totalUsers > 0 ? Math.round(stats.totalTokens / stats.totalUsers) : 0}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-400">Pending Feedback:</span>
                      <span className="text-orange-400 font-bold">{stats.pendingFeedback}</span>
                    </div>
                  </div>
                </div>

                <div className="bg-gray-700 p-6 rounded-lg">
                  <h3 className="text-xl font-bold mb-4">Top Users by Tokens</h3>
                  <div className="space-y-3">
                    {users
                      .sort((a, b) => b.totalTokens - a.totalTokens)
                      .slice(0, 5)
                      .map((user, index) => (
                        <div key={user.id} className="flex justify-between items-center">
                          <div className="flex items-center space-x-3">
                            <span className="text-gray-400">#{index + 1}</span>
                            <span className="text-white">{user.name || 'Anonymous'}</span>
                          </div>
                          <span className="text-green-400 font-bold">{user.totalTokens} tokens</span>
                        </div>
                      ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default AdminDashboard;