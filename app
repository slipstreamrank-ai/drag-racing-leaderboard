import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, collection, query, onSnapshot, addDoc, serverTimestamp, setLogLevel, updateDoc, doc, deleteDoc, where } from 'firebase/firestore';
import { Check, X, Ban, Trash2, Gauge, TrendingUp, Filter } from 'lucide-react'; // Using lucide-react for icons

// Define global variables provided by the environment
const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id';
const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
const initialAuthToken = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;

// --- CONFIGURATION DROPDOWN OPTIONS ---
const US_STATES = [
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", 
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", 
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", 
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", 
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
];
const ENGINE_TYPES = ["Rotary", "4-Cyl", "6-Cyl", "8-Cyl", "10-Cyl", "Other"];
const INDUCTIONS = ["N/A", "Turbo", "Supercharger", "Nitrous"];
const DRIVETRAINS = ["FWD", "RWD", "AWD"];
const REAR_ENDS = ["Solid Axle", "IRS", "Other"];
const TRANSMISSIONS = ["Manual", "Automatic"];
const GEARBOX_TYPES = ["H-Pattern", "Sequential", "Other"];
const TIRE_TYPES = ["Street", "Drag Radial", "Slick"];
const BODY_TYPE_OPTIONS = ["Steel", "Fiberglass", "Carbon Fiber"];
const CHASSIS_MOD_OPTIONS = ["Factory/Stock", "Roll Cage", "Back Halfed", "One Piece Front End", "Aftermarket K Member", "Full Tube Chassis"];
// ----------------------------------------

