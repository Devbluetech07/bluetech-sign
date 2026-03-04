const DOCUMENT_TYPES = [
  { id: 'rg', label: 'RG - Registro Geral', sides: 'both' as const },
  { id: 'cnh', label: 'CNH - Carteira Nacional de Habilitacao', sides: 'both' as const },
  { id: 'passaporte', label: 'Passaporte', sides: 'front' as const },
  { id: 'rne', label: 'RNE - Registro Nacional de Estrangeiro', sides: 'both' as const },
  { id: 'certidao', label: 'Certidao de Nascimento/Casamento', sides: 'front' as const },
  { id: 'outros', label: 'Outro documento', sides: 'front' as const },
];

interface DocumentTypeSelectorProps {
  onSelect: (type: string, sides: 'front' | 'both') => void;
}

export default function DocumentTypeSelector({ onSelect }: DocumentTypeSelectorProps) {
  return (
    <div className="card p-4 sm:p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-1">Tipo de documento</h3>
      <p className="text-sm text-gray-500 mb-4">Selecione qual documento sera fotografado.</p>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {DOCUMENT_TYPES.map((item) => (
          <button
            key={item.id}
            onClick={() => onSelect(item.id, item.sides)}
            className="text-left min-h-11 px-4 py-3 border border-gray-200 rounded-xl hover:border-brand-500 hover:bg-brand-50 transition-colors"
          >
            <p className="text-sm font-medium text-gray-900">{item.label}</p>
            <p className="text-xs text-gray-500 mt-1">
              {item.sides === 'both' ? 'Frente + verso' : 'Apenas frente'}
            </p>
          </button>
        ))}
      </div>
    </div>
  );
}
