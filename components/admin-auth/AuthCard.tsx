import React from 'react';

const AuthCard: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="min-h-screen bg-[#F2F4F7] flex flex-col items-center px-4 py-16">
    <div className="mb-8 text-center">
      <span className="text-lg font-bold tracking-[0.06em] text-[#030616]">ZYNDIO</span>
      <span className="ml-2 align-middle text-[11px] font-medium uppercase tracking-[0.2em] text-slate-500">
        Care Portal
      </span>
    </div>
    <div className="w-full max-w-[480px] rounded-2xl bg-white p-8 shadow-xl">{children}</div>
    <footer className="mt-8 flex gap-4 text-sm text-slate-500">
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
