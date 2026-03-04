import { useState, useEffect } from 'react';
import { foldersAPI } from '../services/api';
import { FolderOpen, Plus, Edit, Trash2, Loader2, X, FileText } from 'lucide-react';
import toast from 'react-hot-toast';

const COLORS = ['#1E40AF', '#059669', '#D97706', '#7C3AED', '#DC2626', '#0891B2', '#4F46E5', '#EA580C'];
const COLOR_CLASSES: Record<string, { iconBg: string; iconText: string; swatch: string }> = {
  '#1E40AF': { iconBg: 'bg-blue-100', iconText: 'text-blue-700', swatch: 'bg-blue-700' },
  '#059669': { iconBg: 'bg-emerald-100', iconText: 'text-emerald-700', swatch: 'bg-emerald-600' },
  '#D97706': { iconBg: 'bg-amber-100', iconText: 'text-amber-700', swatch: 'bg-amber-600' },
  '#7C3AED': { iconBg: 'bg-violet-100', iconText: 'text-violet-700', swatch: 'bg-violet-600' },
  '#DC2626': { iconBg: 'bg-red-100', iconText: 'text-red-700', swatch: 'bg-red-600' },
  '#0891B2': { iconBg: 'bg-cyan-100', iconText: 'text-cyan-700', swatch: 'bg-cyan-600' },
  '#4F46E5': { iconBg: 'bg-indigo-100', iconText: 'text-indigo-700', swatch: 'bg-indigo-600' },
  '#EA580C': { iconBg: 'bg-orange-100', iconText: 'text-orange-700', swatch: 'bg-orange-600' },
};

export default function FoldersPage() {
  const [folders, setFolders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', color: '#1E40AF', description: '' });
  const [saving, setSaving] = useState(false);

  const load = () => { foldersAPI.list().then(r => { setFolders(r.data); setLoading(false); }).catch(() => setLoading(false)); };
  useEffect(() => { load(); }, []);

  const handleSave = async () => {
    if (!form.name) return toast.error('Nome é obrigatório');
    setSaving(true);
    try {
      if (editId) { await foldersAPI.update(editId, form); toast.success('Pasta atualizada'); }
      else { await foldersAPI.create(form); toast.success('Pasta criada'); }
      setShowModal(false); setEditId(null); setForm({ name: '', color: '#1E40AF', description: '' }); load();
    } catch (e: any) { toast.error(e.response?.data?.error || 'Erro'); }
    setSaving(false);
  };

  const handleEdit = (f: any) => { setForm({ name: f.name, color: f.color, description: f.description || '' }); setEditId(f.id); setShowModal(true); };
  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Excluir pasta "${name}"? Documentos serão movidos para fora.`)) return;
    try { await foldersAPI.delete(id); toast.success('Pasta excluída'); load(); } catch { toast.error('Erro ao excluir'); }
  };

  return (
    <div className="animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Pastas</h1>
          <p className="text-gray-500 text-sm mt-1">Organize seus documentos em pastas</p>
        </div>
        <button onClick={() => { setEditId(null); setForm({ name: '', color: '#1E40AF', description: '' }); setShowModal(true); }} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
          <Plus className="w-4 h-4" /> Nova Pasta
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>
      ) : folders.length === 0 ? (
        <div className="card p-12 text-center">
          <FolderOpen className="w-12 h-12 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500">Nenhuma pasta criada</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4">
          {folders.map(f => (
            <div key={f.id} className="card p-5 hover:border-brand-200 transition-all group cursor-pointer">
              <div className="flex items-start justify-between mb-3">
                <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${COLOR_CLASSES[f.color]?.iconBg || 'bg-brand-100'}`}>
                  <FolderOpen className={`w-5 h-5 ${COLOR_CLASSES[f.color]?.iconText || 'text-brand-700'}`} />
                </div>
                <div className="flex gap-1 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                  <button onClick={() => handleEdit(f)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded text-gray-400 hover:text-brand-600"><Edit className="w-3.5 h-3.5" /></button>
                  <button onClick={() => handleDelete(f.id, f.name)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-red-50 rounded text-gray-400 hover:text-red-500"><Trash2 className="w-3.5 h-3.5" /></button>
                </div>
              </div>
              <h3 className="font-semibold text-gray-900">{f.name}</h3>
              {f.description && <p className="text-sm text-gray-500 mt-1 line-clamp-1">{f.description}</p>}
              <div className="flex items-center gap-1 mt-3 text-gray-400 text-sm">
                <FileText className="w-3.5 h-3.5" /> {f.doc_count || 0} documentos
              </div>
            </div>
          ))}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowModal(false)}>
          <div className="bg-white rounded-2xl w-full max-w-md p-6 animate-slide-in" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold text-gray-900">{editId ? 'Editar Pasta' : 'Nova Pasta'}</h3>
              <button onClick={() => setShowModal(false)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded"><X className="w-5 h-5" /></button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nome *</label>
                <input type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="input-field" placeholder="Nome da pasta" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Cor</label>
                <div className="flex gap-2">
                  {COLORS.map(c => (
                    <button key={c} onClick={() => setForm({ ...form, color: c })}
                      className={`w-8 h-8 rounded-full transition-all ${COLOR_CLASSES[c]?.swatch || 'bg-brand-600'} ${form.color === c ? 'ring-2 ring-offset-2 ring-brand-500 scale-110' : 'hover:scale-105'}`} />
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                <textarea value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} className="input-field" rows={2} />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowModal(false)} className="btn-secondary flex-1">Cancelar</button>
              <button onClick={handleSave} disabled={saving} className="btn-primary flex-1">
                {saving ? 'Salvando...' : editId ? 'Salvar' : 'Criar'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
