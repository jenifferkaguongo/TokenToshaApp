import React, { useState, useEffect } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithCustomToken, onAuthStateChanged, setPersistence, browserLocalPersistence } from 'firebase/auth';
import { getFirestore, doc, setDoc, collection, onSnapshot, query, serverTimestamp, setLogLevel, deleteDoc, addDoc, Timestamp, getDocs } from 'firebase/firestore';
import { User, List, Loader, AlertTriangle, Trash2, FileText, MessageSquare, Send, Eye, XCircle } from 'lucide-react';

// --- Firebase Configuration and Globals ---
// Mandatory globals provided by the environment
const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id';
const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
const initialAuthToken = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : '';

// Firestore Path Structures
const PUBLIC_COLLECTION_PATH = `/artifacts/${appId}/public/data/registeredUsers`;
const getPrivateFeedbackPath = (userId) => `/artifacts/${appId}/users/${userId}/adminFeedback`;
const getUserTokensPath = (userId) => `/artifacts/${appId}/users/${userId}/tokens`; 

// Mock Data for Offline/Mock Mode
const MOCK_USERS = [
    { id: 'mock-user-1-abc-xyz', lastActive: Timestamp.now().toMillis() - 60000 * 5 }, // 5 minutes ago
    { id: 'mock-user-2-def-uvw', lastActive: Timestamp.now().toMillis() - 60000 * 60 }, // 1 hour ago
    { id: 'mock-user-3-ghi-rst', lastActive: Timestamp.now().toMillis() - 60000 * 120 }, // 2 hours ago
];

// Mock Tokens for the Mock User
const MOCK_TOKENS = [
    { id: 'MOCK-TKN-1', amount: 50, isUsed: false, tokenNumber: 'A1B2-C3D4', purchaseDate: Date.now() - 3600000 },
    { id: 'MOCK-TKN-2', amount: 100, isUsed: true, tokenNumber: 'E5F6-G7H8', purchaseDate: Date.now() - 7200000 },
];

// Set Firebase log level for debugging
setLogLevel('debug');

/**
 * Checks for missing or invalid configuration variables.
 * @returns {string | null} A string error message if config is bad, otherwise null.
 */
const checkConfigError = () => {
    if (Object.keys(firebaseConfig).length === 0 || !firebaseConfig.apiKey || !firebaseConfig.projectId) {
        return "Firebase Configuration is missing or incomplete (requires apiKey and projectId).";
    }
    if (!initialAuthToken) {
        return "Custom Admin Token (__initial_auth_token) is missing. Cannot authenticate as Admin.";
    }
    return null;
};

