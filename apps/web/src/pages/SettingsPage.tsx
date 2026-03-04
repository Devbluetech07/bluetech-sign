import { useState, useEffect } from 'react';
import { settingsAPI, webhooksAPI } from '../services/api';
import { Settings, Building, Palette, Mail, Webhook, Key, Loader2, Save, Plus, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';

export default function SettingsPage() {
  const [tab, setTab] = useState('organization');
  const [org, setOrg] = useState<any>({});
  const [settings, setSettings] = useState<any[]>([]);
  const [webhooks, setWebhooks] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showWebhookModal, setShowWebhookModal] = useState(false);
  const [whForm, setWhForm] = useState({ url: '', events: [] as string[] });
  const [apiKeys, setApiKeys] = useState<any[]>([]);
  const [newKeyName, setNewKeyName] = useState('');
  const [newKeyScopes, setNewKeyScopes] = useState<string[]>(['documents']);
  const [generatedApiKey, setGeneratedApiKey] = useState('');
  const [creatingApiKey, setCreatingApiKey] = useState(false);

  useEffect(() => {
    Promise.all([settingsAPI.get(), webhooksAPI.list().catch(() => ({ data: [] }))])
      .then(([s, w]) => { setOrg(s.data.organization); setSettings(s.data.settings); setWebhooks(w.data); setLoading(false); })
      .catch(() => setLoading(false));
    settingsAPI.listApiKeys().then((r) => setApiKeys(r.data || [])).catch(() => null);
  }, []);

  const saveOrg = async () => {
    setSaving(true);
    try { await settingsAPI.updateOrg(org); toast.success('Organização atualizada'); } catch { toast.error('Erro'); }
    setSaving(false);
  };

  const saveSetting = async (key: string, value: string) => {
    try { await settingsAPI.updateConfig({ key, value }); toast.success('Configuração salva'); } catch { toast.error('Erro'); }
  };

  const createWebhook = async () => {
    if (!whForm.url) return toast.error('URL obrigatória');
    try {
      await webhooksAPI.create(whForm);
      toast.success('Webhook criado');
      setShowWebhookModal(false);
      const r = await webhooksAPI.list(); setWebhooks(r.data);
    } catch { toast.error('Erro'); }
  };

  const deleteWebhook = async (id: string) => {
    if (!confirm('Excluir webhook?')) return;
    try { await webhooksAPI.delete(id); toast.success('Excluído'); const r = await webhooksAPI.list(); setWebhooks(r.data); } catch { toast.error('Erro'); }
  };

  const createApiKey = async () => {
    if (!newKeyName) return toast.error('Nome da chave e obrigatorio');
    setCreatingApiKey(true);
    try {
      const { data } = await settingsAPI.createApiKey({ name: newKeyName, scopes: newKeyScopes });
      setGeneratedApiKey(data.key || '');
      setNewKeyName('');
      setNewKeyScopes(['documents']);
      const refreshed = await settingsAPI.listApiKeys();
      setApiKeys(refreshed.data || []);
      toast.success('API Key gerada');
    } catch (e: any) { toast.error(e.response?.data?.error || 'Erro ao gerar chave'); }
    setCreatingApiKey(false);
  };

  const revokeApiKey = async (id: string) => {
    try {
      await settingsAPI.revokeApiKey(id);
      setApiKeys((prev) => prev.filter((key) => key.id !== id));
      toast.success('Chave revogada');
    } catch (e: any) { toast.error(e.response?.data?.error || 'Erro ao revogar chave'); }
  };

  const tabs = [
    { id: 'organization', label: 'Organização', icon: Building },
    { id: 'brand', label: 'Marca/Estética', icon: Palette },
    { id: 'notifications', label: 'Notificações', icon: Mail },
    { id: 'webhooks', label: 'Webhooks', icon: Webhook },
    { id: 'advanced', label: 'Avançado', icon: Key },
  ];

  const webhookEvents = ['document.created', 'document.sent', 'document.completed', 'document.cancelled', 'document.expired', 'signer.signed', 'signer.rejected', 'signer.opened'];

  if (loading) return <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>;

  return (
    <div className="animate-fade-in">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Configurações</h1>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Sidebar tabs */}
        <div className="lg:w-56 flex-shrink-0">
          <div className="card p-2 flex lg:flex-col gap-1 overflow-x-auto">
            {tabs.map(t => (
              <button key={t.id} onClick={() => setTab(t.id)}
                className={`flex items-center gap-2 px-3 py-2.5 rounded-lg text-sm font-medium whitespace-nowrap transition-all
                  ${tab === t.id ? 'bg-brand-50 text-brand-700' : 'text-gray-600 hover:bg-gray-50'}`}>
                <t.icon className="w-4 h-4 flex-shrink-0" /> {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1">
          {tab === 'organization' && (
            <div className="card p-6 space-y-4">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Dados da Organização</h2>
              <div className="grid md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nome da Empresa</label>
                  <input type="text" value={org.name || ''} onChange={e => setOrg({ ...org, name: e.target.value })} className="input-field" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">CNPJ</label>
                  <input type="text" value={org.cnpj || ''} onChange={e => setOrg({ ...org, cnpj: e.target.value })} className="input-field" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                  <input type="email" value={org.email || ''} onChange={e => setOrg({ ...org, email: e.target.value })} className="input-field" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Telefone</label>
                  <input type="text" value={org.phone || ''} onChange={e => setOrg({ ...org, phone: e.target.value })} className="input-field" />
                </div>
              </div>
              <button onClick={saveOrg} disabled={saving} className="btn-primary flex items-center gap-2">
                {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />} Salvar
              </button>
            </div>
          )}

          {tab === 'brand' && (
            <div className="card p-6 space-y-4">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Identidade Visual</h2>
              <p className="text-sm text-gray-500 mb-4">Personalize a aparência dos emails e páginas de assinatura enviados pela sua empresa.</p>
              <div className="grid md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Cor Primária</label>
                  <div className="flex items-center gap-2">
                    <input type="color" value={org.brand_primary_color || '#1E3A5F'} onChange={e => setOrg({ ...org, brand_primary_color: e.target.value })} className="min-h-11 min-w-11 w-11 h-11 rounded border cursor-pointer" />
                    <input type="text" value={org.brand_primary_color || '#1E3A5F'} onChange={e => setOrg({ ...org, brand_primary_color: e.target.value })} className="input-field" />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Cor Secundária</label>
                  <div className="flex items-center gap-2">
                    <input type="color" value={org.brand_secondary_color || '#0EA5E9'} onChange={e => setOrg({ ...org, brand_secondary_color: e.target.value })} className="min-h-11 min-w-11 w-11 h-11 rounded border cursor-pointer" />
                    <input type="text" value={org.brand_secondary_color || '#0EA5E9'} onChange={e => setOrg({ ...org, brand_secondary_color: e.target.value })} className="input-field" />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Cor Accent</label>
                  <div className="flex items-center gap-2">
                    <input type="color" value={org.brand_accent_color || '#06B6D4'} onChange={e => setOrg({ ...org, brand_accent_color: e.target.value })} className="min-h-11 min-w-11 w-11 h-11 rounded border cursor-pointer" />
                    <input type="text" value={org.brand_accent_color || '#06B6D4'} onChange={e => setOrg({ ...org, brand_accent_color: e.target.value })} className="input-field" />
                  </div>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Header customizado (email)</label>
                <textarea value={org.custom_email_header || ''} onChange={e => setOrg({ ...org, custom_email_header: e.target.value })} className="input-field" rows={2} placeholder="HTML do cabeçalho do email" />
              </div>
              {/* Preview */}
              <div className="p-4 rounded-xl border bg-brand-700">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
                    <Settings className="w-4 h-4 text-white" />
                  </div>
                  <span className="text-white font-bold">{org.name || 'Sua Empresa'}</span>
                </div>
                <p className="text-white/60 text-sm mt-2">Preview da cor primária nos emails e páginas de assinatura</p>
              </div>
              <button onClick={saveOrg} disabled={saving} className="btn-primary flex items-center gap-2">
                <Save className="w-4 h-4" /> Salvar Marca
              </button>
            </div>
          )}

          {tab === 'notifications' && (
            <div className="card p-6 space-y-4">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Configurações de Notificação</h2>
              {settings.filter(s => ['email_notifications', 'whatsapp_notifications', 'default_remind_interval', 'default_deadline_days', 'default_auth_method'].includes(s.key)).map(s => (
                <div key={s.key} className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 py-3 border-b border-gray-100">
                  <div>
                    <p className="font-medium text-gray-900 text-sm">{s.description || s.key}</p>
                    <p className="text-xs text-gray-400">Chave: {s.key}</p>
                  </div>
                  {s.type === 'boolean' ? (
                    <button onClick={() => saveSetting(s.key, s.value === 'true' ? 'false' : 'true')}
                      className={`w-12 h-6 rounded-full transition-colors self-start sm:self-auto ${s.value === 'true' ? 'bg-brand-600' : 'bg-gray-300'}`}>
                      <div className={`w-5 h-5 bg-white rounded-full shadow transition-transform ${s.value === 'true' ? 'translate-x-6' : 'translate-x-0.5'}`} />
                    </button>
                  ) : (
                    <input type="text" value={s.value} className="input-field w-full sm:w-32 text-sm" onChange={e => {
                      const idx = settings.findIndex(x => x.key === s.key);
                      const updated = [...settings]; updated[idx] = { ...s, value: e.target.value }; setSettings(updated);
                    }} onBlur={() => saveSetting(s.key, s.value)} />
                  )}
                </div>
              ))}
            </div>
          )}

          {tab === 'webhooks' && (
            <div className="card p-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-gray-900">Webhooks</h2>
                <button onClick={() => { setWhForm({ url: '', events: [] }); setShowWebhookModal(true); }} className="btn-primary text-sm flex items-center gap-1"><Plus className="w-4 h-4" /> Novo</button>
              </div>
              {webhooks.length === 0 ? (
                <p className="text-gray-400 text-center py-8">Nenhum webhook configurado</p>
              ) : (
                <div className="space-y-3">
                  {webhooks.map(w => (
                    <div key={w.id} className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3 border rounded-lg">
                      <div>
                        <p className="text-sm font-mono text-gray-700 break-all">{w.url}</p>
                        <div className="flex gap-1 mt-1 flex-wrap">
                          {w.events?.map((e: string) => <span key={e} className="badge bg-gray-100 text-gray-600 text-xs">{e}</span>)}
                        </div>
                      </div>
                      <button onClick={() => deleteWebhook(w.id)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-red-50 rounded text-gray-400 hover:text-red-500 self-end sm:self-auto"><Trash2 className="w-4 h-4" /></button>
                    </div>
                  ))}
                </div>
              )}

              <div className="border-t border-gray-100 mt-6 pt-6">
                <h3 className="text-base font-semibold text-gray-900 mb-2">API Keys</h3>
                <p className="text-sm text-gray-500 mb-3">Gere chaves para integracoes externas via x-api-key.</p>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-2 mb-3">
                  <input value={newKeyName} onChange={e => setNewKeyName(e.target.value)} className="input-field md:col-span-2" placeholder="Nome da chave" />
                  <button onClick={createApiKey} disabled={creatingApiKey} className="btn-primary">
                    {creatingApiKey ? 'Gerando...' : 'Gerar nova API Key'}
                  </button>
                </div>
                <div className="flex flex-wrap gap-2 mb-3">
                  {['documents', 'contacts'].map(scope => (
                    <label key={scope} className="flex items-center gap-2 text-sm text-gray-700">
                      <input
                        type="checkbox"
                        checked={newKeyScopes.includes(scope)}
                        onChange={e => setNewKeyScopes(prev => e.target.checked ? [...prev, scope] : prev.filter(s => s !== scope))}
                      />
                      {scope}
                    </label>
                  ))}
                </div>
                {generatedApiKey && (
                  <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 mb-3">
                    <p className="text-xs text-amber-700 mb-1">Copie agora. Esta chave aparece somente uma vez.</p>
                    <p className="text-sm font-mono break-all text-amber-900">{generatedApiKey}</p>
                  </div>
                )}
                <div className="space-y-2">
                  {apiKeys.map(key => (
                    <div key={key.id} className="border border-gray-200 rounded-lg p-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                      <div>
                        <p className="text-sm font-medium text-gray-900">{key.name}</p>
                        <p className="text-xs text-gray-500">Prefixo: {key.key_prefix} • Ultimo uso: {key.last_used_at ? new Date(key.last_used_at).toLocaleString('pt-BR') : 'Nunca'}</p>
                      </div>
                      <button onClick={() => revokeApiKey(key.id)} className="btn-danger text-sm">Revogar</button>
                    </div>
                  ))}
                  {apiKeys.length === 0 && <p className="text-sm text-gray-400">Nenhuma API key criada.</p>}
                </div>
              </div>
            </div>
          )}

          {tab === 'advanced' && (
            <div className="card p-6 space-y-4">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Configurações Avançadas</h2>
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
                <p className="text-sm text-amber-800"><strong>Biometria Facial:</strong> Para habilitar, configure a chave da API BluePoint nas variáveis de ambiente (BLUEPOINT_API_KEY).</p>
                <p className="text-xs text-amber-600 mt-1">Endpoint: https://bluepoint-api.bluetechfilms.com.br/api/v1/biometria/</p>
              </div>
              <div className="bg-blue-50 border border-blue-200 rounded-xl p-4">
                <p className="text-sm text-blue-800"><strong>MinIO (Armazenamento):</strong> Documentos são armazenados no MinIO local. Para produção, configure o endpoint midias.bluetechfilms.com.br.</p>
              </div>
              <div className="bg-gray-50 border rounded-xl p-4">
                <p className="text-sm text-gray-700"><strong>Plano:</strong> {org.plan || 'Professional'}</p>
                <p className="text-sm text-gray-700"><strong>Documentos no mês:</strong> {org.documents_used_month || 0} / {org.max_documents_month || '∞'}</p>
                <p className="text-sm text-gray-700"><strong>Máx. usuários:</strong> {org.max_users || '∞'}</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {showWebhookModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowWebhookModal(false)}>
          <div className="bg-white rounded-2xl w-full max-w-md p-6 animate-slide-in" onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold mb-4">Novo Webhook</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">URL *</label>
                <input type="url" value={whForm.url} onChange={e => setWhForm({ ...whForm, url: e.target.value })} className="input-field" placeholder="https://..." />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Eventos</label>
                <div className="grid grid-cols-2 gap-2">
                  {webhookEvents.map(ev => (
                    <label key={ev} className="flex items-center gap-2 text-sm cursor-pointer">
                      <input type="checkbox" checked={whForm.events.includes(ev)}
                        onChange={e => setWhForm({ ...whForm, events: e.target.checked ? [...whForm.events, ev] : whForm.events.filter(x => x !== ev) })}
                        className="rounded border-gray-300" />
                      {ev}
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowWebhookModal(false)} className="btn-secondary flex-1">Cancelar</button>
              <button onClick={createWebhook} className="btn-primary flex-1">Criar</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
