export const appThemeTokens = {
  surfaceBase: '245 247 251',
  surfaceElevated: '255 255 255',
  surfaceGlass: '255 255 255',
  textPrimary: '10 22 40',
  textMuted: '71 85 105',
  borderSubtle: '226 232 240',
} as const;

export type ThemeTokenName = keyof typeof appThemeTokens;