// Custom Hook for User Registry Logic
const useUserRegistry = () => {
  const [db, setDb] = useState(null);
  const [auth, setAuth] = useState(null);
  const [userId, setUserId] = useState(null);
  const [isAuthReady, setIsAuthReady] = useState(false);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [authError, setAuthError] = useState(checkConfigError());
  const [isMockMode, setIsMockMode] = useState(false); 

  // 1. Initialize Firebase and Authentication or switch to Mock Mode/Error
  useEffect(() => {
    // Check for critical missing configuration first
    if (authError) {
        // If config is bad, switch to Mock Mode (using mock data for structure but showing error)
        setIsMockMode(true);
        setUserId('MOCK_ADMIN_ID');
        setUsers([{ id: 'MOCK_ADMIN_ID', lastActive: Timestamp.now().toMillis() }, ...MOCK_USERS]);
        setLoading(false);
        setIsAuthReady(true);
        console.error("Critical Configuration Error:", authError);
        return;
    }

    // Standard Firebase Initialization
    try {
      const app = initializeApp(firebaseConfig);
      const authInstance = getAuth(app);
      const dbInstance = getFirestore(app);

      setAuth(authInstance);
      setDb(dbInstance);

      const unsubscribeAuth = onAuthStateChanged(authInstance, async (user) => {
        if (user) {
          setUserId(user.uid);
          await setPersistence(authInstance, browserLocalPersistence);
          setIsAuthReady(true);
        } else {
          // User is not signed in. Attempt to sign in with custom token ONLY.
          try {
            await signInWithCustomToken(authInstance, initialAuthToken);
          } catch (e) {
            console.error("Firebase Sign-In Error (Custom Token Failed):", e);
            setAuthError(`Authentication Failed (Token/API): ${e.message}.`);
            setIsAuthReady(true); // Stop loading, show error
          }
        }
        setLoading(false);
      });

      return () => unsubscribeAuth();
    } catch (e) {
      console.error("Firebase Initialization Error:", e);
      setAuthError(`Initialization failed: ${e.message}. Check console for details.`);
      setLoading(false);
      setIsAuthReady(true);
    }
  }, [authError]);

  // 2. Save current user and set up real-time listener for ALL users
  useEffect(() => {
    if (isMockMode || !db || !userId || !isAuthReady) {
      return;
    }

    const saveUserToRegistry = async () => {
      try {
        const userDocRef = doc(db, PUBLIC_COLLECTION_PATH, userId);
        await setDoc(userDocRef, {
          userId: userId,
          lastActive: serverTimestamp(),
          isAdmin: true 
        }, { merge: true });
      } catch (e) {
        console.error("Error writing user document (Admin ID):", e);
      }
    };

    const setupListener = () => {
      const usersColRef = collection(db, PUBLIC_COLLECTION_PATH);
      const q = query(usersColRef);

      const unsubscribeSnapshot = onSnapshot(q, (snapshot) => {
        const registeredUsers = snapshot.docs.map(d => ({
          id: d.id,
          lastActive: d.data().lastActive ? d.data().lastActive.toMillis() : Date.now(),
          ...d.data()
        }));
        registeredUsers.sort((a, b) => b.lastActive - a.lastActive);
        setUsers(registeredUsers);
      }, (e) => {
        console.error("Error listening to user data:", e);
        // This is where a security rule error will surface for the user list
        setAuthError("Failed to fetch user list. Check Firebase security rules for read permissions.");
      });

      return unsubscribeSnapshot;
    };

    saveUserToRegistry();
    const unsubscribe = setupListener();

    return () => unsubscribe();
  }, [db, userId, isAuthReady, isMockMode]); 

  // --- Admin Functions ---

  const deleteRegisteredUser = async (targetUserId) => {
    if (isMockMode) {
        setUsers(prevUsers => prevUsers.filter(u => u.id !== targetUserId));
        return;
    }
    if (!db || targetUserId === userId) return;

    try {
      const userDocRef = doc(db, PUBLIC_COLLECTION_PATH, targetUserId);
      await deleteDoc(userDocRef);
    } catch (e) {
      console.error("Error deleting user document:", e);
      alert(`Failed to delete user: ${e.message}. Check Firebase security rules.`); 
    }
  };
  
  const sendFeedback = async (feedbackText) => {
    if (isMockMode) return true;
    if (!db || !userId || feedbackText.trim() === "") return false;

    try {
        const feedbackColRef = collection(db, getPrivateFeedbackPath(userId));
        await addDoc(feedbackColRef, {
            feedback: feedbackText,
            submittedAt: serverTimestamp(),
            adminId: userId
        });
        return true;
    } catch (e) {
        console.error("Error sending feedback:", e);
        alert(`Failed to submit feedback: ${e.message}`); 
        return false;
    }
  };

  const generateUserReport = () => {
    if (users.length === 0) return;
    const reportContent = users.map(user => {
        const lastActiveMs = typeof user.lastActive === 'number' ? user.lastActive : user.lastActive?.toMillis();
        const lastActiveTime = lastActiveMs
            ? new Date(lastActiveMs).toLocaleString() 
            : 'N/A';
        return `User ID: ${user.id}, Last Active: ${lastActiveTime}`;
    }).join('\n');

    const mode = isMockMode ? 'MOCK DATA' : 'LIVE DATA';
    const header = `Tosha App User Report (${mode})\nGenerated By: ${userId}\nDate: ${new Date().toLocaleString()}\nTotal Users: ${users.length}\n\n--- User List ---\n`;
    const fullReport = header + reportContent;

    const blob = new Blob([fullReport], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'user_report.txt';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };
  
  // New: Function to load user tokens
  const openTokenViewer = async (targetUserId) => {
    if (isMockMode) {
        return MOCK_TOKENS;
    }
    
    if (!db) {
        console.error("Database not ready for token fetch.");
        return [];
    }

    try {
        const tokensColRef = collection(db, getUserTokensPath(targetUserId));
        const snapshot = await getDocs(tokensColRef);

        const tokens = snapshot.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
        }));
        return tokens;
    } catch (e) {
        console.error("Error fetching tokens:", e);
        // Note: The admin should have the right to read these! Check rule 2 in the previous response.
        alert(`Failed to load tokens for user ${targetUserId}. Check security rules. Error: ${e.message}`);
        return [];
    }
  };


  return { users, userId, loading, authError, deleteRegisteredUser, sendFeedback, generateUserReport, openTokenViewer, isMockMode };
};

