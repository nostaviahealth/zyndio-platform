/**
 * Zyndio Space - Main Application
 * A digital sanctuary for meditation
 */

import { useState, useCallback, useEffect, useRef } from 'react';
import { audioEngine } from './audio/AudioEngine';
import type { AudioMode, FlowVariant, FocusVariant } from './audio/AudioEngine';
import { rppgEngine } from './bio/rPPGEngine';
import { useAuth } from './hooks/useAuth';
import { useHabitSync } from './hooks/useHabitSync';
import { supabase } from './lib/supabase';
import './index.css';

type AppState = 'idle' | 'session' | 'complete';

// Duration presets in minutes
const DURATIONS = [5, 10, 20, 30, 45, 60, Infinity] as const;

function App() {
  // Auth state
  const { user, loading: authLoading, signInWithGoogle, signOut } = useAuth();

  // Welcome screen state
  const [hasSeenWelcome, setHasSeenWelcome] = useState(() => {
    return localStorage.getItem('zyndio-seen-welcome') === 'true';
  });

  const [appState, setAppState] = useState<AppState>('idle');
  const [durationIndex, setDurationIndex] = useState(1); // Default 10m
  const [audioMode, setAudioMode] = useState<AudioMode>('void');
  const [flowVariant] = useState<FlowVariant>('brown');
  const [focusVariant] = useState<FocusVariant>('theta');
  const [isDragging, setIsDragging] = useState(false);
  const [rotation, setRotation] = useState(0);
  const [remainingSeconds, setRemainingSeconds] = useState(0);
  const [showStats, setShowStats] = useState(false);
  const [spaceTheme, setSpaceTheme] = useState(() => {
    return localStorage.getItem('zyndio-space-theme') === 'true';
  });
  const [deepSyncActive, setDeepSyncActive] = useState(() => {
    return localStorage.getItem('zyndio-deepsync') === 'true';
  });

  // Binaural Architecture state
  const [brainwavePosition, setBrainwavePosition] = useState(0.5); // 0=delta, 1=gamma
  const [isSliderDragging, setIsSliderDragging] = useState(false);
  const sliderRef = useRef<HTMLDivElement>(null);

  // Biosensor state
  const [isScanning, setIsScanning] = useState(false);
  const [scanProgress, setScanProgress] = useState(0);
  const [aiMessage, setAiMessage] = useState('');

  // Neutralize Mode state (emergency calming)
  const [neutralizeActive, setNeutralizeActive] = useState(false);
  const [breathPhase, setBreathPhase] = useState<'inhale' | 'hold' | 'exhale' | 'idle'>('idle');
  const breathTimerRef = useRef<number | null>(null);

  // Function menu state
  const [menuExpanded, setMenuExpanded] = useState(false);



  // Biosensor scan handler
  const handleBioscan = useCallback(async () => {
    if (isScanning) return;

    setIsScanning(true);
    setScanProgress(0);
    setAiMessage('');

    try {
      const result = await rppgEngine.startScan((progress) => {
        setScanProgress(progress);
      });

      // Get protocol recommendation
      const protocol = rppgEngine.getProtocolForStress(result.stressIndex);
      setAiMessage(protocol.message);

      // Auto-start session after showing message
      setTimeout(() => {
        // Set brainwave position based on stress
        setBrainwavePosition(protocol.brainwavePosition);

        // Find closest duration
        const targetMinutes = protocol.durationMinutes;
        const closestIndex = DURATIONS.findIndex(d => d >= targetMinutes);
        setDurationIndex(closestIndex >= 0 ? closestIndex : 1);

        // Start session
        sessionStartRef.current = Date.now();
        setAppState('session');
        setRemainingSeconds(protocol.durationMinutes * 60);

        // Start audio with binaural architecture
        audioEngine.start('void', 'brown');
        audioEngine.startBinauralArchitecture();
        audioEngine.setBrainwaveTarget(protocol.brainwavePosition);

        // Clear scan state
        setIsScanning(false);
        setAiMessage('');
      }, 3000);

    } catch (error) {
      console.error('Bioscan error:', error);
      setIsScanning(false);
      setAiMessage('Camera unavailable. Starting default session.');
      setTimeout(() => setAiMessage(''), 2000);
    }
  }, [isScanning]);

  // Habit data from localStorage
  const [habitData, setHabitData] = useState(() => {
    const defaults = {
      todayMinutes: 0,
      currentStreak: 0,
      lifetimeMinutes: 0,
      weeklyMinutes: 0,
      dailyGoal: 10,
      history: [] as { date: string; minutes: number }[]
    };
    try {
      const stored = localStorage.getItem('zyndio-space-habits');
      if (stored) {
        return { ...defaults, ...JSON.parse(stored) };
      }
    } catch (e) {
      console.error('Failed to load habit data:', e);
    }
    return defaults;
  });

  // Cloud sync hook
  const { syncToCloud, loadFromCloud } = useHabitSync(user);

  const dialRef = useRef<HTMLDivElement>(null);
  const centerRef = useRef({ x: 0, y: 0 });
  const lastAngleRef = useRef(0);
  const sessionTimerRef = useRef<number | null>(null);
  const sessionStartRef = useRef<number>(0);
  const touchStartY = useRef(0);
  const [statsPullProgress, setStatsPullProgress] = useState(0);

  // Mode swipe gesture refs
  const modeSwipeStartX = useRef(0);
  const modeSwipeStartY = useRef(0);

  // Load from cloud when user logs in
  useEffect(() => {
    if (user) {
      loadFromCloud().then(cloudData => {
        if (cloudData && cloudData.lifetimeMinutes > habitData.lifetimeMinutes) {
          // Cloud has more data, use it
          setHabitData(cloudData);
          localStorage.setItem('zyndio-space-habits', JSON.stringify(cloudData));
        }
      });
    }
  }, [user, loadFromCloud]);

  // Save habit data to localStorage
  const saveHabitData = useCallback((data: typeof habitData) => {
    setHabitData(data);
    localStorage.setItem('zyndio-space-habits', JSON.stringify(data));
  }, []);

  // Create click sound for dial rotation feedback
  const audioContextRef = useRef<AudioContext | null>(null);
  const playClick = useCallback(() => {
    try {
      if (!audioContextRef.current) {
        audioContextRef.current = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
      }
      const ctx = audioContextRef.current;
      const oscillator = ctx.createOscillator();
      const gainNode = ctx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      oscillator.frequency.value = 1200; // High pitch click
      oscillator.type = 'sine';

      gainNode.gain.setValueAtTime(0.03, ctx.currentTime); // Very quiet
      gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.02);

      oscillator.start(ctx.currentTime);
      oscillator.stop(ctx.currentTime + 0.02);
    } catch {
      // Audio not available
    }
  }, []);

  // Calculate angle from center to pointer
  const getAngle = useCallback((clientX: number, clientY: number): number => {
    const dx = clientX - centerRef.current.x;
    const dy = clientY - centerRef.current.y;
    return Math.atan2(dy, dx) * (180 / Math.PI);
  }, []);

  // Handle pointer down on dial
  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    if (appState !== 'idle' || !dialRef.current) return;

    e.preventDefault();
    const rect = dialRef.current.getBoundingClientRect();
    centerRef.current = {
      x: rect.left + rect.width / 2,
      y: rect.top + rect.height / 2
    };

    lastAngleRef.current = getAngle(e.clientX, e.clientY);
    setIsDragging(true);
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  }, [appState, getAngle]);

  // Handle pointer move
  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    if (!isDragging) return;

    const currentAngle = getAngle(e.clientX, e.clientY);
    let delta = currentAngle - lastAngleRef.current;

    // Handle wrap-around
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    setRotation(prev => {
      const newRotation = prev + delta;
      // Update duration based on rotation
      const notchAngle = 360 / DURATIONS.length;
      const newIndex = ((Math.round(newRotation / notchAngle) % DURATIONS.length) + DURATIONS.length) % DURATIONS.length;

      // Haptic and audio feedback when passing a notch
      setDurationIndex(prevIndex => {
        if (prevIndex !== newIndex) {
          // Vibrate on mobile devices
          if (navigator.vibrate) {
            navigator.vibrate(10);
          }
          // Play click sound (works on all platforms)
          playClick();
        }
        return newIndex;
      });

      return newRotation;
    });

    lastAngleRef.current = currentAngle;
  }, [isDragging, getAngle, playClick]);

  // Handle pointer up - start session
  const handlePointerUp = useCallback((e: React.PointerEvent) => {
    if (!isDragging) return;

    (e.target as HTMLElement).releasePointerCapture(e.pointerId);
    setIsDragging(false);

    // Start session after brief delay
    const duration = DURATIONS[durationIndex];
    setTimeout(async () => {
      sessionStartRef.current = Date.now();
      setAppState('session');
      setRemainingSeconds(duration === Infinity ? Infinity : duration * 60);

      // Request wake lock to prevent screen sleep during meditation
      try {
        if ('wakeLock' in navigator) {
          await (navigator as Navigator & { wakeLock: { request: (type: string) => Promise<unknown> } }).wakeLock.request('screen');
        }
      } catch {
        // Wake lock not supported or denied - timer will still work correctly
      }

      // Start audio
      const variant = audioMode === 'flow' ? flowVariant : focusVariant;
      audioEngine.start(audioMode, variant);
    }, 300);
  }, [isDragging, durationIndex, audioMode, flowVariant, focusVariant]);

  // Handle session end
  const handleSessionEnd = useCallback((actualMinutes: number) => {
    audioEngine.stop();

    // Record session
    const today = new Date().toISOString().split('T')[0];
    const newHistory = [...habitData.history, { date: today, minutes: actualMinutes }];
    const todayMinutes = newHistory
      .filter(s => s.date === today)
      .reduce((sum, s) => sum + s.minutes, 0);

    const newHabitData = {
      ...habitData,
      todayMinutes,
      lifetimeMinutes: habitData.lifetimeMinutes + actualMinutes,
      weeklyMinutes: habitData.weeklyMinutes + actualMinutes,
      history: newHistory
    };

    saveHabitData(newHabitData);

    // Sync to cloud if logged in
    syncToCloud(newHabitData, audioMode);

    // Stop binaural architecture if active
    audioEngine.stopBinauralArchitecture();

    setAppState('complete');
    setTimeout(() => setAppState('idle'), 2000);
  }, [habitData, saveHabitData, syncToCloud, audioMode]);

  // Session timer - uses real timestamps to survive screen sleep
  useEffect(() => {
    if (appState !== 'session') return;

    const duration = DURATIONS[durationIndex];
    if (duration === Infinity) return; // No timer for infinite sessions

    const sessionDurationMs = duration * 60 * 1000;
    const endTime = sessionStartRef.current + sessionDurationMs;
    let hasFaded = false;

    const updateTimer = () => {
      const now = Date.now();
      const remainingMs = Math.max(0, endTime - now);
      const remainingSecs = Math.ceil(remainingMs / 1000);
      setRemainingSeconds(remainingSecs);

      // Smart fade 60 seconds before end
      if (remainingSecs <= 60 && remainingSecs > 0 && !hasFaded) {
        hasFaded = true;
        audioEngine.smartFade();
      }

      // Session complete
      if (remainingMs <= 0) {
        if (sessionTimerRef.current) clearInterval(sessionTimerRef.current);
        const elapsedMinutes = Math.floor((now - sessionStartRef.current) / 60000);
        // Play completion chime
        audioEngine.playCompletionChime();
        handleSessionEnd(Math.max(1, elapsedMinutes));
      }
    };

    // Update immediately, then every second
    updateTimer();
    sessionTimerRef.current = window.setInterval(updateTimer, 1000);

    return () => {
      if (sessionTimerRef.current) {
        clearInterval(sessionTimerRef.current);
      }
    };
  }, [appState, durationIndex, handleSessionEnd]);

  // Tap to end session early
  const handleSessionTap = useCallback(() => {
    if (appState !== 'session') return;

    if (sessionTimerRef.current) {
      clearInterval(sessionTimerRef.current);
    }

    // Calculate precise elapsed time in minutes
    const elapsedMs = Date.now() - sessionStartRef.current;
    const elapsedMinutes = Math.floor(elapsedMs / 60000); // Round down to actual completed minutes
    handleSessionEnd(Math.max(0, elapsedMinutes));
  }, [appState, handleSessionEnd]);

  // Format time display
  const formatDuration = (minutes: number): string => {
    if (minutes === Infinity) return '∞';
    if (minutes >= 60) return `${Math.floor(minutes / 60)}h`;
    return `${minutes}m`;
  };

  const formatTimer = (seconds: number): string => {
    if (seconds === Infinity) return '∞';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const orbitIntensity = habitData.dailyGoal > 0
    ? Math.min(1, habitData.todayMinutes / habitData.dailyGoal)
    : 0;

  const currentDuration = DURATIONS[durationIndex];

  // Handle touch start for pull-down gesture
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    if (appState !== 'idle') return;
    touchStartY.current = e.touches[0].clientY;
  }, [appState]);

  // Handle touch move for pull-down gesture
  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    if (appState !== 'idle' || isDragging) return;
    const currentY = e.touches[0].clientY;
    const deltaY = currentY - touchStartY.current;

    // Only respond to swipe down from top 100px of screen
    if (touchStartY.current < 100 && deltaY > 0) {
      const progress = Math.min(1, deltaY / 150);
      setStatsPullProgress(progress);
      if (progress > 0.5) {
        setShowStats(true);
      }
    }
  }, [appState, isDragging]);

  // Handle touch end
  const handleTouchEnd = useCallback(() => {
    if (statsPullProgress > 0.5) {
      setShowStats(true);
    }
    setStatsPullProgress(0);
  }, [statsPullProgress]);

  // Format hours for display
  const formatHours = (minutes: number): string => {
    if (minutes < 60) return `${minutes}m`;
    const hrs = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hrs}h ${mins}m` : `${hrs}h`;
  };
  // Toggle space theme
  const toggleSpaceTheme = useCallback(() => {
    setSpaceTheme(prev => {
      const newValue = !prev;
      localStorage.setItem('zyndio-space-theme', String(newValue));
      return newValue;
    });
  }, []);

  // Toggle DeepSync binaural beats
  const toggleDeepSync = useCallback(async () => {
    const newValue = !deepSyncActive;
    setDeepSyncActive(newValue);
    localStorage.setItem('zyndio-deepsync', String(newValue));

    if (newValue) {
      // AUDIO CONFLICT GUARD: Stop Binaural Architecture when enabling DeepSync
      // Only one binaural system should be active at a time
      if (audioEngine.isArchitectureActive()) {
        await audioEngine.stopBinauralArchitecture();
      }
      await audioEngine.startDeepSync();
    } else {
      await audioEngine.stopDeepSync();
    }
  }, [deepSyncActive]);

  // Neutralize Mode - Emergency calming with 4-7-8 breathing
  const startNeutralizeMode = useCallback(async () => {
    if (neutralizeActive) return;

    setNeutralizeActive(true);
    setBreathPhase('inhale');

    // Start audio
    await audioEngine.startNeutralizeMode();

    // 4-7-8 breathing cycle: 4s inhale, 7s hold, 8s exhale = 19s total
    const runBreathCycle = () => {
      // Inhale (4s)
      setBreathPhase('inhale');

      breathTimerRef.current = window.setTimeout(() => {
        // Hold (7s)
        setBreathPhase('hold');

        breathTimerRef.current = window.setTimeout(() => {
          // Exhale (8s)
          setBreathPhase('exhale');

          breathTimerRef.current = window.setTimeout(() => {
            // Loop back to inhale
            runBreathCycle();
          }, 8000);
        }, 7000);
      }, 4000);
    };

    runBreathCycle();
  }, [neutralizeActive]);

  const stopNeutralizeMode = useCallback(async () => {
    if (!neutralizeActive) return;

    // Clear breathing timer
    if (breathTimerRef.current) {
      clearTimeout(breathTimerRef.current);
      breathTimerRef.current = null;
    }

    setBreathPhase('idle');
    setNeutralizeActive(false);

    // Stop audio
    await audioEngine.stopNeutralizeMode();
  }, [neutralizeActive]);

  return (
    <div
      className={`app ${spaceTheme ? 'space-theme' : ''}`}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >

      {/* Starfield background */}
      {spaceTheme && (
        <div className="starfield">
          <div className="stars stars-1" />
          <div className="stars stars-2" />
          <div className="stars stars-3" />
        </div>
      )}

      {/* Welcome Screen */}
      {!hasSeenWelcome && !user && (
        <div className="welcome-screen">
          <div className="welcome-content">
            <img
              src="/logo.png"
              alt="Zyndio Space"
              className="welcome-logo-img"
            />
            <p className="welcome-tagline">Your digital sanctuary</p>

            <div className="welcome-actions">
              <button
                className="welcome-button primary"
                onClick={signInWithGoogle}
                disabled={authLoading}
              >
                {authLoading ? 'Loading...' : 'Sign in with Google'}
              </button>
              <button
                className="welcome-button secondary"
                onClick={() => {
                  // Track guest login - fire and forget
                  supabase.from('guest_logins').insert({}).then(({ error }) => {
                    if (error) console.error('Failed to track guest login:', error);
                  });

                  localStorage.setItem('zyndio-seen-welcome', 'true');
                  setHasSeenWelcome(true);
                }}
              >
                Continue as guest
              </button>
            </div>

            <p className="welcome-note">
              Sign in to sync your meditation progress across devices
            </p>
          </div>
        </div>
      )}

      {/* Space theme toggle */}


      {/* Function Menu - Top left expandable menu */}
      {appState === 'idle' && !neutralizeActive && !isScanning && (
        <div className={`function-menu ${menuExpanded ? 'expanded' : ''}`}>
          <button
            className="function-menu-trigger"
            onClick={() => setMenuExpanded(!menuExpanded)}
            aria-label="Toggle function menu"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
              {menuExpanded ? (
                <path d="M18 6L6 18M6 6l12 12" strokeLinecap="round" strokeLinejoin="round" />
              ) : (
                <>
                  <circle cx="12" cy="5" r="1.5" fill="currentColor" />
                  <circle cx="12" cy="12" r="1.5" fill="currentColor" />
                  <circle cx="12" cy="19" r="1.5" fill="currentColor" />
                </>
              )}
            </svg>
          </button>

          {menuExpanded && (
            <div className="function-menu-items">
              {/* Bioscan */}
              <button
                className="function-menu-item bioscan"
                onClick={() => {
                  setMenuExpanded(false);
                  handleBioscan();
                }}
                aria-label="Scan vitals"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M5 12h3l2-3 3 6 2-3h4" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <span>Bioscan</span>
              </button>

              {/* Neutralize */}
              <button
                className="function-menu-item neutralize"
                onClick={() => {
                  setMenuExpanded(false);
                  startNeutralizeMode();
                }}
                aria-label="Activate Neutralize Mode"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" strokeLinecap="round" strokeLinejoin="round" />
                  <path d="M12 8v4" strokeLinecap="round" />
                  <circle cx="12" cy="16" r="1" fill="currentColor" />
                </svg>
                <span>Neutralize</span>
              </button>

              {/* Space Theme Toggle */}
              <button
                className={`function-menu-item space-theme-item ${spaceTheme ? 'active' : ''}`}
                onClick={() => {
                  setMenuExpanded(false);
                  toggleSpaceTheme();
                }}
                aria-label="Toggle space theme"
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                  <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <span>{spaceTheme ? 'Stars On' : 'Stars Off'}</span>
              </button>
            </div>
          )}
        </div>
      )}

      {/* Neutralize Mode Overlay */}
      {neutralizeActive && (
        <div className="neutralize-overlay" onClick={stopNeutralizeMode}>
          <div className={`neutralize-breathing-ring ${breathPhase}`} />
          <div className="neutralize-phase-text">
            {breathPhase === 'inhale' && 'Breathe In'}
            {breathPhase === 'hold' && 'Hold'}
            {breathPhase === 'exhale' && 'Breathe Out'}
          </div>
          <div className="neutralize-hint">Tap anywhere to exit</div>
        </div>
      )}

      {/* DeepSync toggle - Binaural beats for thought reduction */}
      {appState === 'session' && (
        <button
          className={`deepsync-toggle ${deepSyncActive ? 'active' : ''}`}
          onClick={toggleDeepSync}
          aria-label="Toggle DeepSync binaural beats"
          title="DeepSync: Theta waves to quiet mental chatter (use headphones)"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M9.5 4C5.36 4 2 7.36 2 11.5c0 2.54 1.26 4.78 3.19 6.14" strokeLinecap="round" />
            <path d="M14.5 4c4.14 0 7.5 3.36 7.5 7.5 0 2.54-1.26 4.78-3.19 6.14" strokeLinecap="round" />
            <path d="M8 8.5c-1.5 1-2.5 2.7-2.5 4.5 0 1.5.7 2.8 1.7 3.7" strokeLinecap="round" />
            <path d="M16 8.5c1.5 1 2.5 2.7 2.5 4.5 0 1.5-.7 2.8-1.7 3.7" strokeLinecap="round" />
            <circle cx="12" cy="13" r="2" />
            <path d="M12 15v5" strokeLinecap="round" />
          </svg>
        </button>
      )}

      {/* Idle State - The Chronometer */}
      <div
        className={`chronometer-container ${appState !== 'idle' ? 'dissolving' : ''}`}
        style={{
          opacity: appState === 'idle' ? 1 : 0,
          pointerEvents: appState === 'idle' ? 'auto' : 'none'
        }}
      >
        {/* The Orbit */}
        <div className={`orbit ${orbitIntensity > 0 ? 'active' : ''}`}>
          <div className="orbit-ring" />
          <div
            className="orbit-glow"
            style={{
              opacity: orbitIntensity * 0.6,
              filter: `blur(${20 + orbitIntensity * 10}px)`
            }}
          />
        </div>

        {/* The Dial */}
        <div
          ref={dialRef}
          className="chronometer"
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
        >
          <div
            className={`chronometer-dial ${isDragging ? 'active' : ''}`}
            style={{
              transform: `rotate(${rotation}deg)`,
              transition: isDragging ? 'none' : 'box-shadow 0.3s'
            }}
          />

          <div className="chronometer-time">
            <span className="chronometer-duration">{formatDuration(currentDuration)}</span>
            <span className="chronometer-label">
              {isDragging ? 'Release to begin' : 'Wind to set'}
            </span>
          </div>
        </div>
      </div>

      {/* Mode Selector - Swipeable Liquid Glass */}
      {appState === 'idle' && (
        <div
          className="mode-indicator"
          onTouchStart={(e) => {
            modeSwipeStartX.current = e.touches[0].clientX;
            modeSwipeStartY.current = e.touches[0].clientY;
          }}
          onTouchEnd={(e) => {
            const deltaX = e.changedTouches[0].clientX - modeSwipeStartX.current;
            const deltaY = Math.abs(e.changedTouches[0].clientY - modeSwipeStartY.current);
            const modes: AudioMode[] = ['void', 'flow', 'focus'];
            const currentIndex = modes.indexOf(audioMode);

            // Only trigger if horizontal swipe (not vertical)
            if (Math.abs(deltaX) > 40 && deltaY < 50) {
              if (deltaX > 0 && currentIndex > 0) {
                // Swipe right = previous mode
                setAudioMode(modes[currentIndex - 1]);
                if (navigator.vibrate) navigator.vibrate(10);
              } else if (deltaX < 0 && currentIndex < modes.length - 1) {
                // Swipe left = next mode
                setAudioMode(modes[currentIndex + 1]);
                if (navigator.vibrate) navigator.vibrate(10);
              }
            }
          }}
        >
          <div className="mode-glass-bg" />
          <div className="mode-options">
            <div
              className="mode-active-pill"
              style={{ '--active-index': (['void', 'flow', 'focus'] as AudioMode[]).indexOf(audioMode) } as React.CSSProperties}
            />
            {(['void', 'flow', 'focus'] as AudioMode[]).map((mode) => (
              <button
                key={mode}
                className={`mode-option ${audioMode === mode ? 'active' : ''}`}
                onClick={() => {
                  setAudioMode(mode);
                  if (navigator.vibrate) navigator.vibrate(10);
                }}
              >
                {mode === 'void' ? 'Silence' : mode === 'flow' ? 'Ambient' : 'Focus'}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Bioscan overlay */}
      {isScanning && (
        <div className="bioscan-overlay">
          <div className="bioscan-ring" style={{ '--progress': scanProgress } as React.CSSProperties}>
            <div className="bioscan-pulse" />
          </div>
          <div className="bioscan-status">Analyzing...</div>
        </div>
      )}

      {/* AI Message announcement */}
      {aiMessage && !isScanning && (
        <div className="ai-message">
          <div className="ai-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
              <circle cx="12" cy="12" r="10" />
              <path d="M12 6v6l4 2" strokeLinecap="round" />
            </svg>
          </div>
          <p>{aiMessage}</p>
        </div>
      )}

      {/* Session View */}
      <div
        className={`session-view ${appState === 'session' ? 'active' : ''}`}
        onClick={handleSessionTap}
      >
        <div className="breathing-circle" />
        <div className="session-timer">
          {formatTimer(remainingSeconds)}
        </div>
        <div className="session-mode">
          {audioMode === 'void' ? 'Silence' : audioMode === 'flow' ? 'Ambient' : 'Focus'}
        </div>
      </div>

      {/* Binaural Architecture Slider - Right edge during session */}
      {appState === 'session' && (
        <div
          className={`brainwave-slider-container ${isSliderDragging ? 'active' : ''}`}
          ref={sliderRef}
          onPointerDown={(e) => {
            setIsSliderDragging(true);
            (e.target as HTMLElement).setPointerCapture(e.pointerId);

            // AUDIO CONFLICT GUARD: Disable DeepSync when using Binaural Architecture
            // Only one binaural system should be active at a time
            if (deepSyncActive) {
              audioEngine.stopDeepSync();
              setDeepSyncActive(false);
              localStorage.setItem('zyndio-deepsync', 'false');
            }

            // Start architecture if not playing
            if (!audioEngine.isArchitectureActive()) {
              audioEngine.startBinauralArchitecture();
            }

            // Calculate position from pointer
            const rect = sliderRef.current?.getBoundingClientRect();
            if (rect) {
              const y = e.clientY - rect.top;
              const position = 1 - Math.max(0, Math.min(1, y / rect.height));
              setBrainwavePosition(position);
              audioEngine.setBrainwaveTarget(position);
            }
          }}
          onPointerMove={(e) => {
            if (!isSliderDragging) return;
            const rect = sliderRef.current?.getBoundingClientRect();
            if (rect) {
              const y = e.clientY - rect.top;
              const position = 1 - Math.max(0, Math.min(1, y / rect.height));
              setBrainwavePosition(position);
              audioEngine.setBrainwaveTarget(position);
            }
          }}
          onPointerUp={(e) => {
            setIsSliderDragging(false);
            (e.target as HTMLElement).releasePointerCapture(e.pointerId);
          }}
          onPointerCancel={() => setIsSliderDragging(false)}
        >
          <div className="brainwave-track">
            <div className="brainwave-labels">
              <span className="brainwave-label">γ<small>focus</small></span>
              <span className="brainwave-label">β<small>alert</small></span>
              <span className="brainwave-label">α<small>flow</small></span>
              <span className="brainwave-label">θ<small>calm</small></span>
              <span className="brainwave-label">δ<small>rest</small></span>
            </div>
            <div className="brainwave-fill" style={{ height: `${brainwavePosition * 100}%` }} />
            <div
              className={`brainwave-thumb ${isSliderDragging ? 'dragging' : ''}`}
              style={{ bottom: `${brainwavePosition * 100}%` }}
            />
          </div>
        </div>
      )}

      {/* Pull handle indicator at top - clickable for desktop */}
      {appState === 'idle' && (
        <div
          className="pull-handle"
          style={{ opacity: showStats ? 0 : 0.6, cursor: 'pointer' }}
          onClick={() => setShowStats(true)}
        >
          <div className="pull-handle-bar" />
        </div>
      )}

      {/* Overlay to block clicks when stats panel is open */}
      {showStats && (
        <div
          className="stats-overlay"
          onClick={() => setShowStats(false)}
        />
      )}

      {/* Stats Panel - slides from top */}
      <div
        className={`stats-panel ${showStats ? 'active' : ''}`}
        style={{ transform: showStats ? 'translateY(0)' : `translateY(${-100 + statsPullProgress * 100}%)` }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="stats-content">
          <div className="stat-row">
            <div className="stat-item">
              <div className="stat-value">{habitData.currentStreak}</div>
              <div className="stat-label">Day Streak</div>
            </div>
            <div className="stat-item">
              <div className="stat-value">{habitData.todayMinutes}</div>
              <div className="stat-label">Minutes Today</div>
            </div>
          </div>
          <div className="stat-row">
            <div className="stat-item">
              <div className="stat-value">{formatHours(habitData.weeklyMinutes)}</div>
              <div className="stat-label">This Week</div>
            </div>
            <div className="stat-item">
              <div className="stat-value">{formatHours(habitData.lifetimeMinutes)}</div>
              <div className="stat-label">All Time</div>
            </div>
          </div>

          {/* Auth section */}
          <div className="auth-section" onClick={(e) => e.stopPropagation()}>
            {authLoading ? (
              <div className="auth-loading">Loading...</div>
            ) : user ? (
              <div className="auth-user">
                <span className="auth-email">{user.email}</span>
                <button className="auth-button signout" onClick={signOut}>
                  Sign Out
                </button>
              </div>
            ) : (
              <button className="auth-button signin" onClick={signInWithGoogle}>
                Sign in with Google
              </button>
            )}
          </div>

          <div className="stats-close-hint">Tap to close</div>
        </div>
      </div>

      {/* First-time hint */}
      {appState === 'idle' && !showStats && habitData.lifetimeMinutes === 0 && (
        <div className="tap-hint">Pull down for stats</div>
      )}


    </div>
  );
}

export default App;
