import { useMemo, useRef, useState } from 'react';
import { X } from 'lucide-react';
import { DocumentField, FieldType } from '../types/documentBuilder';

interface SignerLite {
  id?: string;
  temp_id?: string;
  name: string;
}

interface PdfViewerProps {
  url: string;
  fields: DocumentField[];
  signers: SignerLite[];
  onFieldAdd: (field: Partial<DocumentField>) => void;
  onFieldUpdate: (fieldId: string, updates: Partial<DocumentField>) => void;
  onFieldDelete: (fieldId: string) => void;
  activeSignerId: string | null;
  editable: boolean;
  currentPage: number;
  onPageChange?: (page: number) => void;
  selectedFieldId?: string | null;
  onSelectedFieldChange?: (fieldId: string | null) => void;
  pendingFieldType?: FieldType | null;
}

type DragState =
  | {
      kind: 'create';
      startX: number;
      startY: number;
      currentX: number;
      currentY: number;
    }
  | {
      kind: 'move';
      fieldId: string;
      startX: number;
      startY: number;
      originX: number;
      originY: number;
    }
  | {
      kind: 'resize';
      fieldId: string;
      startX: number;
      startY: number;
      originW: number;
      originH: number;
    };

const SIGNER_COLORS = [
  'border-brand-600 bg-brand-50/80 text-brand-800',
  'border-emerald-500 bg-emerald-50/80 text-emerald-800',
  'border-violet-500 bg-violet-50/80 text-violet-800',
  'border-amber-500 bg-amber-50/80 text-amber-800',
  'border-cyan-500 bg-cyan-50/80 text-cyan-800',
];

