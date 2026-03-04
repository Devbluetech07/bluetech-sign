import { Router } from 'express';
import { publicController } from '../controllers/public.controller';

const publicRoutes = Router();

publicRoutes.post('/request-access', publicController.requestAccess);
publicRoutes.post('/verify-access', publicController.verifyAccess);

export default publicRoutes;
