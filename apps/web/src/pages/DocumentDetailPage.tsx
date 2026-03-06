import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { documentsAPI } from '../services/api';
import { ArrowLeft, FileText, Send, XCircle, Download, Bell, CheckCircle, Clock, AlertCircle, Eye, Loader2, Copy, Pencil } from 'lucide-react';
import toast from 'react-hot-toast';

const statusConfig: any = {
  draft: { label: 'Rascunho', color: 'bg-gray-100 text-gray-700', dot: 'bg-gray-400' },
  pending: { label: 'Pendente', color: 'bg-yellow-100 text-yellow-700', dot: 'bg-yellow-400' },
  in_progress: { label: 'Em andamento', color: 'bg-blue-100 text-blue-700', dot: 'bg-blue-400' },
  completed: { label: 'Concluído', color: 'bg-emerald-100 text-emerald-700', dot: 'bg-emerald-400' },
  cancelled: { label: 'Cancelado', color: 'bg-red-100 text-red-700', dot: 'bg-red-400' },
  expired: { label: 'Expirado', color: 'bg-orange-100 text-orange-700', dot: 'bg-orange-400' },
  rejected: { label: 'Rejeitado', color: 'bg-rose-100 text-rose-700', dot: 'bg-rose-400' },
};

const signerStatusConfig: any = {
  pending: { label: 'Pendente', color: 'text-gray-500', icon: Clock },
  sent: { label: 'Enviado', color: 'text-blue-500', icon: Send },
  opened: { label: 'Visualizado', color: 'text-amber-500', icon: Eye },
  signed: { label: 'Assinado', color: 'text-emerald-600', icon: CheckCircle },
  rejected: { label: 'Recusado', color: 'text-red-500', icon: XCircle },
  expired: { label: 'Expirado', color: 'text-orange-500', icon: AlertCircle },
};

const auditIcons: any = {
  document_uploaded: '📄', document_sent: '📤', document_completed: '✅', document_cancelled: '❌', document_downloaded: '⬇️',
  signer_added: '👤', signer_notified: '🔔', signer_opened: '👁️', signer_signed: '✍️', signer_rejected: '🚫', signer_removed: '🗑️',
  biometria_verificada: '📷', biometria_falhou: '⚠️', user_login: '🔐',
};

