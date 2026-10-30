import { getStorageBucket } from '../config/firebase';
import { getApps } from 'firebase-admin/app';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import fs from 'fs';

const DEFAULT_UPLOAD_DIR = path.resolve(__dirname, '../../uploads');
const UPLOAD_DIR = process.env.UPLOAD_DIR ? path.resolve(process.env.UPLOAD_DIR) : DEFAULT_UPLOAD_DIR;

if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

/**
 * File storage service - Cloud storage using Firebase Storage with local fallback.
 */
export class StorageService {

  getFilePath(fileName: string): string {
    return `uploads/${fileName}`;
  }

  async fileExists(fileName: string): Promise<boolean> {
    if (getApps().length) {
      const bucket = getStorageBucket();
      const file = bucket.file(this.getFilePath(fileName));
      const [exists] = await file.exists();
      return exists;
    } else {
      return fs.existsSync(path.join(UPLOAD_DIR, fileName));
    }
  }

  async deleteFile(fileName: string): Promise<void> {
    if (getApps().length) {
      const bucket = getStorageBucket();
      const file = bucket.file(this.getFilePath(fileName));
      
      try {
        const [exists] = await file.exists();
        if (exists) {
          await file.delete();
        }
      } catch (error) {
        console.error(`Error deleting file ${fileName} from Firebase Storage:`, error);
      }
    } else {
      const localPath = path.join(UPLOAD_DIR, fileName);
      if (fs.existsSync(localPath)) {
        fs.unlinkSync(localPath);
      }
    }
  }

  async getFileBuffer(fileName: string): Promise<Buffer> {
    if (getApps().length) {
      const bucket = getStorageBucket();
      const file = bucket.file(this.getFilePath(fileName));
      
      const [buffer] = await file.download();
      return buffer;
    } else {
      const localPath = path.join(UPLOAD_DIR, fileName);
      return fs.promises.readFile(localPath);
    }
  }

  getFileUrl(fileName: string): string {
    if (getApps().length) {
      const bucketName = getStorageBucket().name;
      const filePath = encodeURIComponent(this.getFilePath(fileName));
      return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${filePath}?alt=media`;
    } else {
      return `/uploads/${fileName}`;
    }
  }

  /**
   * Upload a buffer to Firebase Storage or local fallback and return the unique filename.
   */
  async uploadBuffer(buffer: Buffer, originalName: string, mimeType: string): Promise<string> {
    const ext = path.extname(originalName).toLowerCase();
    const uniqueName = `${uuidv4()}${ext}`;
    
    if (getApps().length) {
      const filePath = this.getFilePath(uniqueName);
      const bucket = getStorageBucket();
      const file = bucket.file(filePath);

      await file.save(buffer, {
        metadata: {
          contentType: mimeType,
        },
        public: true,
      });

      await file.makePublic();
    } else {
      const localPath = path.join(UPLOAD_DIR, uniqueName);
      await fs.promises.writeFile(localPath, buffer);
      console.log(`Saved file locally to ${localPath}`);
    }

    return uniqueName;
  }
}

export const storageService = new StorageService();
