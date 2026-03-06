import { useCallback, useMemo, useRef, useState } from 'react';
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
  totalPages: number;
  onPageChange?: (page: number) => void;
  selectedFieldId?: string | null;
  onSelectedFieldChange?: (fieldId: string | null) => void;
  pendingFieldType?: FieldType | null;
}

type DragState =
  | { kind: 'create'; startX: number; startY: number; currentX: number; currentY: number }
  | { kind: 'move'; fieldId: string; startX: number; startY: number; originX: number; originY: number }
  | { kind: 'resize'; fieldId: string; startX: number; startY: number; originW: number; originH: number };

const SIGNER_COLORS = [
  'border-brand-600 bg-brand-50/80 text-brand-800',
  'border-emerald-500 bg-emerald-50/80 text-emerald-800',
  'border-violet-500 bg-violet-50/80 text-violet-800',
  'border-amber-500 bg-amber-50/80 text-amber-800',
  'border-cyan-500 bg-cyan-50/80 text-cyan-800',
];

const FIELD_LABELS: Record<string, string> = {
  text: 'Texto', signature: 'Assinatura', initial: 'Rubrica', date: 'Data',
  number: 'Número', image: 'Imagem', checkbox: 'Caixa', multiple: 'Múltiplo',
  file: 'Arquivo', radio: 'Rádio', select: 'Selecionar', cells: 'Células', stamp: 'Carimbo',
};

