import { Routes, Route, Navigate, useLocation, Link, useNavigate } from 'react-router-dom';
import { useState, useEffect, ReactNode } from 'react';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './store/auth.store';
import {
  LayoutDashboard, FileText, FolderOpen, Users, BookUser, FileSignature,
  Settings, BarChart3, LogOut, Menu, Bell, Plus, Shield, ExternalLink, Palette
} from 'lucide-react';
import { appThemeTokens } from './theme/tokens';
import { readWhiteLabelConfig } from './theme/whitelabel';

// Lazy page imports
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import DocumentsPage from './pages/DocumentsPage';
import DocumentDetailPage from './pages/DocumentDetailPage';
import NewDocumentPage from './pages/NewDocumentPage';
import DocumentBuilderPage from './pages/DocumentBuilderPage';
import TemplatesPage from './pages/TemplatesPage';
import FoldersPage from './pages/FoldersPage';
import ContactsPage from './pages/ContactsPage';
import UsersPage from './pages/UsersPage';
import SettingsPage from './pages/SettingsPage';
import ReportsPage from './pages/ReportsPage';
import WhiteLabelAdminPage from './pages/WhiteLabelAdminPage';
import SigningPage from './pages/SigningPage';
import MyDocumentsPage from './pages/MyDocumentsPage';

