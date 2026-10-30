import { Router } from 'express';
import {
  uploadDocument,
  getDocuments,
  getDocument,
  deleteDocument,
  processDocument,
  getDocumentText,
  updateDocumentText,
  updateCategory,
} from '../controllers/documents';
import { authMiddleware } from '../middleware/auth';
import { upload } from '../middleware/upload';

const router = Router();

router.post('/upload', authMiddleware, upload.single('file'), uploadDocument);
router.get('/', authMiddleware, getDocuments);
router.get('/:id', authMiddleware, getDocument);
router.delete('/:id', authMiddleware, deleteDocument);
router.post('/:id/process', authMiddleware, processDocument);
router.get('/:id/text', authMiddleware, getDocumentText);
router.put('/:id/text', authMiddleware, updateDocumentText);
router.patch('/:id/category', authMiddleware, updateCategory);

export default router;
