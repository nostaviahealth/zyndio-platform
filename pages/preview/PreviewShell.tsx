import React from 'react';
import { Users, LogOut, ClipboardList, ListChecks } from 'lucide-react';
import FictionalDataTag from '../../components/ui/FictionalDataTag';

interface PreviewShellProps {
  mode: 'light' | 'dark';
  children: React.ReactNode;
  // 'admin' keeps the TC-013/014 users-roles chrome (Taylor Brooks, Admin).
  // 'clinical' renders the physician chrome (Patients active, Review queue 7,
  // Dr. Morgan Ellis) and a responsive 96 rail below 1280 (specs responsive
  // frame). The clinical pages render their own FICTIONAL DATA tag, so the
  // shell skips it there (showFictionalTag=false).
  variant?: 'admin' | 'clinical';
  showFictionalTag?: boolean;
}

// Preview-only app shell (TC-011 Ava H1): the /__preview harness renders
// pages standalone, so screenshots would otherwise miss the C41 sidebar.
// Fixture-only chrome (no usePortalAuth/router wiring).
const PreviewShell: React.FC<PreviewShellProps> = ({
  mode,
  children,
  variant = 'admin',
  showFictionalTag = true,
}) => {
  const isDark = mode === 'dark';
  const navSurface = isDark ? 'border-slate-800 bg-[#0B0F19]' : 'border-slate-200 bg-white';
  const textPrimary = isDark ? 'text-[#EEF1F8]' : 'text-[#030616]';
  const textSecondary = isDark ? 'text-[#A6B0C3]' : 'text-slate-500';
  const badgeBorder = isDark ? 'border-[#6C7690] text-[#A6B0C3]' : 'border-slate-400 text-slate-500';
  const navActive = isDark ? 'bg-[#18224A] text-[#AFC3FF]' : 'bg-[#E8EDFD] text-[#2C5CF2]';
  const navIdle = isDark ? 'text-[#A6B0C3]' : 'text-slate-700';
  const footerBorder = isDark ? 'border-slate-800' : 'border-slate-100';
  const clinical = variant === 'clinical';

  const account = clinical
    ? { initials: 'ME', name: 'Dr. Morgan Ellis', role: 'Physician' }
    : { initials: 'TB', name: 'Taylor Brooks', role: 'Admin' };

  const railWidth = clinical ? 'w-24 xl:w-[264px]' : 'w-[264px]';

  return (
    <div
      className={`flex min-h-screen ${isDark ? 'dark bg-[#070A14] [color-scheme:dark]' : 'bg-[#F1F4FC] [color-scheme:light]'}`}
      data-preview-theme={mode}
    >
      <nav aria-label="Main" className={`flex h-screen ${railWidth} shrink-0 flex-col border-r ${navSurface}`}>
        <div className={clinical ? 'px-3 py-4 xl:px-6' : 'px-6 py-4'}>
          <div className={`flex items-center gap-2 ${clinical ? 'justify-center xl:justify-start' : ''}`}>
            <span className={`text-base font-bold tracking-[0.06em] ${textPrimary}`}>ZYNDIO</span>
            <span
              className={`rounded border border-dashed px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide ${badgeBorder} ${clinical ? 'hidden xl:inline' : ''}`}
            >
              Placeholder
            </span>
          </div>
          <p className={`mt-1 text-[11px] font-medium uppercase tracking-[0.2em] ${textSecondary} ${clinical ? 'hidden xl:block' : ''}`}>
            Care Portal
          </p>
        </div>

        <div className={`flex-1 space-y-1 ${clinical ? 'px-2 xl:px-3' : 'px-3'}`}>
          {clinical ? (
            <>
              <NavItem icon={<ClipboardList className="h-4 w-4" aria-hidden="true" />} label="Patients" active activeClass={navActive} idleClass={navIdle} />
              <NavItem
                icon={<ListChecks className="h-4 w-4" aria-hidden="true" />}
                label="Review queue"
                badge="7"
                badgeLabel="7 waiting"
                idleClass={navIdle}
              />
            </>
          ) : (
            <span className={`flex min-h-[44px] items-center gap-3 rounded-[10px] px-3 text-sm font-medium ${navActive}`}>
              <Users className="h-4 w-4" aria-hidden="true" />
              Users and roles
            </span>
          )}
        </div>

        <div className={`flex items-center gap-3 border-t px-4 py-4 ${footerBorder} ${clinical ? 'flex-col xl:flex-row' : ''}`}>
          <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold ${navActive}`}>
            {account.initials}
          </div>
          <div className={`min-w-0 flex-1 ${clinical ? 'hidden xl:block' : ''}`}>
            <p className={`truncate text-sm font-semibold ${textPrimary}`}>{account.name}</p>
            <p className={`truncate text-xs ${textSecondary}`}>{account.role}</p>
          </div>
          <span aria-label="Sign out" className={`flex h-11 w-11 items-center justify-center rounded-full ${textSecondary}`}>
            <LogOut className="h-4 w-4" aria-hidden="true" />
          </span>
        </div>
      </nav>

      <main className={`relative flex-1 ${clinical ? 'px-6 py-8 xl:px-10' : 'px-10 py-8'}`}>
        {showFictionalTag && <FictionalDataTag />}
        {children}
      </main>
    </div>
  );
};

const NavItem: React.FC<{
  icon: React.ReactNode;
  label: string;
  active?: boolean;
  badge?: string;
  badgeLabel?: string;
  activeClass?: string;
  idleClass: string;
}> = ({ icon, label, active, badge, badgeLabel, activeClass = '', idleClass }) => (
  <span
    className={`flex min-h-[44px] flex-col items-center gap-1 rounded-[10px] px-2 py-2 text-[11px] font-medium xl:flex-row xl:gap-3 xl:px-3 xl:text-sm ${
      active ? activeClass : idleClass
    }`}
  >
    {icon}
    <span className="xl:flex-1">{label}</span>
    {badge && (
      <span
        aria-label={badgeLabel}
        className="rounded-full bg-[#2C5CF2] px-1.5 py-0.5 text-[10px] font-semibold text-white xl:text-xs"
      >
        {badge}
      </span>
    )}
  </span>
);

export default PreviewShell;