export default function PdfViewer({
  url, fields, signers, onFieldAdd, onFieldUpdate, onFieldDelete,
  activeSignerId, editable, currentPage, totalPages, onPageChange,
  selectedFieldId, onSelectedFieldChange, pendingFieldType,
}: PdfViewerProps) {
  const overlayRef = useRef<HTMLDivElement>(null);
  const [drag, setDrag] = useState<DragState | null>(null);

  const isPlacingField = !!pendingFieldType && !!activeSignerId;

  const signerColorMap = useMemo(() => {
    const map: Record<string, string> = {};
    signers.forEach((signer, idx) => {
      const key = signer.id || signer.temp_id || `s-${idx}`;
      map[key] = SIGNER_COLORS[idx % SIGNER_COLORS.length];
    });
    return map;
  }, [signers]);

  const pageFields = useMemo(() => fields.filter((f) => f.page === currentPage), [fields, currentPage]);

  const getPercentCoords = useCallback((clientX: number, clientY: number) => {
    if (!overlayRef.current) return { x: 0, y: 0 };
    const rect = overlayRef.current.getBoundingClientRect();
    return {
      x: Math.max(0, Math.min(100, ((clientX - rect.left) / rect.width) * 100)),
      y: Math.max(0, Math.min(100, ((clientY - rect.top) / rect.height) * 100)),
    };
  }, []);

  const startCreate = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!editable || !isPlacingField) return;
    const pt = getPercentCoords(e.clientX, e.clientY);
    setDrag({ kind: 'create', startX: pt.x, startY: pt.y, currentX: pt.x, currentY: pt.y });
  };

  const onMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!drag) return;
    const pt = getPercentCoords(e.clientX, e.clientY);
    if (drag.kind === 'create') {
      setDrag({ ...drag, currentX: pt.x, currentY: pt.y });
    } else if (drag.kind === 'move') {
      onFieldUpdate(drag.fieldId, {
        x: Math.max(0, Math.min(100, drag.originX + pt.x - drag.startX)),
        y: Math.max(0, Math.min(100, drag.originY + pt.y - drag.startY)),
      });
    } else if (drag.kind === 'resize') {
      onFieldUpdate(drag.fieldId, {
        width: Math.max(3, Math.min(100, drag.originW + pt.x - drag.startX)),
        height: Math.max(2, Math.min(100, drag.originH + pt.y - drag.startY)),
      });
    }
  };

  const onMouseUp = () => {
    if (!drag) return;
    if (drag.kind === 'create') {
      const w = Math.abs(drag.currentX - drag.startX);
      const h = Math.abs(drag.currentY - drag.startY);
      if (w > 1 && h > 1 && pendingFieldType && activeSignerId) {
        onFieldAdd({
          field_type: pendingFieldType,
          signer_id: activeSignerId,
          page: currentPage,
          x: Math.min(drag.startX, drag.currentX),
          y: Math.min(drag.startY, drag.currentY),
          width: w,
          height: h,
          required: true,
        });
      }
    }
    setDrag(null);
  };

  const pdfUrlWithPage = `${url}#page=${currentPage}`;

  return (
    <div className="w-full h-full flex flex-col gap-3">
      {/* PDF container */}
      <div className="relative flex-1 min-h-[600px] bg-slate-100 rounded-2xl overflow-hidden border border-slate-200 shadow-inner">
        {/* PDF iframe - always interactive for scroll/zoom */}
        <iframe src={pdfUrlWithPage} title="PDF" className="absolute inset-0 w-full h-full" />

        {/* Overlay - only intercepts pointer when placing a field */}
        <div
          ref={overlayRef}
          className={`absolute inset-0 ${
            isPlacingField
              ? 'cursor-crosshair bg-brand-500/5'
              : 'pointer-events-none'
          }`}
          onMouseDown={startCreate}
          onMouseMove={onMouseMove}
          onMouseUp={onMouseUp}
          onMouseLeave={onMouseUp}
        >
          {/* Existing fields are always interactive */}
          {pageFields.map((field) => {
            const signer = signers.find((s) => s.id === field.signer_id || s.temp_id === field.signer_id);
            const signerKey = field.signer_id || signer?.id || signer?.temp_id || '';
            const colorClass = signerColorMap[signerKey] || SIGNER_COLORS[0];
            const isSelected = selectedFieldId === field.id;

            return (
              <div
                key={field.id}
                className={`absolute border-2 border-dashed rounded-md p-1 pointer-events-auto ${colorClass} ${
                  isSelected ? 'border-solid ring-2 ring-brand-300 shadow-lg' : ''
                } ${editable ? 'cursor-move hover:shadow-md' : ''}`}
                style={{
                  left: `${field.x}%`, top: `${field.y}%`,
                  width: `${field.width}%`, height: `${field.height}%`,
                }}
                onMouseDown={(e) => {
                  e.stopPropagation();
                  onSelectedFieldChange?.(field.id);
                  if (!editable) return;
                  const pt = getPercentCoords(e.clientX, e.clientY);
                  setDrag({ kind: 'move', fieldId: field.id, startX: pt.x, startY: pt.y, originX: field.x, originY: field.y });
                }}
              >
                <div className="flex items-center justify-between gap-1">
                  <span className="text-[10px] font-semibold truncate">
                    {FIELD_LABELS[field.field_type] || field.field_type} - {signer?.name || '?'}
                  </span>
                  {editable && (
                    <button
                      className="min-h-5 min-w-5 inline-flex items-center justify-center rounded hover:bg-white/80"
                      onClick={(e) => { e.stopPropagation(); onFieldDelete(field.id); }}
                    >
                      <X className="w-3 h-3" />
                    </button>
                  )}
                </div>
                {editable && (
                  <div
                    className="absolute bottom-0 right-0 w-3 h-3 bg-white border border-gray-300 rounded-sm cursor-se-resize"
                    onMouseDown={(e) => {
                      e.stopPropagation();
                      const pt = getPercentCoords(e.clientX, e.clientY);
                      setDrag({ kind: 'resize', fieldId: field.id, startX: pt.x, startY: pt.y, originW: field.width, originH: field.height });
                    }}
                  />
                )}
              </div>
            );
          })}

          {/* Creation preview rect */}
          {drag?.kind === 'create' && (
            <div
              className="absolute border-2 border-brand-600 border-dashed bg-brand-100/30 rounded-md pointer-events-none"
              style={{
                left: `${Math.min(drag.startX, drag.currentX)}%`,
                top: `${Math.min(drag.startY, drag.currentY)}%`,
                width: `${Math.abs(drag.currentX - drag.startX)}%`,
                height: `${Math.abs(drag.currentY - drag.startY)}%`,
              }}
            />
          )}
        </div>

        {/* Placing hint banner */}
        {isPlacingField && (
          <div className="absolute top-3 left-1/2 -translate-x-1/2 bg-brand-600 text-white text-xs font-medium px-4 py-2 rounded-full shadow-lg pointer-events-none z-10 animate-pulse">
            Clique e arraste para posicionar o campo
          </div>
        )}
      </div>
    </div>
  );
}
