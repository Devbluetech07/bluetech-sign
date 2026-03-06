import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

const api = axios.create({ baseURL: `${API_URL}/api`, headers: { 'Content-Type': 'application/json' } });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('bt_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('bt_token');
      localStorage.removeItem('bt_user');
      if (window.location.pathname !== '/login') window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Auth
export const authAPI = {
  login: (data: any) => api.post('/auth/login', data),
  register: (data: any) => api.post('/auth/register', data),
  me: () => api.get('/auth/me'),
  updateProfile: (data: any) => api.put('/auth/profile', data),
  changePassword: (data: any) => api.put('/auth/password', data),
};

// Documents
export const documentsAPI = {
  list: (params?: any) => api.get('/documents', { params }),
  getById: (id: string) => api.get(`/documents/${id}`),
  upload: (formData: FormData) => api.post('/documents/upload', formData, { headers: { 'Content-Type': 'multipart/form-data' } }),
  update: (id: string, data: any) => api.put(`/documents/${id}`, data),
  delete: (id: string) => api.delete(`/documents/${id}`),
  addSigner: (id: string, data: any) => api.post(`/documents/${id}/signers`, data),
  removeSigner: (docId: string, signerId: string) => api.delete(`/documents/${docId}/signers/${signerId}`),
  addField: (id: string, data: any) => api.post(`/documents/${id}/fields`, data),
  send: (id: string) => api.post(`/documents/${id}/send`),
  cancel: (id: string, data?: any) => api.post(`/documents/${id}/cancel`, data),
  sendReminder: (id: string, data?: any) => api.post(`/documents/${id}/reminder`, data),
  download: (id: string) => api.get(`/documents/${id}/download`),
  stats: () => api.get('/documents/stats'),
};

// Signing (public)
export const signingAPI = {
  getDocument: (token: string) => api.get(`/signing/${token}`),
  requestToken: (token: string) => api.post(`/signing/${token}/request-token`),
  verifyToken: (token: string, code: string) => api.post(`/signing/${token}/verify-token`, { code }),
  verifyBiometria: (token: string, image: string) => api.post(`/signing/${token}/verify-biometria`, { image }),
  sign: (token: string, data: any) => api.post(`/signing/${token}/sign`, data),
  reject: (token: string, reason: string) => api.post(`/signing/${token}/reject`, { reason }),
  uploadPhoto: (token: string, image: string) => api.post(`/signing/${token}/upload-photo`, { image }),
  uploadSelfie: (token: string, image: string) => api.post(`/signing/${token}/upload-selfie`, { image }),
};

// Public (no auth required)
export const publicAPI = {
  requestAccess: (email: string) => api.post('/public/request-access', { email }),
  verifyAccess: (email: string, code: string) => api.post('/public/verify-access', { email, code }),
};

// Templates
export const templatesAPI = {
  list: (params?: any) => api.get('/templates', { params }),
  getById: (id: string) => api.get(`/templates/${id}`),
  create: (formData: FormData) => api.post('/templates', formData, { headers: { 'Content-Type': 'multipart/form-data' } }),
  update: (id: string, data: any) => api.put(`/templates/${id}`, data),
  delete: (id: string) => api.delete(`/templates/${id}`),
};

// Folders
export const foldersAPI = {
  list: () => api.get('/folders'),
  create: (data: any) => api.post('/folders', data),
  update: (id: string, data: any) => api.put(`/folders/${id}`, data),
  delete: (id: string) => api.delete(`/folders/${id}`),
};

// Contacts
export const contactsAPI = {
  list: (params?: any) => api.get('/contacts', { params }),
  create: (data: any) => api.post('/contacts', data),
  update: (id: string, data: any) => api.put(`/contacts/${id}`, data),
  delete: (id: string) => api.delete(`/contacts/${id}`),
};

// Users
export const usersAPI = {
  list: () => api.get('/users'),
  create: (data: any) => api.post('/users', data),
  update: (id: string, data: any) => api.put(`/users/${id}`, data),
  delete: (id: string) => api.delete(`/users/${id}`),
};

// Tags
export const tagsAPI = {
  list: () => api.get('/tags'),
  create: (data: any) => api.post('/tags', data),
  delete: (id: string) => api.delete(`/tags/${id}`),
};

// Settings
export const settingsAPI = {
  get: () => api.get('/settings'),
  updateOrg: (data: any) => api.put('/settings/organization', data),
  updateConfig: (data: any) => api.put('/settings/config', data),
  uploadLogo: (formData: FormData) => api.post('/settings/logo', formData, { headers: { 'Content-Type': 'multipart/form-data' } }),
  listApiKeys: () => api.get('/settings/api-keys'),
  createApiKey: (data: { name: string; scopes: string[] }) => api.post('/settings/api-keys', data),
  revokeApiKey: (id: string) => api.delete(`/settings/api-keys/${id}`),
};

// Webhooks
export const webhooksAPI = {
  list: () => api.get('/webhooks'),
  create: (data: any) => api.post('/webhooks', data),
  delete: (id: string) => api.delete(`/webhooks/${id}`),
};

// Reports
export const reportsAPI = {
  documentsByStatus: (params?: any) => api.get('/reports/documents-by-status', { params }),
  signatureTimeline: (params?: any) => api.get('/reports/signature-timeline', { params }),
  audit: (params?: any) => api.get('/reports/audit', { params }),
  notifications: () => api.get('/reports/notifications'),
};

export default api;
