export type VisualPreset = 'clean' | 'gamified';

export interface WhiteLabelConfig {
  platform_name?: string;
  logo_url?: string;
  brand_primary_color?: string;
  brand_secondary_color?: string;
  brand_accent_color?: string;
  visual_preset?: VisualPreset;
}

export const WHITE_LABEL_STORAGE_KEY = 'bt_whitelabel';

export function readWhiteLabelConfig(): WhiteLabelConfig {
  try {
    const raw = localStorage.getItem(WHITE_LABEL_STORAGE_KEY);
    if (!raw) return {};
    return JSON.parse(raw) as WhiteLabelConfig;
  } catch {
    return {};
  }
}

export function writeWhiteLabelConfig(config: WhiteLabelConfig) {
  localStorage.setItem(WHITE_LABEL_STORAGE_KEY, JSON.stringify(config));
  window.dispatchEvent(new CustomEvent('bt:whitelabel:update', { detail: config }));
}
