import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDropzone } from 'react-dropzone';
import {
  ArrowLeft,
  Check,
  ChevronRight,
  FileText,
  Loader2,
  Plus,
  Send,
  UploadCloud,
  Wand2,
  X,
} from 'lucide-react';
import toast from 'react-hot-toast';
import api, { contactsAPI, documentsAPI, foldersAPI } from '../services/api';
import PdfViewer from '../components/PdfViewer';
import { DocumentField, FieldType, SignerConfig, SignerMetadata } from '../types/documentBuilder';

const FIELD_TYPES: { id: FieldType; label: string }[] = [
  { id: 'text', label: 'Tt Texto' },
  { id: 'signature', label: '✍ Assinatura' },
  { id: 'initial', label: 'AA Rubrica' },
  { id: 'date', label: '📅 Data' },
  { id: 'number', label: '1 Numero' },
  { id: 'image', label: '🖼 Imagem' },
  { id: 'checkbox', label: '☑ Caixa' },
  { id: 'multiple', label: '✅ Multiplo' },
  { id: 'file', label: '📎 Arquivo' },
  { id: 'radio', label: '⭕ Radio' },
  { id: 'select', label: '📋 Selecionar' },
  { id: 'cells', label: '▦ Celulas' },
  { id: 'stamp', label: '🔏 Carimbo' },
];

const AUTH_OPTIONS = [
  { id: 'email_token', label: 'Token por Email' },
  { id: 'sms_token', label: 'Token por SMS' },
  { id: 'whatsapp', label: 'WhatsApp' },
  { id: 'biometria_facial', label: 'Biometria Facial' },
  { id: 'link', label: 'Link direto' },
  { id: 'presencial', label: 'Presencial' },
];

const PARTICIPATION_TYPES = [
  { id: 'assinar', label: '✍ Assinar' },
  { id: 'testemunha', label: '👁 Testemunha' },
  { id: 'aprovar', label: '✅ Aprovar' },
  { id: 'reconhecer', label: '📋 Reconhecer' },
  { id: 'acusar_recebimento', label: '📬 Acusar recebimento' },
];

const SIGNER_COLORS = ['bg-brand-100 text-brand-700', 'bg-emerald-100 text-emerald-700', 'bg-violet-100 text-violet-700', 'bg-amber-100 text-amber-700'];

const makeDefaultMetadata = (): SignerMetadata => ({
  require_face_photo: false,
  require_document_photo: false,
  document_photo_type: 'rg',
  document_photo_sides: 'both',
  require_selfie: false,
  require_handwritten: false,
  require_residence_proof: false,
});

const makeSigner = (partial?: Partial<SignerConfig>): SignerConfig => ({
  temp_id: `tmp-${Date.now()}-${Math.random().toString(16).slice(2)}`,
  name: '',
  email: '',
  cpf: '',
  phone: '',
  signature_type: 'assinar',
  auth_method: 'email_token',
  sign_order: 1,
  metadata: makeDefaultMetadata(),
  ...partial,
});

