import Badge from './Badge';
import { DocumentStatus, SignerStatus } from '../../types';
import { statusClassMap } from '../../theme/status';

interface StatusBadgeProps {
  status: DocumentStatus | SignerStatus;
}

export default function StatusBadge({ status }: StatusBadgeProps) {
  return <Badge className={statusClassMap[status] ?? 'bg-gray-100 text-gray-700'}>{status}</Badge>;
}
