import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDropzone } from 'react-dropzone';
import {
  ArrowLeft, Check, ChevronDown, ChevronRight, ChevronUp, FileText, Loader2, Plus, Send,
  UploadCloud, Wand2, X, FileUp, Users, Settings2, CheckCircle2, PenTool, Trash2,
  UserPlus, BookUser, ArrowDownUp, ArrowRightLeft,
} from 'lucide-react';
import toast from 'react-hot-toast';
import api, { contactsAPI, documentsAPI, foldersAPI } from '../services/api';
import PdfViewer from '../components/PdfViewer';
import { DocumentField, FieldType, SignerConfig, SignerMetadata } from '../types/documentBuilder';

const FIELD_TYPES: { id: FieldType; label: string }[] = [
  { id: 'signature', label: 'Assinatura' },
  { id: 'initial', label: 'Rubrica' },
  { id: 'text', label: 'Texto' },
  { id: 'date', label: 'Data' },
  { id: 'number', label: 'Número' },
  { id: 'image', label: 'Imagem' },
  { id: 'checkbox', label: 'Caixa' },
  { id: 'stamp', label: 'Carimbo' },
  { id: 'file', label: 'Arquivo' },
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
  { id: 'assinar', label: 'Assinar' },
  { id: 'testemunha', label: 'Testemunha' },
  { id: 'aprovar', label: 'Aprovar' },
  { id: 'reconhecer', label: 'Reconhecer' },
  { id: 'acusar_recebimento', label: 'Acusar recebimento' },
];

const SIGNER_COLORS_PILL = [
  'bg-brand-100 text-brand-700 border-brand-200',
  'bg-emerald-100 text-emerald-700 border-emerald-200',
  'bg-violet-100 text-violet-700 border-violet-200',
  'bg-amber-100 text-amber-700 border-amber-200',
  'bg-cyan-100 text-cyan-700 border-cyan-200',
];

