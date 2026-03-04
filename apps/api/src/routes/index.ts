import { Router } from 'express';
import { apiKeyMiddleware } from '../middleware/auth.middleware';
import authRoutes from './auth.routes';
import documentsRoutes from './documents.routes';
import signingRoutes from './signing.routes';
import publicRoutes from './public.routes';
import internalRoutes from './internal.routes';
import v1Routes from './v1.routes';

const router = Router();

// API key support for mixed auth use-cases.
router.use(apiKeyMiddleware);

router.use('/auth', authRoutes);
router.use('/documents', documentsRoutes);
router.use('/signing', signingRoutes);
router.use('/public', publicRoutes);
router.use('/', internalRoutes);

// ============ HEALTH ============
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), version: '1.0.0', service: 'BlueTech Assina API' });
});

// ============ API v1 (public integrations) ============
router.use('/v1', v1Routes);

export default router;
