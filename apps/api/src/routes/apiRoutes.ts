import { Router } from 'express';
import { authOrApiKeyMiddleware, apiKeyMiddleware } from '../middleware/auth';
import { uploadDocument } from '../middleware/upload';
import { documentsController } from '../controllers/documentsController';
import { contactsController } from '../controllers/crudControllers';

const router = Router();

const authOrApiKey = [apiKeyMiddleware, authOrApiKeyMiddleware];

router.post('/documents/upload', ...authOrApiKey, uploadDocument, documentsController.upload);
router.post('/documents/:id/signers', ...authOrApiKey, documentsController.addSigner);
router.post('/documents/:id/send', ...authOrApiKey, documentsController.send);
router.get('/documents/:id', ...authOrApiKey, documentsController.getById);
router.get('/documents/:id/download', ...authOrApiKey, documentsController.download);

router.get('/contacts', ...authOrApiKey, contactsController.list);
router.post('/contacts', ...authOrApiKey, contactsController.create);

export default router;
