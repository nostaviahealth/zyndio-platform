// TC-019 M1/M6 (Ava must-fix): the real app never added Tailwind's `dark`
// class or `color-scheme`, so a dark-OS user always saw light mode. This is
// called once at app start (index.tsx) to mirror the inline <head> bootstrap
// in index.html, which runs the same logic before first paint so there's no
// flash of light theme; this copy keeps the live `change` listener working
// after React mounts and is what tests exercise directly.

export function applySystemTheme(root: HTMLElement, isDark: boolean): void {
  root.classList.toggle('dark', isDark);
  root.style.colorScheme = isDark ? 'dark' : 'light';
}

export function watchSystemTheme(win: Window, root: HTMLElement = win.document.documentElement): void {
  const mql = win.matchMedia('(prefers-color-scheme: dark)');
  applySystemTheme(root, mql.matches);
  mql.addEventListener('change', (e) => applySystemTheme(root, e.matches));
}
