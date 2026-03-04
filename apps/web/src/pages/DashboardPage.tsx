import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { documentsAPI } from '../services/api';
import { FileText, CheckCircle, Clock, XCircle, AlertCircle, Send, Users, FileSignature, Plus, ArrowRight, Loader2 } from 'lucide-react';

const statusConfig: any = {
  draft: { label: 'Rascunho', color: 'bg-gray-100 text-gray-700', icon: FileText },
  pending: { label: 'Pendente', color: 'bg-yellow-100 text-yellow-700', icon: Clock },
  in_progress: { label: 'Em andamento', color: 'bg-blue-100 text-blue-700', icon: Send },
  completed: { label: 'Concluído', color: 'bg-green-100 text-green-700', icon: CheckCircle },
  cancelled: { label: 'Cancelado', color: 'bg-red-100 text-red-700', icon: XCircle },
  expired: { label: 'Expirado', color: 'bg-orange-100 text-orange-700', icon: AlertCircle },
  rejected: { label: 'Rejeitado', color: 'bg-red-100 text-red-700', icon: XCircle },
};

export default function DashboardPage() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    documentsAPI.stats().then(r => { setData(r.data); setLoading(false); }).catch(() => setLoading(false));
  }, []);

  if (loading) return <div className="flex items-center justify-center h-64"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>;

  const stats = data?.stats || {};
  const cards = [
    { label: 'Total de Documentos', value: stats.total_documents || 0, icon: FileText, color: 'from-brand-600 to-brand-700' },
    { label: 'Em Andamento', value: stats.in_progress_documents || 0, icon: Send, color: 'from-blue-500 to-blue-600' },
    { label: 'Concluídos', value: stats.completed_documents || 0, icon: CheckCircle, color: 'from-emerald-500 to-emerald-600' },
    { label: 'Assinaturas', value: stats.total_signed || 0, icon: FileSignature, color: 'from-violet-500 to-violet-600' },
    { label: 'Contatos', value: stats.total_contacts || 0, icon: Users, color: 'from-amber-500 to-amber-600' },
    { label: 'Modelos', value: stats.total_templates || 0, icon: FileText, color: 'from-cyan-500 to-cyan-600' },
  ];

  return (
    <div className="animate-fade-in">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-6 sm:mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <p className="text-gray-500 mt-1">Visão geral do sistema de assinatura</p>
        </div>
        <Link to="/documents/new" className="btn-primary inline-flex items-center justify-center gap-2 w-full sm:w-auto">
          <Plus className="w-4 h-4" /> Novo Documento
        </Link>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-4 mb-8">
        {cards.map((c, i) => (
          <div key={i} className={`bg-gradient-to-br ${c.color} rounded-xl p-4 text-white shadow-lg`}>
            <c.icon className="w-6 h-6 mb-2 opacity-80" />
            <p className="text-2xl font-bold">{c.value}</p>
            <p className="text-sm opacity-80 mt-0.5">{c.label}</p>
          </div>
        ))}
      </div>

      {/* Recent Documents */}
      <div className="card p-6">
        <div className="flex items-center justify-between mb-4 gap-3">
          <h2 className="text-lg font-semibold text-gray-900">Documentos Recentes</h2>
          <Link to="/documents" className="text-brand-600 hover:text-brand-700 text-sm font-medium flex items-center gap-1">
            Ver todos <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        <div className="space-y-3 md:hidden">
          {(data?.recent_documents || []).map((doc: any) => {
            const sc = statusConfig[doc.status] || statusConfig.draft;
            const Icon = sc.icon;
            return (
              <Link to={`/documents/${doc.id}`} key={doc.id} className="block border border-gray-100 rounded-xl p-4 hover:bg-gray-50 transition-colors">
                <p className="text-sm font-semibold text-gray-900 mb-2">{doc.name}</p>
                <div className="flex flex-wrap items-center gap-2 mb-2">
                  <span className={`badge ${sc.color}`}><Icon className="w-3 h-3 mr-1" />{sc.label}</span>
                  <span className="text-xs text-gray-500">Signatários: {doc.signed_count || 0}/{doc.total_signers || 0}</span>
                </div>
                <span className="text-xs text-gray-500">{new Date(doc.created_at).toLocaleDateString('pt-BR')}</span>
              </Link>
            );
          })}
          {(!data?.recent_documents || data.recent_documents.length === 0) && (
            <div className="py-10 text-center text-gray-400">Nenhum documento ainda. Crie o primeiro!</div>
          )}
        </div>

        <div className="hidden md:block overflow-x-auto">
          <table className="w-full min-w-[640px]">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Documento</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Status</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Signatários</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Data</th>
              </tr>
            </thead>
            <tbody>
              {(data?.recent_documents || []).map((doc: any) => {
                const sc = statusConfig[doc.status] || statusConfig.draft;
                const Icon = sc.icon;
                return (
                  <tr key={doc.id} className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors">
                    <td className="py-3 px-4">
                      <Link to={`/documents/${doc.id}`} className="text-sm font-medium text-gray-900 hover:text-brand-600 transition-colors">{doc.name}</Link>
                    </td>
                    <td className="py-3 px-4">
                      <span className={`badge ${sc.color}`}><Icon className="w-3 h-3 mr-1" />{sc.label}</span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-sm text-gray-600">{doc.signed_count || 0}/{doc.total_signers || 0}</span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-sm text-gray-500">{new Date(doc.created_at).toLocaleDateString('pt-BR')}</span>
                    </td>
                  </tr>
                );
              })}
              {(!data?.recent_documents || data.recent_documents.length === 0) && (
                <tr><td colSpan={4} className="py-12 text-center text-gray-400">Nenhum documento ainda. Crie o primeiro!</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
