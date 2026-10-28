import React from 'react';
import { FlagKey } from '../../lib/clinicalApi';

// C54 flag badge (POR-02 roster flags). Text-only badges, 12/16 600,
// padding 2 8, wrap in a cell. Palette per the plan / components.md: Clinical
// context = err pair, Outside range / Needs review / Identity hold = warn,
// Missing labs = neutral (bg.sunken), Question waiting = brand. There is NO
// severity ranking or "urgent" styling (assumption 2) - the colour only
// distinguishes the flag kind, never a priority.

export const FLAG_LABELS: Record<FlagKey, string> = {
  clinical_context: 'Clinical context',
  outside_range: 'Outside range',
  needs_review: 'Needs review',
  identity_hold: 'Identity hold',
  missing_labs: 'Missing labs',
  question_waiting: 'Question waiting',
};

type Tone = 'err' | 'warn' | 'neutral' | 'brand';

const FLAG_TONE: Record<FlagKey, Tone> = {
  clinical_context: 'err',
  outside_range: 'warn',
  needs_review: 'warn',
  identity_hold: 'warn',
  missing_labs: 'neutral',
  question_waiting: 'brand',
};

const TONE_CLASSES: Record<Tone, string> = {
  err: 'bg-[#FBE3E0] text-[#B42318] dark:bg-[#2F1513] dark:text-[#FF8F86]',
  warn: 'bg-[#FCEFD6] text-[#8A4F00] dark:bg-[#2F220D] dark:text-[#F2B65A]',
  neutral: 'bg-[#EEF1F6] text-[#48556A] dark:bg-[#0B0F19] dark:text-[#A6B0C3]',
  brand: 'bg-[#E8EDFD] text-[#2C5CF2] dark:bg-[#18224A] dark:text-[#AFC3FF]',
};

const FlagBadge: React.FC<{ flag: FlagKey }> = ({ flag }) => (
  <span
    className={`inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold leading-4 ${TONE_CLASSES[FLAG_TONE[flag]]}`}
  >
    {FLAG_LABELS[flag]}
  </span>
);

export default FlagBadge;
