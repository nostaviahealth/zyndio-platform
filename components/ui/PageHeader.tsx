import React from 'react';

interface PageHeaderProps {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}

// C-series PageHeader: title + one-line description + a right-aligned
// primary action slot, shared by every admin page.
const PageHeader: React.FC<PageHeaderProps> = ({ title, description, actions }) => (
  <div className="flex flex-wrap items-start justify-between gap-4">
    <div>
      <h1 className="text-2xl font-bold text-[#030616]">{title}</h1>
      {description && <p className="mt-2 max-w-2xl text-sm text-slate-600">{description}</p>}
    </div>
    {actions && <div className="flex shrink-0 items-center gap-3">{actions}</div>}
  </div>
);

export default PageHeader;
