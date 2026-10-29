import React from 'react';

// TC-019 fix round (Ava F4): the auth screens have no dark design yet, so an
// AuthCard is a light surface even when the OS (and <html class="dark">) is
// dark. The `light` class opts this subtree out of Tailwind's `dark:` variant
// (see darkMode in index.html), so Button and the focus ring keep their light
// tokens on the white card, and color-scheme keeps native controls light.
const AuthCard: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="light min-h-screen bg-[#F2F4F7] flex flex-col items-center px-4 py-16" style={{ colorScheme: 'light' }}>
    <div className="mb-8 text-center">
      <span className="text-lg font-bold tracking-[0.06em] text-[#030616]">ZYNDIO</span>
      <span className="ml-2 align-middle text-[11px] font-medium uppercase tracking-[0.2em] text-[#48556A]">
        Care Portal
      </span>
    </div>
    <div className="w-full max-w-[480px] rounded-2xl bg-white p-8 shadow-xl">{children}</div>
    <footer className="mt-8 flex gap-4 text-sm text-[#48556A]">
      <a href="#" className="min-h-[44px] flex items-center">
        Privacy
      </a>
      <a href="#" className="min-h-[44px] flex items-center">
        Terms
      </a>
      <a href="#" className="min-h-[44px] flex items-center">
        Help
      </a>
    </footer>
  </div>
);

export default AuthCard;
