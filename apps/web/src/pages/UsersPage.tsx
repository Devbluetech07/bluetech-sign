import { useState, useEffect } from 'react';
import { usersAPI } from '../services/api';
import { Plus, Edit, Trash2, Loader2, X } from 'lucide-react';
import toast from 'react-hot-toast';

const ROLES: Record<string, { label: string; color: string }> = {
  admin: { label: 'Administrador', color: 'bg-red-100 text-red-700' },
  manager: { label: 'Gerente', color: 'bg-purple-100 text-purple-700' },
  operator: { label: 'Operador', color: 'bg-blue-100 text-blue-700' },
  viewer: { label: 'Visualizador', color: 'bg-gray-100 text-gray-700' },
};

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', email: '', password: '', cpf: '', phone: '', role: 'operator' });
  const [saving, setSaving] = useState(false);

  const load = () => { usersAPI.list().then(r => { setUsers(r.data); setLoading(false); }).catch(() => setLoading(false)); };
  useEffect(() => { load(); }, []);

  const handleSave = async () => {
    if (!form.name || !form.email) return toast.error('Nome e email obrigatórios');
    setSaving(true);
    try {
      if (editId) { await usersAPI.update(editId, { name: form.name, phone: form.phone, role: form.role }); toast.success('Usuário atualizado'); }
      else { await usersAPI.create(form); toast.success('Usuário criado'); }
      setShowModal(false); setEditId(null); load();
    } catch (e: any) { toast.error(e.response?.data?.error || 'Erro'); }
    setSaving(false);
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Desativar usuário "${name}"?`)) return;
    try { await usersAPI.delete(id); toast.success('Usuário desativado'); load(); } catch { toast.error('Erro'); }
  };

  return (
    <div className="animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Usuários</h1>
          <p className="text-gray-500 text-sm mt-1">Gerenciar acesso ao sistema</p>
        </div>
        <button onClick={() => { setEditId(null); setForm({ name: '', email: '', password: '', cpf: '', phone: '', role: 'operator' }); setShowModal(true); }} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
          <Plus className="w-4 h-4" /> Novo Usuário
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>
      ) : (
        <>
          <div className="space-y-3 md:hidden">
            {users.map(u => {
              const role = ROLES[u.role] || ROLES.operator;
              return (
                <div key={u.id} className="card p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="font-semibold text-gray-900 text-sm">{u.name}</h3>
                      <p className="text-xs text-gray-500 break-all">{u.email}</p>
                    </div>
                    <span className={`badge ${role.color}`}>{role.label}</span>
                  </div>
                  <div className="text-xs text-gray-500 mt-2 space-y-1">
                    {u.phone && <p>Tel: {u.phone}</p>}
                    {u.last_login_at && <p>Último login: {new Date(u.last_login_at).toLocaleString('pt-BR')}</p>}
                  </div>
                  <div className="flex items-center justify-between pt-3 mt-3 border-t border-gray-100">
                    <span className={`badge ${u.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                      {u.status === 'active' ? 'Ativo' : 'Inativo'}
                    </span>
                    <div className="flex gap-2">
                      <button onClick={() => { setForm({ name: u.name, email: u.email, password: '', cpf: u.cpf || '', phone: u.phone || '', role: u.role }); setEditId(u.id); setShowModal(true); }}
                        className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg text-gray-400 hover:text-brand-600"><Edit className="w-4 h-4" /></button>
                      <button onClick={() => handleDelete(u.id, u.name)}
                        className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-red-50 rounded-lg text-gray-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="hidden md:block card overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[900px]">
                <thead>
                  <tr className="bg-gray-50 border-b border-gray-200">
                    <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Usuário</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Perfil</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Telefone</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Último login</th>
                    <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Status</th>
                    <th className="text-right py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => {
                    const role = ROLES[u.role] || ROLES.operator;
                    return (
                      <tr key={u.id} className="border-b border-gray-50 hover:bg-gray-50/60">
                        <td className="py-3 px-4">
                          <p className="text-sm font-medium text-gray-900">{u.name}</p>
                          <p className="text-xs text-gray-500">{u.email}</p>
                        </td>
                        <td className="py-3 px-4"><span className={`badge ${role.color}`}>{role.label}</span></td>
                        <td className="py-3 px-4 text-sm text-gray-600">{u.phone || '-'}</td>
                        <td className="py-3 px-4 text-sm text-gray-600">{u.last_login_at ? new Date(u.last_login_at).toLocaleString('pt-BR') : '-'}</td>
                        <td className="py-3 px-4">
                          <span className={`badge ${u.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                            {u.status === 'active' ? 'Ativo' : 'Inativo'}
                          </span>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex justify-end gap-2">
                            <button onClick={() => { setForm({ name: u.name, email: u.email, password: '', cpf: u.cpf || '', phone: u.phone || '', role: u.role }); setEditId(u.id); setShowModal(true); }}
                              className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg text-gray-400 hover:text-brand-600"><Edit className="w-4 h-4" /></button>
                            <button onClick={() => handleDelete(u.id, u.name)}
                              className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-red-50 rounded-lg text-gray-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                  {users.length === 0 && (
                    <tr>
                      <td colSpan={6} className="py-12 text-center text-gray-400">Nenhum usuário cadastrado</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setShowModal(false)}>
          <div className="bg-white rounded-2xl w-full max-w-md p-6 animate-slide-in" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-lg font-bold text-gray-900">{editId ? 'Editar Usuário' : 'Novo Usuário'}</h3>
              <button onClick={() => setShowModal(false)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded"><X className="w-5 h-5" /></button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nome *</label>
                <input type="text" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} className="input-field" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
                <input type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} className="input-field" disabled={!!editId} />
              </div>
              {!editId && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Senha</label>
                  <input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} className="input-field" placeholder="Deixe vazio para senha padrão" />
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Telefone</label>
                <input type="text" value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} className="input-field" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Perfil</label>
                <select value={form.role} onChange={e => setForm({ ...form, role: e.target.value })} className="input-field">
                  {Object.entries(ROLES).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
                </select>
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
