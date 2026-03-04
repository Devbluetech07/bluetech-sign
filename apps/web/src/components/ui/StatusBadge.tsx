import Badge from './Badge';
import { DocumentStatus, SignerStatus } from '../../types';

interface StatusBadgeProps {
  status: DocumentStatus | SignerStatus;
}

const styles: Record<string, string> = {
  draft: 'bg-gray-100 text-gray-700',
  pending: 'bg-yellow-100 text-yellow-700',
  in_progress: 'bg-blue-100 text-blue-700',
  completed: 'bg-emerald-100 text-emerald-700',
  cancelled: 'bg-red-100 text-red-700',
  expired: 'bg-orange-100 text-orange-700',
  rejected: 'bg-rose-100 text-rose-700',
  sent: 'bg-indigo-100 text-indigo-700',
  opened: 'bg-cyan-100 text-cyan-700',
  signed: 'bg-emerald-100 text-emerald-700',
};

export default function StatusBadge({ status }: StatusBadgeProps) {
  return <Badge className={styles[status] ?? 'bg-gray-100 text-gray-700'}>{status}</Badge>;
}
