import { create } from 'zustand';
import { authAPI } from '../services/api';

interface User {
  id: string; organization_id: string; name: string; email: string; cpf?: string; phone?: string;
  avatar_url?: string; role: string; permissions: any; org_name?: string; brand_primary_color?: string; logo_url?: string;
}

interface AuthState {
  user: User | null; token: string | null; loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  loadUser: () => Promise<void>;
  updateUser: (data: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: JSON.parse(localStorage.getItem('bt_user') || 'null'),
  token: localStorage.getItem('bt_token'),
  loading: false,

  login: async (email, password) => {
    set({ loading: true });
    try {
      const { data } = await authAPI.login({ email, password });
      localStorage.setItem('bt_token', data.token);
      localStorage.setItem('bt_user', JSON.stringify(data.user));
      set({ user: data.user, token: data.token, loading: false });
    } catch (error: any) {
      set({ loading: false });
      throw new Error(error.response?.data?.error || 'Erro ao fazer login');
    }
  },

  logout: () => {
    localStorage.removeItem('bt_token');
    localStorage.removeItem('bt_user');
    set({ user: null, token: null });
  },

  loadUser: async () => {
    const token = localStorage.getItem('bt_token');
    if (!token) return;
    try {
      const { data } = await authAPI.me();
      localStorage.setItem('bt_user', JSON.stringify(data));
      set({ user: data, token });
    } catch {
      localStorage.removeItem('bt_token');
      localStorage.removeItem('bt_user');
      set({ user: null, token: null });
    }
  },

  updateUser: (data) => {
    const current = get().user;
    if (current) {
      const updated = { ...current, ...data };
      localStorage.setItem('bt_user', JSON.stringify(updated));
      set({ user: updated });
    }
  },
}));
