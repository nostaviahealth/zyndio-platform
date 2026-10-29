// design/tokens/zyndio-site.json → color.focus.ring
// Light #2346DD, dark #AFC3FF. Width 3px, offset 2px (Ava TC-014 must-fix).
// Class strings are fully static so Tailwind's content scan keeps them.
export const FOCUS_RING_LIGHT = '#2346DD';
export const FOCUS_RING_DARK = '#AFC3FF';
export const FOCUS_RING_WIDTH_PX = 3;
export const FOCUS_RING_OFFSET_PX = 2;

/** Inputs/selects. Both :focus and :focus-visible so Dialog autofocus
 * (programmatic .focus()) shows the token ring, not the browser default. */
export const FOCUS_RING_CLASS =
  'outline-none focus:outline-none focus-visible:outline-none ' +
  'focus:ring-[3px] focus-visible:ring-[3px] ' +
  'focus:ring-offset-2 focus-visible:ring-offset-2 ' +
  'focus:ring-[#2346DD] focus-visible:ring-[#2346DD] ' +
  'dark:focus:ring-[#AFC3FF] dark:focus-visible:ring-[#AFC3FF] ' +
  'focus:ring-offset-white focus-visible:ring-offset-white ' +
  'dark:focus:ring-offset-[#10141F] dark:focus-visible:ring-offset-[#10141F]';

/** Same ring on the dark sunken surface (#0B0F19, the sidebar), so the
 * 2px offset matches what is behind it (TC-021 item 10 F5). */
export const FOCUS_RING_ON_SUNKEN_CLASS =
  'outline-none focus:outline-none focus-visible:outline-none ' +
  'focus:ring-[3px] focus-visible:ring-[3px] ' +
  'focus:ring-offset-2 focus-visible:ring-offset-2 ' +
  'focus:ring-[#2346DD] focus-visible:ring-[#2346DD] ' +
  'dark:focus:ring-[#AFC3FF] dark:focus-visible:ring-[#AFC3FF] ' +
  'focus:ring-offset-white focus-visible:ring-offset-white ' +
  'dark:focus:ring-offset-[#0B0F19] dark:focus-visible:ring-offset-[#0B0F19]';

/** TC-021 item 21 (Ava, #21): menu items inside a rounded panel. Same token
 * colours and 3px width, drawn INSIDE the item (ring-inset, no offset), so it
 * never paints over the panel's rounded border. Ring vs panel/hover fill is
 * >= 3:1 in both themes (light #2346DD on #FFFFFF/#F8FAFC, dark #AFC3FF on
 * #10141F/#222838). */
export const FOCUS_RING_INSET_CLASS =
  'outline-none focus:outline-none focus-visible:outline-none ' +
  'focus:ring-[3px] focus-visible:ring-[3px] ' +
  'focus:ring-inset focus-visible:ring-inset ' +
  'focus:ring-[#2346DD] focus-visible:ring-[#2346DD] ' +
  'dark:focus:ring-[#AFC3FF] dark:focus-visible:ring-[#AFC3FF]';
