import tokens from '../../design/tokens/zyndio-site.json';

export interface ZyndioBrandColors {
  dark: string;
  blue: string;
  sage: string;
  sageDark: string;
  gold: string;
  goldLight: string;
  bg: string;
  card: string;
}

export interface ZyndioTailwindTheme {
  colors: {
    brand: ZyndioBrandColors;
  };
  fontFamily: {
    sans: string[];
    serif: string[];
  };
  borderRadius: {
    sm: string;
    md: string;
    lg: string;
    button: string;
    pill: string;
  };
}

/**
 * Maps the existing root-admin `brand-*` Tailwind keys onto Zyndio design
 * tokens (design/tokens/zyndio-site.json), using the light-mode values since
 * the root admin has no dark theme toggle today.
 */
export function buildTailwindTheme(): ZyndioTailwindTheme {
  return {
    colors: {
      brand: {
        dark: tokens.color.text.primary.$value.light,
        blue: tokens.color.brand.primary.$value.light,
        sage: tokens.color.brand.subtle.$value.light,
        sageDark: tokens.color.brand.onSubtle.$value.light,
        gold: tokens.color.status.warning.$value.light,
        goldLight: tokens.color.status.warningSubtle.$value.light,
        bg: tokens.color.bg.canvas.$value.light,
        card: tokens.color.bg.surface.$value.light,
      },
    },
    fontFamily: {
      sans: tokens.font.family.text.$value,
      serif: tokens.font.family.display.$value,
    },
    borderRadius: {
      sm: tokens.radius.sm.$value,
      md: tokens.radius.md.$value,
      lg: tokens.radius.lg.$value,
      button: tokens.radius.button.$value,
      pill: tokens.radius.pill.$value,
    },
  };
}