export default function NewDocumentPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [folders, setFolders] = useState<any[]>([]);
  const [contacts, setContacts] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [file, setFile] = useState<File | null>(null);
  const [documentId, setDocumentId] = useState('');
  const [fileUrl, setFileUrl] = useState('');
  const [docName, setDocName] = useState('');
  const [description, setDescription] = useState('');
  const [folderId, setFolderId] = useState('');
  const [message, setMessage] = useState('');
  const [deadlineAt, setDeadlineAt] = useState('');
  const [sequenceEnabled, setSequenceEnabled] = useState(false);
  const [remindInterval, setRemindInterval] = useState('3');
  const [autoClose, setAutoClose] = useState(true);

  const [signers, setSigners] = useState<SignerConfig[]>([]);
  const [activeSignerId, setActiveSignerId] = useState<string | null>(null);
  const [quickSigner, setQuickSigner] = useState({ name: '', email: '' });
  const [showContacts, setShowContacts] = useState(false);
  const [expandedSigner, setExpandedSigner] = useState<string | null>(null);

  const [fields, setFields] = useState<DocumentField[]>([]);
  const [pendingFieldType, setPendingFieldType] = useState<FieldType | null>(null);
  const [selectedFieldId, setSelectedFieldId] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);

  useEffect(() => {
    foldersAPI.list().then((r) => setFolders(r.data || [])).catch(() => null);
    contactsAPI.list({ limit: 100 }).then((r) => setContacts(r.data.contacts || [])).catch(() => null);
  }, []);

  const loadDocumentData = async (docId: string) => {
    try {
      const { data } = await documentsAPI.getById(docId);
      if (data?.name) setDocName(data.name);
      if (data?.description) setDescription(data.description);
      if (data?.folder_id) setFolderId(data.folder_id);
      if (data?.message) setMessage(data.message);
      if (data?.file_url) setFileUrl(data.file_url);
      if (Array.isArray(data?.fields)) setFields(data.fields);
      if (Array.isArray(data?.signers)) {
        const mapped = data.signers.map((s: any, idx: number) =>
          makeSigner({
            ...s,
            id: s.id,
            temp_id: s.id || `tmp-load-${idx}`,
            sign_order: s.sign_order || idx + 1,
            metadata: { ...makeDefaultMetadata(), ...(s.metadata || {}) },
          }),
        );
        setSigners(mapped);
        setActiveSignerId(mapped[0]?.id || mapped[0]?.temp_id || null);
      }
    } catch {
      toast.error('Nao foi possivel carregar detalhes do documento');
    }
  };

  const uploadFile = async (acceptedFile: File) => {
    if (!['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/msword'].includes(acceptedFile.type)) {
      toast.error('Formato invalido. Use PDF ou DOCX.');
      return;
    }
    if (acceptedFile.size > 25 * 1024 * 1024) {
      toast.error('Arquivo maior que 25MB.');
      return;
    }

    setFile(acceptedFile);
    setDocName((prev) => prev || acceptedFile.name.replace(/\.[^.]+$/, ''));
    setUploading(true);
    setUploadProgress(8);
    const interval = window.setInterval(() => {
      setUploadProgress((prev) => (prev >= 92 ? prev : prev + 6));
    }, 180);

    try {
      const formData = new FormData();
      formData.append('file', acceptedFile);
      formData.append('name', acceptedFile.name.replace(/\.[^.]+$/, ''));
      const { data } = await documentsAPI.upload(formData);
      setDocumentId(data.id);
      setFileUrl(data.file_url || data.url || '');
      setUploadProgress(100);
      await loadDocumentData(data.id);
      toast.success('Documento enviado com sucesso');
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Falha no upload');
    } finally {
      window.clearInterval(interval);
      setUploading(false);
      setTimeout(() => setUploadProgress(0), 300);
    }
  };

  const onDropAccepted = (accepted: File[]) => {
    const first = accepted[0];
    if (first) uploadFile(first);
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDropAccepted,
    accept: {
      'application/pdf': ['.pdf'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
      'application/msword': ['.doc'],
    },
    maxFiles: 1,
    maxSize: 25 * 1024 * 1024,
  });

  const activeSigner = useMemo(
    () => signers.find((signer) => (signer.id || signer.temp_id) === activeSignerId),
    [signers, activeSignerId],
  );

  const addQuickSigner = async () => {
    if (!documentId) return toast.error('Envie um documento primeiro');
    if (!quickSigner.name || !quickSigner.email) return toast.error('Informe nome e email');
    try {
      const payload = makeSigner({
        name: quickSigner.name,
        email: quickSigner.email,
        sign_order: signers.length + 1,
      });
      const { data } = await documentsAPI.addSigner(documentId, payload);
      const mapped = makeSigner({
        ...payload,
        ...data,
        id: data.id,
        temp_id: data.id || payload.temp_id,
      });
      setSigners((prev) => [...prev, mapped]);
      setActiveSignerId(mapped.id || mapped.temp_id);
      setQuickSigner({ name: '', email: '' });
      toast.success('Signatario adicionado');
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Erro ao adicionar signatario');
    }
  };

  const onCreateField = async (payload: Partial<DocumentField>) => {
    if (!documentId) return;
    try {
      const { data } = await documentsAPI.addField(documentId, payload);
      const created: DocumentField = {
        id: data?.id || `tmp-field-${Date.now()}`,
        document_id: documentId,
        signer_id: payload.signer_id || '',
        field_type: payload.field_type as FieldType,
        page: payload.page || 1,
        x: payload.x || 0,
        y: payload.y || 0,
        width: payload.width || 12,
        height: payload.height || 6,
        required: payload.required ?? true,
        label: payload.label || data?.label || '',
      };
      setFields((prev) => [...prev, created]);
      setPendingFieldType(null);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Nao foi possivel adicionar campo');
    }
  };

  const onUpdateField = async (fieldId: string, updates: Partial<DocumentField>) => {
    setFields((prev) => prev.map((field) => (field.id === fieldId ? { ...field, ...updates } : field)));
    try {
      await api.put(`/documents/${documentId}/fields/${fieldId}`, updates);
    } catch {
      null;
    }
  };

  const onDeleteField = async (fieldId: string) => {
    setFields((prev) => prev.filter((field) => field.id !== fieldId));
    try {
      await api.delete(`/documents/${documentId}/fields/${fieldId}`);
    } catch {
      null;
    }
  };

  const saveDocumentSettings = async () => {
    if (!documentId) return;
    setLoading(true);
    try {
      await documentsAPI.update(documentId, {
        name: docName,
        description,
        folder_id: folderId || null,
        message,
        deadline_at: deadlineAt || null,
        sequence_enabled: sequenceEnabled,
        remind_interval: remindInterval === 'off' ? null : Number(remindInterval),
        auto_close: autoClose,
      });
      toast.success('Configuracoes salvas');
      setStep(4);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Erro ao salvar configuracoes');
    } finally {
      setLoading(false);
    }
  };

  const persistSigners = async () => {
    if (!documentId) return;
    for (const signer of signers) {
      const payload = {
        name: signer.name,
        email: signer.email,
        cpf: signer.cpf,
        phone: signer.phone,
        signature_type: signer.signature_type,
        auth_method: signer.auth_method,
        sign_order: signer.sign_order,
        metadata: signer.metadata,
      };
      if (signer.id) {
        try {
          await api.put(`/documents/${documentId}/signers/${signer.id}`, payload);
        } catch {
          null;
        }
      } else {
        try {
          const { data } = await documentsAPI.addSigner(documentId, payload);
          signer.id = data.id;
        } catch {
          null;
        }
      }
    }
  };

  const toReview = async () => {
    if (!signers.length) return toast.error('Adicione pelo menos um signatario');
    setLoading(true);
    try {
      await persistSigners();
      setStep(5);
    } finally {
      setLoading(false);
    }
  };

  const sendDocument = async () => {
    if (!documentId) return;
    setLoading(true);
    try {
      await documentsAPI.send(documentId);
      toast.success('Documento enviado para assinatura');
      navigate(`/documents/${documentId}`);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Falha ao enviar documento');
    } finally {
      setLoading(false);
    }
  };

  const stepLabels = ['Upload', 'Editor PDF', 'Configuracoes', 'Signatarios', 'Revisao'];

  return (
    <div className="animate-fade-in space-y-6">
      <button onClick={() => navigate(-1)} className="min-h-11 inline-flex items-center gap-2 text-gray-500 hover:text-gray-700 text-sm">
        <ArrowLeft className="w-4 h-4" /> Voltar
      </button>

      <div className="flex items-center gap-2 overflow-x-auto">
        {stepLabels.map((label, index) => {
          const current = index + 1;
          return (
            <div key={label} className="flex items-center gap-2 min-w-fit">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold ${step > current ? 'bg-emerald-500 text-white' : step === current ? 'bg-brand-600 text-white' : 'bg-gray-200 text-gray-500'}`}>
                {step > current ? <Check className="w-4 h-4" /> : current}
              </div>
              <span className={`text-sm ${step >= current ? 'text-gray-800 font-medium' : 'text-gray-400'}`}>{label}</span>
              {current < stepLabels.length && <ChevronRight className="w-4 h-4 text-gray-300" />}
            </div>
          );
        })}
      </div>

      {step === 1 && (
        <div className="card p-5 sm:p-8 space-y-6">
          <div
            {...getRootProps()}
            className={`border-2 border-dashed rounded-2xl p-8 sm:p-12 text-center cursor-pointer transition-colors ${
              isDragActive ? 'border-brand-600 bg-brand-50' : 'border-brand-300 bg-white hover:bg-brand-50/50'
            }`}
          >
            <input {...getInputProps()} />
            <UploadCloud className="w-12 h-12 mx-auto mb-3 text-brand-600" />
            <p className="text-gray-700 font-medium">Arraste o arquivo aqui ou clique para selecionar</p>
            <p className="text-sm text-gray-400 mt-1">PDF, DOCX ate 25MB</p>
          </div>

          {file && (
            <div className="border border-gray-200 rounded-xl p-4 flex items-center justify-between gap-3">
              <div>
                <p className="text-sm font-semibold text-gray-900">{file.name}</p>
                <p className="text-xs text-gray-500">{(file.size / 1024 / 1024).toFixed(2)} MB</p>
              </div>
              <button onClick={() => setFile(null)} className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-lg hover:bg-red-50">
                <X className="w-4 h-4 text-red-500" />
              </button>
            </div>
          )}

          {uploading && (
            <div>
              <div className="flex justify-between text-xs text-gray-500 mb-1">
                <span>Upload em andamento</span>
                <span>{uploadProgress}%</span>
              </div>
              <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
                <div className="h-full bg-brand-600 rounded-full transition-all" style={{ width: `${uploadProgress}%` }} />
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Nome do documento</label>
              <input value={docName} onChange={(e) => setDocName(e.target.value)} className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Pasta</label>
              <select value={folderId} onChange={(e) => setFolderId(e.target.value)} className="input-field">
                <option value="">Sem pasta</option>
                {folders.map((folder: any) => (
                  <option key={folder.id} value={folder.id}>
                    {folder.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Descricao</label>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="input-field" />
          </div>

          <div className="flex justify-end">
            <button
              onClick={() => (documentId ? setStep(2) : toast.error('Envie um arquivo primeiro'))}
              className="btn-primary w-full sm:w-auto"
            >
              Proximo
            </button>
          </div>
        </div>
      )}

      {step === 2 && (
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-4">
          <div className="xl:col-span-2 card p-3 space-y-2">
            <p className="text-xs font-semibold text-gray-500 uppercase">Paginas</p>
            {Array.from({ length: Math.max(1, currentPage + 2) }).map((_, idx) => {
              const page = idx + 1;
              return (
                <button
                  key={page}
                  onClick={() => setCurrentPage(page)}
                  className={`min-h-11 w-full rounded-lg text-sm border ${
                    currentPage === page ? 'border-brand-600 text-brand-700 bg-brand-50' : 'border-gray-200 text-gray-500'
                  }`}
                >
                  Pagina {page}
                </button>
              );
            })}
          </div>

          <div className="xl:col-span-7 card p-3">
            {fileUrl ? (
              <PdfViewer
                url={fileUrl}
                fields={fields}
                signers={signers}
                onFieldAdd={onCreateField}
                onFieldUpdate={onUpdateField}
                onFieldDelete={onDeleteField}
                activeSignerId={activeSignerId}
                editable
                currentPage={currentPage}
                onPageChange={setCurrentPage}
                selectedFieldId={selectedFieldId}
                onSelectedFieldChange={setSelectedFieldId}
                pendingFieldType={pendingFieldType}
              />
            ) : (
              <div className="min-h-[520px] flex items-center justify-center text-gray-400">Arquivo sem URL de visualizacao</div>
            )}
          </div>

          <div className="xl:col-span-3 space-y-4">
            <div className="card p-4 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-semibold text-gray-900">Signatarios</h3>
                <button onClick={addQuickSigner} className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-lg hover:bg-gray-100">
                  <Plus className="w-4 h-4 text-gray-600" />
                </button>
              </div>
              <input
                placeholder="Nome"
                value={quickSigner.name}
                onChange={(e) => setQuickSigner((prev) => ({ ...prev, name: e.target.value }))}
                className="input-field"
              />
              <input
                placeholder="Email"
                value={quickSigner.email}
                onChange={(e) => setQuickSigner((prev) => ({ ...prev, email: e.target.value }))}
                className="input-field"
              />
              <div className="space-y-2">
                {signers.map((signer, idx) => {
                  const key = signer.id || signer.temp_id;
                  return (
                    <button
                      key={key}
                      onClick={() => setActiveSignerId(key)}
                      className={`w-full rounded-lg p-3 text-left ${activeSignerId === key ? 'bg-brand-50 border border-brand-200' : 'bg-gray-50 border border-gray-100'}`}
                    >
                      <p className="text-sm font-semibold text-gray-900">{signer.name || 'Novo signatario'}</p>
                      <p className="text-xs text-gray-500">{signer.email || 'sem email'}</p>
                      <span className={`badge mt-2 ${SIGNER_COLORS[idx % SIGNER_COLORS.length]}`}>Cor {idx + 1}</span>
                    </button>
                  );
                })}
              </div>
            </div>

            <div className="card p-4">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Tipos de campo</h3>
              <div className="grid grid-cols-2 gap-2">
                {FIELD_TYPES.map((field) => (
                  <button
                    key={field.id}
                    onClick={() => {
                      if (!activeSigner) return toast.error('Selecione um signatario');
                      setPendingFieldType(field.id);
                      toast.success(`Clique e arraste no PDF para criar: ${field.label}`);
                    }}
                    className={`min-h-11 px-2 rounded-lg border text-xs ${
                      pendingFieldType === field.id ? 'border-brand-600 text-brand-700 bg-brand-50' : 'border-gray-200 text-gray-600'
                    }`}
                  >
                    {field.label}
                  </button>
                ))}
              </div>
              <button onClick={() => toast.success('Deteccao simulada concluida')} className="btn-secondary w-full mt-3 inline-flex items-center justify-center gap-2">
                <Wand2 className="w-4 h-4" /> Detectar campos
              </button>
            </div>
          </div>

          <div className="xl:col-span-12 flex flex-col-reverse sm:flex-row justify-between gap-3">
            <button onClick={() => setStep(1)} className="btn-secondary w-full sm:w-auto">Voltar</button>
            <button onClick={() => setStep(3)} className="btn-primary w-full sm:w-auto">Proximo</button>
          </div>
        </div>
      )}

      {step === 3 && (
        <div className="card p-5 sm:p-8 space-y-5">
          <h2 className="text-xl font-bold text-gray-900">Configuracoes do documento</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Nome</label>
              <input value={docName} onChange={(e) => setDocName(e.target.value)} className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Pasta</label>
              <select value={folderId} onChange={(e) => setFolderId(e.target.value)} className="input-field">
                <option value="">Sem pasta</option>
                {folders.map((folder: any) => (
                  <option key={folder.id} value={folder.id}>
                    {folder.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mensagem para signatarios</label>
            <textarea value={message} onChange={(e) => setMessage(e.target.value)} rows={4} className="input-field" />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Data limite</label>
              <input type="date" value={deadlineAt} onChange={(e) => setDeadlineAt(e.target.value)} className="input-field" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Lembrete automatico</label>
              <select value={remindInterval} onChange={(e) => setRemindInterval(e.target.value)} className="input-field">
                <option value="off">Desativado</option>
                <option value="1">1 dia</option>
                <option value="2">2 dias</option>
                <option value="3">3 dias</option>
                <option value="7">7 dias</option>
              </select>
            </div>
            <div className="space-y-2">
              <label className="flex items-center gap-2 text-sm text-gray-700">
                <input type="checkbox" checked={sequenceEnabled} onChange={(e) => setSequenceEnabled(e.target.checked)} />
                Ordem sequencial
              </label>
              <label className="flex items-center gap-2 text-sm text-gray-700">
                <input type="checkbox" checked={autoClose} onChange={(e) => setAutoClose(e.target.checked)} />
                Fechar automaticamente
              </label>
            </div>
          </div>
          <div className="flex flex-col-reverse sm:flex-row justify-between gap-3">
            <button onClick={() => setStep(2)} className="btn-secondary w-full sm:w-auto">Voltar</button>
            <button onClick={saveDocumentSettings} disabled={loading} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
              Proximo
            </button>
          </div>
        </div>
      )}

      {step === 4 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold text-gray-900">Signatarios e validacoes</h2>
            <button onClick={() => setShowContacts(true)} className="btn-secondary">Adicionar da agenda</button>
          </div>
          {signers.map((signer, idx) => {
            const key = signer.id || signer.temp_id;
            const open = expandedSigner === key;
            return (
              <div key={key} className="card p-4">
                <button onClick={() => setExpandedSigner(open ? null : key)} className="w-full text-left">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="font-semibold text-gray-900">{signer.name || 'Sem nome'}</p>
                      <p className="text-sm text-gray-500">{signer.email || 'Sem email'}</p>
                    </div>
                    <span className={`badge ${SIGNER_COLORS[idx % SIGNER_COLORS.length]}`}>Signatario {idx + 1}</span>
                  </div>
                </button>
                {open && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-4">
                    <input value={signer.name} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, name: e.target.value } : it)))} className="input-field" placeholder="Nome" />
                    <input value={signer.email} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, email: e.target.value } : it)))} className="input-field" placeholder="Email" />
                    <input value={signer.cpf} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, cpf: e.target.value } : it)))} className="input-field" placeholder="CPF" />
                    <input value={signer.phone} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, phone: e.target.value } : it)))} className="input-field" placeholder="Telefone" />

                    <select value={signer.signature_type} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, signature_type: e.target.value } : it)))} className="input-field">
                      {PARTICIPATION_TYPES.map((opt) => (
                        <option key={opt.id} value={opt.id}>
                          {opt.label}
                        </option>
                      ))}
                    </select>
                    <select value={signer.auth_method} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, auth_method: e.target.value } : it)))} className="input-field">
                      {AUTH_OPTIONS.map((opt) => (
                        <option key={opt.id} value={opt.id}>
                          {opt.label}
                        </option>
                      ))}
                    </select>

                    <label className="flex items-center gap-2 text-sm text-gray-700">
                      <input type="checkbox" checked={signer.metadata.require_face_photo} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, require_face_photo: e.target.checked } } : it)))} />
                      Coletar foto do rosto
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                      <input type="checkbox" checked={signer.metadata.require_document_photo} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, require_document_photo: e.target.checked } } : it)))} />
                      Coletar documento de identificacao
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                      <input type="checkbox" checked={signer.metadata.require_selfie} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, require_selfie: e.target.checked } } : it)))} />
                      Coletar selfie com documento
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                      <input type="checkbox" checked={signer.metadata.require_handwritten} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, require_handwritten: e.target.checked } } : it)))} />
                      Assinatura manuscrita obrigatoria
                    </label>
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                      <input type="checkbox" checked={signer.metadata.require_residence_proof} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, require_residence_proof: e.target.checked } } : it)))} />
                      Foto de comprovante de residencia
                    </label>
                    <div className="grid grid-cols-2 gap-2">
                      <select value={signer.metadata.document_photo_type} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, document_photo_type: e.target.value } } : it)))} className="input-field">
                        <option value="rg">RG</option>
                        <option value="cnh">CNH</option>
                        <option value="passaporte">Passaporte</option>
                        <option value="rne">RNE</option>
                        <option value="certidao">Certidao</option>
                      </select>
                      <select value={signer.metadata.document_photo_sides} onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, metadata: { ...it.metadata, document_photo_sides: e.target.value as 'front' | 'both' } } : it)))} className="input-field">
                        <option value="front">Apenas frente</option>
                        <option value="both">Frente e verso</option>
                      </select>
                    </div>
                    {sequenceEnabled && (
                      <input
                        type="number"
                        min={1}
                        value={signer.sign_order}
                        onChange={(e) => setSigners((prev) => prev.map((it) => (it.temp_id === signer.temp_id ? { ...it, sign_order: Number(e.target.value) } : it)))}
                        className="input-field"
                        placeholder="Ordem de assinatura"
                      />
                    )}
                  </div>
                )}
              </div>
            );
          })}

          <div className="flex flex-col-reverse sm:flex-row justify-between gap-3">
            <button onClick={() => setStep(3)} className="btn-secondary w-full sm:w-auto">Voltar</button>
            <button onClick={toReview} disabled={loading} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
              {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
              Proximo
            </button>
          </div>
        </div>
      )}

      {step === 5 && (
        <div className="card p-5 sm:p-8 space-y-5">
          <h2 className="text-xl font-bold text-gray-900">Revisao e envio</h2>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="border border-gray-200 rounded-xl p-4">
              <h3 className="font-semibold text-gray-900 mb-2">Documento</h3>
              <p className="text-sm text-gray-700">{docName}</p>
              <p className="text-xs text-gray-500 mt-1">{file?.name}</p>
              <p className="text-xs text-gray-500 mt-1">{folderId ? `Pasta: ${folders.find((f: any) => f.id === folderId)?.name || '-'}` : 'Sem pasta'}</p>
              <p className="text-xs text-gray-500 mt-1">Prazo: {deadlineAt || 'Nao definido'}</p>
              <p className="text-xs text-gray-500 mt-1">Campos posicionados: {fields.length}</p>
            </div>
            <div className="border border-gray-200 rounded-xl p-4">
              <h3 className="font-semibold text-gray-900 mb-2">Mensagem</h3>
              <p className="text-sm text-gray-600">{message || 'Sem mensagem personalizada'}</p>
            </div>
          </div>

          <div className="space-y-3">
            {signers.map((signer, idx) => {
              const signerKey = signer.id || signer.temp_id;
              const signerFields = fields.filter((field) => field.signer_id === signerKey || field.signer_id === signer.id);
              return (
                <div key={signerKey} className="border border-gray-200 rounded-xl p-4">
                  <div className="flex items-center justify-between gap-2 flex-wrap">
                    <div>
                      <p className="font-semibold text-gray-900">{signer.name}</p>
                      <p className="text-xs text-gray-500">{signer.email}</p>
                    </div>
                    <span className={`badge ${SIGNER_COLORS[idx % SIGNER_COLORS.length]}`}>{signer.auth_method}</span>
                  </div>
                  <div className="mt-2 flex flex-wrap gap-2">
                    {signer.metadata.require_face_photo && <span className="badge bg-blue-100 text-blue-700">🤳 Biometria</span>}
                    {signer.metadata.require_document_photo && <span className="badge bg-violet-100 text-violet-700">🪪 Documento</span>}
                    {signer.metadata.require_selfie && <span className="badge bg-cyan-100 text-cyan-700">📸 Selfie</span>}
                    {signer.metadata.require_handwritten && <span className="badge bg-amber-100 text-amber-700">✍ Manuscrita</span>}
                    {signer.metadata.require_residence_proof && <span className="badge bg-emerald-100 text-emerald-700">🏠 Comprovante</span>}
                  </div>
                  <p className="text-xs text-gray-500 mt-2">Campos no PDF: {signerFields.length}</p>
                </div>
              );
            })}
          </div>

          <div className="flex flex-col-reverse sm:flex-row justify-between gap-3">
            <button onClick={() => setStep(4)} className="btn-secondary w-full sm:w-auto">Voltar</button>
            <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
              <button onClick={() => navigate(`/documents/${documentId}`)} className="btn-secondary w-full sm:w-auto">Salvar rascunho</button>
              <button onClick={sendDocument} disabled={loading} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
                {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
                Enviar documento
              </button>
            </div>
          </div>
        </div>
      )}

      {showContacts && (
        <div className="fixed inset-0 bg-black/50 z-50 p-4 flex items-center justify-center" onClick={() => setShowContacts(false)}>
          <div className="bg-white rounded-2xl w-full max-w-xl max-h-[80vh] overflow-auto p-5" onClick={(event) => event.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">Adicionar da agenda</h3>
              <button onClick={() => setShowContacts(false)} className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-lg hover:bg-gray-100">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <div className="space-y-2">
              {contacts.map((contact: any) => (
                <button
                  key={contact.id}
                  className="w-full text-left border border-gray-200 rounded-xl p-3 hover:bg-gray-50"
                  onClick={() => {
                    setSigners((prev) => [
                      ...prev,
                      makeSigner({
                        name: contact.name,
                        email: contact.email,
                        cpf: contact.cpf || '',
                        phone: contact.phone || '',
                        sign_order: prev.length + 1,
                      }),
                    ]);
                    setShowContacts(false);
                  }}
                >
                  <p className="font-medium text-gray-900">{contact.name}</p>
                  <p className="text-xs text-gray-500">{contact.email}</p>
                </button>
              ))}
              {!contacts.length && <p className="text-sm text-gray-400 text-center py-6">Nenhum contato encontrado</p>}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
