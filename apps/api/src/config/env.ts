const requiredInProduction = ['DATABASE_URL', 'REDIS_URL', 'JWT_SECRET'] as const;

const missing = requiredInProduction.filter((key) => !process.env[key]);
if (process.env.NODE_ENV === 'production' && missing.length > 0) {
  throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
}

const parseNumber = (value: string | undefined, fallback: number): number => {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: parseNumber(process.env.PORT, 3000),
  isDev: process.env.NODE_ENV !== 'production',
  isProd: process.env.NODE_ENV === 'production',

  db: {
    url: process.env.DATABASE_URL ?? 'postgresql://bluetech:BlueTech@2024@localhost:5432/bluetech_sign',
  },
  redis: {
    url: process.env.REDIS_URL ?? 'redis://localhost:6379',
  },
  minio: {
    endpoint: process.env.MINIO_ENDPOINT ?? 'localhost',
    port: parseNumber(process.env.MINIO_PORT, 9000),
    accessKey: process.env.MINIO_ACCESS_KEY ?? 'bluetech_admin',
    secretKey: process.env.MINIO_SECRET_KEY ?? 'BlueTech@Minio2024',
    bucket: process.env.MINIO_BUCKET ?? 'bluetech-sign',
    useSSL: process.env.MINIO_USE_SSL === 'true',
  },
  jwt: {
    secret: process.env.JWT_SECRET ?? 'trocar-em-producao-gerar-string-aleatoria-64-chars',
    expiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  },
  smtp: {
    host: process.env.SMTP_HOST ?? 'smtp.gmail.com',
    port: parseNumber(process.env.SMTP_PORT, 587),
    user: process.env.SMTP_USER ?? '',
    pass: process.env.SMTP_PASS ?? '',
    fromName: process.env.SMTP_FROM_NAME ?? 'BlueTech Sign',
  },
  urls: {
    app: process.env.APP_URL ?? 'http://localhost:5173',
    frontend: process.env.FRONTEND_URL ?? 'http://localhost:5173',
    api: process.env.API_URL ?? `http://localhost:${process.env.PORT ?? '3000'}`,
  },
  bluepoint: {
    url: process.env.BLUEPOINT_API_URL ?? '',
    key: process.env.BLUEPOINT_API_KEY ?? '',
  },
};
