import { useState, useEffect } from 'react';
import { contactsAPI } from '../services/api';
import { BookUser, Plus, Search, Edit, Trash2, Loader2, X } from 'lucide-react';
import toast from 'react-hot-toast';

export default function ContactsPage() {
  const [contacts, setContacts] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [showModal, setShowModal] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', email: '', cpf: '', phone: '', company: '', position: '', notes: '' });
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    contactsAPI.list({ search: search || undefined, page, limit: 50 })
      .then(r => { setContacts(r.data.contacts); setTotal(r.data.total); setLoading(false); })
      .catch(() => setLoading(false));
  };
  useEffect(() => { load(); }, [page]);

  const handleSave = async () => {
    if (!form.name || !form.email) return toast.error('Nome e email são obrigatórios');
    setSaving(true);
    try {
      if (editId) { await contactsAPI.update(editId, form); toast.success('Contato atualizado'); }
      else { await contactsAPI.create(form); toast.success('Contato criado'); }
      setShowModal(false); setEditId(null); resetForm(); load();
    } catch (e: any) { toast.error(e.response?.data?.error || 'Erro'); }
    setSaving(false);
  };

  const resetForm = () => setForm({ name: '', email: '', cpf: '', phone: '', company: '', position: '', notes: '' });
  const handleEdit = (c: any) => { setForm({ name: c.name, email: c.email, cpf: c.cpf || '', phone: c.phone || '', company: c.company || '', position: c.position || '', notes: c.notes || '' }); setEditId(c.id); setShowModal(true); };
  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Excluir contato "${name}"?`)) return;
    try { await contactsAPI.delete(id); toast.success('Contato excluído'); load(); } catch { toast.error('Erro'); }
  };

  return (
    <div className="animate-fade-in page-shell">
      <div className="page-header">
        <div>
          <h1 className="section-title">Contatos</h1>
          <p className="section-subtitle">{total} contatos na agenda</p>
        </div>
        <button onClick={() => { setEditId(null); resetForm(); setShowModal(true); }} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
          <Plus className="w-4 h-4" /> Novo Contato
        </button>
      </div>

      <div className="relative mb-6">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input type="text" value={search} onChange={e => setSearch(e.target.value)} onKeyDown={e => e.key === 'Enter' && load()}
          placeholder="Buscar por nome, email ou CPF..." className="input-field pl-10 w-full sm:max-w-md" />
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>
      ) : contacts.length === 0 ? (
        <div className="card empty-state">
          <BookUser className="empty-state-icon" />
          <p className="empty-state-title">Nenhum contato encontrado</p>
          <p className="empty-state-text">Adicione contatos para facilitar o envio de documentos</p>
        </div>
      ) : (
        <div className="table-container">
          <div className="space-y-3 p-4 md:hidden">
            {contacts.map((c) => (
              <div key={c.id} className="border border-gray-100 rounded-xl p-4">
                <p className="text-sm font-semibold text-gray-900">{c.name}</p>
                <p className="text-xs text-gray-500 break-all">{c.email}</p>
                {c.cpf && <p className="text-xs text-gray-400 mt-1">{c.cpf}</p>}
                <div className="mt-3 flex gap-2">
                  <button onClick={() => handleEdit(c)} className="btn-secondary flex-1 text-xs">Editar</button>
                  <button onClick={() => handleDelete(c.id, c.name)} className="btn-danger flex-1 text-xs">Excluir</button>
                </div>
              </div>
            ))}
          </div>

          <div className="hidden md:block mobile-table-scroll">
          <table className="min-w-[860px]">
            <thead>
              <tr>
                <th>Nome</th>
                <th className="hidden md:table-cell">Email</th>
                <th className="hidden lg:table-cell">Telefone</th>
                <th className="hidden lg:table-cell">Empresa</th>
                <th className="text-right">Ações</th>
              </tr>
            </thead>
            <tbody>
              {contacts.map(c => (
                <tr key={c.id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-brand-100 rounded-full flex items-center justify-center text-brand-600 font-semibold text-sm">
                        {c.name?.charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <p className="font-medium text-gray-900 text-sm">{c.name}</p>
                        {c.cpf && <p className="text-xs text-gray-400">{c.cpf}</p>}
                      </div>
                    </div>
                  </td>
                  <td className="py-3 px-4 hidden md:table-cell"><span className="text-sm text-gray-600">{c.email}</span></td>
                  <td className="py-3 px-4 hidden lg:table-cell"><span className="text-sm text-gray-600">{c.phone || '-'}</span></td>
                  <td className="py-3 px-4 hidden lg:table-cell"><span className="text-sm text-gray-600">{c.company || '-'}</span></td>
                  <td className="py-3 px-4 text-right">
                    <button onClick={() => handleEdit(c)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded text-gray-400 hover:text-brand-600"><Edit className="w-4 h-4" /></button>
                    <button onClick={() => handleDelete(c.id, c.name)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-red-50 rounded text-gray-400 hover:text-red-500 ml-1"><Trash2 className="w-4 h-4" /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          </div>
        </div>
      )}

      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-panel max-w-lg" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editId ? 'Editar Contato' : 'Novo Contato'}</h3>
              <button onClick={() => setShowModal(false)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded"><X className="w-5 h-5" /></button>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">Nome completo *</label>
                <input type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="input-field" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
                <input type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} className="input-field" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">CPF</label>
                <input type="text" value={form.cpf} onChange={e => setForm({ ...form, cpf: e.target.value })} className="input-field" placeholder="000.000.000-00" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Telefone</label>
                <input type="text" value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} className="input-field" placeholder="(00) 00000-0000" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Empresa</label>
                <input type="text" value={form.company} onChange={e => setForm({ ...form, company: e.target.value })} className="input-field" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Cargo</label>
                <input type="text" value={form.position} onChange={e => setForm({ ...form, position: e.target.value })} className="input-field" />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">Observações</label>
                <textarea value={form.notes} onChange={e => setForm({ ...form, notes: e.target.value })} className="input-field" rows={2} />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowModal(false)} className="btn-secondary flex-1">Cancelar</button>
              <button onClick={handleSave} disabled={saving} className="btn-primary flex-1">{saving ? 'Salvando...' : 'Salvar'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
