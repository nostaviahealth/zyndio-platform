import { AppRole, MemberStatus } from '../../lib/usersRolesApi';

// Fictional-only fixture data for the /__preview harness (copy-deck.md
// "07-users-roles", names kept, emails moved to the repo's example.test
// convention instead of the handoff's example.com). Never imported by the
// default `npm run build` entry point - see tests/preview-harness.test.ts.
export const PREVIEW_FIXTURE_MARKER = 'zyndio-preview-fixture-taylor-brooks';

export interface PreviewMember {
  user_id: string;
  email: string;
  name: string;
  role: AppRole;
  status: MemberStatus;
  twoFactor: string;
  lastSignIn: string;
}

export const SELF_USER_ID = 'preview-taylor-brooks';

export const PREVIEW_MEMBERS: PreviewMember[] = [
  {
    user_id: SELF_USER_ID,
    email: 'taylor.brooks@example.test',
    name: 'Taylor Brooks (you)',
    role: 'org_admin',
    status: 'active',
    twoFactor: 'On',
    lastSignIn: 'Today, 9:02 AM',
  },
  {
    user_id: 'preview-morgan-ellis',
    email: 'morgan.ellis@example.test',
    name: 'Dr. Morgan Ellis',
    role: 'physician',
    status: 'active',
    twoFactor: 'On',
    lastSignIn: 'Today, 8:47 AM',
  },
  {
    user_id: 'preview-priya-raman',
    email: 'priya.raman@example.test',
    name: 'Dr. Priya Raman',
    role: 'physician',
    status: 'active',
    twoFactor: 'On',
    lastSignIn: 'Oct 24, 2026',
  },
  {
    user_id: 'preview-riley-chen',
    email: 'riley.chen@example.test',
    name: 'Riley Chen',
    role: 'read_only',
    status: 'active',
    twoFactor: 'On',
    lastSignIn: 'Oct 22, 2026',
  },
  {
    user_id: 'preview-sam-okafor',
    email: 'sam.okafor@example.test',
    name: 'Sam Okafor',
    role: 'care_coordinator',
    status: 'invited',
    twoFactor: 'Not set up yet',
    lastSignIn: 'Never',
  },
  {
    user_id: 'preview-jamie-ortiz',
    email: 'jamie.ortiz@example.test',
    name: 'Jamie Ortiz',
    role: 'care_coordinator',
    status: 'deactivated',
    twoFactor: 'On',
    lastSignIn: 'Sep 30, 2026',
  },
];
