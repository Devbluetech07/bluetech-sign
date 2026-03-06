import multer from 'multer';
import path from 'path';
import { Request, Response, NextFunction } from 'express';

const storage = multer.memoryStorage();

const documentFilter = (req: Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowed = ['.pdf', '.docx', '.doc', '.png', '.jpg', '.jpeg'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.includes(ext)) {
    cb(null, true);
  } else {
    const err: any = new Error(`Tipo de arquivo não suportado: ${ext}. Permitidos: ${allowed.join(', ')}`);
    err.status = 400;
    cb(err);
  }
};

const imageFilter = (req: Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowed = ['.png', '.jpg', '.jpeg', '.webp', '.svg', '.gif'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.includes(ext)) {
    cb(null, true);
  } else {
    const err: any = new Error(`Tipo de imagem não suportado: ${ext}`);
    err.status = 400;
    cb(err);
  }
};

const docUploader = multer({ storage, fileFilter: documentFilter, limits: { fileSize: 25 * 1024 * 1024 } });
const imgUploader = multer({ storage, fileFilter: imageFilter, limits: { fileSize: 10 * 1024 * 1024 } });

export function uploadDocument(req: Request, res: Response, next: NextFunction) {
  const upload = docUploader.any();
  upload(req, res, (err) => {
    if (err) return res.status((err as any).status || 400).json({ error: err.message });
    if (req.files && Array.isArray(req.files) && req.files.length > 0) {
      req.file = req.files[0];
    }
    next();
  });
}

export function uploadImage(req: Request, res: Response, next: NextFunction) {
  const upload = imgUploader.any();
  upload(req, res, (err) => {
    if (err) return res.status((err as any).status || 400).json({ error: err.message });
    if (req.files && Array.isArray(req.files) && req.files.length > 0) {
      req.file = req.files[0];
    }
    next();
  });
}

export const uploadMultiple = multer({
  storage,
  fileFilter: documentFilter,
  limits: { fileSize: 25 * 1024 * 1024 },
}).array('files', 10);
