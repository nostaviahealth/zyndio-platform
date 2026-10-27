import React from 'react';
import { Users, LogOut } from 'lucide-react';
import FictionalDataTag from '../../components/ui/FictionalDataTag';

interface PreviewShellProps {
  mode: 'light' | 'dark';
  children: React.ReactNode;
}

// Preview-only app shell (TC-011 Ava H1): the /__preview harness renders
// pages standalone, so Ava's screenshots were missing the C41 sidebar
// entirely. This mirrors components/admin-shell/Sidebar.tsx's structure
// with a hardcoded, fictional signed-in user (Taylor Brooks, Admin) - no
// usePortalAuth/router wiring, since this is fixture-only screenshot chrome.
const PreviewShell: React.FC<PreviewShellProps> = ({ mode, children }) => {
  const isDark = mode === 'dark';
  const navSurface = isDark ? 'border-slate-800 bg-[#0B0F1A]' : 'border-slate-200 bg-white';
  const textPrimary = isDark ? 'text-white' : 'text-[#030616]';
  const textSecondary = isDark ? 'text-slate-400' : 'text-slate-500';
  const badgeBorder = isDark ? 'border-slate-600 text-slate-400' : 'border-slate-400 text-slate-500';
  const navActive = isDark ? 'bg-[#1E2A6B] text-[#8FB0FF]' : 'bg-[#E8EDFD] text-[#2C5CF2]';
  const footerBorder = isDark ? 'border-slate-800' : 'border-slate-100';

  return (
    <div className={`flex min-h-screen ${isDark ? 'bg-[#030616]' : 'bg-[#F2F4F7]'}`}>
      <nav aria-label="Main" className={`flex h-screen w-[264px] shrink-0 flex-col border-r ${navSurface}`}>
        <div className="px-6 py-4">
          <div className="flex items-center gap-2">
            <span className={`text-base font-bold tracking-[0.06em] ${textPrimary}`}>ZYNDIO</span>
            <span
              className={`rounded border border-dashed px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide ${badgeBorder}`}
            >
              Placeholder
            </span>
          </div>
          <p className={`mt-1 text-[11px] font-medium uppercase tracking-[0.2em] ${textSecondary}`}>Care Portal</p>
        </div>

        <div className="flex-1 space-y-1 px-3">
          <span className={`flex min-h-[44px] items-center gap-3 rounded-[10px] px-3 text-sm font-medium ${navActive}`}>
            <Users className="h-4 w-4" aria-hidden="true" />
            Users and roles
          </span>
        </div>

        <div className={`flex items-center gap-3 border-t px-4 py-4 ${footerBorder}`}>
          <div className={`flex h-10 w-10 items-center justify-center rounded-full text-sm font-semibold ${navActive}`}>
            TB
          </div>
          <div className="min-w-0 flex-1">
            <p className={`truncate text-sm font-semibold ${textPrimary}`}>Taylor Brooks</p>
            <p className={`truncate text-xs ${textSecondary}`}>Admin</p>
          </div>
          <span aria-label="Sign out" className={`flex h-11 w-11 items-center justify-center rounded-full ${textSecondary}`}>
            <LogOut className="h-4 w-4" aria-hidden="true" />
          </span>
        </div>
      </nav>

      <main className="relative flex-1 px-10 py-8" style={isDark ? { color: '#F2F4F7' } : undefined}>
        <FictionalDataTag />
        {children}
      </main>
    </div>
  );
};

export default PreviewShell;