// --- Modals and Helper Components ---

// Converts time in milliseconds to a relative string (e.g., "5 minutes ago")
const timeAgo = (timestampMs) => {
    const seconds = Math.floor((Date.now() - timestampMs) / 1000);
    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)} minutes ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 86400)} hours ago`;
    return `${Math.floor(seconds / 86400)} days ago`;
};


// Confirmation Modal (used for user deletion)
const ConfirmationModal = ({ isOpen, onClose, onConfirm, userToDelete }) => {
    if (!isOpen) return null;
    return (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center p-4 z-50">
            <div className="bg-white p-6 rounded-xl shadow-2xl max-w-sm w-full transform transition-all">
                <h3 className="text-xl font-bold text-red-600 mb-3">Confirm Deletion</h3>
                <p className="text-gray-700 mb-4">
                Are you sure you want to permanently delete the user with ID:
                <code className="block bg-gray-100 p-2 mt-2 rounded break-all text-xs font-mono">{userToDelete}</code>
                </p>
                <div className="flex justify-end space-x-3">
                    <button
                        onClick={onClose}
                        className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-lg hover:bg-gray-300 transition"
                    >
                        Cancel
                    </button>
                    <button
                        onClick={onConfirm}
                        className="px-4 py-2 text-sm font-medium text-white bg-red-500 rounded-lg hover:bg-red-600 transition"
                    >
                        Delete User
                    </button>
                </div>
            </div>
        </div>
    );
};

// Feedback Modal
const FeedbackModal = ({ isOpen, onClose, onSubmit }) => {
    const [feedback, setFeedback] = useState('');
    const [isSending, setIsSending] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (feedback.trim().length < 5) {
            alert("Feedback must be at least 5 characters long."); 
            return;
        }
        setIsSending(true);
        const success = await onSubmit(feedback);
        setIsSending(false);
        if (success) {
            setFeedback('');
            onClose();
        }
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center p-4 z-50">
            <div className="bg-white p-6 rounded-xl shadow-2xl max-w-md w-full transform transition-all">
                <h3 className="text-xl font-bold text-indigo-600 mb-4 flex items-center">
                    <MessageSquare className="w-5 h-5 mr-2" />
                    Give Feedback
                </h3>
                <p className="text-gray-600 mb-4 text-sm">
                    Submit private notes or feedback regarding the system. (Saved only to your private admin log)
                </p>
                <form onSubmit={handleSubmit}>
                    <textarea
                        value={feedback}
                        onChange={(e) => setFeedback(e.target.value)}
                        placeholder="Type your feedback here..."
                        rows="4"
                        className="w-full p-3 border border-gray-300 rounded-lg focus:ring-indigo-500 focus:border-indigo-500 mb-4 resize-none"
                        required
                    />
                    <div className="flex justify-end space-x-3">
                        <button
                            type="button"
                            onClick={onClose}
                            className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-lg hover:bg-gray-300 transition"
                            disabled={isSending}
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            className={`px-4 py-2 text-sm font-medium text-white rounded-lg transition flex items-center ${
                                isSending ? 'bg-indigo-400 cursor-not-allowed' : 'bg-indigo-500 hover:bg-indigo-600'
                            }`}
                            disabled={isSending}
                        >
                            {isSending ? (
                                <Loader className="w-4 h-4 mr-2 animate-spin" />
                            ) : (
                                <Send className="w-4 h-4 mr-2" />
                            )}
                            {isSending ? 'Sending...' : 'Send Feedback'}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};

// Token Viewer Modal
const TokenModal = ({ isOpen, onClose, userId, tokens }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center p-4 z-50">
      <div className="bg-white p-6 rounded-xl w-full max-w-lg shadow-2xl transform transition-all max-h-[90vh] overflow-y-auto">

        <h3 className="text-xl font-bold text-indigo-600 mb-4 border-b pb-2">
          Tokens for: <code className="text-sm font-mono bg-gray-100 p-1 rounded break-all">{userId}</code>
        </h3>

        {tokens.length === 0 ? (
          <p className="text-gray-500 italic text-center py-4">
            No tokens found for this user in their private collection. 
            <span className="block mt-2 text-xs text-red-500">
                (If tokens exist, check your **Firestore Security Rules** to ensure the admin has read access to the target user's private collection: `/artifacts/{appId}/users/{targetUserId}/tokens/{tokenDocId}`).
            </span>
          </p>
        ) : (
          <ul className="space-y-3">
            {tokens.map(t => {
                const purchaseTime = t.purchaseDate && t.purchaseDate.seconds 
                    ? t.purchaseDate.seconds * 1000 
                    : t.purchaseDate;

                return (
                    <li key={t.id} className="bg-gray-50 p-4 rounded-lg border border-gray-200 shadow-sm">
                        <div className="flex justify-between items-start mb-1">
                            <p className="text-lg font-semibold text-gray-800">
                                {t.amount} Tokens
                            </p>
                            <span className={`px-2 py-0.5 text-xs font-bold rounded-full ${t.isUsed ? 'bg-red-100 text-red-600' : 'bg-green-100 text-green-600'}`}>
                                {t.isUsed ? "USED" : "ACTIVE"}
                            </span>
                        </div>
                        <p className="text-sm text-gray-600">
                            <strong className="font-medium">Token ID:</strong> {t.tokenNumber || 'N/A'}
                        </p>
                        <p className="text-sm text-gray-600">
                            <strong className="font-medium">Purchased:</strong> {purchaseTime ? new Date(purchaseTime).toLocaleString() : 'N/A'}
                        </p>
                        <p className="text-xs text-gray-400 mt-2 break-all">
                            Doc ID: {t.id}
                        </p>
                    </li>
                );
            })}
          </ul>
        )}

        <button
          onClick={onClose}
          className="mt-6 w-full px-4 py-2 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 transition font-semibold"
        >
          Close
        </button>
      </div>
    </div>
  );
};


// Main App Component
const App = () => {
  const { 
    users, 
    userId, 
    loading, 
    authError, 
    deleteRegisteredUser, 
    sendFeedback, 
    generateUserReport, 
    openTokenViewer, 
    isMockMode 
  } = useUserRegistry();

  // State for Admin Modals
  const [isDeleteModalOpen, setIsDeleteModalOpen] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);
  const [isFeedbackModalOpen, setIsFeedbackModalOpen] = useState(false);
  
  // New States for Token Viewer
  const [isTokenModalOpen, setIsTokenModalOpen] = useState(false);
  const [selectedUserTokens, setSelectedUserTokens] = useState([]);
  const [selectedUserId, setSelectedUserId] = useState(null);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-gray-50 p-4">
        <Loader className="w-8 h-8 animate-spin text-indigo-600 mb-4" />
        <p className="text-gray-600 font-medium">Authenticating Admin and Initializing...</p>
      </div>
    );
  }

  // CRITICAL CONFIGURATION ERROR SCREEN (REPLACES GENERIC ERROR)
  if (authError && isMockMode) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center p-4">
        <div className="bg-white p-8 rounded-2xl shadow-2xl border border-red-300 max-w-md w-full">
          <XCircle className="w-8 h-8 text-red-500 mb-4 mx-auto" />
          <h2 className="text-2xl font-bold text-red-600 mb-3 text-center">Configuration Required</h2>
          <p className="text-sm text-gray-700 mb-6 text-center">
            The application cannot proceed because critical Firebase or Authentication variables are missing from the environment.
          </p>
          <div className="bg-red-50 p-4 rounded-xl border border-red-200">
              <p className="text-sm font-semibold text-red-800">
                  Detailed Error:
              </p>
              <code className="block mt-1 text-xs text-red-700 font-mono break-words bg-red-100 p-2 rounded">
                  {authError}
              </code>
          </div>
          <p className="text-xs text-gray-500 mt-4 text-center">
              Please ensure you have provided the complete Firebase config and the custom admin token.
          </p>
        </div>
      </div>
    );
  }

  // POST-AUTH ERROR SCREEN (e.g., failed to fetch data due to rules)
  if (authError) {
    return (
        <div className="min-h-screen bg-red-50 flex items-center justify-center p-4">
            <div className="bg-white p-6 rounded-xl shadow-lg border border-red-300 max-w-lg w-full">
                <AlertTriangle className="w-6 h-6 text-red-500 inline mr-2" />
                <h2 className="text-xl font-bold text-red-600 mb-2">Data Connection Error</h2>
                <p className="text-sm text-red-800 break-words">
                    Authentication succeeded, but a subsequent data operation failed (e.g., fetching the user list or invalid token).
                </p>
                <p className="text-xs mt-3 text-red-600 font-mono">
                    Details: {authError}
                </p>
                <p className="text-xs mt-2 text-red-600 font-semibold">
                    Action: You must verify your **Firestore Security Rules** allow the authenticated admin user to read the public user registry (`/artifacts/{appId}/public/data/registeredUsers`).
                </p>
            </div>
        </div>
    );
  }
  
  const handleViewTokens = async (targetUserId) => {
    setSelectedUserId(targetUserId);
    const tokens = await openTokenViewer(targetUserId); 
    setSelectedUserTokens(tokens);
    setIsTokenModalOpen(true);
  };

  const confirmDelete = (targetUserId) => {
    setUserToDelete(targetUserId);
    setIsDeleteModalOpen(true);
  };

  const handleDelete = async () => {
    if (userToDelete) {
      await deleteRegisteredUser(userToDelete);
    }
    setIsDeleteModalOpen(false);
    setUserToDelete(null);
  };

  return (
    <div className="min-h-screen bg-gray-100 p-4 sm:p-8 flex flex-col items-center">
      <script src="https://cdn.tailwindcss.com"></script>
      <style>
        {`
          @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
          body { font-family: 'Inter', sans-serif; }
          .user-id-text { font-size: 0.75rem; }
          @media (min-width: 640px) { .user-id-text { font-size: 0.875rem; } }
          .shadow-admin-button {
              box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1), 0 0 0 3px rgba(239, 68, 68, 0.3);
          }
        `}
      </style>

      {/* Header Card */}
      <div className="w-full max-w-lg bg-indigo-600 text-white p-6 rounded-2xl shadow-xl mb-6">
        <h1 className="text-2xl font-bold mb-1">Tosha Admin Panel</h1>
        <p className="opacity-90">User Management and Reporting</p>
        <div className="mt-4 pt-4 border-t border-indigo-400">
          <p className="text-sm font-semibold opacity-80">Your Authenticated User ID:</p>
          <code className="user-id-text block mt-1 bg-indigo-700 p-2 rounded-lg break-all">{userId}</code>
        </div>
      </div>

      {/* Mock Mode Banner */}
      {isMockMode && (
          <div className="w-full max-w-lg bg-yellow-100 border border-yellow-400 text-yellow-800 p-3 rounded-xl mb-6 shadow-md">
              <AlertTriangle className="w-5 h-5 inline mr-2" />
              <span className="font-semibold">Mock Mode Active:</span> Configuration Error detected. Displaying simulated data only.
          </div>
      )}


      {/* Admin Actions Bar */}
      <div className="w-full max-w-lg mb-6 flex justify-between space-x-3">
        <button
          onClick={generateUserReport}
          className="flex-1 flex items-center justify-center px-3 py-3 text-sm font-semibold text-white bg-green-500 rounded-xl hover:bg-green-600 transition shadow-lg hover:shadow-xl"
          title="Download all registered user IDs and timestamps"
        >
          <FileText className="w-4 h-4 mr-2" />
          Export Report
        </button>
        
        <button
          onClick={() => setIsFeedbackModalOpen(true)}
          className="flex-1 flex items-center justify-center px-3 py-3 text-sm font-semibold text-white bg-indigo-500 rounded-xl hover:bg-indigo-600 transition shadow-lg hover:shadow-xl"
          title="Submit internal administrative feedback"
        >
          <MessageSquare className="w-4 h-4 mr-2" />
          Give Feedback
        </button>
      </div>

      {/* User List Card */}
      <div className="w-full max-w-lg bg-white p-6 rounded-2xl shadow-lg">
        <h2 className="text-xl font-bold text-gray-800 flex items-center mb-4 border-b pb-2">
            <List className="w-5 h-5 mr-2" />
            Registered Users ({isMockMode ? users.length - 1 : users.length})
        </h2>

        {users.length === 0 ? (
          <p className="text-center text-gray-500 py-8">No users found. Start your Tosha app to register users.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-1/2">User ID</th>
                  <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Last Active</th>
                  <th className="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {users
                  .filter(u => u.id !== userId) // Filter out the admin user from the list
                  .map((user) => (
                    <tr key={user.id} className="hover:bg-gray-50">
                      <td className="px-3 py-4 whitespace-nowrap">
                        <code className="user-id-text text-gray-700 font-mono break-all">{user.id}</code>
                        {user.isAdmin && <span className="ml-2 px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">ADMIN</span>}
                      </td>
                      <td className="px-3 py-4 whitespace-nowrap text-sm text-gray-500">
                        {user.lastActive ? timeAgo(user.lastActive) : 'N/A'}
                      </td>
                      <td className="px-3 py-4 whitespace-nowrap text-right text-sm font-medium flex space-x-2">
                        <button
                          onClick={() => handleViewTokens(user.id)}
                          className="text-indigo-600 hover:text-indigo-900 p-1 rounded-full hover:bg-indigo-50 transition"
                          title="View User Tokens"
                        >
                            <Eye className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => confirmDelete(user.id)}
                          className={`text-red-600 hover:text-red-900 p-1 rounded-full hover:bg-red-50 transition ${isMockMode ? 'opacity-50 cursor-not-allowed' : ''}`}
                          title="Delete User"
                          disabled={isMockMode}
                        >
                            <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modals */}
      <ConfirmationModal
        isOpen={isDeleteModalOpen}
        onClose={() => setIsDeleteModalOpen(false)}
        onConfirm={handleDelete}
        userToDelete={userToDelete}
      />
      <FeedbackModal
        isOpen={isFeedbackModalOpen}
        onClose={() => setIsFeedbackModalOpen(false)}
        onSubmit={sendFeedback}
      />
      <TokenModal
        isOpen={isTokenModalOpen}
        onClose={() => setIsTokenModalOpen(false)}
        userId={selectedUserId}
        tokens={selectedUserTokens}
      />
    </div>
  );
};

export default App;