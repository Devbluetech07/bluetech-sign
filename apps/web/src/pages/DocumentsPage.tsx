import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { documentsAPI, foldersAPI } from '../services/api';
import { FileText, Plus, CheckCircle, Clock, XCircle, Send, AlertCircle, Trash2, Eye, MoreVertical, ChevronLeft, ChevronRight, Loader2, FolderOpen } from 'lucide-react';
import toast from 'react-hot-toast';

const statusConfig: any = {
  draft: { label: 'Rascunho', color: 'bg-gray-100 text-gray-700', icon: FileText },
  pending: { label: 'Pendente', color: 'bg-yellow-100 text-yellow-700', icon: Clock },
  in_progress: { label: 'Em andamento', color: 'bg-blue-100 text-blue-700', icon: Send },
  completed: { label: 'Concluído', color: 'bg-emerald-100 text-emerald-700', icon: CheckCircle },
  cancelled: { label: 'Cancelado', color: 'bg-red-100 text-red-700', icon: XCircle },
  expired: { label: 'Expirado', color: 'bg-orange-100 text-orange-700', icon: AlertCircle },
  rejected: { label: 'Rejeitado', color: 'bg-rose-100 text-rose-700', icon: XCircle },
};

export default function DocumentsPage() {
  const [documents, setDocuments] = useState<any[]>([]);
  const [folders, setFolders] = useState<any[]>([]);
  const [pagination, setPagination] = useState({ total: 0, page: 1, pages: 1 });
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [folderFilter, setFolderFilter] = useState('');
  const [menuOpen, setMenuOpen] = useState<string | null>(null);

  const loadDocuments = async (page = 1) => {
    setLoading(true);
    try {
      const params: any = { page, limit: 20 };
      if (statusFilter) params.status = statusFilter;
      if (folderFilter) params.folder_id = folderFilter;
      const { data } = await documentsAPI.list(params);
      setDocuments(data.documents);
      setPagination(data.pagination);
    } catch { toast.error('Erro ao carregar documentos'); }
    setLoading(false);
  };

  useEffect(() => { loadDocuments(); foldersAPI.list().then(r => setFolders(r.data)).catch(() => {}); }, [statusFilter, folderFilter]);

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Excluir "${name}"?`)) return;
    try { await documentsAPI.delete(id); toast.success('Documento excluído'); loadDocuments(); } catch { toast.error('Erro ao excluir'); }
  };

  const handleCancel = async (id: string) => {
    const reason = prompt('Motivo do cancelamento:');
    if (reason === null) return;
    try { await documentsAPI.cancel(id, { reason }); toast.success('Documento cancelado'); loadDocuments(); } catch { toast.error('Erro ao cancelar'); }
  };

  const getProgressClass = (percent: number) => {
    if (percent >= 95) return 'w-full';
    if (percent >= 85) return 'w-11/12';
    if (percent >= 75) return 'w-10/12';
    if (percent >= 65) return 'w-8/12';
    if (percent >= 55) return 'w-7/12';
    if (percent >= 45) return 'w-6/12';
    if (percent >= 35) return 'w-5/12';
    if (percent >= 25) return 'w-4/12';
    if (percent >= 15) return 'w-3/12';
    if (percent >= 5) return 'w-2/12';
    return 'w-1/12';
  };

  return (
    <div className="animate-fade-in page-shell">
      <div className="page-header">
        <div>
          <h1 className="section-title">Documentos</h1>
          <p className="section-subtitle">{pagination.total} documento(s) encontrado(s)</p>
        </div>
        <Link to="/documents/new" className="btn-primary flex items-center gap-2 w-full sm:w-auto justify-center"><Plus className="w-4 h-4" /> Novo Documento</Link>
      </div>

      <div className="filter-bar">
        <div className="filter-bar-inner">
          <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="input-field sm:w-48">
            <option value="">Todos os status</option>
            {Object.entries(statusConfig).map(([k, v]: any) => <option key={k} value={k}>{v.label}</option>)}
          </select>
          <select value={folderFilter} onChange={e => setFolderFilter(e.target.value)} className="input-field sm:w-48">
            <option value="">Todas as pastas</option>
            {folders.map((f: any) => <option key={f.id} value={f.id}>{f.name}</option>)}
          </select>
        </div>
      </div>

      <div className="table-container">
        {loading ? (
          <div className="flex items-center justify-center py-20"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>
        ) : documents.length === 0 ? (
          <div className="empty-state">
            <FileText className="empty-state-icon" />
            <h3 className="empty-state-title">Nenhum documento encontrado</h3>
            <p className="empty-state-text">Comece criando seu primeiro documento</p>
            <Link to="/documents/new" className="btn-primary inline-flex items-center gap-2"><Plus className="w-4 h-4" /> Criar Documento</Link>
          </div>
        ) : (
          <>
          <div className="space-y-3 p-4 md:hidden">
            {documents.map((doc: any) => {
              const sc = statusConfig[doc.status] || statusConfig.draft;
              const Icon = sc.icon;
              const pct = doc.total_signers ? (doc.signed_count / doc.total_signers) * 100 : 0;
              return (
                <div key={doc.id} className="border border-gray-100 rounded-xl p-4">
                  <Link to={`/documents/${doc.id}`} className="block">
                    <p className="text-sm font-semibold text-gray-900">{doc.name}</p>
                    <p className="text-xs text-gray-400 mt-0.5 break-all">{doc.file_name}</p>
                  </Link>
                  <div className="mt-3 flex items-center gap-2 flex-wrap">
                    <span className={`badge ${sc.color}`}><Icon className="w-3 h-3 mr-1" />{sc.label}</span>
                    <span className="text-xs text-gray-500">{new Date(doc.created_at).toLocaleDateString('pt-BR')}</span>
                  </div>
                  <div className="mt-3 flex items-center gap-2">
                    <div className="w-24 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                      <div className={`h-full bg-emerald-500 rounded-full ${getProgressClass(pct)}`} />
                    </div>
                    <span className="text-xs text-gray-500">{doc.signed_count || 0}/{doc.total_signers || 0}</span>
                  </div>
                  <div className="mt-3 flex items-center gap-2">
                    <Link to={`/documents/${doc.id}`} className="btn-secondary flex-1 inline-flex items-center justify-center gap-1 text-xs">
                      <Eye className="w-4 h-4" /> Detalhes
                    </Link>
                    {doc.status === 'in_progress' && (
                      <button onClick={() => handleCancel(doc.id)} className="btn-secondary flex-1 text-xs">Cancelar</button>
                    )}
                    {(doc.status === 'draft' || doc.status === 'cancelled') && (
                      <button onClick={() => handleDelete(doc.id, doc.name)} className="btn-danger flex-1 text-xs">Excluir</button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="hidden md:block mobile-table-scroll">
            <table className="min-w-[920px]">
              <thead>
                <tr>
                  <th>Documento</th>
                  <th className="hidden md:table-cell">Pasta</th>
                  <th>Status</th>
                  <th>Assinaturas</th>
                  <th className="hidden sm:table-cell">Criado em</th>
                  <th className="text-right">Ações</th>
                </tr>
              </thead>
              <tbody>
                {documents.map((doc: any) => {
                  const sc = statusConfig[doc.status] || statusConfig.draft;
                  const Icon = sc.icon;
                  return (
                    <tr key={doc.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                      <td className="py-3 px-4">
                        <Link to={`/documents/${doc.id}`} className="group">
                          <p className="text-sm font-medium text-gray-900 group-hover:text-brand-600 transition-colors">{doc.name}</p>
                          <p className="text-xs text-gray-400 mt-0.5">{doc.file_name}</p>
                        </Link>
                      </td>
                      <td className="py-3 px-4 hidden md:table-cell">
                        {doc.folder_name ? <span className="text-xs text-gray-500 flex items-center gap-1"><FolderOpen className="w-3 h-3" />{doc.folder_name}</span> : <span className="text-xs text-gray-300">—</span>}
                      </td>
                      <td className="py-3 px-4"><span className={`badge ${sc.color}`}><Icon className="w-3 h-3 mr-1" />{sc.label}</span></td>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2">
                          <div className="w-16 h-1.5 bg-gray-200 rounded-full overflow-hidden">
                            <div className={`h-full bg-emerald-500 rounded-full transition-all ${getProgressClass(doc.total_signers ? (doc.signed_count / doc.total_signers) * 100 : 0)}`} />
                          </div>
                          <span className="text-xs text-gray-500">{doc.signed_count || 0}/{doc.total_signers || 0}</span>
                        </div>
                      </td>
                      <td className="py-3 px-4 hidden sm:table-cell"><span className="text-sm text-gray-500">{new Date(doc.created_at).toLocaleDateString('pt-BR')}</span></td>
                      <td className="py-3 px-4 text-right">
                        <div className="relative inline-block">
                          <button onClick={() => setMenuOpen(menuOpen === doc.id ? null : doc.id)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg"><MoreVertical className="w-4 h-4 text-gray-400" /></button>
                          {menuOpen === doc.id && (
                            <div className="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-xl border border-gray-100 py-1 z-20 w-48 animate-fade-in" onMouseLeave={() => setMenuOpen(null)}>
                              <Link to={`/documents/${doc.id}`} className="flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50"><Eye className="w-4 h-4" /> Ver detalhes</Link>
                              {doc.status === 'in_progress' && <button onClick={() => handleCancel(doc.id)} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-orange-600 hover:bg-orange-50"><XCircle className="w-4 h-4" /> Cancelar</button>}
                              {(doc.status === 'draft' || doc.status === 'cancelled') && <button onClick={() => handleDelete(doc.id, doc.name)} className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-600 hover:bg-red-50"><Trash2 className="w-4 h-4" /> Excluir</button>}
                            </div>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          </>
        )}

        {/* Pagination */}
        {pagination.pages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100">
            <span className="text-sm text-gray-500">Página {pagination.page} de {pagination.pages}</span>
            <div className="flex gap-2">
              <button onClick={() => loadDocuments(pagination.page - 1)} disabled={pagination.page <= 1} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg disabled:opacity-30"><ChevronLeft className="w-4 h-4" /></button>
              <button onClick={() => loadDocuments(pagination.page + 1)} disabled={pagination.page >= pagination.pages} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg disabled:opacity-30"><ChevronRight className="w-4 h-4" /></button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
