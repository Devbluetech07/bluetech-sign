import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { authMiddleware } from '../middleware/auth.middleware';

const authRoutes = Router();

authRoutes.post('/login', authController.login);
authRoutes.post('/register', authController.register);
authRoutes.get('/me', authMiddleware, authController.me);
authRoutes.put('/profile', authMiddleware, authController.updateProfile);
authRoutes.put('/password', authMiddleware, authController.changePassword);

export default authRoutes;
