import { useCallback, useEffect, useMemo, useState } from 'react';

type FacingMode = 'user' | 'environment';

export function useCamera(facingMode: FacingMode = 'user') {
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [isActive, setIsActive] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [error, setError] = useState<string | null>(null);

  const stopCamera = useCallback(() => {
    if (stream) {
      // Always stop tracks to release camera device.
      stream.getTracks().forEach((track) => track.stop());
      setStream(null);
    }
    setIsActive(false);
  }, [stream]);

  const startCamera = useCallback(async () => {
    try {
      const media = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode,
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });
      setStream(media);
      setIsActive(true);
      setHasPermission(true);
      setError(null);
      return media;
    } catch (err) {
      setIsActive(false);
      setHasPermission(false);
      setError(err instanceof Error ? err.message : 'Nao foi possivel acessar a camera');
      return null;
    }
  }, [facingMode]);

  const captureFrame = useCallback(
    (videoElement: HTMLVideoElement | null): string | null => {
      if (!videoElement) return null;
      const canvas = document.createElement('canvas');
      canvas.width = videoElement.videoWidth || 1280;
      canvas.height = videoElement.videoHeight || 720;
      const context = canvas.getContext('2d');
      if (!context) return null;
      context.drawImage(videoElement, 0, 0, canvas.width, canvas.height);
      return canvas.toDataURL('image/jpeg', 0.85);
    },
    [],
  );

  useEffect(() => {
    return () => {
      stopCamera();
    };
  }, [stopCamera]);

  return useMemo(
    () => ({
      stream,
      isActive,
      hasPermission,
      error,
      startCamera,
      stopCamera,
      captureFrame,
    }),
    [stream, isActive, hasPermission, error, startCamera, stopCamera, captureFrame],
  );
}