export default function DocumentDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [doc, setDoc] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('signers');

  const load = async () => {
    try { const { data } = await documentsAPI.getById(id!); setDoc(data); } catch { toast.error('Documento não encontrado'); navigate('/documents'); }
    setLoading(false);
  };

  useEffect(() => { load(); }, [id]);

  const handleSend = async () => { try { await documentsAPI.send(id!); toast.success('Documento enviado!'); load(); } catch (e: any) { toast.error(e.response?.data?.error || 'Erro'); } };
  const handleCancel = async () => { const r = prompt('Motivo:'); if (r === null) return; try { await documentsAPI.cancel(id!, { reason: r }); toast.success('Cancelado'); load(); } catch { toast.error('Erro'); } };
  const handleDownload = async () => { try { const { data } = await documentsAPI.download(id!); window.open(data.url, '_blank'); } catch { toast.error('Erro ao baixar'); } };
  const handleReminder = async (signerId?: string) => { try { await documentsAPI.sendReminder(id!, signerId ? { signer_id: signerId } : {}); toast.success('Lembrete enviado'); } catch { toast.error('Erro'); } };
  const copySigningLink = (token: string) => { navigator.clipboard.writeText(`${window.location.origin}/sign/${token}`); toast.success('Link copiado!'); };

  if (loading) return <div className="flex items-center justify-center h-64"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>;
  if (!doc) return null;

  const sc = statusConfig[doc.status] || statusConfig.draft;

  return (
    <div className="animate-fade-in page-shell">
      <button onClick={() => navigate('/documents')} className="min-h-11 inline-flex items-center gap-2 text-gray-500 hover:text-gray-700 mb-6 text-sm"><ArrowLeft className="w-4 h-4" /> Documentos</button>

      {/* Header */}
      <div className="card-glass p-6 mb-6">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-brand-50 rounded-xl flex items-center justify-center"><FileText className="w-6 h-6 text-brand-600" /></div>
            <div className="min-w-0">
              <h1 className="text-xl font-bold text-gray-900 break-words">{doc.name}</h1>
              <div className="flex flex-wrap items-center gap-2 sm:gap-3 mt-1">
                <span className={`badge ${sc.color}`}><span className={`w-2 h-2 rounded-full ${sc.dot} mr-1.5`} />{sc.label}</span>
                <span className="text-sm text-gray-400">·</span>
                <span className="text-sm text-gray-500 break-all">{doc.file_name}</span>
                <span className="text-sm text-gray-400">·</span>
                <span className="text-sm text-gray-500">{new Date(doc.created_at).toLocaleDateString('pt-BR')}</span>
              </div>
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:flex gap-2 w-full lg:w-auto">
            <button onClick={handleDownload} className="btn-secondary flex items-center justify-center gap-2 text-sm"><Download className="w-4 h-4" /> Baixar</button>
            {doc.status === 'draft' && <button onClick={() => navigate(`/documents/${doc.id}/edit`)} className="btn-secondary flex items-center justify-center gap-2 text-sm"><Pencil className="w-4 h-4" /> Editar Campos</button>}
            {doc.status === 'draft' && <button onClick={handleSend} className="btn-primary flex items-center justify-center gap-2 text-sm"><Send className="w-4 h-4" /> Enviar</button>}
            {doc.status === 'in_progress' && <button onClick={() => handleReminder()} className="btn-secondary flex items-center justify-center gap-2 text-sm"><Bell className="w-4 h-4" /> Lembrete</button>}
            {(doc.status === 'in_progress' || doc.status === 'pending') && <button onClick={handleCancel} className="btn-danger flex items-center justify-center gap-2 text-sm"><XCircle className="w-4 h-4" /> Cancelar</button>}
          </div>
        </div>
        {doc.message && <div className="mt-4 p-3 bg-blue-50 rounded-lg text-sm text-blue-700 border border-blue-100">💬 {doc.message}</div>}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-gray-100 rounded-xl p-1 overflow-x-auto">
        {[{ k: 'signers', l: 'Signatários', c: doc.signers?.length }, { k: 'audit', l: 'Histórico', c: doc.audit_log?.length }].map(t => (
          <button key={t.k} onClick={() => setTab(t.k)} className={`min-h-11 min-w-[9rem] sm:min-w-0 sm:flex-1 py-2.5 px-4 rounded-lg text-sm font-medium transition-all ${tab === t.k ? 'bg-white text-brand-600 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.l} {t.c ? `(${t.c})` : ''}
          </button>
        ))}
      </div>

      {/* Signatários */}
      {tab === 'signers' && (
        <div className="space-y-3">
          {(doc.signers || []).map((s: any, i: number) => {
            const ss = signerStatusConfig[s.status] || signerStatusConfig.pending;
            const SSIcon = ss.icon;
            return (
              <div key={s.id} className="card p-4 sm:p-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="flex items-start sm:items-center gap-4 min-w-0">
                    <div className="w-10 h-10 bg-brand-50 rounded-full flex items-center justify-center text-brand-600 font-bold text-sm">{i + 1}</div>
                    <div className="min-w-0">
                      <p className="font-medium text-gray-900">{s.name}</p>
                      <p className="text-sm text-gray-500 break-all">{s.email} {s.cpf ? `· CPF: ${s.cpf}` : ''}</p>
                      <div className="flex flex-wrap items-center gap-2 sm:gap-3 mt-1">
                        <span className={`text-xs font-medium ${ss.color} flex items-center gap-1`}><SSIcon className="w-3 h-3" />{ss.label}</span>
                        <span className="text-xs text-gray-400">Tipo: {s.signature_type}</span>
                        <span className="text-xs text-gray-400">Auth: {s.auth_method}</span>
                        {s.metadata?.require_face_photo && <span className="badge bg-blue-100 text-blue-700">🤳 Biometria</span>}
                        {s.metadata?.require_document_photo && <span className="badge bg-violet-100 text-violet-700">🪪 Documento</span>}
                        {s.metadata?.require_selfie && <span className="badge bg-cyan-100 text-cyan-700">📸 Selfie</span>}
                        {s.metadata?.require_handwritten && <span className="badge bg-amber-100 text-amber-700">✍ Manuscrita</span>}
                        {s.signed_at && <span className="text-xs text-emerald-600">Assinado: {new Date(s.signed_at).toLocaleString('pt-BR')}</span>}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {s.access_token && <button onClick={() => copySigningLink(s.access_token)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg" title="Copiar link"><Copy className="w-4 h-4 text-gray-400" /></button>}
                    {['sent', 'opened'].includes(s.status) && <button onClick={() => handleReminder(s.id)} className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-blue-50 rounded-lg" title="Enviar lembrete"><Bell className="w-4 h-4 text-blue-500" /></button>}
                  </div>
                </div>
                {s.signed_ip && <div className="mt-3 pt-3 border-t border-gray-100 text-xs text-gray-400">IP: {s.signed_ip} {s.biometria_verified && `· Biometria: ✅ Score: ${s.biometria_score}%`}</div>}
              </div>
            );
          })}
          {(!doc.signers || doc.signers.length === 0) && <div className="card p-12 text-center text-gray-400">Nenhum signatário adicionado</div>}
        </div>
      )}

      {/* Audit Log */}
      {tab === 'audit' && (
        <div className="card-glass p-6">
          <div className="space-y-0">
            {(doc.audit_log || []).map((log: any, i: number) => (
              <div key={log.id} className="flex gap-4 pb-6 relative">
                {i < (doc.audit_log?.length || 0) - 1 && <div className="absolute left-5 top-10 bottom-0 w-px bg-gray-200" />}
                <div className="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0 text-lg z-10">{auditIcons[log.action] || '📌'}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-800">{log.description}</p>
                  <div className="flex items-center gap-3 mt-1">
                    <span className="text-xs text-gray-400">{new Date(log.created_at).toLocaleString('pt-BR')}</span>
                    {log.user_name && <span className="text-xs text-gray-400">por {log.user_name}</span>}
                    {log.ip_address && <span className="text-xs text-gray-300">IP: {log.ip_address}</span>}
                  </div>
                </div>
              </div>
            ))}
            {(!doc.audit_log || doc.audit_log.length === 0) && <div className="text-center py-8 text-gray-400">Nenhum registro ainda</div>}
          </div>
        </div>
      )}
    </div>
  );
}
