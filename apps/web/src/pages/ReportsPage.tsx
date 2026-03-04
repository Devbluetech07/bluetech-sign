import { useState, useEffect } from 'react';
import { reportsAPI } from '../services/api';
import { Loader2 } from 'lucide-react';

const STATUS_MAP: Record<string, { label: string; color: string }> = {
  draft: { label: 'Rascunho', color: '#9CA3AF' },
  pending: { label: 'Pendente', color: '#F59E0B' },
  in_progress: { label: 'Em andamento', color: '#3B82F6' },
  completed: { label: 'Concluído', color: '#10B981' },
  cancelled: { label: 'Cancelado', color: '#EF4444' },
  expired: { label: 'Expirado', color: '#F97316' },
  rejected: { label: 'Rejeitado', color: '#DC2626' },
};

export default function ReportsPage() {
  const [tab, setTab] = useState('overview');
  const [period, setPeriod] = useState('30d');
  const [statusFilter, setStatusFilter] = useState('all');
  const [statusData, setStatusData] = useState<any[]>([]);
  const [timelineData, setTimelineData] = useState<any[]>([]);
  const [auditData, setAuditData] = useState<any[]>([]);
  const [notifData, setNotifData] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      reportsAPI.documentsByStatus().catch(() => ({ data: [] })),
      reportsAPI.signatureTimeline().catch(() => ({ data: [] })),
      reportsAPI.audit({ limit: 50 }).catch(() => ({ data: [] })),
      reportsAPI.notifications().catch(() => ({ data: [] })),
    ]).then(([s, t, a, n]) => {
      setStatusData(s.data); setTimelineData(t.data); setAuditData(a.data); setNotifData(n.data); setLoading(false);
    });
  }, []);

  const getSpanClass = (value: number) => {
    if (value >= 95) return 'col-span-12';
    if (value >= 85) return 'col-span-11';
    if (value >= 75) return 'col-span-10';
    if (value >= 65) return 'col-span-9';
    if (value >= 55) return 'col-span-8';
    if (value >= 45) return 'col-span-7';
    if (value >= 35) return 'col-span-6';
    if (value >= 25) return 'col-span-5';
    if (value >= 15) return 'col-span-4';
    if (value >= 8) return 'col-span-3';
    if (value >= 4) return 'col-span-2';
    return 'col-span-1';
  };

  const getHeightClass = (value: number) => {
    if (value >= 95) return 'h-36';
    if (value >= 85) return 'h-32';
    if (value >= 75) return 'h-28';
    if (value >= 65) return 'h-24';
    if (value >= 55) return 'h-20';
    if (value >= 45) return 'h-16';
    if (value >= 35) return 'h-14';
    if (value >= 25) return 'h-12';
    if (value >= 15) return 'h-10';
    if (value >= 8) return 'h-8';
    if (value >= 4) return 'h-6';
    return 'h-4';
  };

  const filteredStatusData = statusFilter === 'all'
    ? statusData
    : statusData.filter((s) => s.status === statusFilter);

  const totalDocs = statusData.reduce((sum, s) => sum + parseInt(s.count), 0);
  const timelineMax = Math.max(...timelineData.map((x) => parseInt(x.count)), 1);

  const tabs = [
    { id: 'overview', label: 'Visão Geral' },
    { id: 'audit', label: 'Log de Auditoria' },
    { id: 'notifications', label: 'Notificações' },
  ];

  if (loading) return <div className="flex justify-center py-12"><Loader2 className="w-8 h-8 animate-spin text-brand-600" /></div>;

  return (
    <div className="animate-fade-in">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">Relatórios</h1>
      <p className="text-gray-500 text-sm mb-6">Análise e auditoria do sistema</p>

      <div className="card p-4 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div>
            <label className="text-xs font-medium text-gray-600 mb-1 block">Período</label>
            <select value={period} onChange={(e) => setPeriod(e.target.value)} className="input-field">
              <option value="7d">Últimos 7 dias</option>
              <option value="30d">Últimos 30 dias</option>
              <option value="90d">Últimos 90 dias</option>
            </select>
          </div>
          <div>
            <label className="text-xs font-medium text-gray-600 mb-1 block">Status</label>
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="input-field">
              <option value="all">Todos</option>
              {Object.entries(STATUS_MAP).map(([key, value]) => (
                <option key={key} value={key}>{value.label}</option>
              ))}
            </select>
          </div>
          <div className="flex items-end">
            <button type="button" className="btn-secondary w-full">Filtros aplicados localmente</button>
          </div>
        </div>
      </div>

      <div className="flex gap-2 mb-6 border-b border-gray-200 pb-2 overflow-x-auto">
        {tabs.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`min-h-11 px-4 py-2 rounded-lg text-sm font-medium transition-all whitespace-nowrap ${tab === t.id ? 'bg-brand-600 text-white' : 'text-gray-600 hover:bg-gray-100'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div className="space-y-6">
          {/* Status chart */}
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Documentos por Status</h3>
            {filteredStatusData.length === 0 ? (
              <p className="text-gray-400 text-center py-8">Sem dados no período</p>
            ) : (
              <div className="space-y-3">
                {filteredStatusData.map(s => {
                  const cfg = STATUS_MAP[s.status] || { label: s.status, color: '#6B7280' };
                  const pct = totalDocs ? (parseInt(s.count) / totalDocs) * 100 : 0;
                  return (
                    <div key={s.status} className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
                      <div className="sm:w-28 text-sm font-medium text-gray-700">{cfg.label}</div>
                      <div className="flex-1 bg-gray-100 rounded-full h-6 overflow-hidden px-1 py-1">
                        <div className={`h-full rounded-full transition-all bg-brand-600 grid grid-cols-12 ${getSpanClass(Math.max(pct, 5))}`}>
                          <span className="col-span-12 text-xs text-white font-medium text-right pr-2 leading-4">{s.count}</span>
                        </div>
                      </div>
                      <div className="sm:w-12 text-right text-sm text-gray-500">{pct.toFixed(0)}%</div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* Timeline */}
          <div className="card p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Assinaturas nos Últimos 30 Dias</h3>
            {timelineData.length === 0 ? (
              <p className="text-gray-400 text-center py-8">Sem assinaturas no período</p>
            ) : (
              <div className="flex items-end gap-1 h-40">
                {timelineData.map((d, i) => {
                  const h = timelineMax ? (parseInt(d.count) / timelineMax) * 100 : 0;
                  return (
                    <div key={i} className="flex-1 flex flex-col items-center gap-1 group relative">
                      <div className="absolute -top-6 bg-gray-800 text-white text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
                        {new Date(d.date).toLocaleDateString('pt-BR')}: {d.count}
                      </div>
                      <div className={`w-full bg-brand-500 rounded-t transition-all hover:bg-brand-600 ${getHeightClass(Math.max(h, 4))}`} />
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {tab === 'audit' && (
        <div className="card overflow-hidden">
          <div className="space-y-3 p-4 md:hidden">
            {auditData.map((log: any) => (
              <div key={log.id} className="border border-gray-100 rounded-xl p-3">
                <p className="text-xs text-gray-500 mb-1">{new Date(log.created_at).toLocaleString('pt-BR')}</p>
                <p className="text-sm font-medium text-gray-900 mb-2">{log.action}</p>
                <p className="text-xs text-gray-600">Documento: {log.document_name || '-'}</p>
                <p className="text-xs text-gray-600">Usuário: {log.user_name || '-'}</p>
                <p className="text-xs text-gray-500 mt-1">{log.description || '-'}</p>
                <p className="text-xs text-gray-400 mt-1">IP: {log.ip_address || '-'}</p>
              </div>
            ))}
            {auditData.length === 0 && <div className="py-10 text-center text-gray-400">Nenhum log encontrado</div>}
          </div>

          <div className="hidden md:block overflow-x-auto">
          <table className="w-full min-w-[900px]">
            <thead>
              <tr className="bg-gray-50 border-b">
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Data</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Ação</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Documento</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Usuário</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">Descrição</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase hidden lg:table-cell">IP</th>
              </tr>
            </thead>
            <tbody>
              {auditData.map((log: any) => (
                <tr key={log.id} className="border-b border-gray-50 hover:bg-gray-50/50 text-sm">
                  <td className="py-2.5 px-4 text-gray-500 whitespace-nowrap">{new Date(log.created_at).toLocaleString('pt-BR')}</td>
                  <td className="py-2.5 px-4"><span className="badge bg-brand-50 text-brand-700 text-xs">{log.action}</span></td>
                  <td className="py-2.5 px-4 hidden md:table-cell text-gray-700 truncate max-w-[200px]">{log.document_name || '-'}</td>
                  <td className="py-2.5 px-4 hidden md:table-cell text-gray-700">{log.user_name || '-'}</td>
                  <td className="py-2.5 px-4 hidden lg:table-cell text-gray-500 truncate max-w-[300px]">{log.description || '-'}</td>
                  <td className="py-2.5 px-4 hidden lg:table-cell text-gray-400 font-mono text-xs">{log.ip_address || '-'}</td>
                </tr>
              ))}
              {auditData.length === 0 && <tr><td colSpan={6} className="py-12 text-center text-gray-400">Nenhum log encontrado</td></tr>}
            </tbody>
          </table>
          </div>
        </div>
      )}

      {tab === 'notifications' && (
        <div className="card overflow-hidden">
          <div className="space-y-3 p-4 md:hidden">
            {notifData.map((n: any) => (
              <div key={n.id} className="border border-gray-100 rounded-xl p-3">
                <p className="text-xs text-gray-500 mb-1">{new Date(n.created_at).toLocaleString('pt-BR')}</p>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <span className="badge bg-blue-100 text-blue-700">{n.type}</span>
                  <span className={`badge ${n.status === 'sent' || n.status === 'delivered' ? 'bg-green-100 text-green-700' : n.status === 'failed' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-700'}`}>{n.status}</span>
                </div>
                <p className="text-xs text-gray-600 break-all">Destino: {n.recipient}</p>
                <p className="text-xs text-gray-500 mt-1">{n.subject || '-'}</p>
              </div>
            ))}
            {notifData.length === 0 && <div className="py-10 text-center text-gray-400">Nenhuma notificação</div>}
          </div>

          <div className="hidden md:block overflow-x-auto">
          <table className="w-full min-w-[760px]">
            <thead>
              <tr className="bg-gray-50 border-b">
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Data</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Tipo</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Destinatário</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase hidden md:table-cell">Assunto</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-gray-500 uppercase">Status</th>
              </tr>
            </thead>
            <tbody>
              {notifData.map((n: any) => (
                <tr key={n.id} className="border-b border-gray-50 hover:bg-gray-50/50 text-sm">
                  <td className="py-2.5 px-4 text-gray-500 whitespace-nowrap">{new Date(n.created_at).toLocaleString('pt-BR')}</td>
                  <td className="py-2.5 px-4"><span className="badge bg-blue-100 text-blue-700">{n.type}</span></td>
                  <td className="py-2.5 px-4 text-gray-700">{n.recipient}</td>
                  <td className="py-2.5 px-4 hidden md:table-cell text-gray-500 truncate max-w-[300px]">{n.subject || '-'}</td>
                  <td className="py-2.5 px-4"><span className={`badge ${n.status === 'sent' || n.status === 'delivered' ? 'bg-green-100 text-green-700' : n.status === 'failed' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-700'}`}>{n.status}</span></td>
                </tr>
              ))}
              {notifData.length === 0 && <tr><td colSpan={5} className="py-12 text-center text-gray-400">Nenhuma notificação</td></tr>}
            </tbody>
          </table>
          </div>
        </div>
      )}
    </div>
  );
}
