import { useEffect, useState } from 'react';
import { Loader2, Palette, Save, Upload } from 'lucide-react';
import toast from 'react-hot-toast';
import { settingsAPI } from '../services/api';
import { useAuthStore } from '../store/auth.store';
import { readWhiteLabelConfig, WhiteLabelConfig, writeWhiteLabelConfig } from '../theme/whitelabel';

export default function WhiteLabelAdminPage() {
  const { updateUser } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [org, setOrg] = useState<any>({});
  const [whiteLabel, setWhiteLabel] = useState<WhiteLabelConfig>({
    visual_preset: 'gamified',
    platform_name: 'BlueTech Sign',
    brand_primary_color: '#1E3A5F',
    brand_secondary_color: '#0EA5E9',
    brand_accent_color: '#06B6D4',
    logo_url: '',
  });

  useEffect(() => {
    settingsAPI.get()
      .then((res) => {
        const organization = res.data?.organization || {};
        const local = readWhiteLabelConfig();
        const merged: WhiteLabelConfig = {
          platform_name: organization.platform_name || local.platform_name || organization.name || 'BlueTech Sign',
          logo_url: organization.logo_url || local.logo_url || '',
          brand_primary_color: organization.brand_primary_color || local.brand_primary_color || '#1E3A5F',
          brand_secondary_color: organization.brand_secondary_color || local.brand_secondary_color || '#0EA5E9',
          brand_accent_color: organization.brand_accent_color || local.brand_accent_color || '#06B6D4',
          visual_preset: organization.visual_preset || local.visual_preset || 'gamified',
        };
        setOrg(organization);
        setWhiteLabel(merged);
        // Keep local storage synced with authoritative server values.
        writeWhiteLabelConfig(merged);
      })
      .catch(() => toast.error('Falha ao carregar configurações'))
      .finally(() => setLoading(false));
  }, []);

  const uploadLogo = async (file?: File | null) => {
    if (!file) return;
    setUploadingLogo(true);
    try {
      const formData = new FormData();
      formData.append('logo', file);
      const { data } = await settingsAPI.uploadLogo(formData);
      const logoUrl = data?.logo_url || data?.url || '';
      setWhiteLabel((prev) => ({ ...prev, logo_url: logoUrl }));
      toast.success('Logo enviada');
    } catch {
      toast.error('Erro ao enviar logo');
    } finally {
      setUploadingLogo(false);
    }
  };

  const save = async () => {
    setSaving(true);
    try {
      await settingsAPI.updateOrg({
        ...org,
        ...whiteLabel,
      });
      writeWhiteLabelConfig(whiteLabel);
      updateUser({
        org_name: whiteLabel.platform_name || org.name,
        platform_name: whiteLabel.platform_name,
        logo_url: whiteLabel.logo_url,
        brand_primary_color: whiteLabel.brand_primary_color,
        brand_secondary_color: whiteLabel.brand_secondary_color,
        brand_accent_color: whiteLabel.brand_accent_color,
        visual_preset: whiteLabel.visual_preset,
      } as any);
      toast.success('White Label salvo com sucesso');
    } catch {
      toast.error('Erro ao salvar White Label');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-16">
        <Loader2 className="w-8 h-8 animate-spin text-brand-600" />
      </div>
    );
  }

  return (
    <div className="animate-fade-in page-shell space-y-6">
      <div>
        <h1 className="section-title">Admin White Label</h1>
        <p className="section-subtitle">Controle identidade visual, logo e preset do produto.</p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-5">
        <div className="xl:col-span-2 card-glass p-6 space-y-4">
          <h2 className="text-lg font-semibold text-gray-900">Configurações visuais</h2>

          <div className="grid md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Nome da plataforma</label>
              <input
                className="input-field"
                value={whiteLabel.platform_name || ''}
                onChange={(e) => setWhiteLabel((prev) => ({ ...prev, platform_name: e.target.value }))}
                placeholder="Ex: SignArena"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Preset visual</label>
              <select
                className="input-field"
                value={whiteLabel.visual_preset || 'gamified'}
                onChange={(e) => setWhiteLabel((prev) => ({ ...prev, visual_preset: e.target.value as 'clean' | 'gamified' }))}
              >
                <option value="gamified">Gamified (Neon)</option>
                <option value="clean">Clean (Corporativo)</option>
              </select>
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Cor primária</label>
              <div className="flex gap-2">
                <input
                  type="color"
                  className="min-h-11 min-w-11 w-11 h-11 rounded border cursor-pointer"
                  value={whiteLabel.brand_primary_color || '#1E3A5F'}
                  onChange={(e) => setWhiteLabel((prev) => ({ ...prev, brand_primary_color: e.target.value }))}
                />
                <input
                  className="input-field"
                  value={whiteLabel.brand_primary_color || ''}
                  onChange={(e) => setWhiteLabel((prev) => ({ ...prev, brand_primary_color: e.target.value }))}
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Cor secundária</label>
              <div className="flex gap-2">
                <input
                  type="color"
                  className="min-h-11 min-w-11 w-11 h-11 rounded border cursor-pointer"
                  value={whiteLabel.brand_secondary_color || '#0EA5E9'}
                  onChange={(e) => setWhiteLabel((prev) => ({ ...prev, brand_secondary_color: e.target.value }))}
                />
                <input
                  className="input-field"
                  value={whiteLabel.brand_secondary_color || ''}
                  onChange={(e) => setWhiteLabel((prev) => ({ ...prev, brand_secondary_color: e.target.value }))}
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Cor accent</label>
              <div className="flex gap-2">
                <input
                  type="color"
                  className="min-h-11 min-w-11 w-11 h-11 rounded border cursor-pointer"
                  value={whiteLabel.brand_accent_color || '#06B6D4'}
                  onChange={(e) => setWhiteLabel((prev) => ({ ...prev, brand_accent_color: e.target.value }))}
                />
                <input
                  className="input-field"
                  value={whiteLabel.brand_accent_color || ''}
                  onChange={(e) => setWhiteLabel((prev) => ({ ...prev, brand_accent_color: e.target.value }))}
                />
              </div>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Logo</label>
            <div className="flex flex-col sm:flex-row gap-3">
              <input type="file" accept="image/*" className="input-field" onChange={(e) => uploadLogo(e.target.files?.[0])} />
              <button type="button" className="btn-secondary inline-flex items-center justify-center gap-2" disabled={uploadingLogo}>
                {uploadingLogo ? <Loader2 className="w-4 h-4 animate-spin" /> : <Upload className="w-4 h-4" />} Upload
              </button>
            </div>
          </div>

          <button onClick={save} disabled={saving} className="btn-primary inline-flex items-center gap-2">
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />} Salvar White Label
          </button>
        </div>

        <div className="card-glass p-5 space-y-3">
          <h3 className="text-base font-semibold text-gray-900 inline-flex items-center gap-2">
            <Palette className="w-4 h-4" /> Preview
          </h3>
          <div className="rounded-xl border border-cyan-400/20 p-4 bg-gradient-to-br from-slate-900 to-slate-800">
            <div className="flex items-center gap-2">
              {whiteLabel.logo_url ? (
                <img src={whiteLabel.logo_url} alt="Logo" className="w-10 h-10 rounded-lg object-cover" />
              ) : (
                <div className="w-10 h-10 rounded-lg bg-cyan-400/20 border border-cyan-300/20" />
              )}
              <div>
                <p className="text-white font-semibold">{whiteLabel.platform_name || 'Plataforma'}</p>
                <p className="text-cyan-100/70 text-xs">{whiteLabel.visual_preset === 'clean' ? 'Clean' : 'Gamified'}</p>
              </div>
            </div>
            <div className="mt-4 flex gap-2">
              <span className="w-8 h-8 rounded-md border border-white/20" style={{ backgroundColor: whiteLabel.brand_primary_color }} />
              <span className="w-8 h-8 rounded-md border border-white/20" style={{ backgroundColor: whiteLabel.brand_secondary_color }} />
              <span className="w-8 h-8 rounded-md border border-white/20" style={{ backgroundColor: whiteLabel.brand_accent_color }} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
