import { useEffect, useMemo, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';
import { AlertTriangle, CheckCircle, FileText, Loader2, Lock, PenTool, Shield, XCircle } from 'lucide-react';
import toast, { Toaster } from 'react-hot-toast';
import { signingAPI } from '../services/api';
import CameraCapture from '../components/CameraCapture';
import DocumentTypeSelector from '../components/DocumentTypeSelector';

type Screen =
  | 'loading'
  | 'error'
  | 'already_signed'
  | 'welcome'
  | 'auth'
  | 'validations'
  | 'view_document'
  | 'sign'
  | 'success'
  | 'rejected';

type ValidationType = 'face' | 'document' | 'selfie' | 'residence';

const AUTH_LABELS: Record<string, string> = {
  email_token: 'Token por Email',
  sms_token: 'Token por SMS',
  whatsapp: 'WhatsApp',
  biometria_facial: 'Biometria facial',
  link: 'Link direto',
  presencial: 'Presencial',
};

export default function SigningPage() {
  const { token } = useParams<{ token: string }>();
  const [screen, setScreen] = useState<Screen>('loading');
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState('');

  const [verificationCode, setVerificationCode] = useState('');
  const [verifying, setVerifying] = useState(false);
  const [signing, setSigning] = useState(false);

  const [validationQueue, setValidationQueue] = useState<ValidationType[]>([]);
  const [validationIndex, setValidationIndex] = useState(0);
  const [docType, setDocType] = useState<string>('');
  const [docSides, setDocSides] = useState<'front' | 'both'>('front');
  const [docFront, setDocFront] = useState<string | null>(null);
  const [docBack, setDocBack] = useState<string | null>(null);
  const [residencePhoto, setResidencePhoto] = useState<string | null>(null);

  const [signatureMode, setSignatureMode] = useState<'draw' | 'type'>('draw');
  const [typedName, setTypedName] = useState('');
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showReject, setShowReject] = useState(false);

  useEffect(() => {
    if (!token) return;
    signingAPI
      .getDocument(token)
      .then((response) => {
        setData(response.data);
        if (response.data.already_signed) setScreen('already_signed');
        else setScreen('welcome');
      })
      .catch((err) => {
        setError(err.response?.data?.error || 'Link invalido ou expirado');
        setScreen('error');
      });
  }, [token]);

  const metadata = useMemo(() => {
    const signerMetadata = data?.signer?.metadata || {};
    return {
      require_face_photo: !!signerMetadata.require_face_photo,
      require_document_photo: !!signerMetadata.require_document_photo,
      require_selfie: !!signerMetadata.require_selfie,
      require_handwritten: !!signerMetadata.require_handwritten,
      require_residence_proof: !!signerMetadata.require_residence_proof,
      document_photo_type: signerMetadata.document_photo_type || '',
      document_photo_sides: signerMetadata.document_photo_sides === 'both' ? 'both' : 'front',
    };
  }, [data]);

  useEffect(() => {
    if (metadata.require_handwritten) {
      setSignatureMode('draw');
    }
  }, [metadata.require_handwritten]);

  const beginAuth = async () => {
    const method = data?.signer?.auth_method;
    if (['email_token', 'sms_token', 'whatsapp'].includes(method)) {
      try {
        await signingAPI.requestToken(token!);
        toast.success('Codigo enviado para validacao');
      } catch {
        toast.error('Falha ao enviar codigo');
      }
    }
    setScreen('auth');
  };

  const proceedAfterAuth = () => {
    const queue: ValidationType[] = [];
    if (metadata.require_face_photo) queue.push('face');
    if (metadata.require_document_photo) queue.push('document');
    if (metadata.require_selfie) queue.push('selfie');
    if (metadata.require_residence_proof) queue.push('residence');
    setValidationQueue(queue);
    setValidationIndex(0);
    setScreen(queue.length ? 'validations' : 'view_document');
  };

  const verifyAuth = async (capturedFace?: string) => {
    const method = data?.signer?.auth_method;
    setVerifying(true);
    try {
      if (['email_token', 'sms_token', 'whatsapp'].includes(method)) {
        await signingAPI.verifyToken(token!, verificationCode);
      }
      if (method === 'biometria_facial') {
        if (!capturedFace) throw new Error('Foto nao fornecida');
        const result = await signingAPI.verifyBiometria(token!, capturedFace);
        if (!result.data?.verified) throw new Error('Biometria nao validada');
      }
      toast.success('Autenticacao validada');
      proceedAfterAuth();
    } catch {
      toast.error('Não foi possível validar autenticação');
    } finally {
      setVerifying(false);
    }
  };

  const currentValidation = validationQueue[validationIndex];

  const nextValidation = () => {
    if (validationIndex < validationQueue.length - 1) {
      setValidationIndex((prev) => prev + 1);
      return;
    }
    setScreen('view_document');
  };

  const handleFaceValidation = async (image: string) => {
    setVerifying(true);
    try {
      const result = await signingAPI.verifyBiometria(token!, image);
      if (!result.data?.verified) throw new Error();
      toast.success('Biometria validada');
      nextValidation();
    } catch {
      toast.error('Verificacao facial falhou');
    } finally {
      setVerifying(false);
    }
  };

  const submitDocumentPhotos = async () => {
    if (!docFront) return toast.error('Capture a frente do documento');
    setVerifying(true);
    try {
      await signingAPI.uploadPhoto(token!, docFront);
      if (docSides === 'both' && docBack) {
        await signingAPI.uploadPhoto(token!, docBack);
      }
      toast.success('Fotos do documento enviadas');
      nextValidation();
    } catch {
      toast.error('Erro ao enviar fotos do documento');
    } finally {
      setVerifying(false);
    }
  };

  const submitResidencePhoto = async () => {
    if (!residencePhoto) return;
    setVerifying(true);
    try {
      await signingAPI.uploadPhoto(token!, residencePhoto);
      toast.success('Comprovante enviado');
      nextValidation();
    } catch {
      toast.error('Falha ao enviar comprovante');
    } finally {
      setVerifying(false);
    }
  };

  const submitSignature = async () => {
    setSigning(true);
    try {
      let image: string | null = null;
      if (signatureMode === 'draw' && canvasRef.current) image = canvasRef.current.toDataURL('image/png');
      await signingAPI.sign(token!, {
        signature_data: {
          type: signatureMode,
          image,
          typed_name: signatureMode === 'type' ? typedName : null,
        },
        token_code: verificationCode || undefined,
      });
      toast.success('Documento assinado com sucesso');
      setScreen('success');
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Erro ao assinar');
    } finally {
      setSigning(false);
    }
  };

  const rejectDocument = async () => {
    try {
      await signingAPI.reject(token!, rejectReason);
      setScreen('rejected');
    } catch {
      toast.error('Erro ao recusar assinatura');
    }
  };

  const startDraw = (event: React.MouseEvent | React.TouchEvent) => {
    if (!canvasRef.current) return;
    const ctx = canvasRef.current.getContext('2d');
    if (!ctx) return;
    const rect = canvasRef.current.getBoundingClientRect();
    const pointX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const pointY = 'touches' in event ? event.touches[0].clientY : event.clientY;
    ctx.beginPath();
    ctx.moveTo(pointX - rect.left, pointY - rect.top);
    setIsDrawing(true);
  };

  const draw = (event: React.MouseEvent | React.TouchEvent) => {
    if (!isDrawing || !canvasRef.current) return;
    const ctx = canvasRef.current.getContext('2d');
    if (!ctx) return;
    const rect = canvasRef.current.getBoundingClientRect();
    const pointX = 'touches' in event ? event.touches[0].clientX : event.clientX;
    const pointY = 'touches' in event ? event.touches[0].clientY : event.clientY;
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.strokeStyle = '#1E3A5F';
    ctx.lineTo(pointX - rect.left, pointY - rect.top);
    ctx.stroke();
  };

  const clearCanvas = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
  };

  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <div className="min-h-screen bg-gradient-to-br from-slate-100 via-white to-sky-50">
      <Toaster position="top-center" />
      <header className="bg-white/80 backdrop-blur-md border-b border-slate-200">
        <div className="max-w-5xl mx-auto px-4 py-4 flex items-center gap-3">
          <div className="w-10 h-10 bg-brand-600 rounded-xl flex items-center justify-center">
            <Shield className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="text-gray-900 font-semibold">{data?.organization?.name || 'BlueTech Assina'}</h1>
            <p className="text-xs text-gray-500">Assinatura digital segura</p>
          </div>
        </div>
      </header>
      <main className="max-w-5xl mx-auto px-3 sm:px-4 py-5 sm:py-8 page-shell">{children}</main>
    </div>
  );

  if (screen === 'loading') {
    return (
      <Wrapper>
        <div className="flex justify-center py-20">
          <Loader2 className="w-8 h-8 animate-spin text-brand-600" />
        </div>
      </Wrapper>
    );
  }

  if (screen === 'error') {
    return (
      <Wrapper>
        <div className="card p-10 text-center">
          <XCircle className="w-12 h-12 text-red-500 mx-auto mb-3" />
          <h2 className="font-semibold text-gray-900">Link invalido</h2>
          <p className="text-sm text-gray-500 mt-1">{error}</p>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'already_signed') {
    return (
      <Wrapper>
        <div className="card p-10 text-center">
          <CheckCircle className="w-12 h-12 text-emerald-500 mx-auto mb-3" />
          <h2 className="font-semibold text-gray-900">Documento ja assinado</h2>
          <p className="text-sm text-gray-500 mt-1">Esta assinatura ja foi concluida anteriormente.</p>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'welcome') {
    return (
      <Wrapper>
        <div className="card-glass p-6 sm:p-8 space-y-4">
          <h2 className="text-xl font-bold text-gray-900">Bem-vindo ao fluxo de assinatura</h2>
          <p className="text-sm text-gray-600">Documento: <strong>{data?.document?.name}</strong></p>
          <p className="text-sm text-gray-600">Metodo de autenticacao: {AUTH_LABELS[data?.signer?.auth_method] || data?.signer?.auth_method}</p>
          <button onClick={beginAuth} className="btn-primary w-full sm:w-auto">Iniciar</button>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'auth') {
    const method = data?.signer?.auth_method;
    if (['link', 'presencial'].includes(method)) {
      proceedAfterAuth();
      return null;
    }

    if (method === 'biometria_facial') {
      return (
        <Wrapper>
          <CameraCapture
            mode="selfie"
            title="Validacao biometrica"
            instruction="Posicione seu rosto no enquadramento para validar."
            onCapture={(image) => verifyAuth(image)}
            onCancel={() => setScreen('welcome')}
          />
        </Wrapper>
      );
    }

    return (
      <Wrapper>
        <div className="max-w-md mx-auto card-glass p-5 sm:p-8 space-y-4">
          <div className="text-center">
            <div className="w-14 h-14 bg-brand-50 rounded-full flex items-center justify-center mx-auto mb-2">
              <Lock className="w-7 h-7 text-brand-600" />
            </div>
            <h2 className="text-xl font-semibold text-gray-900">Informe o codigo de verificacao</h2>
          </div>
          <input
            value={verificationCode}
            onChange={(e) => setVerificationCode(e.target.value)}
            maxLength={6}
            className="input-field text-center text-2xl tracking-[0.5em]"
            placeholder="000000"
          />
          <button
            onClick={() => verifyAuth()}
            disabled={verifying || verificationCode.length < 6}
            className="btn-primary w-full inline-flex items-center justify-center gap-2 disabled:opacity-50"
          >
            {verifying ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
            Verificar
          </button>
          <button
            onClick={() => signingAPI.requestToken(token!).then(() => toast.success('Codigo reenviado')).catch(() => toast.error('Erro ao reenviar'))}
            className="btn-secondary w-full"
          >
            Reenviar codigo
          </button>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'validations') {
    if (currentValidation === 'face') {
      return (
        <Wrapper>
          <CameraCapture
            mode="selfie"
            title="Coleta de foto do rosto"
            instruction="Use boa iluminacao e mantenha o rosto visivel."
            onCapture={handleFaceValidation}
            onCancel={() => setScreen('welcome')}
          />
        </Wrapper>
      );
    }

    if (currentValidation === 'document') {
      if (!docType && !metadata.document_photo_type) {
        return (
          <Wrapper>
            <DocumentTypeSelector
              onSelect={(type, sides) => {
                setDocType(type);
                setDocSides(sides);
              }}
            />
          </Wrapper>
        );
      }

      if (!docFront) {
        return (
          <Wrapper>
            <CameraCapture
              mode="document"
              title={`Frente do documento (${docType || metadata.document_photo_type})`}
              instruction="Posicione o documento no centro e capture a frente."
              onCapture={(base64) => setDocFront(base64)}
              onCancel={() => {
                setDocType('');
                setDocFront(null);
                setDocBack(null);
              }}
            />
          </Wrapper>
        );
      }

      if ((docSides === 'both' || metadata.document_photo_sides === 'both') && !docBack) {
        return (
          <Wrapper>
            <CameraCapture
              mode="document"
              title="Verso do documento"
              instruction="Agora capture o verso do documento."
              onCapture={(base64) => setDocBack(base64)}
              onCancel={() => setDocBack(null)}
            />
          </Wrapper>
        );
      }

      return (
        <Wrapper>
          <div className="card-glass p-6 max-w-lg mx-auto">
            <h3 className="font-semibold text-gray-900 mb-2">Enviar fotos do documento</h3>
            <p className="text-sm text-gray-500 mb-4">As capturas estao prontas para envio.</p>
            <button onClick={submitDocumentPhotos} disabled={verifying} className="btn-primary w-full inline-flex items-center justify-center gap-2">
              {verifying ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
              Confirmar envio
            </button>
          </div>
        </Wrapper>
      );
    }

    if (currentValidation === 'selfie') {
      return (
        <Wrapper>
          <CameraCapture
            mode="selfie"
            title="Selfie com documento"
            instruction="Segure o documento e capture uma selfie."
            onCapture={async (image) => {
              try {
                await signingAPI.uploadSelfie(token!, image);
                toast.success('Selfie enviada');
                nextValidation();
              } catch {
                toast.error('Falha ao enviar selfie');
              }
            }}
            onCancel={() => setScreen('welcome')}
          />
        </Wrapper>
      );
    }

    if (currentValidation === 'residence') {
      if (!residencePhoto) {
        return (
          <Wrapper>
            <CameraCapture
              mode="document"
              title="Comprovante de residencia"
              instruction="Capture a foto do comprovante."
              onCapture={(image) => setResidencePhoto(image)}
              onCancel={() => setScreen('welcome')}
            />
          </Wrapper>
        );
      }
      return (
        <Wrapper>
          <div className="card-glass p-6 max-w-lg mx-auto">
            <button onClick={submitResidencePhoto} disabled={verifying} className="btn-primary w-full inline-flex items-center justify-center gap-2">
              {verifying ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
              Enviar comprovante
            </button>
          </div>
        </Wrapper>
      );
    }
  }

  if (screen === 'view_document') {
    return (
      <Wrapper>
        <div className="card-glass overflow-hidden">
          <div className="p-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="font-semibold text-gray-900 inline-flex items-center gap-2">
              <FileText className="w-4 h-4" /> {data?.document?.name}
            </h2>
            <button onClick={() => setScreen('sign')} className="btn-primary">Continuar</button>
          </div>
          <iframe src={data?.document?.file_url} className="w-full h-[70vh]" title="Documento" />
          <div className="p-4 border-t border-gray-100">
            <button onClick={() => setShowReject((prev) => !prev)} className="btn-secondary">Recusar assinatura</button>
            {showReject && (
              <div className="mt-3 space-y-2">
                <textarea value={rejectReason} onChange={(e) => setRejectReason(e.target.value)} className="input-field" rows={3} placeholder="Motivo da recusa" />
                <button onClick={rejectDocument} className="btn-danger">Confirmar recusa</button>
              </div>
            )}
          </div>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'sign') {
    return (
      <Wrapper>
        <div className="max-w-2xl mx-auto card-glass p-5 sm:p-8 space-y-5">
          <h2 className="text-xl font-semibold text-gray-900 text-center">Assinar documento</h2>

          {!metadata.require_handwritten && (
            <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
              <button onClick={() => setSignatureMode('draw')} className={`flex-1 min-h-11 rounded-md ${signatureMode === 'draw' ? 'bg-white shadow text-gray-900' : 'text-gray-500'}`}>Desenhar</button>
              <button onClick={() => setSignatureMode('type')} className={`flex-1 min-h-11 rounded-md ${signatureMode === 'type' ? 'bg-white shadow text-gray-900' : 'text-gray-500'}`}>Digitar</button>
            </div>
          )}

          {signatureMode === 'draw' && (
            <div>
              <div className="border-2 border-dashed border-gray-200 rounded-xl overflow-hidden relative">
                <canvas
                  ref={canvasRef}
                  width={600}
                  height={220}
                  className="w-full touch-none"
                  onMouseDown={startDraw}
                  onMouseMove={draw}
                  onMouseUp={() => setIsDrawing(false)}
                  onMouseLeave={() => setIsDrawing(false)}
                  onTouchStart={startDraw}
                  onTouchMove={draw}
                  onTouchEnd={() => setIsDrawing(false)}
                />
                <p className="absolute bottom-2 left-1/2 -translate-x-1/2 text-xs text-gray-300">Assine na area</p>
              </div>
              <button onClick={clearCanvas} className="btn-secondary mt-2">Limpar</button>
            </div>
          )}

          {signatureMode === 'type' && (
            <div className="space-y-3">
              <input value={typedName} onChange={(e) => setTypedName(e.target.value)} className="input-field" placeholder="Digite seu nome completo" />
              <div className="border border-gray-200 rounded-xl p-6 text-center bg-gray-50 min-h-[96px] flex items-center justify-center">
                <span className="text-3xl italic font-serif text-gray-800">{typedName || 'Sua assinatura'}</span>
              </div>
            </div>
          )}

          <div className="bg-amber-50 border border-amber-100 rounded-xl p-4">
            <p className="text-xs text-amber-800">
              <AlertTriangle className="inline w-3.5 h-3.5 mr-1" />
              Ao assinar, voce confirma a leitura e concordancia com o conteudo do documento.
            </p>
          </div>

          <button onClick={submitSignature} disabled={signing || (signatureMode === 'type' && !typedName)} className="btn-primary w-full inline-flex items-center justify-center gap-2 disabled:opacity-50">
            {signing ? <Loader2 className="w-4 h-4 animate-spin" /> : <PenTool className="w-4 h-4" />}
            Confirmar assinatura
          </button>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'success') {
    return (
      <Wrapper>
        <div className="card p-10 text-center">
          <CheckCircle className="w-14 h-14 text-emerald-500 mx-auto mb-4" />
          <h2 className="text-xl font-semibold text-gray-900">Assinatura realizada</h2>
          <p className="text-sm text-gray-500 mt-1">Obrigado! O remetente sera notificado automaticamente.</p>
        </div>
      </Wrapper>
    );
  }

  if (screen === 'rejected') {
    return (
      <Wrapper>
        <div className="card p-10 text-center">
          <XCircle className="w-14 h-14 text-red-500 mx-auto mb-4" />
          <h2 className="text-xl font-semibold text-gray-900">Assinatura recusada</h2>
          <p className="text-sm text-gray-500 mt-1">Sua recusa foi registrada e enviada ao remetente.</p>
        </div>
      </Wrapper>
    );
  }

  return null;
}
