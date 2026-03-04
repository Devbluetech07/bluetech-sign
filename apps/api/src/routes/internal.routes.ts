import { Router } from 'express';
import { authMiddleware, requirePermission, requireRole } from '../middleware/auth.middleware';
import { uploadDocument, uploadImage } from '../middleware/upload.middleware';
import { templatesController } from '../controllers/templates.controller';
import { foldersController } from '../controllers/folders.controller';
import { contactsController } from '../controllers/contacts.controller';
import { usersController } from '../controllers/users.controller';
import { tagsController } from '../controllers/tags.controller';
import { webhooksController } from '../controllers/webhooks.controller';
import { settingsController } from '../controllers/settings.controller';
import { reportsController } from '../controllers/reports.controller';

const internalRoutes = Router();

internalRoutes.get('/templates', authMiddleware, templatesController.list);
internalRoutes.get('/templates/:id', authMiddleware, templatesController.getById);
internalRoutes.post('/templates', authMiddleware, uploadDocument, templatesController.create);
internalRoutes.put('/templates/:id', authMiddleware, templatesController.update);
internalRoutes.delete('/templates/:id', authMiddleware, templatesController.delete);

internalRoutes.get('/folders', authMiddleware, foldersController.list);
internalRoutes.post('/folders', authMiddleware, foldersController.create);
internalRoutes.put('/folders/:id', authMiddleware, foldersController.update);
internalRoutes.delete('/folders/:id', authMiddleware, foldersController.delete);

internalRoutes.get('/contacts', authMiddleware, contactsController.list);
internalRoutes.post('/contacts', authMiddleware, contactsController.create);
internalRoutes.put('/contacts/:id', authMiddleware, contactsController.update);
internalRoutes.delete('/contacts/:id', authMiddleware, contactsController.delete);

internalRoutes.get('/users', authMiddleware, requireRole('admin', 'manager'), usersController.list);
internalRoutes.post('/users', authMiddleware, requireRole('admin'), usersController.create);
internalRoutes.put('/users/:id', authMiddleware, requireRole('admin'), usersController.update);
internalRoutes.delete('/users/:id', authMiddleware, requireRole('admin'), usersController.delete);

internalRoutes.get('/tags', authMiddleware, tagsController.list);
internalRoutes.post('/tags', authMiddleware, tagsController.create);
internalRoutes.delete('/tags/:id', authMiddleware, tagsController.delete);

internalRoutes.get('/webhooks', authMiddleware, requirePermission('api_keys'), webhooksController.list);
internalRoutes.post('/webhooks', authMiddleware, requirePermission('api_keys'), webhooksController.create);
internalRoutes.delete('/webhooks/:id', authMiddleware, requirePermission('api_keys'), webhooksController.delete);

internalRoutes.get('/settings', authMiddleware, requirePermission('settings'), settingsController.getOrganization);
internalRoutes.put('/settings/organization', authMiddleware, requirePermission('settings'), settingsController.updateOrganization);
internalRoutes.put('/settings/config', authMiddleware, requirePermission('settings'), settingsController.updateSetting);
internalRoutes.post('/settings/logo', authMiddleware, requirePermission('settings'), uploadImage, settingsController.uploadLogo);
internalRoutes.get('/settings/api-keys', authMiddleware, requirePermission('settings'), settingsController.listApiKeys);
internalRoutes.post('/settings/api-keys', authMiddleware, requirePermission('settings'), settingsController.createApiKey);
internalRoutes.delete('/settings/api-keys/:id', authMiddleware, requirePermission('settings'), settingsController.revokeApiKey);

internalRoutes.get('/reports/documents-by-status', authMiddleware, requirePermission('reports'), reportsController.documentsByStatus);
internalRoutes.get('/reports/signature-timeline', authMiddleware, requirePermission('reports'), reportsController.signatureTimeline);
internalRoutes.get('/reports/audit', authMiddleware, requirePermission('reports'), reportsController.auditReport);
internalRoutes.get('/reports/notifications', authMiddleware, requirePermission('reports'), reportsController.notificationsReport);

export default internalRoutes;
