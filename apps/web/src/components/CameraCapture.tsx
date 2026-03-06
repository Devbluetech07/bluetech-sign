import { useEffect, useMemo, useRef, useState } from 'react';
import { Camera, Loader2, RefreshCcw, Upload, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { useCamera } from '../hooks/useCamera';

interface CameraCaptureProps {
  mode: 'selfie' | 'document';
  title: string;
  instruction: string;
  onCapture: (base64: string) => void;
  onCancel: () => void;
}

export default function CameraCapture({
  mode,
  title,
  instruction,
  onCapture,
  onCancel,
}: CameraCaptureProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [captured, setCaptured] = useState<string | null>(null);
  const [loadingCamera, setLoadingCamera] = useState(true);

  const facingMode = useMemo(() => (mode === 'selfie' ? 'user' : 'environment'), [mode]);
  const { stream, hasPermission, startCamera, stopCamera, captureFrame: captureFromVideo } = useCamera(facingMode);

  useEffect(() => {
    const bootstrap = async () => {
      setLoadingCamera(true);
      const media = await startCamera();
      if (!media) {
        toast.error('Não foi possível acessar a câmera. Use upload de imagem.');
      }
      setLoadingCamera(false);
    };
    bootstrap();
    return () => {
      stopCamera();
    };
  }, [facingMode, startCamera, stopCamera]);

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
    }
  }, [stream]);

  const handleCapture = () => {
    const base64 = captureFromVideo(videoRef.current);
    if (!base64) return;
    setCaptured(base64);
    stopCamera();
  };

  const handleFile = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setCaptured(String(reader.result));
    reader.readAsDataURL(file);
  };

  return (
    <div className="card p-4 sm:p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
          <p className="text-sm text-gray-500">{instruction}</p>
        </div>
        <button onClick={onCancel} className="min-h-11 min-w-11 inline-flex items-center justify-center rounded-lg hover:bg-gray-100">
          <X className="w-5 h-5 text-gray-500" />
        </button>
      </div>

      {!captured ? (
        <div className="space-y-4">
          <div className="relative rounded-xl overflow-hidden bg-black aspect-video">
            {loadingCamera ? (
              <div className="absolute inset-0 flex items-center justify-center">
                <Loader2 className="w-7 h-7 animate-spin text-white" />
              </div>
            ) : (
              <video ref={videoRef} autoPlay playsInline muted className="w-full h-full object-cover" />
            )}
            <div
              className={`absolute inset-6 border-2 border-white/70 pointer-events-none ${
                mode === 'selfie' ? 'rounded-full' : 'rounded-lg border-dashed'
              }`}
            />
          </div>

          <div className="flex flex-col sm:flex-row gap-2">
            {hasPermission !== false && (
              <button
                onClick={handleCapture}
                className="btn-primary flex-1 inline-flex items-center justify-center gap-2"
              >
                <Camera className="w-4 h-4" /> Capturar
              </button>
            )}
            <label className="btn-secondary flex-1 inline-flex items-center justify-center gap-2 cursor-pointer">
              <Upload className="w-4 h-4" /> Enviar imagem
              <input type="file" accept="image/*" className="hidden" onChange={handleFile} />
            </label>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          <img src={captured} alt="Captura" className="w-full rounded-xl border border-gray-200" />
          <div className="flex flex-col sm:flex-row gap-2">
            <button
              onClick={() => {
                setCaptured(null);
                startCamera();
              }}
              className="btn-secondary flex-1 inline-flex items-center justify-center gap-2"
            >
              <RefreshCcw className="w-4 h-4" /> Refazer
            </button>
            <button onClick={() => onCapture(captured)} className="btn-primary flex-1">
              Confirmar foto
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
