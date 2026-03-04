export interface ApiUser {
  id: string;
  organization_id: string;
  name: string;
  email: string;
  role: string;
  permissions: Record<string, boolean>;
}

export interface ApiErrorResponse {
  error: string;
  details?: unknown;
}
