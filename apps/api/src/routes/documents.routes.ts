import { Router } from 'express';
import { documentsController } from '../controllers/documents.controller';
import { authMiddleware } from '../middleware/auth.middleware';
import { uploadDocument } from '../middleware/upload.middleware';

const documentsRoutes = Router();

documentsRoutes.get('/stats', authMiddleware, documentsController.stats);
documentsRoutes.get('/', authMiddleware, documentsController.list);
documentsRoutes.get('/:id', authMiddleware, documentsController.getById);
documentsRoutes.post('/upload', authMiddleware, uploadDocument, documentsController.upload);
documentsRoutes.put('/:id', authMiddleware, documentsController.update);
documentsRoutes.delete('/:id', authMiddleware, documentsController.delete);
documentsRoutes.post('/:id/signers', authMiddleware, documentsController.addSigner);
documentsRoutes.delete('/:id/signers/:signerId', authMiddleware, documentsController.removeSigner);
documentsRoutes.post('/:id/fields', authMiddleware, documentsController.addField);
documentsRoutes.post('/:id/send', authMiddleware, documentsController.send);
documentsRoutes.post('/:id/cancel', authMiddleware, documentsController.cancel);
documentsRoutes.post('/:id/reminder', authMiddleware, documentsController.sendReminder);
documentsRoutes.get('/:id/download', authMiddleware, documentsController.download);

export default documentsRoutes;
