import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Loader2, Save, Send } from 'lucide-react';
import toast from 'react-hot-toast';
import api, { documentsAPI } from '../services/api';
import PdfViewer from '../components/PdfViewer';
import { DocumentField, FieldType, SignerConfig } from '../types/documentBuilder';

export default function DocumentBuilderPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [docName, setDocName] = useState('');
  const [fileUrl, setFileUrl] = useState('');
  const [fields, setFields] = useState<DocumentField[]>([]);
  const [signers, setSigners] = useState<SignerConfig[]>([]);
  const [activeSignerId, setActiveSignerId] = useState<string | null>(null);
  const [pendingFieldType, setPendingFieldType] = useState<FieldType | null>(null);
  const [selectedFieldId, setSelectedFieldId] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);

  useEffect(() => {
    if (!id) return;
    documentsAPI
      .getById(id)
      .then(({ data }) => {
        setDocName(data.name || 'Documento');
        setFileUrl(data.file_url || '');
        setFields(data.fields || []);
        const mapped = (data.signers || []).map((s: any, idx: number) => ({
          ...s,
          temp_id: s.id || `loaded-${idx}`,
          metadata: s.metadata || {},
        }));
        setSigners(mapped);
        setActiveSignerId(mapped[0]?.id || mapped[0]?.temp_id || null);
      })
      .catch(() => toast.error('Nao foi possivel carregar o documento'))
      .finally(() => setLoading(false));
  }, [id]);

  const addField = async (payload: Partial<DocumentField>) => {
    if (!id) return;
    try {
      const { data } = await documentsAPI.addField(id, payload);
      setFields((prev) => [
        ...prev,
        {
          id: data.id,
          document_id: id,
          signer_id: payload.signer_id || '',
          field_type: payload.field_type as FieldType,
          page: payload.page || 1,
          x: payload.x || 0,
          y: payload.y || 0,
          width: payload.width || 12,
          height: payload.height || 6,
          required: payload.required ?? true,
          label: payload.label || '',
        },
      ]);
      setPendingFieldType(null);
    } catch {
      toast.error('Erro ao adicionar campo');
    }
  };

  const updateField = async (fieldId: string, updates: Partial<DocumentField>) => {
    setFields((prev) => prev.map((field) => (field.id === fieldId ? { ...field, ...updates } : field)));
    try {
      await api.put(`/documents/${id}/fields/${fieldId}`, updates);
    } catch {
      null;
    }
  };

  const deleteField = async (fieldId: string) => {
    setFields((prev) => prev.filter((field) => field.id !== fieldId));
    try {
      await api.delete(`/documents/${id}/fields/${fieldId}`);
    } catch {
      null;
    }
  };

  const saveDraft = async () => {
    if (!id) return;
    setSaving(true);
    try {
      await documentsAPI.update(id, { name: docName });
      toast.success('Rascunho atualizado');
      navigate(`/documents/${id}`);
    } catch {
      toast.error('Erro ao salvar');
    } finally {
      setSaving(false);
    }
  };

  const sendDocument = async () => {
    if (!id) return;
    setSaving(true);
    try {
      await documentsAPI.send(id);
      toast.success('Documento enviado');
      navigate(`/documents/${id}`);
    } catch {
      toast.error('Falha ao enviar');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <Loader2 className="w-8 h-8 animate-spin text-brand-600" />
      </div>
    );
  }

  return (
    <div className="space-y-4 animate-fade-in">
      <button onClick={() => navigate(-1)} className="min-h-11 inline-flex items-center gap-2 text-gray-500 hover:text-gray-700">
        <ArrowLeft className="w-4 h-4" /> Voltar
      </button>

      <div className="card p-4 flex flex-col md:flex-row gap-3 md:items-center md:justify-between">
        <input value={docName} onChange={(e) => setDocName(e.target.value)} className="input-field md:max-w-md" />
        <div className="flex flex-col sm:flex-row gap-2">
          <button onClick={saveDraft} disabled={saving} className="btn-secondary inline-flex items-center justify-center gap-2">
            <Save className="w-4 h-4" /> Salvar
          </button>
          <button onClick={sendDocument} disabled={saving} className="btn-primary inline-flex items-center justify-center gap-2">
            <Send className="w-4 h-4" /> Enviar
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-12 gap-4">
        <div className="xl:col-span-9 card p-3">
          <PdfViewer
            url={fileUrl}
            fields={fields}
            signers={signers}
            onFieldAdd={addField}
            onFieldUpdate={updateField}
            onFieldDelete={deleteField}
            activeSignerId={activeSignerId}
            editable
            currentPage={currentPage}
            onPageChange={setCurrentPage}
            selectedFieldId={selectedFieldId}
            onSelectedFieldChange={setSelectedFieldId}
            pendingFieldType={pendingFieldType}
          />
        </div>
        <div className="xl:col-span-3 space-y-3">
          <div className="card p-4">
            <p className="text-sm font-semibold text-gray-900 mb-2">Signatarios</p>
            <div className="space-y-2">
              {signers.map((signer) => {
                const key = signer.id || signer.temp_id;
                return (
                  <button
                    key={key}
                    onClick={() => setActiveSignerId(key)}
                    className={`w-full rounded-lg p-2.5 text-left border ${
                      activeSignerId === key ? 'border-brand-500 bg-brand-50' : 'border-gray-200'
                    }`}
                  >
                    <p className="text-sm font-medium text-gray-900">{signer.name}</p>
                    <p className="text-xs text-gray-500">{signer.email}</p>
                  </button>
                );
              })}
            </div>
          </div>
          <div className="card p-4">
            <p className="text-sm font-semibold text-gray-900 mb-2">Campos</p>
            <div className="grid grid-cols-2 gap-2">
              {(['text', 'signature', 'initial', 'date', 'number', 'checkbox', 'file', 'radio', 'select', 'stamp'] as FieldType[]).map((type) => (
                <button
                  key={type}
                  onClick={() => setPendingFieldType(type)}
                  className={`min-h-11 rounded-lg border text-xs ${
                    pendingFieldType === type ? 'border-brand-600 bg-brand-50 text-brand-700' : 'border-gray-200 text-gray-600'
                  }`}
                >
                  {type}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
