import { Router } from 'express';
import multer from 'multer';
import { runOCR, getHealth, getModelInfo } from '../controllers/ocrController';

const router = Router();
const upload = multer({ dest: 'uploads/' });

router.post('/', upload.single('image'), runOCR);
router.get('/health', getHealth);
router.get('/model-info', getModelInfo);

export default router;
