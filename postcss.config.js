// TC-032: build-time Tailwind (no CDN). No autoprefixer: the Play CDN didn't
// add vendor prefixes either, so output stays the same.
export default {
  plugins: {
    tailwindcss: {},
  },
};
