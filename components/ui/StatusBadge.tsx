import React from 'react';

export type MemberStatusBadgeKind = 'active' | 'invited' | 'deactivated';

interface StatusBadgeProps {
  kind: MemberStatusBadgeKind;
  children: React.ReactNode;
}

// TC-013 Ava M4: status as a pill badge (success/brand/neutral) rather than
// plain text, matching handoff/admin/states/07-users-roles.
const KIND_CLASSES: Record<MemberStatusBadgeKind, string> = {
  active: 'bg-emerald-100 text-emerald-800',
  invited: 'bg-[#E8EDFD] text-[#2C5CF2]',
  deactivated: 'bg-slate-100 text-slate-600',
};

const StatusBadge: React.FC<StatusBadgeProps> = ({ kind, children }) => (
  <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${KIND_CLASSES[kind]}`}>
    {children}
  </span>
);

export default StatusBadge;
