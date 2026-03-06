import { useState, useEffect } from 'react';
import { templatesAPI } from '../services/api';
import { FileSignature, Plus, Search, Trash2, Loader2, X } from 'lucide-react';
import toast from 'react-hot-toast';

export default function TemplatesPage() {
  const [templates, setTemplates] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ name: '', description: '', category: '', default_message: '' });
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    templatesAPI.list({ search: search || undefined }).then(r => { setTemplates(r.data); setLoading(false); }).catch(() => setLoading(false));
  };
  useEffect(() => { load(); }, []);

  const handleCreate = async () => {
    if (!form.name) return toast.error('Nome é obrigatório');
    setSaving(true);
    try {
      const fd = new FormData();
      fd.append('name', form.name);
      fd.append('description', form.description);
      fd.append('category', form.category);
      fd.append('default_message', form.default_message);
      if (file) fd.append('file', file);
      await templatesAPI.create(fd);
      toast.success('Modelo criado!');
      setShowModal(false); setForm({ name: '', description: '', category: '', default_message: '' }); setFile(null);
      load();
    } catch (e: any) { toast.error(e.response?.data?.error || 'Erro'); }
    setSaving(false);
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Excluir modelo "${name}"?`)) return;
    try { await templatesAPI.delete(id); toast.success('Modelo excluído'); load(); } catch { toast.error('Erro ao excluir'); }
  };

  const categories = ['Contrato', 'NDA', 'Proposta', 'RH', 'Financeiro', 'Jurídico', 'Outro'];
  const filtered = templates.filter(t => !search || t.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="animate-fade-in page-shell">
      <div className="page-header">
        <div>
          <h1 className="section-title">Modelos</h1>
          <p className="section-subtitle">Templates reutilizáveis para documentos</p>
        </div>
        <button onClick={() => setShowModal(true)} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
          <Plus className="w-4 h-4" /> Novo Modelo
        </button>
      </div>

      {/* Search */}
      <div className="relative mb-6">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input type="text" value={search} onChange={e => { setSearch(e.target.value); }} onKeyDown={e => e.key === 'Enter' && load()}
          placeholder="Buscar modelos..." className="input-field pl-10 w-full sm:max-w-md" />
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>
      ) : filtered.length === 0 ? (
        <div className="card empty-state">
          <FileSignature className="empty-state-icon" />
          <p className="empty-state-title">Nenhum modelo encontrado</p>
          <p className="empty-state-text">Crie um modelo para agilizar a criação de documentos</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {filtered.map(t => (
            <div key={t.id} className="card-glass p-5 hover:border-brand-200 transition-all">
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 bg-brand-50 rounded-lg flex items-center justify-center">
                  <FileSignature className="w-5 h-5 text-brand-600" />
                </div>
                <div className="flex gap-1">
                  <button onClick={() => handleDelete(t.id, t.name)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-red-50 rounded text-gray-400 hover:text-red-500">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
              <h3 className="font-semibold text-gray-900 mb-1">{t.name}</h3>
              {t.description && <p className="text-sm text-gray-500 mb-2 line-clamp-2">{t.description}</p>}
              <div className="flex items-center gap-2 mt-3">
                {t.category && <span className="badge bg-brand-50 text-brand-700">{t.category}</span>}
                <span className="badge bg-gray-100 text-gray-600">{t.use_count || 0} usos</span>
                <span className={`badge ${t.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>
                  {t.status === 'active' ? 'Ativo' : 'Inativo'}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Create Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-panel max-w-md" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Novo Modelo</h3>
              <button onClick={() => setShowModal(false)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded"><X className="w-5 h-5" /></button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="form-label">Nome *</label>
                <input type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="input-field" placeholder="Ex: Contrato de Prestação de Serviço" />
              </div>
              <div>
                <label className="form-label">Categoria</label>
                <select value={form.category} onChange={e => setForm({ ...form, category: e.target.value })} className="input-field">
                  <option value="">Selecione...</option>
                  {categories.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
              <div>
                <label className="form-label">Descrição</label>
                <textarea value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} className="input-field" rows={2} />
              </div>
              <div>
                <label className="form-label">Mensagem padrão</label>
                <textarea value={form.default_message} onChange={e => setForm({ ...form, default_message: e.target.value })} className="input-field" rows={2} placeholder="Mensagem enviada junto ao documento" />
              </div>
              <div>
                <label className="form-label">Arquivo modelo (PDF)</label>
                <input type="file" accept=".pdf,.docx" onChange={e => setFile(e.target.files?.[0] || null)} className="input-field text-sm" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowModal(false)} className="btn-secondary flex-1">Cancelar</button>
              <button onClick={handleCreate} disabled={saving} className="btn-primary flex-1 flex items-center justify-center gap-2">
                {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
                {saving ? 'Criando...' : 'Criar Modelo'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