// The main component for the Drag Racer Leaderboard
const App = () => {
    const [races, setRaces] = useState([]); // Approved races for public display
    const [pendingRaces, setPendingRaces] = useState([]); // All races for admin panel
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');
    const [db, setDb] = useState(null);
    const [auth, setAuth] = useState(null);
    const [userId, setUserId] = useState(null);
    const [isAuthReady, setIsAuthReady] = useState(false);
    
    // --- Form State ---
    const [racerName, setRacerName] = useState('');
    const [state, setState] = useState(''); 
    const [time, setTime] = useState(''); 
    const [eighthMileTime, setEighthMileTime] = useState(''); 
    const [eighthMileMph, setEighthMileMph] = useState(''); 
    const [quarterMileMph, setQuarterMileMph] = useState(''); 
    const [car, setCar] = useState('');
    const [reactionTime, setReactionTime] = useState(''); 
    const [trackTemp, setTrackTemp] = useState('');
    const [engineType, setEngineType] = useState('');
    const [induction, setInduction] = useState('');
    const [drivetrain, setDrivetrain] = useState('');
    const [rearEnd, setRearEnd] = useState('');
    const [transmission, setTransmission] = useState('');
    const [gearboxType, setGearboxType] = useState('');
    const [tireType, setTireType] = useState('');
    const [tireSize, setTireSize] = useState('');
    const [bodyType, setBodyType] = useState([]); 
    const [chassisMods, setChassisMods] = useState([]); 
    const [isSubmitting, setIsSubmitting] = useState(false);
    
    // --- Filter State ---
    const [filterEngineType, setFilterEngineType] = useState('');
    const [filterDrivetrain, setFilterDrivetrain] = useState('');
    const [filterTireType, setFilterTireType] = useState('');
    const [filterInduction, setFilterInduction] = useState(''); 
    const [filterRearEnd, setFilterRearEnd] = useState(''); 
    const [filterTransmission, setFilterTransmission] = useState(''); 
    const [filterGearboxType, setFilterGearboxType] = useState(''); 
    const [filterState, setFilterState] = useState(''); 
    const [filterBodyType, setFilterBodyType] = useState(''); 
    const [filterChassisMods, setFilterChassisMods] = useState(''); 

    // --- ADMIN LOGIC ---
    // For demonstration, the user is considered an admin if they are successfully authenticated.
    // In a real application, a separate database check for role would be necessary.
    const isAdmin = useMemo(() => !!userId && isAuthReady, [userId, isAuthReady]); 

    // 1. Firebase Initialization and Authentication
    useEffect(() => {
        try {
            if (!firebaseConfig.apiKey) {
                setError("Firebase configuration is missing. Cannot initialize database.");
                setLoading(false);
                return;
            }

            const app = initializeApp(firebaseConfig);
            const firestore = getFirestore(app);
            const firebaseAuth = getAuth(app);
            
            setLogLevel('debug'); 
            
            setDb(firestore);
            setAuth(firebaseAuth);

            const performAuth = async () => {
                try {
                    if (initialAuthToken) {
                        await signInWithCustomToken(firebaseAuth, initialAuthToken);
                    } else {
                        await signInAnonymously(firebaseAuth);
                    }
                } catch (authError) {
                    console.error("Firebase Auth Error:", authError);
                    setError("Failed to authenticate user.");
                }
            };
            performAuth();

            const unsubscribe = onAuthStateChanged(firebaseAuth, (user) => {
                setUserId(user ? user.uid : null);
                setIsAuthReady(true);
            });

            return () => unsubscribe();
            
        } catch (e) {
            console.error("Initialization Error:", e);
            setError("An error occurred during application setup. Check console for details."); 
            setLoading(false);
        }
    }, []);

    // Helper function to process snapshot data
    const processSnapshot = (snapshot) => {
        return snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            time: parseFloat(doc.data().time) || Infinity,
            eighthMileTime: parseFloat(doc.data().eighthMileTime) || Infinity, 
            reactionTime: parseFloat(doc.data().reactionTime) || Infinity,
            eighthMileMph: parseFloat(doc.data().eighthMileMph) || 0, 
            quarterMileMph: parseFloat(doc.data().quarterMileMph) || 0,
            bodyType: doc.data().bodyType || [],
            chassisMods: doc.data().chassisMods || [],
            status: doc.data().status || 'pending', // Default to pending if not present
        }));
    };

    // 2a. Public Leaderboard Data Listener (Only Approved Races)
    useEffect(() => {
        if (!db || !userId || !isAuthReady) return;

        const path = `/artifacts/${appId}/public/data/races`;
        const racesCol = collection(db, path);
        // Query only races explicitly marked as 'approved'
        const q = query(racesCol, where('status', '==', 'approved')); 

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const raceList = processSnapshot(snapshot);
            setRaces(raceList);
            setLoading(false);
        }, (snapError) => {
            console.error("Firestore Public Snapshot Error:", snapError);
            setLoading(false); 
        });

        return () => unsubscribe();
    }, [db, userId, appId, isAuthReady]); 

    // 2b. Admin Data Listener (All Races - Approved, Pending, Denied)
    useEffect(() => {
        if (!db || !userId || !isAuthReady || !isAdmin) return;
        
        // For the Admin Panel, we fetch ALL races regardless of status
        const path = `/artifacts/${appId}/public/data/races`;
        const racesCol = collection(db, path);
        const q = query(racesCol); 

        const unsubscribe = onSnapshot(q, (snapshot) => {
            const raceList = processSnapshot(snapshot);
            setPendingRaces(raceList); // Store all races here
        }, (snapError) => {
            console.error("Firestore Admin Snapshot Error:", snapError);
        });

        return () => unsubscribe();
    }, [db, userId, appId, isAuthReady, isAdmin]);


    // 3. Filter and Sort Logic (Uses the 'races' state which only contains approved ones)
    const filteredAndSortedRaces = useMemo(() => {
        let currentRaces = races;
        
        if (filterEngineType) { currentRaces = currentRaces.filter(race => race.engineType === filterEngineType); }
        if (filterDrivetrain) { currentRaces = currentRaces.filter(race => race.drivetrain === filterDrivetrain); }
        if (filterTireType) { currentRaces = currentRaces.filter(race => race.tireType === filterTireType); }
        if (filterInduction) { currentRaces = currentRaces.filter(race => race.induction === filterInduction); }
        if (filterRearEnd) { currentRaces = currentRaces.filter(race => race.rearEnd === filterRearEnd); }
        if (filterTransmission) { currentRaces = currentRaces.filter(race => race.transmission === filterTransmission); }
        if (filterGearboxType) { currentRaces = currentRaces.filter(race => race.gearboxType === filterGearboxType); }
        if (filterState) { currentRaces = currentRaces.filter(race => race.state === filterState); }
        if (filterBodyType) { currentRaces = currentRaces.filter(race => race.bodyType && race.bodyType.includes(filterBodyType)); }
        if (filterChassisMods) { currentRaces = currentRaces.filter(race => race.chassisMods && race.chassisMods.includes(filterChassisMods)); }

        const validRaces = currentRaces.filter(race => race.time !== Infinity);
        return validRaces.sort((a, b) => a.time - b.time);
    }, [
        races, filterEngineType, filterDrivetrain, filterTireType, filterInduction, 
        filterRearEnd, filterTransmission, filterGearboxType, filterState, 
        filterBodyType, filterChassisMods
    ]);


    // 4. Handle Form Submission (Add New Race - now includes status: 'pending')
    const handleSubmitRace = useCallback(async (e) => {
        e.preventDefault();

        if (!db || !userId) {
            setError('Cannot submit: Authentication is still pending or failed.');
            return;
        }

        // ... (Validation logic) ...
        const numericTime = parseFloat(time);
        const numericEighthTime = parseFloat(eighthMileTime); 
        const numericRT = parseFloat(reactionTime);
        const numericEighthMph = parseFloat(eighthMileMph); 
        const numericQuarterMph = parseFloat(quarterMileMph); 

        if (!racerName.trim() || !state || !car.trim() || !trackTemp.trim() || 
            isNaN(numericTime) || numericTime <= 0 || 
            isNaN(numericRT) || numericRT < 0 || 
            isNaN(numericEighthTime) || numericEighthTime <= 0 || 
            isNaN(numericEighthMph) || numericEighthMph <= 0 || 
            isNaN(numericQuarterMph) || numericQuarterMph <= 0 ||
            !engineType || !induction || !drivetrain || !rearEnd || !transmission || !gearboxType || !tireType || !tireSize.trim() ||
            bodyType.length === 0 || chassisMods.length === 0
        ) {
            setError('Please fill out all fields correctly. Ensure all times/speeds are positive and all configuration options (including Body Type and Chassis Mods) are selected.');
            return;
        }
        
        if (numericEighthTime >= numericTime) { setError('1/8 mile ET must be strictly less than 1/4 mile ET.'); return; }
        if (numericEighthMph >= numericQuarterMph) { setError('1/8 mile MPH must be strictly less than 1/4 mile MPH.'); return; }

        setIsSubmitting(true);
        setError('');

        try {
            const racesCol = collection(db, `/artifacts/${appId}/public/data/races`);
            
            await addDoc(racesCol, {
                // ... (All previous fields) ...
                racerName: racerName.trim(), state: state, car: car.trim(), 
                time: numericTime.toFixed(3), eighthMileTime: numericEighthTime.toFixed(3), 
                reactionTime: numericRT.toFixed(3), eighthMileMph: numericEighthMph.toFixed(2), 
                quarterMileMph: numericQuarterMph.toFixed(2), trackTemp: trackTemp.trim(), 
                
                engineType: engineType, induction: induction, drivetrain: drivetrain, rearEnd: rearEnd, 
                transmission: transmission, gearboxType: gearboxType, tireType: tireType, tireSize: tireSize.trim(),
                bodyType: bodyType, chassisMods: chassisMods,
                
                // NEW: Status and Metadata
                status: 'pending', // <--- NEW DEFAULT STATUS
                userId: userId,
                timestamp: serverTimestamp(),
            });

            // Clear form on success
            setRacerName(''); setState(''); setTime(''); setEighthMileTime(''); setEighthMileMph(''); setQuarterMileMph(''); 
            setCar(''); setReactionTime(''); setTrackTemp('');
            setEngineType(''); setInduction(''); setDrivetrain(''); setRearEnd(''); setTransmission(''); 
            setGearboxType(''); setTireType(''); setTireSize('');
            setBodyType([]); setChassisMods([]); 

        } catch (submitError) {
            console.error("Error submitting race:", submitError);
            setError('Failed to submit race time. Check console/network for database error.');
        } finally {
            setIsSubmitting(false);
        }
    }, [
        db, userId, racerName, state, time, eighthMileTime, eighthMileMph, quarterMileMph, car, reactionTime, trackTemp, appId,
        engineType, induction, drivetrain, rearEnd, transmission, gearboxType, tireType, tireSize,
        bodyType, chassisMods 
    ]);

    // 5. Admin Functions (Approve and Delete)
    const approveRace = useCallback(async (raceId) => {
        if (!isAdmin || !db) return;
        try {
            const raceRef = doc(db, `/artifacts/${appId}/public/data/races`, raceId);
            await updateDoc(raceRef, { status: 'approved' });
        } catch (e) {
            console.error("Error approving race:", e);
            console.log("Failed to approve entry. Check Firestore permissions."); 
        }
    }, [db, isAdmin, appId]);

    // Simple deny function (sets status to 'denied')
    const denyRace = useCallback(async (raceId) => {
        if (!isAdmin || !db) return;
        try {
            const raceRef = doc(db, `/artifacts/${appId}/public/data/races`, raceId);
            await updateDoc(raceRef, { status: 'denied' });
        } catch (e) {
            console.error("Error denying race:", e);
            console.log("Failed to deny entry. Check Firestore permissions."); 
        }
    }, [db, isAdmin, appId]);

    const deleteRace = useCallback(async (raceId) => {
        if (!isAdmin || !db) return;
        try {
            const raceRef = doc(db, `/artifacts/${appId}/public/data/races`, raceId);
            await deleteDoc(raceRef);
        } catch (e) {
            console.error("Error deleting race:", e);
            console.log("Failed to delete entry. Check Firestore permissions."); 
        }
    }, [db, isAdmin, appId]);


    // 6. UI Components
    
    const SelectField = ({ id, label, value, onChange, options }) => (
        <div>
            <label htmlFor={id} className="block text-sm font-medium text-gray-300 mb-1">{label}</label>
            <select
                id={id}
                value={value}
                onChange={(e) => onChange(e.target.value)}
                required
                className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white appearance-none focus:ring-yellow-500 focus:border-yellow-500"
            >
                <option value="" disabled>Select {label.toLowerCase()}...</option>
                {options.map((opt) => (
                    <option key={opt} value={opt}>{opt}</option>
                ))}
            </select>
        </div>
    );

    const FilterSelectField = ({ id, label, value, onChange, options }) => (
        <div>
            <label htmlFor={id} className="block text-xs font-medium text-gray-400 mb-1 truncate">{label}</label>
            <select
                id={id}
                value={value}
                onChange={(e) => onChange(e.target.value)}
                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-sm text-white appearance-none focus:ring-yellow-500 focus:border-yellow-500"
            >
                <option value="">All {label}</option>
                {options.map((opt) => (
                    <option key={opt} value={opt}>{opt}</option>
                ))}
            </select>
        </div>
    );
    
    const CheckboxGroup = ({ label, options, selected, onSelectionChange }) => {
        const handleCheck = (option) => {
            onSelectionChange(prev => 
                prev.includes(option)
                    ? prev.filter(item => item !== option)
                    : [...prev, option]
            );
        };

        return (
            <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">{label}</label>
                <div className="space-y-1">
                    {options.map((option) => (
                        <div key={option} className="flex items-center">
                            <input
                                id={option}
                                type="checkbox"
                                checked={selected.includes(option)}
                                onChange={() => handleCheck(option)}
                                className="h-4 w-4 text-yellow-500 bg-gray-700 border-gray-600 rounded focus:ring-yellow-500"
                            />
                            <label htmlFor={option} className="ml-2 text-sm text-gray-300 cursor-pointer">
                                {option}
                            </label>
                        </div>
                    ))}
                </div>
            </div>
        );
    };

    // Component for a single leaderboard row (Public View)
    const LeaderboardEntry = ({ race, index }) => {
        const isCurrentUser = race.userId === userId;
        const rank = index + 1;
        let rankColor = 'text-gray-400';
        let rowBg = 'hover:bg-gray-700/50';

        if (rank === 1) {
            rankColor = 'text-amber-400'; rowBg = 'bg-amber-500/10 hover:bg-amber-500/20';
        } else if (rank === 2) {
            rankColor = 'text-slate-300'; rowBg = 'bg-slate-500/10 hover:bg-slate-500/20';
        } else if (rank === 3) {
            rankColor = 'text-yellow-600'; rowBg = 'bg-yellow-600/10 hover:bg-yellow-600/20';
        }
        
        if (isCurrentUser) {
            rowBg = `${rowBg} ring-2 ring-indigo-500`; 
        }
        
        const mph18 = race.eighthMileMph > 0 ? `${race.eighthMileMph} MPH` : 'N/A';
        const mph14 = race.quarterMileMph > 0 ? `${race.quarterMileMph} MPH` : 'N/A';
        const stateDisplay = race.state || 'N/A';
        const bodyDisplay = race.bodyType && race.bodyType.length > 0 ? race.bodyType.join(', ') : 'Stock';
        const chassisModSummary = race.chassisMods && race.chassisMods.length > 0
            ? race.chassisMods.join(', ')
            : 'Stock';

        return (
            <tr key={race.id} className={`${rowBg} transition duration-150`}>
                {/* 1. Racer & Car Details */}
                <td className={`px-2 py-3 text-lg font-bold ${rankColor}`}>#{rank}</td>
                <td className="px-2 py-3 text-white truncate max-w-[150px]">{race.racerName}</td>
                <td className="px-2 py-3 text-xs font-semibold text-gray-300">{stateDisplay}</td>
                <td className="px-2 py-3 text-gray-300 truncate max-w-[200px]">{race.car}</td>
                
                {/* 2. Powertrain Specs */}
                <td className="px-2 py-3 text-xs text-yellow-300 whitespace-nowrap">{race.engineType}</td>
                <td className="px-2 py-3 text-xs text-purple-300 whitespace-nowrap">{race.induction}</td>
                <td className="px-2 py-3 text-xs font-semibold text-teal-400 whitespace-nowrap">{race.drivetrain}</td>
                <td className="px-2 py-3 text-xs text-fuchsia-300 whitespace-nowrap">{race.rearEnd}</td>
                <td className="px-2 py-3 text-xs text-blue-300 whitespace-nowrap">{race.transmission}</td>
                <td className="px-2 py-3 text-xs text-cyan-500 whitespace-nowrap">{race.gearboxType}</td>
                <td className="px-2 py-3 text-xs text-pink-500 whitespace-nowrap">{race.tireType}</td>
                <td className="px-2 py-3 text-xs text-pink-400 whitespace-nowrap">{race.tireSize}</td>

                {/* 3. Structure & Safety */}
                <td className="px-2 py-3 text-xs text-purple-400 truncate max-w-[120px]">{bodyDisplay}</td>
                <td className="px-2 py-3 text-xs text-lime-400 truncate max-w-[120px]">{chassisModSummary}</td>
                
                {/* 4. Run Results */}
                <td className="px-2 py-3 text-lg font-mono text-green-400 whitespace-nowrap">{race.time}s</td>
                <td className="px-2 py-3 text-lg font-mono text-red-400 whitespace-nowrap">{mph14}</td> 
                <td className="px-2 py-3 text-lg font-mono text-cyan-400 whitespace-nowrap">{race.eighthMileTime !== Infinity ? `${race.eighthMileTime}s` : 'N/A'}</td> 
                <td className="px-2 py-3 text-sm font-mono text-orange-400 whitespace-nowrap">{mph18}</td>
                <td className="px-2 py-3 text-xs font-mono text-pink-400 whitespace-nowrap">{race.reactionTime !== Infinity ? race.reactionTime : 'N/A'}s</td>
                <td className="px-2 py-3 text-gray-400 truncate max-w-[150px]">{race.trackTemp || 'N/A'}</td>

                {/* 5. Metadata */}
                <td className="px-2 py-3 text-xs text-gray-500 truncate max-w-[120px]">
                    {isCurrentUser ? <span className="text-indigo-400 font-semibold">You</span> : race.userId}
                </td>
            </tr>
        );
    }

    // Component for a single Admin Row
    const AdminEntry = ({ race }) => {
        const statusColor = race.status === 'approved' ? 'text-green-400' : race.status === 'denied' ? 'text-red-400' : 'text-yellow-400';
        const statusText = race.status.toUpperCase();
        
        return (
            <tr className="border-t border-gray-700 hover:bg-gray-700/50 transition duration-150">
                <td className="px-2 py-3 text-sm font-semibold truncate max-w-[100px]">{race.racerName}</td>
                <td className="px-2 py-3 text-xs truncate max-w-[150px]">{race.car}</td>
                <td className="px-2 py-3 text-sm font-mono text-green-400 whitespace-nowrap">{race.time}s</td>
                <td className="px-2 py-3 text-xs text-gray-400 truncate max-w-[100px]">{race.userId}</td>
                <td className={`px-2 py-3 text-xs font-bold ${statusColor} whitespace-nowrap`}>{statusText}</td>
                <td className="px-2 py-3 flex space-x-2">
                    {race.status !== 'approved' && (
                        <button 
                            onClick={() => approveRace(race.id)}
                            className="p-1.5 bg-green-600 hover:bg-green-700 rounded-full transition-colors text-white"
                            title="Approve Entry"
                        >
                            <Check size={16} />
                        </button>
                    )}
                    {race.status !== 'denied' && (
                        <button 
                            onClick={() => denyRace(race.id)} 
                            className="p-1.5 bg-red-600 hover:bg-red-700 rounded-full transition-colors text-white"
                            title="Deny Entry"
                        >
                            <Ban size={16} />
                        </button>
                    )}
                    <button 
                        onClick={() => deleteRace(race.id)}
                        className="p-1.5 bg-gray-600 hover:bg-gray-700 rounded-full transition-colors text-white"
                        title="Delete Permanently"
                    >
                        <Trash2 size={16} />
                    </button>
                </td>
            </tr>
        );
    };
    
    // 7. Admin Panel Component
    const AdminPanel = () => {
        const pendingCount = pendingRaces.filter(r => r.status === 'pending').length;
        // Sort by timestamp descending (newest first)
        const sortedRaces = pendingRaces.sort((a, b) => (new Date(b.timestamp?.seconds * 1000 || 0)) - (new Date(a.timestamp?.seconds * 1000 || 0)));

        return (
            <div className="lg:col-span-4 max-w-7xl mx-auto bg-gray-800 p-6 rounded-xl shadow-2xl mb-8 border-t-4 border-red-500">
                <h2 className="text-3xl font-bold text-red-400 mb-4 flex items-center space-x-3">
                    <X size={28} /> <span>Admin Review Panel ({pendingCount} Pending)</span>
                </h2>
                <div className="overflow-x-auto">
                    <table className="min-w-full table-auto text-left text-gray-300 border-collapse">
                        <thead>
                            <tr className="border-b border-gray-600 text-gray-400 uppercase text-xs tracking-wider">
                                <th className="px-2 py-2">Racer</th>
                                <th className="px-2 py-2">Car</th>
                                <th className="px-2 py-2">1/4 ET</th>
                                <th className="px-2 py-2">Submitter ID</th>
                                <th className="px-2 py-2">Status</th>
                                <th className="px-2 py-2">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {sortedRaces.length > 0 ? (
                                sortedRaces.map(race => <AdminEntry key={race.id} race={race} />)
                            ) : (
                                <tr>
                                    <td colSpan="6" className="text-center py-4 text-gray-500">
                                        No races found in the database.
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        );
    };


    if (loading && !isAuthReady) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-900 text-white">
                <p className="text-xl font-semibold">Loading App and Authenticating...</p>
            </div>
        );
    }

    if (error) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-gray-900 p-4">
                <div className="text-white text-center p-6 bg-red-700 rounded-xl shadow-xl">
                    <h2 className="text-2xl font-bold mb-2">Error</h2>
                    <p>{error}</p>
                </div>
            </div>
        );
    }


    return (
        <div className="min-h-screen bg-gray-900 text-white p-4 sm:p-8 font-sans">
            
            {/* Header and User Info */}
            <div className="max-w-7xl mx-auto mb-8 text-center">
                <h1 className="text-5xl font-extrabold text-yellow-400 mb-2 tracking-tighter">
                    <Gauge className="inline-block mr-2 h-10 w-10 text-red-500" /> Drag Racer Leaderboard
                </h1>
                <p className="text-lg text-gray-400 mb-4">
                    Post your best quarter-mile times! The lower the time, the faster the rank. (Entries require admin approval to appear)
                </p>
                <p className="text-xs text-gray-600">
                    Your User ID: <span className="font-mono text-gray-400 break-all">{userId || 'Not signed in'}</span>
                    {isAdmin && <span className="ml-4 text-red-400 font-bold"> (ADMIN)</span>}
                </p>
            </div>
            
            {/* Conditional Admin Panel */}
            {isAdmin && <AdminPanel />}

            <div className="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-4 gap-8">
                
                {/* Submission Form (lg:col-span-1) */}
                <div className="lg:col-span-1 bg-gray-800 p-6 rounded-xl shadow-2xl h-fit border-t-4 border-yellow-500">
                    <h2 className="text-2xl font-semibold text-white mb-4 border-b border-gray-700 pb-2 flex items-center">
                        <TrendingUp size={24} className="mr-2 text-yellow-500"/> Submit Your Run
                    </h2>
                    <form onSubmit={handleSubmitRace} className="space-y-4">
                        <h3 className="text-lg font-bold text-gray-300 pt-2 border-t border-gray-700">Racer & Car Details</h3>
                        
                        {/* Racer Name and State */}
                        <div>
                            <label htmlFor="racerName" className="block text-sm font-medium text-gray-300 mb-1">Racer Name</label>
                            <input id="racerName" type="text" value={racerName} onChange={(e) => setRacerName(e.target.value)} placeholder="The Drag King" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>
                        <SelectField id="state" label="State" value={state} onChange={setState} options={US_STATES} />
                        <div>
                            <label htmlFor="car" className="block text-sm font-medium text-gray-300 mb-1">Year/Make/Model</label>
                            <input id="car" type="text" value={car} onChange={(e) => setCar(e.target.value)} placeholder="2020 Toyota Supra" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>

                        <h3 className="text-lg font-bold text-gray-300 pt-4 border-t border-gray-700">Powertrain Specs</h3>
                        
                        {/* Configuration Fields (Dropdowns/Input) */}
                        <SelectField id="engineType" label="Engine Type" value={engineType} onChange={setEngineType} options={ENGINE_TYPES} />
                        <SelectField id="induction" label="Induction" value={induction} onChange={setInduction} options={INDUCTIONS} />
                        <SelectField id="drivetrain" label="Drivetrain" value={drivetrain} onChange={setDrivetrain} options={DRIVETRAINS} />
                        <SelectField id="rearEnd" label="Rear End" value={rearEnd} onChange={setRearEnd} options={REAR_ENDS} />
                        <SelectField id="transmission" label="Transmission" value={transmission} onChange={setTransmission} options={TRANSMISSIONS} />
                        <SelectField id="gearboxType" label="Gearbox Type" value={gearboxType} onChange={setGearboxType} options={GEARBOX_TYPES} />
                        <SelectField id="tireType" label="Tire Type" value={tireType} onChange={setTireType} options={TIRE_TYPES} />
                        <div>
                            <label htmlFor="tireSize" className="block text-sm font-medium text-gray-300 mb-1">Tire Size</label>
                            <input id="tireSize" type="text" value={tireSize} onChange={(e) => setTireSize(e.target.value)} placeholder="305/45R17" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>
                        
                        <h3 className="text-lg font-bold text-gray-300 pt-4 border-t border-gray-700">Structure & Safety</h3>
                        
                        {/* Checkbox Fields */}
                        <CheckboxGroup 
                            label="Body Type (Select all that apply)" options={BODY_TYPE_OPTIONS} selected={bodyType} onSelectionChange={setBodyType}
                        />
                        <CheckboxGroup 
                            label="Chassis Modifications (Select all that apply)" options={CHASSIS_MOD_OPTIONS} selected={chassisMods} onSelectionChange={setChassisMods}
                        />
                        
                        <h3 className="text-lg font-bold text-gray-300 pt-4 border-t border-gray-700">Run Results</h3>

                        {/* 1/8 Mile Time/MPH */}
                        <div>
                            <label htmlFor="eighthMileTime" className="block text-sm font-medium text-gray-300 mb-1">1/8 Mile ET (s)</label>
                            <input id="eighthMileTime" type="number" step="0.001" value={eighthMileTime} onChange={(e) => setEighthMileTime(e.target.value)} placeholder="6.500" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>
                        <div>
                            <label htmlFor="eighthMileMph" className="block text-sm font-medium text-gray-300 mb-1">1/8 Mile MPH</label>
                            <input id="eighthMileMph" type="number" step="0.01" value={eighthMileMph} onChange={(e) => setEighthMileMph(e.target.value)} placeholder="105.50" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>

                        {/* 1/4 Mile Time/MPH */}
                        <div>
                            <label htmlFor="time" className="block text-sm font-medium text-gray-300 mb-1">1/4 Mile ET (s)</label>
                            <input id="time" type="number" step="0.001" value={time} onChange={(e) => setTime(e.target.value)} placeholder="9.500" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>
                        <div>
                            <label htmlFor="quarterMileMph" className="block text-sm font-medium text-gray-300 mb-1">1/4 Mile MPH</label>
                            <input id="quarterMileMph" type="number" step="0.01" value={quarterMileMph} onChange={(e) => setQuarterMileMph(e.target.value)} placeholder="145.50" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>

                        {/* Reaction Time and Track */}
                        <div>
                            <label htmlFor="reactionTime" className="block text-sm font-medium text-gray-300 mb-1">Reaction Time (s)</label>
                            <input id="reactionTime" type="number" step="0.001" value={reactionTime} onChange={(e) => setReactionTime(e.target.value)} placeholder="0.450" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>

                        <div>
                            <label htmlFor="trackTemp" className="block text-sm font-medium text-gray-300 mb-1">Track Temp (F)</label>
                            <input id="trackTemp" type="text" value={trackTemp} onChange={(e) => setTrackTemp(e.target.value)} placeholder="85F" required className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:ring-yellow-500 focus:border-yellow-500" />
                        </div>

                        <button
                            type="submit"
                            disabled={isSubmitting}
                            className={`w-full py-3 rounded-lg font-bold text-lg transition-all shadow-lg ${isSubmitting ? 'bg-gray-600 text-gray-400 cursor-not-allowed' : 'bg-yellow-500 hover:bg-yellow-600 text-gray-900 hover:shadow-yellow-500/50'}`}
                        >
                            {isSubmitting ? 'Submitting...' : 'Submit for Review'}
                        </button>
                    </form>
                </div>

                {/* Leaderboard and Filters (lg:col-span-3) */}
                <div className="lg:col-span-3">
                    <div className="bg-gray-800 p-6 rounded-xl shadow-2xl mb-6 border-t-4 border-indigo-500">
                        <h2 className="text-2xl font-semibold text-white mb-4 border-b border-gray-700 pb-2 flex items-center">
                            <Filter size={24} className="mr-2 text-indigo-500"/> Leaderboard Filters
                        </h2>
                        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
                            <FilterSelectField id="filterEngine" label="Engine" value={filterEngineType} onChange={setFilterEngineType} options={ENGINE_TYPES} />
                            <FilterSelectField id="filterInduction" label="Induction" value={filterInduction} onChange={setFilterInduction} options={INDUCTIONS} />
                            <FilterSelectField id="filterDrivetrain" label="Drivetrain" value={filterDrivetrain} onChange={setFilterDrivetrain} options={DRIVETRAINS} />
                            <FilterSelectField id="filterTrans" label="Transmission" value={filterTransmission} onChange={setFilterTransmission} options={TRANSMISSIONS} />
                            <FilterSelectField id="filterGearbox" label="Gearbox" value={filterGearboxType} onChange={setFilterGearboxType} options={GEARBOX_TYPES} />
                            <FilterSelectField id="filterRearEnd" label="Rear End" value={filterRearEnd} onChange={setFilterRearEnd} options={REAR_ENDS} />
                            <FilterSelectField id="filterTire" label="Tire Type" value={filterTireType} onChange={setFilterTireType} options={TIRE_TYPES} />
                            <FilterSelectField id="filterState" label="State" value={filterState} onChange={setFilterState} options={US_STATES} />
                            <FilterSelectField id="filterBody" label="Body Type" value={filterBodyType} onChange={setFilterBodyType} options={BODY_TYPE_OPTIONS} />
                            <FilterSelectField id="filterChassis" label="Chassis Mods" value={filterChassisMods} onChange={setFilterChassisMods} options={CHASSIS_MOD_OPTIONS} />
                        </div>
                        <button 
                            onClick={() => {
                                setFilterEngineType(''); setFilterDrivetrain(''); setFilterTireType(''); setFilterInduction('');
                                setFilterRearEnd(''); setFilterTransmission(''); setFilterGearboxType(''); setFilterState('');
                                setFilterBodyType(''); setFilterChassisMods('');
                            }}
                            className="mt-4 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-semibold transition-colors"
                        >
                            Clear Filters
                        </button>
                    </div>

                    <div className="bg-gray-800 p-6 rounded-xl shadow-2xl overflow-x-auto">
                        <h2 className="text-2xl font-semibold text-white mb-4">Official Leaderboard ({filteredAndSortedRaces.length} Entries)</h2>
                        <table className="min-w-full table-auto text-left text-gray-300 border-collapse">
                            <thead className="sticky top-0 bg-gray-900/90 backdrop-blur-sm">
                                <tr className="border-b border-gray-600 text-gray-400 uppercase text-xs tracking-wider">
                                    <th className="px-2 py-2">Rank</th>
                                    <th className="px-2 py-2">Racer</th>
                                    <th className="px-2 py-2">State</th>
                                    <th className="px-2 py-2">Car</th>
                                    <th className="px-2 py-2">Engine</th>
                                    <th className="px-2 py-2">Induction</th>
                                    <th className="px-2 py-2">Drivetrain</th>
                                    <th className="px-2 py-2">Rear End</th>
                                    <th className="px-2 py-2">Trans.</th>
                                    <th className="px-2 py-2">Gearbox</th>
                                    <th className="px-2 py-2">Tire Type</th>
                                    <th className="px-2 py-2">Tire Size</th>
                                    <th className="px-2 py-2">Body Type</th>
                                    <th className="px-2 py-2">Chassis Mods</th>
                                    <th className="px-2 py-2 font-bold text-green-400">1/4 ET</th>
                                    <th className="px-2 py-2">1/4 MPH</th>
                                    <th className="px-2 py-2">1/8 ET</th>
                                    <th className="px-2 py-2">1/8 MPH</th>
                                    <th className="px-2 py-2">R/T</th>
                                    <th className="px-2 py-2">Track Temp</th>
                                    <th className="px-2 py-2">User ID</th>
                                </tr>
                            </thead>
                            <tbody>
                                {filteredAndSortedRaces.length > 0 ? (
                                    filteredAndSortedRaces.map((race, index) => (
                                        <LeaderboardEntry key={race.id} race={race} index={index} />
                                    ))
                                ) : (
                                    <tr>
                                        <td colSpan="20" className="text-center py-8 text-lg text-gray-500">
                                            {loading ? 'Fetching approved records...' : 'No races match the current filters or no entries have been approved yet.'}
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    );
}

export default App;
