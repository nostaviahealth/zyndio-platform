// @vitest-environment jsdom
// TC-030 (0b): unknown /admin/* paths (old bookmarks, email links, routes that
// now live behind the legacy-patient-screens flag) must redirect to the staff
// home (/admin), never fall through the app-wide catch-all
// (<Navigate to="/" />) into the patient portal Home ("Welcome to Zyndio").
//
// Fail-first: without the `/admin/*` catch-all INSIDE the admin shell route
// subtree, an unknown /admin/... path matches only the global `path="*"` →
// Navigate to "/" → the patient Home renders. These tests then see
// "Welcome to Zyndio" / PATIENT_HOME and the /admin redirect assertions go red.
//
// This test mirrors App.tsx's route shape (admin subtree with an index + a
// nested catch-all, the patient "/" subtree, and the global catch-all) rather
// than mounting the whole App (which needs Supabase, auth and session gates).
// A static guard below pins the real fix into App.tsx itself.
import React from 'react';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';

const LocationProbe: React.FC = () => <div data-testid="location">{useLocation().pathname}</div>;

// Mirrors the App.tsx structure: the admin shell subtree with an index and an
// /admin/* catch-all, the patient portal "/" subtree, and the global catch-all.
function renderAt(url: string) {
  return render(
    <MemoryRouter initialEntries={[url]}>
      <Routes>
        <Route path="/admin">
          <Route index element={<div>STAFF_HOME</div>} />
          <Route path="patients" element={<div>PATIENTS_ROSTER</div>} />
          {/* The fix under test: */}
          <Route path="*" element={<Navigate to="/admin" replace />} />
        </Route>
        <Route path="/">
          <Route index element={<div>Welcome to Zyndio</div>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <LocationProbe />
    </MemoryRouter>
  );
}

const UNKNOWN_ADMIN_PATHS = [
  '/admin/nutrition-lab',
  '/admin/patient/p-fictional-1',
  '/admin/some-old-bookmark',
];

describe('TC-030 0b: unknown /admin/* routes redirect to the staff home', () => {
  it.each(UNKNOWN_ADMIN_PATHS)('%s lands on /admin (staff home), not the patient portal', (url) => {
    renderAt(url);
    expect(screen.getByText('STAFF_HOME')).toBeInTheDocument();
    expect(screen.getByTestId('location').textContent).toBe('/admin');
    // The bug: dropping staff into the patient app.
    expect(screen.queryByText('Welcome to Zyndio')).not.toBeInTheDocument();
  });

  it('App.tsx registers an /admin/* catch-all inside the admin shell route subtree', () => {
    const app = fs.readFileSync(path.resolve(__dirname, '../../App.tsx'), 'utf8');
    // The admin shell route: <Route path="/admin" ...> ... </Route>
    const adminBlock = app.match(/path="\/admin"[\s\S]*?<\/Route>\s*\n/);
    expect(adminBlock, 'could not find the /admin shell route block in App.tsx').not.toBeNull();
    // A catch-all redirecting to /admin must live INSIDE that block.
    expect(adminBlock![0]).toMatch(/path="\*"[\s\S]*?Navigate\s+to="\/admin"/);
  });
});
