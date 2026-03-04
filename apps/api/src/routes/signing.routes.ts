import { Router } from 'express';
import { signingController } from '../controllers/signing.controller';

const signingRoutes = Router();

signingRoutes.get('/:token', signingController.getDocument);
signingRoutes.post('/:token/request-token', signingController.requestToken);
signingRoutes.post('/:token/verify-token', signingController.verifyToken);
signingRoutes.post('/:token/verify-biometria', signingController.verifyBiometria);
signingRoutes.post('/:token/sign', signingController.sign);
signingRoutes.post('/:token/reject', signingController.reject);
signingRoutes.post('/:token/upload-photo', signingController.uploadDocumentPhoto);
signingRoutes.post('/:token/upload-selfie', signingController.uploadSelfie);

export default signingRoutes;
