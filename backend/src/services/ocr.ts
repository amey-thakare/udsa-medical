import path from 'path';
import sharp from 'sharp';
import https from 'https';
import { storageService } from './storage';

export type OCRQualityStatus = 'HIGH' | 'MEDIUM' | 'LOW_REVIEW_NEEDED';

export interface OCRResult {
  text: string;
  confidence: number;
  qualityStatus: OCRQualityStatus;
  pageCount: number;
  engine: 'gemini_vision';
  model: string;
  isLowConfidence: boolean;
  unclearCount: number;
  warning?: string;
}

export class OCRError extends Error {
  code: string;
  statusCode?: number;
  constructor(message: string, code: string, statusCode?: number) {
    super(message);
    this.name = 'OCRError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

export class ConfigurationError extends OCRError {
  constructor(message = 'Gemini API key is not configured. Please set the GEMINI_API_KEY environment variable.') {
    super(message, 'CONFIG_ERROR', 500);
  }
}

export class AuthenticationError extends OCRError {
  constructor(message = 'Authentication failed with Google Gemini API. Please check your GEMINI_API_KEY.') {
    super(message, 'AUTH_ERROR', 401);
  }
}

export class QuotaExceededError extends OCRError {
  constructor(message = 'Gemini API quota exceeded or rate limit reached. Please check your quota or retry shortly.') {
    super(message, 'QUOTA_ERROR', 429);
  }
}

export class ServiceUnavailableError extends OCRError {
  constructor(message = 'Gemini Vision OCR service is temporarily unavailable due to high demand. Please try again.') {
    super(message, 'SERVICE_UNAVAILABLE', 503);
  }
}

export class TimeoutError extends OCRError {
  constructor(message = 'OCR transcription timed out after 60 seconds. Please try again.') {
    super(message, 'TIMEOUT_ERROR', 504);
  }
}

export class InvalidImageError extends OCRError {
  constructor(message = 'No readable text could be transcribed from the image. The image may be blurry, unreadable, or blank.') {
    super(message, 'INVALID_IMAGE', 422);
  }
}

const OCR_TRANSCRIPTION_PROMPT = `You are an OCR transcription engine. Read the supplied document image and transcribe all visible text as faithfully as possible.

Preserve the original reading order, headings, paragraphs, bullet points, numbering, punctuation, mathematical symbols, dates, numbers, and units.

Preserve tables using Markdown tables when their row and column structure is reasonably clear.

Do not summarize, explain, correct, or rewrite the author's content. Do not invent missing words. If a word or passage cannot be read confidently, mark it as [unclear]. Distinguish handwriting from printed text where useful. Return only the transcription, without introductory commentary.`;

/**
 * Supported fallback vision models when temporary 503 spikes occur.
 */
const FALLBACK_MODELS = [
  'gemini-3-flash-preview',
  'gemini-3.5-flash',
  'gemini-3.6-flash',
  'gemini-3.1-flash-lite',
];

/**
 * Dedicated Gemini Vision OCR Service.
 * Transcribes handwritten notes, printed reports, prescriptions, and tables verbatim.
 * Strictly no silent fallback to legacy engines.
 */
export class OCRService {

  /**
   * Process a file from storage and extract verbatim transcription using Gemini Vision.
   */
  async processFile(fileName: string): Promise<OCRResult> {
    const buffer = await storageService.getFileBuffer(fileName);
    const ext = path.extname(fileName).toLowerCase();

    if (['.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'].includes(ext)) {
      return this.processImage(buffer, ext);
    } else if (ext === '.pdf') {
      return this.processPdf(buffer);
    } else {
      throw new OCRError(`Unsupported file type: ${ext}`, 'UNSUPPORTED_FORMAT', 400);
    }
  }

  /**
   * Preprocess image preserving thin pen strokes, normalizing contrast,
   * and correcting EXIF camera orientation.
   */
  private async preprocessImage(
    buffer: Buffer,
    ext: string
  ): Promise<{ buffer: Buffer; mimeType: string }> {
    try {
      let pipeline = sharp(buffer).rotate();
      const metadata = await pipeline.metadata();
      const width = metadata.width || 800;
      const height = metadata.height || 600;

      // Downscale if oversized to optimize transmission while keeping crisp text
      if (width > 2500 || height > 2500) {
        pipeline = pipeline.resize({
          width: width >= height ? 2500 : undefined,
          height: height > width ? 2500 : undefined,
          fit: 'inside',
        });
      } else if (width < 1000 && height < 1000) {
        // Upscale tiny images with high-order Lanczos3 to clarify thin pen strokes
        const scale = Math.max(1000 / width, 1000 / height);
        pipeline = pipeline.resize({
          width: Math.round(width * scale),
          height: Math.round(height * scale),
          fit: 'inside',
          kernel: sharp.kernel.lanczos3,
        });
      }

      // Gentle contrast normalization without binarization/destructive thresholding
      pipeline = pipeline.normalize();

      if (ext === '.png') {
        const preprocessed = await pipeline.png().toBuffer();
        return { buffer: preprocessed, mimeType: 'image/png' };
      } else if (ext === '.webp') {
        const preprocessed = await pipeline.webp({ quality: 90 }).toBuffer();
        return { buffer: preprocessed, mimeType: 'image/webp' };
      } else {
        const preprocessed = await pipeline.jpeg({ quality: 90 }).toBuffer();
        return { buffer: preprocessed, mimeType: 'image/jpeg' };
      }
    } catch (error) {
      console.warn('[OCR] Preprocessing warning, using original buffer:', (error as Error).message);
      const mime = ext === '.png' ? 'image/png' : ext === '.webp' ? 'image/webp' : 'image/jpeg';
      return { buffer, mimeType: mime };
    }
  }

  /**
   * Execute single API call to Gemini with timeout and payload serialization.
   */
  private async executeGeminiCall(
    modelName: string,
    apiKey: string,
    base64Data: string,
    mimeType: string
  ): Promise<{ statusCode: number; data: string }> {
    const payload = JSON.stringify({
      contents: [{
        parts: [
          { text: OCR_TRANSCRIPTION_PROMPT },
          { inline_data: { mime_type: mimeType, data: base64Data } }
        ]
      }],
      generationConfig: {
        temperature: 0.1
      }
    });

    return new Promise((resolve, reject) => {
      const req = https.request({
        hostname: 'generativelanguage.googleapis.com',
        path: `/v1beta/models/${modelName}:generateContent?key=${apiKey}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload)
        },
        timeout: 60000
      }, res => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          resolve({ statusCode: res.statusCode || 500, data });
        });
      });

      req.on('error', err => reject(err));
      req.on('timeout', () => {
        req.destroy();
        reject(new TimeoutError());
      });

      req.write(payload);
      req.end();
    });
  }

  /**
   * Transcribe document image with Gemini, supporting transient retry and model failover.
   */
  private async transcribeWithGemini(buffer: Buffer, mimeType: string): Promise<OCRResult> {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey || apiKey.trim().length === 0) {
      throw new ConfigurationError();
    }

    const configuredModel = process.env.GEMINI_OCR_MODEL || 'gemini-3-flash-preview';
    const modelsToTry = [configuredModel, ...FALLBACK_MODELS.filter(m => m !== configuredModel)];
    const base64Data = buffer.toString('base64');

    let lastError: Error | null = null;

    for (const model of modelsToTry) {
      // Allow up to 2 retries for transient 503 high demand spikes on each model
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          console.log(`[OCR Gemini] Attempting transcription with model "${model}" (attempt ${attempt + 1})...`);
          const response = await this.executeGeminiCall(model, apiKey, base64Data, mimeType);

          if (response.statusCode === 200) {
            const json = JSON.parse(response.data);
            const rawText = json.candidates?.[0]?.content?.parts?.[0]?.text || '';
            const cleanedText = rawText.trim();

            if (!cleanedText) {
              throw new InvalidImageError();
            }

            // Calculate honest quality metrics based on transcript completeness and [unclear] markers
            const unclearCount = (cleanedText.match(/\[unclear\]/gi) || []).length;
            let confidence = 0.95 - (unclearCount * 0.08);

            if (cleanedText.length < 30) {
              confidence = Math.min(confidence, 0.60);
            }
            confidence = Math.max(0.20, Math.min(0.99, confidence));
            const roundedConfidence = parseFloat(confidence.toFixed(2));

            let qualityStatus: OCRQualityStatus = 'HIGH';
            if (roundedConfidence < 0.65) {
              qualityStatus = 'LOW_REVIEW_NEEDED';
            } else if (roundedConfidence < 0.85) {
              qualityStatus = 'MEDIUM';
            }

            const isLowConfidence = roundedConfidence < 0.65;
            const warning = isLowConfidence
              ? (unclearCount > 0
                  ? `Transcription contains ${unclearCount} unclear passage(s). Manual review recommended.`
                  : 'Extracted text is brief or uncertain. Please review the transcription.')
              : undefined;

            console.log(`[OCR Gemini] Transcription success using ${model}! Quality: ${qualityStatus}, Conf: ${roundedConfidence * 100}%, Chars: ${cleanedText.length}`);

            return {
              text: cleanedText,
              confidence: roundedConfidence,
              qualityStatus,
              pageCount: 1,
              engine: 'gemini_vision',
              model,
              isLowConfidence,
              unclearCount,
              warning
            };
          }

          // Handle specific HTTP error status codes
          let errorMessage = 'Gemini API Error';
          try {
            const errJson = JSON.parse(response.data);
            if (errJson.error?.message) {
              errorMessage = errJson.error.message;
            }
          } catch (_) {}

          if (response.statusCode === 400 || response.statusCode === 401 || response.statusCode === 403) {
            if (errorMessage.toLowerCase().includes('api key') || response.statusCode === 401 || response.statusCode === 403) {
              throw new AuthenticationError(`Gemini API Authentication Error (${response.statusCode}): ${errorMessage}`);
            }
            throw new OCRError(`Gemini API Error (${response.statusCode}): ${errorMessage}`, 'API_ERROR', response.statusCode);
          }

          if (response.statusCode === 429) {
            throw new QuotaExceededError(`Gemini API Quota Exceeded: ${errorMessage}`);
          }

          if (response.statusCode === 503) {
            console.warn(`[OCR Gemini] Model ${model} returned 503 high demand. Waiting before retry...`);
            if (attempt < 2) {
              await new Promise(r => setTimeout(r, 1500 * (attempt + 1)));
              continue;
            }
            lastError = new ServiceUnavailableError(`Model ${model} is temporarily unavailable: ${errorMessage}`);
            break; // Try next fallback model
          }

          throw new OCRError(`Gemini API Error (${response.statusCode}): ${errorMessage}`, 'API_ERROR', response.statusCode);
        } catch (err) {
          if (err instanceof AuthenticationError || err instanceof ConfigurationError || err instanceof QuotaExceededError || err instanceof InvalidImageError) {
            throw err;
          }
          lastError = err as Error;
          if (attempt < 2 && !(err instanceof TimeoutError)) {
            await new Promise(r => setTimeout(r, 1500 * (attempt + 1)));
            continue;
          }
          break; // Break inner retry loop to try next model
        }
      }
    }

    throw lastError || new ServiceUnavailableError('All Gemini vision models are temporarily unavailable. Please retry shortly.');
  }

  /**
   * Primary image processing entry point.
   */
  private async processImage(buffer: Buffer, ext: string): Promise<OCRResult> {
    const { buffer: preprocessedBuffer, mimeType } = await this.preprocessImage(buffer, ext);
    return this.transcribeWithGemini(preprocessedBuffer, mimeType);
  }

  /**
   * Process PDF documents via Gemini Vision.
   */
  private async processPdf(buffer: Buffer): Promise<OCRResult> {
    try {
      return await this.processImage(buffer, '.pdf');
    } catch (err) {
      if (err instanceof OCRError) throw err;
      throw new OCRError(
        'PDF processing failed. For best results, please upload an image (JPG/PNG) of your medical report.',
        'PDF_PROCESSING_FAILED',
        422
      );
    }
  }
}

export const ocrService = new OCRService();
