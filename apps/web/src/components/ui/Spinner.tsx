import { Loader2 } from 'lucide-react';

interface SpinnerProps {
  className?: string;
}

export default function Spinner({ className = 'w-5 h-5' }: SpinnerProps) {
  return <Loader2 className={`${className} animate-spin`} />;
}
