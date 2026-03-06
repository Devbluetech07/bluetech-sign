import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { initMinio } from './config/minio';
import { initRedis } from './config/redis';
import { env } from './config/env';
import routes from './routes';

const app = express();
const PORT = env.port;

// Middleware
app.use(helmet({ crossOriginResourcePolicy: { policy: "cross-origin" }, contentSecurityPolicy: false, frameguard: false }));
app.use(cors({
  origin: env.urls.frontend,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key'],
}));
app.use(compression());
app.use(morgan('dev'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  message: { error: 'Muitas requisições. Tente novamente em alguns minutos.' },
});
app.use('/api/', limiter);

// File proxy for MinIO (presigned URLs point to internal hostname)
app.get('/api/files/*', async (req, res) => {
  try {
    const { getFileBuffer } = await import('./config/minio');
    const key = req.params[0];
    if (!key) return res.status(400).json({ error: 'File key is required' });
    const buffer = await getFileBuffer(key);
    const ext = key.split('.').pop()?.toLowerCase() || '';
    const contentTypes: Record<string, string> = {
      pdf: 'application/pdf', png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg',
      webp: 'image/webp', svg: 'image/svg+xml', doc: 'application/msword',
      docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    res.setHeader('Content-Type', contentTypes[ext] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.send(buffer);
  } catch (e: any) {
    res.status(404).json({ error: 'File not found' });
  }
});

// Routes
app.use('/api', routes);

// Root
app.get('/', (req, res) => {
  res.json({
    name: 'BlueTech Assina API',
    version: '1.0.0',
    description: 'Sistema de Gestão de Assinatura Digital - Réplica Clicksign',
    docs: '/api-docs',
    health: '/api/health',
    endpoints: {
      auth: '/api/auth',
      documents: '/api/documents',
      templates: '/api/templates',
      folders: '/api/folders',
      contacts: '/api/contacts',
      users: '/api/users',
      signing: '/api/signing/:token',
      settings: '/api/settings',
      reports: '/api/reports',
      webhooks: '/api/webhooks',
      tags: '/api/tags',
    },
  });
});

// Error handler
app.use((err: unknown, req: express.Request, res: express.Response, next: express.NextFunction) => {
  const error = err instanceof Error ? err : new Error('Erro interno do servidor');
  const errorWithStatus = err as { status?: number };
  console.error('❌ Error:', err);
  res.status(errorWithStatus.status || 500).json({
    error: error.message,
    ...(env.isDev && { stack: error.stack }),
  });
});

// Initialize services and start
async function start() {
  try {
    console.log('🔄 Inicializando serviços...');
    await initRedis().catch((e) => console.warn('⚠️ Redis não disponível:', e.message));
    await initMinio().catch((e) => console.warn('⚠️ MinIO não disponível:', e.message));
    
    app.listen(PORT, () => {
      console.log(`\n🚀 ===================================`);
      console.log(`🚀 BlueTech Assina API`);
      console.log(`🚀 Rodando na porta ${PORT}`);
      console.log(`🚀 ${env.nodeEnv} mode`);
      console.log(`🚀 ===================================\n`);
    });
  } catch (error) {
    console.error('❌ Falha ao iniciar servidor:', error);
    process.exit(1);
  }
}

start();

export default app;