// Protected Route
function ProtectedRoute({ children }: { children: ReactNode }) {
  const { user } = useAuthStore();
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

// Sidebar
function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { user, logout } = useAuthStore();
  const location = useLocation();
  const navigate = useNavigate();
  const labelConfig = readWhiteLabelConfig();
  const platformName = labelConfig.platform_name || user?.platform_name || user?.org_name || 'BlueTech';
  const logoUrl = labelConfig.logo_url || user?.logo_url;
  const isAdmin = user?.role === 'admin';
  const isAdminOrManager = isAdmin || user?.role === 'manager';

  const links = [
    { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { to: '/documents', icon: FileText, label: 'Documentos' },
    { to: '/templates', icon: FileSignature, label: 'Modelos' },
    { to: '/folders', icon: FolderOpen, label: 'Pastas' },
    { to: '/contacts', icon: BookUser, label: 'Contatos' },
    ...(isAdminOrManager ? [{ to: '/users', icon: Users, label: 'Usuários' }] : []),
    ...(isAdmin ? [{ to: '/admin/white-label', icon: Palette, label: 'White Label' }] : []),
    ...(isAdmin || user?.permissions?.reports ? [{ to: '/reports', icon: BarChart3, label: 'Relatórios' }] : []),
    ...(isAdmin || user?.permissions?.settings ? [{ to: '/settings', icon: Settings, label: 'Configurações' }] : []),
  ];

  const isActive = (path: string) => path === '/' ? location.pathname === '/' : location.pathname.startsWith(path);

  return (
    <>
      {open && <div className="fixed inset-0 bg-black/60 z-40 lg:hidden" onClick={onClose} />}
      <aside className={`fixed top-0 left-0 h-full w-72 bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 z-50 transform transition-transform duration-300 ease-in-out
        ${open ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0 lg:static lg:z-auto flex flex-col`}>
        <div className="p-6 border-b border-white/10">
          <div className="flex items-center gap-3">
            {logoUrl ? (
              <img src={logoUrl} alt={platformName} className="w-11 h-11 rounded-xl object-cover border border-white/20 shadow-sm" />
            ) : (
              <div className="w-11 h-11 bg-cyan-400/20 rounded-xl flex items-center justify-center shadow-[0_0_24px_rgba(34,211,238,0.35)]">
                <Shield className="w-6 h-6 text-cyan-200" />
              </div>
            )}
            <div>
              <h1 className="text-white font-bold text-lg leading-tight tracking-wide">{platformName}</h1>
              <p className="text-cyan-200/80 text-xs">Signature Arena</p>
            </div>
          </div>
        </div>

        <div className="px-4 pt-4">
          <button onClick={() => { navigate('/documents/new'); onClose(); }}
            className="w-full min-h-11 flex items-center justify-center gap-2 bg-accent-500 hover:bg-accent-600 text-white py-2.5 px-4 rounded-xl font-medium text-sm transition-all shadow-lg shadow-black/20">
            <Plus className="w-4 h-4" /> Novo Documento
          </button>
        </div>

        <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          {links.map(({ to, icon: Icon, label }) => (
            <Link key={to} to={to} onClick={onClose}
              className={`sidebar-link ${isActive(to) ? 'active' : ''}`}>
              <Icon className="w-5 h-5 flex-shrink-0" />
              <span>{label}</span>
            </Link>
          ))}
        </nav>

        <div className="p-4 border-t border-white/10">
          <div className="flex items-center gap-3 mb-3 rounded-xl bg-white/10 border border-white/10 p-3">
            <div className="w-9 h-9 bg-white/20 rounded-full flex items-center justify-center text-white font-semibold text-sm">
              {user?.name?.charAt(0).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-white text-sm font-medium truncate">{user?.name}</p>
              <p className="text-blue-200 text-xs truncate">{user?.email}</p>
            </div>
          </div>
          <button onClick={() => { logout(); navigate('/login'); }}
            className="w-full min-h-11 flex items-center gap-2 text-blue-200 hover:text-white text-sm py-2 px-3 rounded-lg hover:bg-white/10 transition-all">
            <LogOut className="w-4 h-4" /> Sair
          </button>
          <a href="/meus-documentos" target="_blank" rel="noreferrer" className="text-xs text-blue-200 hover:text-white inline-flex items-center gap-1 mt-3">
            <ExternalLink className="w-3 h-3" /> Portal do Signatário
          </a>
        </div>
      </aside>
    </>
  );
}

// Header
function Header({ onMenuClick }: { onMenuClick: () => void }) {
  const { user } = useAuthStore();

  return (
    <header className="bg-slate-950/80 backdrop-blur-md border-b border-cyan-400/10 min-h-16 flex items-center justify-between px-3 sm:px-4 lg:px-8 sticky top-0 z-30">
      <div className="flex items-center gap-4">
        <button onClick={onMenuClick} className="lg:hidden min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-slate-100 rounded-xl">
          <Menu className="w-5 h-5 text-gray-600" />
        </button>
      </div>
      <div className="flex items-center gap-3">
        <button className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-white/10 rounded-lg relative">
          <Bell className="w-5 h-5 text-cyan-100" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <div className="flex items-center gap-2 pl-2 sm:pl-3 border-l border-cyan-400/20">
          <div className="w-8 h-8 bg-cyan-500/20 rounded-full flex items-center justify-center text-cyan-100 text-sm font-semibold border border-cyan-400/30">
            {user?.name?.charAt(0).toUpperCase()}
          </div>
          <span className="text-sm font-medium text-cyan-100 hidden lg:inline">{user?.name?.split(' ')[0]}</span>
        </div>
      </div>
    </header>
  );
}

// Layout
function DashboardLayout({ children }: { children: ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  return (
    <div className="min-h-screen bg-transparent flex">
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="flex-1 flex flex-col min-w-0">
        <Header onMenuClick={() => setSidebarOpen(true)} />
        <main className="flex-1 safe-px py-4 sm:py-5 md:py-6 lg:py-8 overflow-auto">
          <div className="page-shell">{children}</div>
        </main>
      </div>
    </div>
  );
}

// App
export default function App() {
  const { loadUser, user } = useAuthStore();
  const location = useLocation();
  const [whiteLabelVersion, setWhiteLabelVersion] = useState(0);

  useEffect(() => { loadUser(); }, [loadUser]);

  useEffect(() => {
    const refreshTheme = () => setWhiteLabelVersion((prev) => prev + 1);
    window.addEventListener('bt:whitelabel:update', refreshTheme as EventListener);
    window.addEventListener('storage', refreshTheme);
    return () => {
      window.removeEventListener('bt:whitelabel:update', refreshTheme as EventListener);
      window.removeEventListener('storage', refreshTheme);
    };
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    const themedUser = user as any;
    const whiteLabel = readWhiteLabelConfig();
    root.style.setProperty('--surface-base', appThemeTokens.surfaceBase);
    root.style.setProperty('--surface-elevated', appThemeTokens.surfaceElevated);
    root.style.setProperty('--surface-glass', appThemeTokens.surfaceGlass);
    root.style.setProperty('--text-primary', appThemeTokens.textPrimary);
    root.style.setProperty('--text-muted', appThemeTokens.textMuted);
    root.style.setProperty('--border-subtle', appThemeTokens.borderSubtle);
    root.classList.remove('theme-gamified');
    // Backend/user data is source of truth; local white-label is fallback.
    const primary = themedUser?.brand_primary_color || whiteLabel.brand_primary_color;
    const secondary = themedUser?.brand_secondary_color || whiteLabel.brand_secondary_color;
    const accent = themedUser?.brand_accent_color || whiteLabel.brand_accent_color;
    const preset = themedUser?.visual_preset || whiteLabel.visual_preset || 'gamified';
    if (primary) root.style.setProperty('--brand-primary', primary);
    if (secondary) root.style.setProperty('--brand-secondary', secondary);
    if (accent) root.style.setProperty('--brand-accent', accent);
    if (preset === 'gamified') root.classList.add('theme-gamified');
  }, [user, whiteLabelVersion]);

  return (
    <>
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 4000,
          style: {
            borderRadius: '12px',
            background: '#0F1F35',
            color: '#F8FAFC',
            border: '1px solid rgba(255,255,255,0.12)',
          },
        }}
      />
      <Routes location={location}>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/sign/:token" element={<SigningPage />} />
        <Route path="/meus-documentos" element={<MyDocumentsPage />} />
        <Route path="/meu-historico" element={<MyDocumentsPage />} />
        <Route path="/" element={<ProtectedRoute><DashboardLayout><DashboardPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/documents" element={<ProtectedRoute><DashboardLayout><DocumentsPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/documents/new" element={<ProtectedRoute><DashboardLayout><NewDocumentPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/documents/:id" element={<ProtectedRoute><DashboardLayout><DocumentDetailPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/documents/:id/edit" element={<ProtectedRoute><DashboardLayout><DocumentBuilderPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/templates" element={<ProtectedRoute><DashboardLayout><TemplatesPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/folders" element={<ProtectedRoute><DashboardLayout><FoldersPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/contacts" element={<ProtectedRoute><DashboardLayout><ContactsPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/users" element={<ProtectedRoute><DashboardLayout><UsersPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/settings" element={<ProtectedRoute><DashboardLayout><SettingsPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/reports" element={<ProtectedRoute><DashboardLayout><ReportsPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="/admin/white-label" element={<ProtectedRoute><DashboardLayout><WhiteLabelAdminPage /></DashboardLayout></ProtectedRoute>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}
