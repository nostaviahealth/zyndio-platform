import React from 'react';

// 07-users-roles: placeholder landing page for org_admin under the new
// AppShell. The full table/invite/role-change/deactivate flow is built in
// a later step (plan F.8) - this only gives org_admin somewhere to land now
// that the clinical routes are closed to them (OVERRIDES: "org_admin: users
// only").
const UsersRoles: React.FC = () => (
  <div>
    <h1 className="text-2xl font-bold text-[#030616]">Users and roles</h1>
    <p className="mt-2 text-sm text-slate-600">
      People at Zyndio who can sign in to the care portal. Everyone must use two-factor sign-in.
    </p>
  </div>
);

export default UsersRoles;
