import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { CheckCircle, Clock, Loader2, Mail, Search } from 'lucide-react';
import toast from 'react-hot-toast';
import { publicAPI } from '../services/api';
import { readWhiteLabelConfig } from '../theme/whitelabel';

interface PublicDocument {
  id: string;
  name: string;
  status: string;
  signer_status: string;
  organization_name: string;
  created_at: string;
  access_token: string;
  signed_at?: string;
}

export default function MyDocumentsPage() {
  const whiteLabel = readWhiteLabelConfig();
  const [step, setStep] = useState<'email' | 'code' | 'list'>('email');
  const [loading, setLoading] = useState(false);
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [tab, setTab] = useState<'pending' | 'signed'>('pending');
  const [documents, setDocuments] = useState<PublicDocument[]>([]);

  const pendingDocs = useMemo(
    () => documents.filter((doc) => doc.signer_status !== 'signed'),
    [documents],
  );
  const signedDocs = useMemo(
    () => documents.filter((doc) => doc.signer_status === 'signed'),
    [documents],
  );

  const requestCode = async () => {
    if (!email) return toast.error('Informe seu email');
    setLoading(true);
    try {
      await publicAPI.requestAccess(email);
      toast.success('Codigo enviado para seu email');
      setStep('code');
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Erro ao solicitar codigo');
    } finally {
      setLoading(false);
    }
  };

  const verifyCode = async () => {
    if (!code) return toast.error('Informe o codigo');
    setLoading(true);
    try {
      const { data } = await publicAPI.verifyAccess(email, code);
      setDocuments(data.documents || []);
      setStep('list');
      toast.success('Acesso liberado');
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Codigo invalido');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-brand-700 via-brand-800 to-accent-500 px-4 py-10">
      <div className="max-w-3xl mx-auto space-y-5">
        <div className="text-center text-white">
          <h1 className="text-2xl font-bold">Portal do Signatario</h1>
          <p className="text-sm text-blue-100 mt-1">Consulte seus documentos em {whiteLabel.platform_name || 'BlueTech'} sem login</p>
        </div>

        {step === 'email' && (
          <div className="card-glass p-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">Email</label>
            <div className="relative">
              <Mail className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
              <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" className="input-field pl-10" placeholder="voce@empresa.com" />
            </div>
            <button onClick={requestCode} disabled={loading} className="btn-primary w-full mt-4 inline-flex items-center justify-center gap-2">
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Search className="w-4 h-4" />}
              Buscar meus documentos
            </button>
          </div>
        )}

        {step === 'code' && (
          <div className="card-glass p-6">
            <p className="text-sm text-gray-600 mb-3">Enviamos um codigo de 6 digitos para <strong>{email}</strong>.</p>
            <input value={code} onChange={(e) => setCode(e.target.value)} maxLength={6} className="input-field text-center text-2xl tracking-[0.5em]" placeholder="000000" />
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 mt-4">
              <button onClick={() => setStep('email')} className="btn-secondary">Voltar</button>
              <button onClick={verifyCode} disabled={loading || code.length < 6} className="btn-primary inline-flex items-center justify-center gap-2">
                {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                Verificar codigo
              </button>
            </div>
          </div>
        )}

        {step === 'list' && (
          <div className="card-glass p-5">
            <div className="flex gap-2 mb-4 overflow-x-auto">
              <button onClick={() => setTab('pending')} className={`min-h-11 px-4 rounded-lg ${tab === 'pending' ? 'bg-brand-600 text-white' : 'bg-gray-100 text-gray-600'}`}>
                Pendentes
              </button>
              <button onClick={() => setTab('signed')} className={`min-h-11 px-4 rounded-lg ${tab === 'signed' ? 'bg-brand-600 text-white' : 'bg-gray-100 text-gray-600'}`}>
                Ja assinados
              </button>
            </div>

            <div className="space-y-3">
              {(tab === 'pending' ? pendingDocs : signedDocs).map((doc) => (
                <div key={`${doc.id}-${doc.access_token}`} className="border border-gray-200 rounded-xl p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="font-semibold text-gray-900">{doc.name}</p>
                      <p className="text-xs text-gray-500">{doc.organization_name} • {new Date(doc.created_at).toLocaleDateString('pt-BR')}</p>
                    </div>
                    <span className={`badge ${doc.signer_status === 'signed' ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'}`}>
                      {doc.signer_status === 'signed' ? <CheckCircle className="w-3 h-3 mr-1" /> : <Clock className="w-3 h-3 mr-1" />}
                      {doc.signer_status}
                    </span>
                  </div>
                  <div className="mt-3">
                    <Link to={`/sign/${doc.access_token}`} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center">
                      {doc.signer_status === 'signed' ? 'Ver documento' : 'Ver / Assinar'}
                    </Link>
                  </div>
                </div>
              ))}
              {(tab === 'pending' ? pendingDocs : signedDocs).length === 0 && (
                <p className="text-sm text-gray-400 text-center py-6">Nenhum documento nesta aba.</p>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
