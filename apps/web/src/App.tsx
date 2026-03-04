import { Routes, Route, Navigate, useLocation, Link, useNavigate } from 'react-router-dom';
import { useState, useEffect, ReactNode } from 'react';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './store/auth.store';
import {
  LayoutDashboard, FileText, FolderOpen, Users, BookUser, FileSignature,
  Settings, BarChart3, LogOut, Menu, Bell, Search, Plus, Shield, ExternalLink
} from 'lucide-react';

// Lazy page imports
import LoginPage from './pages/public/LoginPage';
import DashboardPage from './pages/internal/DashboardPage';
import DocumentsPage from './pages/internal/DocumentsPage';
import DocumentDetailPage from './pages/internal/DocumentDetailPage';
import NewDocumentPage from './pages/internal/NewDocumentPage';
import DocumentBuilderPage from './pages/DocumentBuilderPage';
import TemplatesPage from './pages/internal/TemplatesPage';
import FoldersPage from './pages/internal/FoldersPage';
import ContactsPage from './pages/internal/ContactsPage';
import UsersPage from './pages/internal/UsersPage';
import SettingsPage from './pages/internal/SettingsPage';
import ReportsPage from './pages/internal/ReportsPage';
import SigningPage from './pages/public/SigningPage';
import MyDocumentsPage from './pages/public/MyDocumentsPage';

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

  const links = [
    { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
    { to: '/documents', icon: FileText, label: 'Documentos' },
    { to: '/templates', icon: FileSignature, label: 'Modelos' },
    { to: '/folders', icon: FolderOpen, label: 'Pastas' },
    { to: '/contacts', icon: BookUser, label: 'Contatos' },
    ...(user?.role === 'admin' || user?.role === 'manager' ? [{ to: '/users', icon: Users, label: 'Usuários' }] : []),
    ...(user?.permissions?.reports ? [{ to: '/reports', icon: BarChart3, label: 'Relatórios' }] : []),
    ...(user?.permissions?.settings ? [{ to: '/settings', icon: Settings, label: 'Configurações' }] : []),
  ];

  const isActive = (path: string) => path === '/' ? location.pathname === '/' : location.pathname.startsWith(path);

  return (
    <>
      {open && <div className="fixed inset-0 bg-black/60 z-40 lg:hidden" onClick={onClose} />}
      <aside className={`fixed top-0 left-0 h-full w-64 bg-brand-600 z-50 transform transition-transform duration-300 ease-in-out
        ${open ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0 lg:static lg:z-auto flex flex-col`}>
        {/* Logo */}
        <div className="p-6 border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center">
              <Shield className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-white font-bold text-lg leading-tight">BlueTech</h1>
              <p className="text-blue-200 text-xs">Assina Digital</p>
            </div>
          </div>
        </div>

        {/* New Document */}
        <div className="px-4 pt-4">
          <button onClick={() => { navigate('/documents/new'); onClose(); }}
            className="w-full min-h-11 flex items-center justify-center gap-2 bg-accent-500 hover:bg-accent-600 text-white py-2.5 px-4 rounded-lg font-medium text-sm transition-all">
            <Plus className="w-4 h-4" /> Novo Documento
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          {links.map(({ to, icon: Icon, label }) => (
            <Link key={to} to={to} onClick={onClose}
              className={`sidebar-link ${isActive(to) ? 'active' : ''}`}>
              <Icon className="w-5 h-5 flex-shrink-0" />
              <span>{label}</span>
            </Link>
          ))}
        </nav>

        {/* User */}
        <div className="p-4 border-t border-white/10">
          <div className="flex items-center gap-3 mb-3">
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
            <ExternalLink className="w-3 h-3" /> Portal do Signatario
          </a>
        </div>
      </aside>
    </>
  );
}

// Header
function Header({ onMenuClick }: { onMenuClick: () => void }) {
  const { user } = useAuthStore();
  const [searchOpen, setSearchOpen] = useState(false);

  return (
    <header className="bg-white border-b border-gray-100 min-h-16 flex items-center justify-between px-3 sm:px-4 lg:px-8 sticky top-0 z-30">
      <div className="flex items-center gap-4">
        <button onClick={onMenuClick} className="lg:hidden min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg">
          <Menu className="w-5 h-5 text-gray-600" />
        </button>

        <div className="relative hidden md:block">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" placeholder="Buscar documentos..." className="input-field pl-10 w-64 lg:w-72" />
        </div>

        <div className="relative md:hidden">
          <button
            type="button"
            onClick={() => setSearchOpen((prev) => !prev)}
            className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg"
            aria-label="Abrir busca"
          >
            <Search className="w-5 h-5 text-gray-600" />
          </button>
          {searchOpen && (
            <div className="absolute top-12 left-0 right-auto w-[min(80vw,20rem)] bg-white border border-gray-200 rounded-xl shadow-lg p-2">
              <input
                type="text"
                placeholder="Buscar documentos..."
                className="input-field text-sm"
                onBlur={() => setSearchOpen(false)}
                autoFocus
              />
            </div>
          )}
        </div>
      </div>
      <div className="flex items-center gap-3">
        <button className="min-h-11 min-w-11 inline-flex items-center justify-center hover:bg-gray-100 rounded-lg relative">
          <Bell className="w-5 h-5 text-gray-500" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <div className="flex items-center gap-2 pl-2 sm:pl-3 border-l border-gray-200">
          <div className="w-8 h-8 bg-brand-600 rounded-full flex items-center justify-center text-white text-sm font-semibold">
            {user?.name?.charAt(0).toUpperCase()}
          </div>
          <span className="text-sm font-medium text-gray-700 hidden lg:inline">{user?.name?.split(' ')[0]}</span>
        </div>
      </div>
    </header>
  );
}

// Layout
function DashboardLayout({ children }: { children: ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  return (
    <div className="min-h-screen bg-gray-50 flex">
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="flex-1 flex flex-col min-w-0">
        <Header onMenuClick={() => setSidebarOpen(true)} />
        <main className="flex-1 px-3 py-4 sm:px-4 sm:py-5 md:px-6 md:py-6 lg:px-8 lg:py-8 overflow-auto">{children}</main>
      </div>
    </div>
  );
}

// App
export default function App() {
  const { loadUser } = useAuthStore();
  useEffect(() => { loadUser(); }, []);

  return (
    <>
      <Toaster position="top-right" toastOptions={{ duration: 4000, className: '!bg-brand-700 !text-white !rounded-xl' }} />
      <Routes>
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
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}
