import { Router } from 'express';
import { documentsController } from '../controllers/documents.controller';
import { contactsController } from '../controllers/contacts.controller';
import { apiKeyMiddleware, authOrApiKeyMiddleware } from '../middleware/auth.middleware';
import { uploadDocument } from '../middleware/upload.middleware';

const v1Routes = Router();
const authOrApiKey = [apiKeyMiddleware, authOrApiKeyMiddleware];

v1Routes.post('/documents/upload', ...authOrApiKey, uploadDocument, documentsController.upload);
v1Routes.post('/documents/:id/signers', ...authOrApiKey, documentsController.addSigner);
v1Routes.post('/documents/:id/send', ...authOrApiKey, documentsController.send);
v1Routes.get('/documents/:id', ...authOrApiKey, documentsController.getById);
v1Routes.get('/documents/:id/download', ...authOrApiKey, documentsController.download);

v1Routes.get('/contacts', ...authOrApiKey, contactsController.list);
v1Routes.post('/contacts', ...authOrApiKey, contactsController.create);

v1Routes.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

export default v1Routes;
