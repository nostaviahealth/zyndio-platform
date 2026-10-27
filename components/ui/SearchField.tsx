import React from 'react';
import { Search } from 'lucide-react';

interface SearchFieldProps {
  value?: string;
  onChange?: (value: string) => void;
  placeholder: string;
  'aria-label': string;
  className?: string;
  readOnly?: boolean;
}

// TC-013 Ava L8: pill search field with a leading search icon (C42 search
// variant). Dark tokens match design/tokens bg.surface / text.secondary.
const SearchField: React.FC<SearchFieldProps> = ({ value, onChange, placeholder, className = '', ...rest }) => (
  <div className={`relative ${className}`}>
    <Search
      className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400 dark:text-[#8F9AAF]"
      aria-hidden="true"
    />
    <input
      type="search"
      placeholder={placeholder}
      className="min-h-[44px] w-full rounded-full border border-slate-300 bg-white pl-11 pr-4 text-sm text-[#030616] placeholder:text-slate-400 dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:placeholder:text-[#8F9AAF]"
      value={value}
      onChange={onChange ? (e) => onChange(e.target.value) : undefined}
      {...rest}
    />
  </div>
);

export default SearchField;
