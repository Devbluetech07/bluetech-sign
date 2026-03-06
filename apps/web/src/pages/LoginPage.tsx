import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/auth.store';
import { Shield, Eye, EyeOff, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { readWhiteLabelConfig } from '../theme/whitelabel';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPass, setShowPass] = useState(false);
  const { login, loading } = useAuthStore();
  const navigate = useNavigate();
  const whiteLabel = readWhiteLabelConfig();
  const platformName = whiteLabel.platform_name || 'BlueTech Assina';
  const logoUrl = whiteLabel.logo_url;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await login(email, password);
      toast.success('Login realizado com sucesso!');
      navigate('/');
    } catch (err: any) {
      toast.error(err.message);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-brand-600 via-brand-700 to-brand-900 flex items-center justify-center p-4">
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-accent-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-brand-400/10 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          {logoUrl ? (
            <img src={logoUrl} alt={platformName} className="inline-flex w-16 h-16 rounded-2xl mb-4 object-cover border border-white/30" />
          ) : (
            <div className="inline-flex items-center justify-center w-16 h-16 bg-white/10 backdrop-blur rounded-2xl mb-4 border border-white/20">
              <Shield className="w-8 h-8 text-white" />
            </div>
          )}
          <h1 className="text-3xl font-bold text-white">{platformName}</h1>
          <p className="text-blue-200 mt-2">Sistema de Assinatura Digital Gamificado</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="glass-panel rounded-2xl p-5 sm:p-8 border-white/25 shadow-2xl">
          <h2 className="text-xl font-semibold text-white mb-6">Entrar na sua conta</h2>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-blue-100 mb-1.5">Email</label>
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="seu@email.com"
                className="input-glass" required />
            </div>

            <div>
              <label className="block text-sm font-medium text-blue-100 mb-1.5">Senha</label>
              <div className="relative">
                <input type={showPass ? 'text' : 'password'} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••"
                  className="input-glass pr-12" required />
                <button type="button" onClick={() => setShowPass(!showPass)} className="absolute right-1 top-1/2 -translate-y-1/2 min-h-11 min-w-11 inline-flex items-center justify-center text-blue-300 hover:text-white">
                  {showPass ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
          </div>

          <button type="submit" disabled={loading}
            className="w-full mt-6 min-h-11 py-3 bg-accent-500 hover:bg-accent-600 text-white font-semibold rounded-xl transition-all duration-200 flex items-center justify-center gap-2 disabled:opacity-50 shadow-lg shadow-accent-500/25">
            {loading ? <><Loader2 className="w-5 h-5 animate-spin" /> Entrando...</> : 'Entrar'}
          </button>

          <div className="mt-6 p-4 bg-white/5 rounded-xl border border-white/10">
            <p className="text-blue-200 text-xs text-center mb-2">Credenciais de teste:</p>
            <div className="text-center">
              <p className="text-white text-sm font-mono">admin@bluetechfilms.com.br</p>
              <p className="text-white text-sm font-mono">Admin@2024</p>
            </div>
          </div>
        </form>

        <p className="text-center text-blue-300/60 text-xs mt-6">&copy; {new Date().getFullYear()} BlueTech Films. Todos os direitos reservados.</p>
      </div>
    </div>
  );
}
