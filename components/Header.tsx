import React, { useState, useEffect, useRef } from 'react';
import { Bell, MessageSquare, Search, X, CheckCircle2, AlertCircle, Sparkles, FileText, Clock } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useUser } from '../contexts/UserContext';
import { isLegacyPatientScreensEnabled } from '../lib/featureFlags';

interface HeaderProps {
  title: string;
}

interface Notification {
  id: string;
  type: 'success' | 'info' | 'warning';
  title: string;
  message: string;
  time: string;
  read: boolean;
  action?: string;
}

const Header: React.FC<HeaderProps> = ({ title }) => {
  const navigate = useNavigate();
  const { publishedIntelligence, publishedJourney, hasAnyPublishedContent, patientProfile } = useUser();
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Generate dynamic notifications based on user state
  useEffect(() => {
    const newNotifications: Notification[] = [];

    // Check if intelligence is published
    if (publishedIntelligence?.published) {
      newNotifications.push({
        id: 'intel-ready',
        type: 'success',
        title: 'Intelligence Ready',
        message: 'Your health intelligence analysis has been published and is ready to view.',
        time: 'Just now',
        read: false,
        action: '/intelligence'
      });
    }

    // Check if protocol is published
    if (hasAnyPublishedContent()) {
      newNotifications.push({
        id: 'protocol-ready',
        type: 'success',
        title: 'Protocol Published',
        message: 'Your personalized health protocol is ready. Start your wellness journey!',
        time: 'Just now',
        read: false,
        action: '/protocol'
      });
    }

    // Check if still waiting for data
    if (!publishedIntelligence?.published) {
      newNotifications.push({
        id: 'intel-pending',
        type: 'info',
        title: 'Analysis In Progress',
        message: 'Our wellness experts are preparing your health intelligence. Check back soon!',
        time: '1h ago',
        read: true
      });
    }

    // Welcome notification
    if (patientProfile?.stage === 'profile_creation') {
      const legacyScreensOn = isLegacyPatientScreensEnabled();
      newNotifications.push({
        id: 'welcome',
        type: 'info',
        title: 'Welcome to Zyndio',
        // TC-030 (11): the questionnaire copy only makes sense while the legacy
        // screen exists and this notification links to it. With the flag off it
        // has no action, so keep the copy neutral (no dead "complete your
        // questionnaire" call to action).
        message: legacyScreensOn
          ? 'Complete your health questionnaire to get started with your personalized journey.'
          : 'Welcome aboard. Your care team will guide you through the next steps of your personalized journey.',
        time: '2h ago',
        read: true,
        // TC-026: link to the questionnaire only while the legacy screen exists.
        ...(legacyScreensOn ? { action: '/questionnaire' } : {}),
      });
    }

    setNotifications(newNotifications);
  }, [publishedIntelligence, publishedJourney, hasAnyPublishedContent, patientProfile]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowNotifications(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const unreadCount = notifications.filter(n => !n.read).length;

  const handleNotificationClick = (notif: Notification) => {
    // Mark as read
    setNotifications(prev =>
      prev.map(n => n.id === notif.id ? { ...n, read: true } : n)
    );
    // Navigate if action exists
    if (notif.action) {
      setShowNotifications(false);
      navigate(notif.action);
    }
  };

  const markAllAsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'success': return <CheckCircle2 className="w-5 h-5 text-emerald-500" />;
      case 'warning': return <AlertCircle className="w-5 h-5 text-amber-500" />;
      default: return <Sparkles className="w-5 h-5 text-blue-500" />;
    }
  };

  return (
    <header className="h-16 bg-white/80 backdrop-blur-md border-b border-slate-200 flex items-center justify-between px-4 md:px-8 sticky top-0 z-20">
      <div className="flex items-center gap-3 md:gap-6">
        {/* Title removed to avoid duplication with page headings */}
      </div>

      <div className="flex items-center gap-3 md:gap-6">
        <div className="hidden md:flex items-center bg-slate-100 px-3 py-2 rounded-full border border-slate-200">
          <Search className="w-4 h-4 text-slate-400 mr-2" />
          <input
            type="text"
            placeholder="Search biomarkers..."
            className="bg-transparent border-none outline-none text-sm text-slate-700 w-48 placeholder-slate-400"
          />
        </div>

        {/* Notification Bell */}
        <div className="relative" ref={dropdownRef}>
          <button
            onClick={() => setShowNotifications(!showNotifications)}
            className="relative p-2 text-slate-500 hover:text-brand-dark hover:bg-slate-100 rounded-full transition-colors"
          >
            <Bell className="w-5 h-5" />
            {unreadCount > 0 && (
              <span className="absolute top-1 right-1 w-2.5 h-2.5 bg-red-500 rounded-full border-2 border-white"></span>
            )}
          </button>

          {/* Notifications Dropdown */}
          {showNotifications && (
            <div className="absolute right-0 top-full mt-2 w-80 md:w-96 bg-white border border-slate-200 rounded-2xl shadow-2xl shadow-slate-900/10 overflow-hidden z-50">
              <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-gradient-to-r from-slate-50 to-white">
                <div>
                  <h3 className="font-bold text-slate-900">Notifications</h3>
                  <p className="text-xs text-slate-500">{unreadCount} unread</p>
                </div>
                {unreadCount > 0 && (
                  <button
                    onClick={markAllAsRead}
                    className="text-xs text-brand-dark hover:underline font-medium"
                  >
                    Mark all read
                  </button>
                )}
              </div>

              <div className="max-h-80 overflow-y-auto">
                {notifications.length > 0 ? (
                  notifications.map((notif) => {
                    // TC-030 (11): a notification with no action does nothing
                    // when clicked, so it must not look tappable - drop the
                    // pointer cursor, hover highlight and button role.
                    const isClickable = !!notif.action;
                    return (
                    <div
                      key={notif.id}
                      onClick={isClickable ? () => handleNotificationClick(notif) : undefined}
                      role={isClickable ? 'button' : undefined}
                      className={`p-4 border-b border-slate-100 transition-colors flex gap-3 ${isClickable ? 'hover:bg-slate-50 cursor-pointer' : ''} ${!notif.read ? 'bg-blue-50/50' : ''
                        }`}
                    >
                      <div className="flex-shrink-0 mt-0.5">
                        {getIcon(notif.type)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className={`text-sm ${!notif.read ? 'font-semibold text-slate-900' : 'font-medium text-slate-700'}`}>
                          {notif.title}
                        </p>
                        <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">{notif.message}</p>
                        <div className="flex items-center gap-2 mt-1.5">
                          <Clock className="w-3 h-3 text-slate-400" />
                          <span className="text-xs text-slate-400">{notif.time}</span>
                        </div>
                      </div>
                      {!notif.read && (
                        <div className="w-2 h-2 bg-blue-500 rounded-full flex-shrink-0 mt-2"></div>
                      )}
                    </div>
                    );
                  })
                ) : (
                  <div className="p-8 text-center">
                    <Bell className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                    <p className="text-slate-500 text-sm">No notifications yet</p>
                  </div>
                )}
              </div>

              <div className="p-3 text-center border-t border-slate-100 bg-slate-50">
                <button
                  onClick={() => {
                    setShowNotifications(false);
                    navigate('/settings');
                  }}
                  className="text-sm text-slate-600 hover:text-brand-dark font-medium"
                >
                  Notification Settings
                </button>
              </div>
            </div>
          )}
        </div>

        <button
          onClick={() => navigate('/concierge')}
          className="flex items-center gap-2 bg-brand-dark text-white px-3 py-2 md:px-4 md:py-2 rounded-full text-sm font-medium hover:bg-slate-800 transition-colors shadow-lg shadow-slate-200"
        >
          <MessageSquare className="w-4 h-4" />
          <span className="hidden md:inline">Ask Concierge</span>
        </button>
      </div>
    </header>
  );
};

export default Header;