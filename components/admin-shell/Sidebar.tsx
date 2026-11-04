import React from 'react';
import { NavLink } from 'react-router-dom';
import { Users, ClipboardList, LogOut, Plug } from 'lucide-react';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import { FOCUS_RING_ON_SUNKEN_CLASS } from '../ui/focusRing';

const ROLE_LABELS: Record<string, string> = {
  org_admin: 'Admin',
  physician: 'Physician',
  care_coordinator: 'Care coordinator',
  read_only: 'Read-only',
};

// C41: 264 wide, role-conditional nav. Admins only ever see "Users and
// roles" and (PP-03) "Integrations" (least privilege, Henry: "admins manage
// users only" - integrations are credentials, not clinical data); clinical
// roles only ever see "Patients".
const Sidebar: React.FC = () => {
  const { role, email, signOut } = usePortalAuth();
  const isOrgAdmin = role === 'org_admin';

  const navItemClass = ({ isActive }: { isActive: boolean }) =>
    `flex min-h-[44px] items-center gap-3 rounded-[10px] px-3 text-sm font-medium transition-colors ${FOCUS_RING_ON_SUNKEN_CLASS} ${
      isActive
        ? 'bg-[#E8EDFD] text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]'
        : 'text-slate-700 hover:bg-slate-50 dark:text-[#A6B0C3] dark:hover:bg-[#18224A]'
    }`;

  // TC-021 item 14: sticky + full viewport height, so the sidebar surface
  // still fills the screen when a long page (users at 1024) is scrolled.
  return (
    <nav
      aria-label="Main"
      className="sticky top-0 flex h-screen w-[264px] shrink-0 flex-col border-r border-slate-200 bg-white dark:border-slate-800 dark:bg-[#0B0F19]"
    >
      <div className="px-6 py-4">
        <div className="flex items-center gap-2">
          <span className="text-base font-bold tracking-[0.06em] text-[#030616] dark:text-[#EEF1F8]">ZYNDIO</span>
          <span className="rounded border border-dashed border-slate-400 px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-slate-500 dark:border-[#6C7690] dark:text-[#A6B0C3]">
            Placeholder
          </span>
        </div>
        <p className="mt-1 text-[11px] font-medium uppercase tracking-[0.2em] text-[#48556A] dark:text-[#A6B0C3]">Care Portal</p>
      </div>

      <div className="flex-1 space-y-1 px-3">
        {isOrgAdmin ? (
          <>
            <NavLink to="/admin/users" className={navItemClass} end>
              <Users className="h-4 w-4" aria-hidden="true" />
              Users and roles
            </NavLink>
            <NavLink to="/admin/integrations" className={navItemClass} end>
              <Plug className="h-4 w-4" aria-hidden="true" />
              Integrations
            </NavLink>
          </>
        ) : (
          <NavLink to="/admin/patients" className={navItemClass}>
            <ClipboardList className="h-4 w-4" aria-hidden="true" />
            Patients
          </NavLink>
        )}
      </div>

      <div className="flex items-center gap-3 border-t border-slate-100 px-4 py-4 dark:border-slate-800">
        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[#030616] text-sm font-semibold text-white dark:bg-[#18224A] dark:text-[#AFC3FF]">
          {(email ?? '?').slice(0, 1).toUpperCase()}
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-slate-900 dark:text-[#EEF1F8]">{email}</p>
          <p className="truncate text-xs text-slate-500 dark:text-[#A6B0C3]">{(role && ROLE_LABELS[role]) || role}</p>
        </div>
        <button
          type="button"
          onClick={() => signOut()}
          aria-label="Sign out"
          className={`flex h-11 w-11 items-center justify-center rounded-full text-slate-500 hover:bg-slate-100 hover:text-slate-700 dark:text-[#A6B0C3] dark:hover:bg-[#222838] dark:hover:text-[#EEF1F8] ${FOCUS_RING_ON_SUNKEN_CLASS}`}
        >
          <LogOut className="h-4 w-4" aria-hidden="true" />
        </button>
      </div>
    </nav>
  );
};

export default Sidebar;