const SIGNER_DOT_COLORS = ['bg-brand-500', 'bg-emerald-500', 'bg-violet-500', 'bg-amber-500', 'bg-cyan-500'];

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
  name: '', email: '', cpf: '', phone: '',
  signature_type: 'assinar', auth_method: 'email_token', sign_order: 1,
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
  const [totalPages, setTotalPages] = useState(1);
  const [docName, setDocName] = useState('');
  const [description, setDescription] = useState('');
  const [folderId, setFolderId] = useState('');
  const [message, setMessage] = useState('');
  const [deadlineAt, setDeadlineAt] = useState('');
  const [signingOrder, setSigningOrder] = useState<'parallel' | 'sequential'>('parallel');
  const [remindInterval, setRemindInterval] = useState('3');
  const [autoClose, setAutoClose] = useState(true);

  const [signers, setSigners] = useState<SignerConfig[]>([]);
  const [activeSignerId, setActiveSignerId] = useState<string | null>(null);
  const [showAddSigner, setShowAddSigner] = useState(false);
  const [newSigner, setNewSigner] = useState({ name: '', email: '', cpf: '', phone: '' });
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
      if (data?.file_pages) setTotalPages(data.file_pages);
      if (Array.isArray(data?.fields)) setFields(data.fields);
      if (Array.isArray(data?.signers)) {
        const mapped = data.signers.map((s: any, idx: number) =>
          makeSigner({ ...s, id: s.id, temp_id: s.id || `tmp-load-${idx}`, sign_order: s.sign_order || idx + 1, metadata: { ...makeDefaultMetadata(), ...(s.metadata || {}) } }),
        );
        setSigners(mapped);
        setActiveSignerId(mapped[0]?.id || mapped[0]?.temp_id || null);
      }
    } catch { toast.error('Não foi possível carregar detalhes do documento'); }
  };

  const uploadFile = async (acceptedFile: File) => {
    if (!['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/msword'].includes(acceptedFile.type)) {
      return toast.error('Formato inválido. Use PDF ou DOCX.');
    }
    if (acceptedFile.size > 25 * 1024 * 1024) return toast.error('Arquivo maior que 25MB.');

    setFile(acceptedFile);
    setDocName((prev) => prev || acceptedFile.name.replace(/\.[^.]+$/, ''));
    setUploading(true);
    setUploadProgress(8);
    const interval = window.setInterval(() => setUploadProgress((p) => (p >= 92 ? p : p + 6)), 180);

    try {
      const formData = new FormData();
      formData.append('file', acceptedFile);
      formData.append('name', acceptedFile.name.replace(/\.[^.]+$/, ''));
      const { data } = await documentsAPI.upload(formData);
      setDocumentId(data.id);
      setFileUrl(data.file_url || data.url || '');
      setTotalPages(data.file_pages || 1);
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

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDropAccepted: (accepted) => { if (accepted[0]) uploadFile(accepted[0]); },
    accept: { 'application/pdf': ['.pdf'], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'], 'application/msword': ['.doc'] },
    maxFiles: 1, maxSize: 25 * 1024 * 1024,
  });

  const activeSigner = useMemo(
    () => signers.find((s) => (s.id || s.temp_id) === activeSignerId),
    [signers, activeSignerId],
  );

  const addSigner = async (signerData: { name: string; email: string; cpf?: string; phone?: string }) => {
    if (!documentId) return toast.error('Envie um documento primeiro');
    if (!signerData.name || !signerData.email) return toast.error('Informe nome e email');
    try {
      const payload = makeSigner({ ...signerData, sign_order: signers.length + 1 });
      const { data } = await documentsAPI.addSigner(documentId, payload);
      const mapped = makeSigner({ ...payload, ...data, id: data.id, temp_id: data.id || payload.temp_id });
      setSigners((prev) => [...prev, mapped]);
      setActiveSignerId(mapped.id || mapped.temp_id);
      setShowAddSigner(false);
      setNewSigner({ name: '', email: '', cpf: '', phone: '' });
      toast.success('Signatário adicionado');
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Erro ao adicionar signatário');
    }
  };

  const removeSigner = async (signer: SignerConfig) => {
    const key = signer.id || signer.temp_id;
    if (signer.id && documentId) {
      try { await documentsAPI.removeSigner(documentId, signer.id); } catch { /* ignore */ }
    }
    setSigners((prev) => prev.filter((s) => (s.id || s.temp_id) !== key));
    if (activeSignerId === key) setActiveSignerId(signers[0]?.id || signers[0]?.temp_id || null);
    setFields((prev) => prev.filter((f) => f.signer_id !== key && f.signer_id !== signer.id));
  };

  const reorderSigner = (idx: number, dir: -1 | 1) => {
    const target = idx + dir;
    if (target < 0 || target >= signers.length) return;
    setSigners((prev) => {
      const next = [...prev];
      [next[idx], next[target]] = [next[target], next[idx]];
      return next.map((s, i) => ({ ...s, sign_order: i + 1 }));
    });
  };

  const onCreateField = async (payload: Partial<DocumentField>) => {
    if (!documentId) return;
    try {
      const { data } = await documentsAPI.addField(documentId, payload);
      setFields((prev) => [...prev, {
        id: data?.id || `tmp-field-${Date.now()}`, document_id: documentId,
        signer_id: payload.signer_id || '', field_type: payload.field_type as FieldType,
        page: payload.page || 1, x: payload.x || 0, y: payload.y || 0,
        width: payload.width || 12, height: payload.height || 6,
        required: payload.required ?? true, label: payload.label || data?.label || '',
      }]);
      setPendingFieldType(null);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Não foi possível adicionar campo');
    }
  };

  const onUpdateField = async (fieldId: string, updates: Partial<DocumentField>) => {
    setFields((prev) => prev.map((f) => (f.id === fieldId ? { ...f, ...updates } : f)));
    try { await api.put(`/documents/${documentId}/fields/${fieldId}`, updates); } catch { /* ignore */ }
  };

  const onDeleteField = async (fieldId: string) => {
    setFields((prev) => prev.filter((f) => f.id !== fieldId));
    try { await api.delete(`/documents/${documentId}/fields/${fieldId}`); } catch { /* ignore */ }
  };

  const saveDocumentSettings = async () => {
    if (!documentId) return;
    setLoading(true);
    try {
      await documentsAPI.update(documentId, {
        name: docName, description, folder_id: folderId || null, message,
        deadline_at: deadlineAt || null, sequence_enabled: signingOrder === 'sequential',
        remind_interval: remindInterval === 'off' ? null : Number(remindInterval), auto_close: autoClose,
      });
      toast.success('Configurações salvas');
      setStep(4);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Erro ao salvar configurações');
    } finally { setLoading(false); }
  };

  const persistSigners = async () => {
    if (!documentId) return;
    for (const signer of signers) {
      const payload = {
        name: signer.name, email: signer.email, cpf: signer.cpf, phone: signer.phone,
        signature_type: signer.signature_type, auth_method: signer.auth_method,
        sign_order: signer.sign_order, metadata: signer.metadata,
      };
      if (signer.id) {
        try { await api.put(`/documents/${documentId}/signers/${signer.id}`, payload); } catch { /* ignore */ }
      } else {
        try { const { data } = await documentsAPI.addSigner(documentId, payload); signer.id = data.id; } catch { /* ignore */ }
      }
    }
  };

  const toReview = async () => {
    if (!signers.length) return toast.error('Adicione pelo menos um signatário');
    setLoading(true);
    try { await persistSigners(); setStep(5); } finally { setLoading(false); }
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
    } finally { setLoading(false); }
  };

  const stepConfig = [
    { label: 'Upload', icon: FileUp },
    { label: 'Editor PDF', icon: PenTool },
    { label: 'Configurações', icon: Settings2 },
    { label: 'Signatários', icon: Users },
    { label: 'Revisão', icon: CheckCircle2 },
  ];

  const summaryItems = [
    { label: 'Documento', value: docName || '-', done: !!docName },
    { label: 'Arquivo', value: file ? file.name : '-', done: !!file },
    { label: 'Páginas', value: `${totalPages}`, done: totalPages > 0 },
    { label: 'Signatários', value: `${signers.length}`, done: signers.length > 0 },
    { label: 'Campos', value: `${fields.length}`, done: fields.length > 0 },
    { label: 'Fluxo', value: signingOrder === 'parallel' ? 'Paralelo' : 'Sequencial', done: true },
  ];

  return (
    <div className="animate-fade-in page-shell">
      <button onClick={() => navigate(-1)} className="min-h-11 inline-flex items-center gap-2 text-gray-500 hover:text-gray-700 text-sm mb-4">
        <ArrowLeft className="w-4 h-4" /> Voltar
      </button>

      <div className="flex gap-6">
        {/* Progress sidebar */}
        <aside className="hidden xl:block w-56 flex-shrink-0">
          <div className="step-summary">
            <p className="step-summary-title">Progresso</p>
            <div className="space-y-1.5">
              {stepConfig.map((s, index) => {
                const num = index + 1;
                const active = step === num;
                const done = step > num;
                return (
                  <div key={s.label} className={`flex items-center gap-2.5 px-2 py-1.5 rounded-lg text-sm transition-all ${active ? 'bg-brand-50/80 text-brand-700 font-medium' : done ? 'text-emerald-600' : 'text-gray-400'}`}>
                    <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs flex-shrink-0 ${done ? 'bg-emerald-500 text-white' : active ? 'bg-brand-600 text-white' : 'bg-gray-200 text-gray-500'}`}>
                      {done ? <Check className="w-3 h-3" /> : num}
                    </div>
                    <span className="truncate">{s.label}</span>
                  </div>
                );
              })}
            </div>
            <div className="border-t border-gray-200 pt-3 mt-3">
              <p className="step-summary-title">Resumo</p>
              <div className="space-y-2">
                {summaryItems.map((item) => (
                  <div key={item.label} className="step-summary-item">
                    <span className="step-summary-label">{item.label}</span>
                    <span className={`step-summary-value text-xs truncate max-w-[7rem] text-right ${item.done ? '' : 'opacity-50'}`}>{item.value}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </aside>

        <div className="flex-1 min-w-0 space-y-6">
          {/* Step bar mobile */}
          <div className="card-glass p-3 flex items-center gap-2 overflow-x-auto xl:hidden">
            {stepConfig.map((s, index) => {
              const current = index + 1;
              return (
                <div key={s.label} className="flex items-center gap-2 min-w-fit">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold ${step > current ? 'bg-emerald-500 text-white' : step === current ? 'bg-brand-600 text-white' : 'bg-slate-200 text-slate-500'}`}>
                    {step > current ? <Check className="w-4 h-4" /> : current}
                  </div>
                  <span className={`text-sm ${step >= current ? 'text-gray-800 font-medium' : 'text-gray-400'}`}>{s.label}</span>
                  {current < stepConfig.length && <ChevronRight className="w-4 h-4 text-gray-300" />}
                </div>
              );
            })}
          </div>

          {/* ============ STEP 1: Upload ============ */}
          {step === 1 && (
            <div className="card-glass p-5 sm:p-8 space-y-6">
              <div {...getRootProps()} className={`border-2 border-dashed rounded-2xl p-8 sm:p-12 text-center cursor-pointer transition-colors ${isDragActive ? 'border-brand-600 bg-brand-50' : 'border-brand-300 bg-white hover:bg-brand-50/50'}`}>
                <input {...getInputProps()} />
                <UploadCloud className="w-12 h-12 mx-auto mb-3 text-brand-600" />
                <p className="text-gray-700 font-medium">Arraste o arquivo aqui ou clique para selecionar</p>
                <p className="text-sm text-gray-400 mt-1">PDF, DOCX até 25MB</p>
              </div>

              {file && (
                <div className="border border-gray-200 rounded-xl p-4 flex items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <FileText className="w-8 h-8 text-brand-600 flex-shrink-0" />
                    <div>
                      <p className="text-sm font-semibold text-gray-900">{file.name}</p>
                      <p className="text-xs text-gray-500">{(file.size / 1024 / 1024).toFixed(2)} MB {totalPages > 1 ? `· ${totalPages} páginas` : ''}</p>
                    </div>
                  </div>
                  <button onClick={() => { setFile(null); setDocumentId(''); setFileUrl(''); }} className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-lg hover:bg-red-50">
                    <X className="w-4 h-4 text-red-500" />
                  </button>
                </div>
              )}

              {uploading && (
                <div>
                  <div className="flex justify-between text-xs text-gray-500 mb-1">
                    <span>Upload em andamento</span><span>{uploadProgress}%</span>
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
                    {folders.map((f: any) => <option key={f.id} value={f.id}>{f.name}</option>)}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Descrição</label>
                <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} className="input-field" />
              </div>
              <div className="flex justify-end">
                <button onClick={() => (documentId ? setStep(2) : toast.error('Envie um arquivo primeiro'))} className="btn-primary w-full sm:w-auto">Próximo</button>
              </div>
            </div>
          )}

          {/* ============ STEP 2: Editor PDF ============ */}
          {step === 2 && (
            <div className="grid grid-cols-1 xl:grid-cols-12 gap-4">
              {/* Left: page thumbnails */}
              <div className="xl:col-span-2 card-glass p-3 space-y-2 max-h-[700px] overflow-y-auto">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Páginas ({totalPages})</p>
                {Array.from({ length: totalPages }).map((_, idx) => {
                  const page = idx + 1;
                  return (
                    <button key={page} onClick={() => setCurrentPage(page)}
                      className={`min-h-10 w-full rounded-lg text-sm border transition-all ${currentPage === page ? 'border-brand-600 text-brand-700 bg-brand-50 font-medium shadow-sm' : 'border-gray-200 text-gray-500 hover:bg-gray-50'}`}>
                      Pág. {page}
                    </button>
                  );
                })}
              </div>

              {/* Center: PDF viewer */}
              <div className="xl:col-span-7 card-glass p-3">
                {fileUrl ? (
                  <PdfViewer
                    url={fileUrl} fields={fields} signers={signers}
                    onFieldAdd={onCreateField} onFieldUpdate={onUpdateField} onFieldDelete={onDeleteField}
                    activeSignerId={activeSignerId} editable currentPage={currentPage}
                    totalPages={totalPages} onPageChange={setCurrentPage}
                    selectedFieldId={selectedFieldId} onSelectedFieldChange={setSelectedFieldId}
                    pendingFieldType={pendingFieldType}
                  />
                ) : (
                  <div className="min-h-[520px] flex items-center justify-center text-gray-400">Arquivo sem URL de visualização</div>
                )}
              </div>

              {/* Right: signers + fields */}
              <div className="xl:col-span-3 space-y-4">
                {/* Signers panel */}
                <div className="card-glass p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold text-gray-900">Signatários</h3>
                    <div className="flex gap-1">
                      <button onClick={() => setShowContacts(true)} className="min-h-9 min-w-9 inline-flex items-center justify-center rounded-lg hover:bg-gray-100" title="Adicionar da agenda">
                        <BookUser className="w-4 h-4 text-gray-500" />
                      </button>
                      <button onClick={() => setShowAddSigner(true)} className="min-h-9 min-w-9 inline-flex items-center justify-center rounded-lg hover:bg-gray-100" title="Novo signatário">
                        <UserPlus className="w-4 h-4 text-gray-600" />
                      </button>
                    </div>
                  </div>

                  {showAddSigner && (
                    <div className="border border-brand-200 bg-brand-50/30 rounded-xl p-3 space-y-2">
                      <input placeholder="Nome *" value={newSigner.name} onChange={(e) => setNewSigner((p) => ({ ...p, name: e.target.value }))} className="input-field text-sm" />
                      <input placeholder="Email *" value={newSigner.email} onChange={(e) => setNewSigner((p) => ({ ...p, email: e.target.value }))} className="input-field text-sm" />
                      <div className="grid grid-cols-2 gap-2">
                        <input placeholder="CPF" value={newSigner.cpf} onChange={(e) => setNewSigner((p) => ({ ...p, cpf: e.target.value }))} className="input-field text-sm" />
                        <input placeholder="Telefone" value={newSigner.phone} onChange={(e) => setNewSigner((p) => ({ ...p, phone: e.target.value }))} className="input-field text-sm" />
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => addSigner(newSigner)} className="btn-primary flex-1 text-sm py-2">Adicionar</button>
                        <button onClick={() => { setShowAddSigner(false); setNewSigner({ name: '', email: '', cpf: '', phone: '' }); }} className="btn-secondary text-sm py-2">Cancelar</button>
                      </div>
                    </div>
                  )}

                  <div className="space-y-2">
                    {signers.map((signer, idx) => {
                      const key = signer.id || signer.temp_id;
                      const active = activeSignerId === key;
                      return (
                        <div key={key}
                          onClick={() => setActiveSignerId(key)}
                          className={`rounded-xl p-3 cursor-pointer transition-all ${active ? 'bg-brand-50 border-2 border-brand-300 shadow-sm' : 'bg-gray-50 border border-gray-100 hover:border-gray-200'}`}>
                          <div className="flex items-center gap-2">
                            <div className={`w-3 h-3 rounded-full flex-shrink-0 ${SIGNER_DOT_COLORS[idx % SIGNER_DOT_COLORS.length]}`} />
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-semibold text-gray-900 truncate">{signer.name || 'Novo signatário'}</p>
                              <p className="text-xs text-gray-500 truncate">{signer.email || 'sem email'}</p>
                            </div>
                            <button onClick={(e) => { e.stopPropagation(); removeSigner(signer); }}
                              className="min-h-8 min-w-8 inline-flex items-center justify-center rounded-lg hover:bg-red-50">
                              <Trash2 className="w-3.5 h-3.5 text-gray-400 hover:text-red-500" />
                            </button>
                          </div>
                          {active && (
                            <div className="mt-2 flex gap-1 flex-wrap">
                              <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full border ${SIGNER_COLORS_PILL[idx % SIGNER_COLORS_PILL.length]}`}>
                                {PARTICIPATION_TYPES.find((t) => t.id === signer.signature_type)?.label || signer.signature_type}
                              </span>
                              <span className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-gray-100 text-gray-600 border border-gray-200">
                                {fields.filter((f) => f.signer_id === key || f.signer_id === signer.id).length} campos
                              </span>
                            </div>
                          )}
                        </div>
                      );
                    })}
                    {!signers.length && (
                      <p className="text-xs text-gray-400 text-center py-4">Nenhum signatário adicionado</p>
                    )}
                  </div>
                </div>

                {/* Field types */}
                <div className="card-glass p-4">
                  <h3 className="text-sm font-semibold text-gray-900 mb-3">Tipos de campo</h3>
                  <div className="grid grid-cols-3 gap-1.5">
                    {FIELD_TYPES.map((field) => (
                      <button key={field.id}
                        onClick={() => {
                          if (!activeSigner) return toast.error('Selecione um signatário');
                          setPendingFieldType(pendingFieldType === field.id ? null : field.id);
                        }}
                        className={`min-h-10 px-1.5 rounded-lg border text-xs transition-all ${pendingFieldType === field.id ? 'border-brand-600 text-brand-700 bg-brand-50 shadow-sm' : 'border-gray-200 text-gray-600 hover:bg-gray-50'}`}>
                        {field.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="xl:col-span-12 flex flex-col-reverse sm:flex-row justify-between gap-3">
                <button onClick={() => setStep(1)} className="btn-secondary w-full sm:w-auto">Voltar</button>
                <button onClick={() => setStep(3)} className="btn-primary w-full sm:w-auto">Próximo</button>
              </div>
            </div>
          )}

          {/* ============ STEP 3: Configurações ============ */}
          {step === 3 && (
            <div className="card-glass p-5 sm:p-8 space-y-6">
              <h2 className="text-xl font-bold text-gray-900">Configurações do documento</h2>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Nome</label>
                  <input value={docName} onChange={(e) => setDocName(e.target.value)} className="input-field" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Pasta</label>
                  <select value={folderId} onChange={(e) => setFolderId(e.target.value)} className="input-field">
                    <option value="">Sem pasta</option>
                    {folders.map((f: any) => <option key={f.id} value={f.id}>{f.name}</option>)}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Mensagem para signatários</label>
                <textarea value={message} onChange={(e) => setMessage(e.target.value)} rows={3} className="input-field" />
              </div>

              {/* Signing Flow - Parallel vs Sequential */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-3">Fluxo de assinatura</label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setSigningOrder('parallel')}
                    className={`relative rounded-xl border-2 p-4 text-left transition-all ${
                      signingOrder === 'parallel'
                        ? 'border-brand-600 bg-brand-50/50 shadow-sm'
                        : 'border-gray-200 hover:border-gray-300 bg-white'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${signingOrder === 'parallel' ? 'bg-brand-100 text-brand-700' : 'bg-gray-100 text-gray-500'}`}>
                        <ArrowRightLeft className="w-5 h-5" />
                      </div>
                      <div>
                        <p className={`font-semibold text-sm ${signingOrder === 'parallel' ? 'text-brand-800' : 'text-gray-900'}`}>Paralelo</p>
                        <p className="text-xs text-gray-500 mt-0.5">Todos recebem ao mesmo tempo. Qualquer um pode assinar a qualquer momento.</p>
                      </div>
                    </div>
                    {signingOrder === 'parallel' && (
                      <div className="absolute top-2 right-2 w-5 h-5 bg-brand-600 rounded-full flex items-center justify-center">
                        <Check className="w-3 h-3 text-white" />
                      </div>
                    )}
                  </button>

                  <button
                    type="button"
                    onClick={() => setSigningOrder('sequential')}
                    className={`relative rounded-xl border-2 p-4 text-left transition-all ${
                      signingOrder === 'sequential'
                        ? 'border-brand-600 bg-brand-50/50 shadow-sm'
                        : 'border-gray-200 hover:border-gray-300 bg-white'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${signingOrder === 'sequential' ? 'bg-brand-100 text-brand-700' : 'bg-gray-100 text-gray-500'}`}>
                        <ArrowDownUp className="w-5 h-5" />
                      </div>
                      <div>
                        <p className={`font-semibold text-sm ${signingOrder === 'sequential' ? 'text-brand-800' : 'text-gray-900'}`}>Sequencial</p>
                        <p className="text-xs text-gray-500 mt-0.5">Segue uma ordem. O próximo só recebe após o anterior assinar.</p>
                      </div>
                    </div>
                    {signingOrder === 'sequential' && (
                      <div className="absolute top-2 right-2 w-5 h-5 bg-brand-600 rounded-full flex items-center justify-center">
                        <Check className="w-3 h-3 text-white" />
                      </div>
                    )}
                  </button>
                </div>

                {signingOrder === 'sequential' && signers.length > 0 && (
                  <div className="mt-4 border border-gray-200 rounded-xl p-4 space-y-2">
                    <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Ordem de assinatura</p>
                    {signers.map((signer, idx) => (
                      <div key={signer.id || signer.temp_id} className="flex items-center gap-3 bg-gray-50 rounded-lg p-2.5">
                        <span className="w-7 h-7 rounded-full bg-brand-600 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">
                          {idx + 1}
                        </span>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">{signer.name || 'Sem nome'}</p>
                          <p className="text-xs text-gray-500 truncate">{signer.email}</p>
                        </div>
                        <div className="flex flex-col gap-0.5">
                          <button disabled={idx === 0} onClick={() => reorderSigner(idx, -1)}
                            className="min-h-7 min-w-7 inline-flex items-center justify-center rounded hover:bg-gray-200 disabled:opacity-20">
                            <ChevronUp className="w-3.5 h-3.5" />
                          </button>
                          <button disabled={idx === signers.length - 1} onClick={() => reorderSigner(idx, 1)}
                            className="min-h-7 min-w-7 inline-flex items-center justify-center rounded hover:bg-gray-200 disabled:opacity-20">
                            <ChevronDown className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Data limite</label>
                  <input type="date" value={deadlineAt} onChange={(e) => setDeadlineAt(e.target.value)} className="input-field" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Lembrete automático</label>
                  <select value={remindInterval} onChange={(e) => setRemindInterval(e.target.value)} className="input-field">
                    <option value="off">Desativado</option>
                    <option value="1">1 dia</option>
                    <option value="2">2 dias</option>
                    <option value="3">3 dias</option>
                    <option value="7">7 dias</option>
                  </select>
                </div>
                <div className="flex items-end">
                  <label className="flex items-center gap-2 text-sm text-gray-700">
                    <input type="checkbox" checked={autoClose} onChange={(e) => setAutoClose(e.target.checked)} className="rounded" />
                    Fechar automaticamente ao completar
                  </label>
                </div>
              </div>

              <div className="flex flex-col-reverse sm:flex-row justify-between gap-3">
                <button onClick={() => setStep(2)} className="btn-secondary w-full sm:w-auto">Voltar</button>
                <button onClick={saveDocumentSettings} disabled={loading} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
                  {loading && <Loader2 className="w-4 h-4 animate-spin" />} Próximo
                </button>
              </div>
            </div>
          )}

          {/* ============ STEP 4: Signatários ============ */}
          {step === 4 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between flex-wrap gap-3">
                <h2 className="text-xl font-bold text-gray-900">Signatários e validações</h2>
                <div className="flex gap-2">
                  <button onClick={() => setShowContacts(true)} className="btn-secondary inline-flex items-center gap-2">
                    <BookUser className="w-4 h-4" /> Agenda
                  </button>
                  <button onClick={() => setShowAddSigner(true)} className="btn-primary inline-flex items-center gap-2">
                    <UserPlus className="w-4 h-4" /> Novo signatário
                  </button>
                </div>
              </div>

              {showAddSigner && (
                <div className="card-glass p-5 border-2 border-brand-200 space-y-3">
                  <h3 className="text-sm font-semibold text-gray-900">Adicionar signatário</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <input placeholder="Nome *" value={newSigner.name} onChange={(e) => setNewSigner((p) => ({ ...p, name: e.target.value }))} className="input-field" />
                    <input placeholder="Email *" value={newSigner.email} onChange={(e) => setNewSigner((p) => ({ ...p, email: e.target.value }))} className="input-field" />
                    <input placeholder="CPF" value={newSigner.cpf} onChange={(e) => setNewSigner((p) => ({ ...p, cpf: e.target.value }))} className="input-field" />
                    <input placeholder="Telefone" value={newSigner.phone} onChange={(e) => setNewSigner((p) => ({ ...p, phone: e.target.value }))} className="input-field" />
                  </div>
                  <div className="flex gap-2 justify-end">
                    <button onClick={() => { setShowAddSigner(false); setNewSigner({ name: '', email: '', cpf: '', phone: '' }); }} className="btn-secondary">Cancelar</button>
                    <button onClick={() => addSigner(newSigner)} className="btn-primary">Adicionar</button>
                  </div>
                </div>
              )}

              {signers.map((signer, idx) => {
                const key = signer.id || signer.temp_id;
                const open = expandedSigner === key;
                return (
                  <div key={key} className="card-glass overflow-hidden">
                    <button onClick={() => setExpandedSigner(open ? null : key)} className="w-full text-left p-4">
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex items-center gap-3">
                          <span className="w-8 h-8 rounded-full bg-brand-600 text-white flex items-center justify-center text-sm font-bold flex-shrink-0">
                            {signingOrder === 'sequential' ? idx + 1 : signer.name?.charAt(0)?.toUpperCase() || '?'}
                          </span>
                          <div>
                            <p className="font-semibold text-gray-900">{signer.name || 'Sem nome'}</p>
                            <p className="text-sm text-gray-500">{signer.email || 'Sem email'}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className={`text-xs font-medium px-2.5 py-1 rounded-full border ${SIGNER_COLORS_PILL[idx % SIGNER_COLORS_PILL.length]}`}>
                            {PARTICIPATION_TYPES.find((t) => t.id === signer.signature_type)?.label || signer.signature_type}
                          </span>
                          <button onClick={(e) => { e.stopPropagation(); removeSigner(signer); }}
                            className="min-h-9 min-w-9 inline-flex items-center justify-center rounded-lg hover:bg-red-50">
                            <Trash2 className="w-4 h-4 text-gray-400 hover:text-red-500" />
                          </button>
                        </div>
                      </div>
                    </button>
                    {open && (
                      <div className="px-4 pb-4 border-t border-gray-100 pt-4 grid grid-cols-1 md:grid-cols-2 gap-3">
                        <input value={signer.name} onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, name: e.target.value } : it)))} className="input-field" placeholder="Nome" />
                        <input value={signer.email} onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, email: e.target.value } : it)))} className="input-field" placeholder="Email" />
                        <input value={signer.cpf} onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, cpf: e.target.value } : it)))} className="input-field" placeholder="CPF" />
                        <input value={signer.phone} onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, phone: e.target.value } : it)))} className="input-field" placeholder="Telefone" />

                        <select value={signer.signature_type} onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, signature_type: e.target.value } : it)))} className="input-field">
                          {PARTICIPATION_TYPES.map((opt) => <option key={opt.id} value={opt.id}>{opt.label}</option>)}
                        </select>
                        <select value={signer.auth_method} onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, auth_method: e.target.value } : it)))} className="input-field">
                          {AUTH_OPTIONS.map((opt) => <option key={opt.id} value={opt.id}>{opt.label}</option>)}
                        </select>

                        <div className="md:col-span-2 grid grid-cols-2 md:grid-cols-3 gap-2">
                          {([
                            ['require_face_photo', 'Foto do rosto'],
                            ['require_document_photo', 'Documento de ID'],
                            ['require_selfie', 'Selfie com documento'],
                            ['require_handwritten', 'Assinatura manuscrita'],
                          ] as const).map(([metaKey, label]) => (
                            <label key={metaKey} className="flex items-center gap-2 text-sm text-gray-700">
                              <input type="checkbox" checked={(signer.metadata as any)[metaKey]}
                                onChange={(e) => setSigners((prev) => prev.map((it) => ((it.id || it.temp_id) === key ? { ...it, metadata: { ...it.metadata, [metaKey]: e.target.checked } } : it)))} className="rounded" />
                              {label}
                            </label>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}

              {!signers.length && (
                <div className="card-glass p-8 text-center">
                  <Users className="w-12 h-12 mx-auto text-gray-300 mb-3" />
                  <p className="text-gray-500 font-medium">Nenhum signatário adicionado</p>
                  <p className="text-sm text-gray-400 mt-1">Adicione signatários para continuar</p>
                </div>
              )}

              <div className="flex flex-col-reverse sm:flex-row justify-between gap-3">
                <button onClick={() => setStep(3)} className="btn-secondary w-full sm:w-auto">Voltar</button>
                <button onClick={toReview} disabled={loading} className="btn-primary w-full sm:w-auto inline-flex items-center justify-center gap-2">
                  {loading && <Loader2 className="w-4 h-4 animate-spin" />} Próximo
                </button>
              </div>
            </div>
          )}

          {/* ============ STEP 5: Review ============ */}
          {step === 5 && (
            <div className="card-glass p-5 sm:p-8 space-y-5">
              <h2 className="text-xl font-bold text-gray-900">Revisão e envio</h2>

              <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                <div className="border border-gray-200 rounded-xl p-4">
                  <h3 className="font-semibold text-gray-900 mb-2">Documento</h3>
                  <p className="text-sm text-gray-700">{docName}</p>
                  <p className="text-xs text-gray-500 mt-1">{file?.name} · {totalPages} páginas</p>
                  <p className="text-xs text-gray-500 mt-1">{folderId ? `Pasta: ${folders.find((f: any) => f.id === folderId)?.name || '-'}` : 'Sem pasta'}</p>
                  <p className="text-xs text-gray-500 mt-1">Campos: {fields.length}</p>
                </div>
                <div className="border border-gray-200 rounded-xl p-4">
                  <h3 className="font-semibold text-gray-900 mb-2">Fluxo</h3>
                  <div className="flex items-center gap-2">
                    {signingOrder === 'parallel' ? <ArrowRightLeft className="w-4 h-4 text-brand-600" /> : <ArrowDownUp className="w-4 h-4 text-brand-600" />}
                    <span className="text-sm text-gray-700 font-medium">{signingOrder === 'parallel' ? 'Paralelo' : 'Sequencial'}</span>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">{signingOrder === 'parallel' ? 'Todos recebem ao mesmo tempo' : 'Segue ordem definida'}</p>
                  <p className="text-xs text-gray-500 mt-1">Prazo: {deadlineAt || 'Não definido'}</p>
                </div>
                <div className="border border-gray-200 rounded-xl p-4">
                  <h3 className="font-semibold text-gray-900 mb-2">Mensagem</h3>
                  <p className="text-sm text-gray-600 line-clamp-4">{message || 'Sem mensagem personalizada'}</p>
                </div>
              </div>

              <div className="space-y-3">
                <h3 className="font-semibold text-gray-900">Signatários ({signers.length})</h3>
                {signers.map((signer, idx) => {
                  const signerKey = signer.id || signer.temp_id;
                  const signerFields = fields.filter((f) => f.signer_id === signerKey || f.signer_id === signer.id);
                  return (
                    <div key={signerKey} className="border border-gray-200 rounded-xl p-4">
                      <div className="flex items-center justify-between gap-2 flex-wrap">
                        <div className="flex items-center gap-3">
                          {signingOrder === 'sequential' && (
                            <span className="w-7 h-7 rounded-full bg-brand-600 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">{idx + 1}</span>
                          )}
                          <div>
                            <p className="font-semibold text-gray-900">{signer.name}</p>
                            <p className="text-xs text-gray-500">{signer.email}</p>
                          </div>
                        </div>
                        <span className={`text-xs font-medium px-2.5 py-1 rounded-full border ${SIGNER_COLORS_PILL[idx % SIGNER_COLORS_PILL.length]}`}>
                          {AUTH_OPTIONS.find((a) => a.id === signer.auth_method)?.label || signer.auth_method}
                        </span>
                      </div>
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        {signer.metadata.require_face_photo && <span className="badge bg-blue-100 text-blue-700">Biometria</span>}
                        {signer.metadata.require_document_photo && <span className="badge bg-violet-100 text-violet-700">Documento</span>}
                        {signer.metadata.require_selfie && <span className="badge bg-cyan-100 text-cyan-700">Selfie</span>}
                        {signer.metadata.require_handwritten && <span className="badge bg-amber-100 text-amber-700">Manuscrita</span>}
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
        </div>
      </div>

      {/* Contacts Modal */}
      {showContacts && (
        <div className="modal-overlay" onClick={() => setShowContacts(false)}>
          <div className="modal-panel max-w-xl max-h-[80vh] overflow-auto" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Adicionar da agenda</h3>
              <button onClick={() => setShowContacts(false)} className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-lg hover:bg-gray-100">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <div className="space-y-2">
              {contacts.map((contact: any) => (
                <button key={contact.id} className="w-full text-left border border-gray-200 rounded-xl p-3 hover:bg-gray-50"
                  onClick={async () => {
                    await addSigner({ name: contact.name, email: contact.email, cpf: contact.cpf || '', phone: contact.phone || '' });
                    setShowContacts(false);
                  }}>
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