export default function PdfViewer({
  url,
  fields,
  signers,
  onFieldAdd,
  onFieldUpdate,
  onFieldDelete,
  activeSignerId,
  editable,
  currentPage,
  onPageChange,
  selectedFieldId,
  onSelectedFieldChange,
  pendingFieldType,
}: PdfViewerProps) {
  const overlayRef = useRef<HTMLDivElement>(null);
  const [drag, setDrag] = useState<DragState | null>(null);

  const signerColorMap = useMemo(() => {
    const map: Record<string, string> = {};
    signers.forEach((signer, idx) => {
      const key = signer.id || signer.temp_id || `s-${idx}`;
      map[key] = SIGNER_COLORS[idx % SIGNER_COLORS.length];
    });
    return map;
  }, [signers]);

  const pageFields = useMemo(() => fields.filter((field) => field.page === currentPage), [fields, currentPage]);

  const getPercentCoords = (clientX: number, clientY: number) => {
    if (!overlayRef.current) return { x: 0, y: 0 };
    const rect = overlayRef.current.getBoundingClientRect();
    const x = ((clientX - rect.left) / rect.width) * 100;
    const y = ((clientY - rect.top) / rect.height) * 100;
    return {
      x: Math.max(0, Math.min(100, x)),
      y: Math.max(0, Math.min(100, y)),
    };
  };

  const startCreate = (event: React.MouseEvent<HTMLDivElement>) => {
    if (!editable || !pendingFieldType || !activeSignerId) return;
    const point = getPercentCoords(event.clientX, event.clientY);
    setDrag({
      kind: 'create',
      startX: point.x,
      startY: point.y,
      currentX: point.x,
      currentY: point.y,
    });
  };

  const onMouseMove = (event: React.MouseEvent<HTMLDivElement>) => {
    if (!drag) return;
    const point = getPercentCoords(event.clientX, event.clientY);
    if (drag.kind === 'create') {
      setDrag({ ...drag, currentX: point.x, currentY: point.y });
      return;
    }
    if (drag.kind === 'move') {
      const deltaX = point.x - drag.startX;
      const deltaY = point.y - drag.startY;
      onFieldUpdate(drag.fieldId, {
        x: Math.max(0, Math.min(100, drag.originX + deltaX)),
        y: Math.max(0, Math.min(100, drag.originY + deltaY)),
      });
      return;
    }
    if (drag.kind === 'resize') {
      const deltaX = point.x - drag.startX;
      const deltaY = point.y - drag.startY;
      onFieldUpdate(drag.fieldId, {
        width: Math.max(3, Math.min(100, drag.originW + deltaX)),
        height: Math.max(2, Math.min(100, drag.originH + deltaY)),
      });
    }
  };

  const onMouseUp = () => {
    if (!drag) return;
    if (drag.kind === 'create') {
      const width = Math.abs(drag.currentX - drag.startX);
      const height = Math.abs(drag.currentY - drag.startY);
      if (width > 1 && height > 1 && pendingFieldType && activeSignerId) {
        onFieldAdd({
          field_type: pendingFieldType,
          signer_id: activeSignerId,
          page: currentPage,
          x: Math.min(drag.startX, drag.currentX),
          y: Math.min(drag.startY, drag.currentY),
          width,
          height,
          required: true,
        });
      }
    }
    setDrag(null);
  };

  return (
    <div className="w-full h-full flex flex-col gap-3">
      <div className="flex gap-2 overflow-x-auto">
        {Array.from({ length: Math.max(1, currentPage + 2) }).map((_, idx) => {
          const page = idx + 1;
          return (
            <button
              key={page}
              onClick={() => onPageChange?.(page)}
              className={`min-h-11 min-w-11 px-3 rounded-lg border text-sm ${
                currentPage === page ? 'border-brand-600 text-brand-700 bg-brand-50' : 'border-gray-200 text-gray-500'
              }`}
            >
              {page}
            </button>
          );
        })}
      </div>

      <div className="relative flex-1 min-h-[520px] bg-gray-100 rounded-2xl overflow-hidden border border-gray-200">
        <iframe src={url} title="PDF" className="absolute inset-0 w-full h-full" />
        <embed src={url} type="application/pdf" className="absolute inset-0 w-full h-full pointer-events-none opacity-0" />

        <div
          ref={overlayRef}
          className={`absolute inset-0 ${editable ? 'cursor-crosshair' : 'cursor-default'}`}
          onMouseDown={startCreate}
          onMouseMove={onMouseMove}
          onMouseUp={onMouseUp}
          onMouseLeave={onMouseUp}
        >
          {pageFields.map((field) => {
            const signer = signers.find((item) => item.id === field.signer_id || item.temp_id === field.signer_id);
            const signerKey = field.signer_id || signer?.id || signer?.temp_id || '';
            const colorClass = signerColorMap[signerKey] || SIGNER_COLORS[0];
            const isSelected = selectedFieldId === field.id;

            return (
              <div
                key={field.id}
                className={`absolute border-2 border-dashed rounded-md p-1 ${colorClass} ${
                  isSelected ? 'border-solid ring-2 ring-brand-200' : ''
                }`}
                style={{
                  left: `${field.x}%`,
                  top: `${field.y}%`,
                  width: `${field.width}%`,
                  height: `${field.height}%`,
                }}
                onMouseDown={(event) => {
                  event.stopPropagation();
                  onSelectedFieldChange?.(field.id);
                  if (!editable) return;
                  const point = getPercentCoords(event.clientX, event.clientY);
                  setDrag({
                    kind: 'move',
                    fieldId: field.id,
                    startX: point.x,
                    startY: point.y,
                    originX: field.x,
                    originY: field.y,
                  });
                }}
              >
                <div className="flex items-center justify-between gap-1">
                  <span className="text-[10px] font-semibold truncate">
                    {field.field_type} - {signer?.name || 'Sem signatario'}
                  </span>
                  {editable && (
                    <button
                      className="min-h-5 min-w-5 inline-flex items-center justify-center rounded hover:bg-white/80"
                      onClick={(event) => {
                        event.stopPropagation();
                        onFieldDelete(field.id);
                      }}
                    >
                      <X className="w-3 h-3" />
                    </button>
                  )}
                </div>
                {editable && (
                  <button
                    className="absolute bottom-0 right-0 w-3 h-3 bg-white border border-gray-300 rounded-sm"
                    onMouseDown={(event) => {
                      event.stopPropagation();
                      const point = getPercentCoords(event.clientX, event.clientY);
                      setDrag({
                        kind: 'resize',
                        fieldId: field.id,
                        startX: point.x,
                        startY: point.y,
                        originW: field.width,
                        originH: field.height,
                      });
                    }}
                  />
                )}
              </div>
            );
          })}

          {drag?.kind === 'create' && (
            <div
              className="absolute border-2 border-brand-600 border-dashed bg-brand-100/30 rounded-md"
              style={{
                left: `${Math.min(drag.startX, drag.currentX)}%`,
                top: `${Math.min(drag.startY, drag.currentY)}%`,
                width: `${Math.abs(drag.currentX - drag.startX)}%`,
                height: `${Math.abs(drag.currentY - drag.startY)}%`,
              }}
            />
          )}
        </div>
      </div>
    </div>
  );
}
