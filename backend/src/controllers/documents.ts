import { Response, NextFunction } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { NotFoundError, ForbiddenError, ValidationError } from '../utils/errors';
import { ocrService } from '../services/ocr';
import { paramExtractorService } from '../services/paramExtractor';
import { categorizerService } from '../services/categorizer';
import { storageService } from '../services/storage';

const prisma = new PrismaClient();

export async function uploadDocument(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    if (!req.file) {
      throw new ValidationError('No file uploaded');
    }

    const file = req.file;
    const uniqueName = await storageService.uploadBuffer(file.buffer, file.originalname, file.mimetype);

    const document = await prisma.medicalDocument.create({
      data: {
        userId: req.userId!,
        fileName: uniqueName,
        originalName: file.originalname,
        fileType: file.mimetype,
        fileSize: file.size,
        storagePath: storageService.getFileUrl(uniqueName),
        processingStatus: 'UPLOADED',
      },
    });

    res.status(201).json({
      message: 'Document uploaded successfully',
      document: {
        id: document.id,
        originalName: document.originalName,
        fileType: document.fileType,
        fileSize: document.fileSize,
        processingStatus: document.processingStatus,
        uploadedAt: document.uploadedAt,
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function getDocuments(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const status = req.query.status as string;
    const categoryId = req.query.categoryId as string;

    const where: any = { userId: req.userId };
    if (status) where.processingStatus = status;
    if (categoryId) where.categoryId = categoryId;

    const [documents, total] = await Promise.all([
      prisma.medicalDocument.findMany({
        where,
        include: {
          category: { select: { id: true, name: true, icon: true } },
          tags: { select: { id: true, tag: true } },
          extractedText: { select: { id: true, confidence: true } },
          _count: { select: { healthMeasurements: true } },
        },
        orderBy: { uploadedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.medicalDocument.count({ where }),
    ]);

    res.json({
      documents,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    next(error);
  }
}

export async function getDocument(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const document = await prisma.medicalDocument.findUnique({
      where: { id: req.params.id as string },
      include: {
        category: true,
        tags: true,
        extractedText: true,
        healthMeasurements: {
          include: { parameter: true },
          orderBy: { measuredAt: 'desc' },
        },
      },
    });

    if (!document) {
      throw new NotFoundError('Document not found');
    }

    // Authorization: ensure document belongs to requesting user
    if (document.userId !== req.userId) {
      throw new ForbiddenError('Access denied');
    }

    res.json({ document });
  } catch (error) {
    next(error);
  }
}

export async function deleteDocument(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const document = await prisma.medicalDocument.findUnique({
      where: { id: req.params.id as string },
    });

    if (!document) {
      throw new NotFoundError('Document not found');
    }

    if (document.userId !== req.userId) {
      throw new ForbiddenError('Access denied');
    }

    // Delete file from storage
    await storageService.deleteFile(document.fileName);

    // Delete from database (cascade deletes related records)
    await prisma.medicalDocument.delete({
      where: { id: document.id },
    });

    res.json({ message: 'Document deleted successfully' });
  } catch (error) {
    next(error);
  }
}

export async function processDocument(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const document = await prisma.medicalDocument.findUnique({
      where: { id: req.params.id as string },
    });

    if (!document) {
      throw new NotFoundError('Document not found');
    }

    if (document.userId !== req.userId) {
      throw new ForbiddenError('Access denied');
    }

    // Prevent duplicate simultaneous processing of the same document
    if (document.processingStatus === 'PROCESSING') {
      res.status(409).json({
        message: 'Document is already being processed',
        processingStatus: 'PROCESSING',
      });
      return;
    }

    // Update status to PROCESSING
    await prisma.medicalDocument.update({
      where: { id: document.id },
      data: { processingStatus: 'PROCESSING', processingError: null },
    });

    // Start async processing with safety logging
    processDocumentAsync(document.id, document.fileName, document.originalName, req.userId!).catch(
      (err) => console.error(`[CRITICAL] Background processing crashed for doc ${document.id}:`, err)
    );

    res.json({
      message: 'Processing started',
      processingStatus: 'PROCESSING',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * Async document processing pipeline:
 * 1. OCR text extraction
 * 2. Health parameter extraction
 * 3. Document categorization
 * 4. Tag generation
 */
async function processDocumentAsync(
  documentId: string,
  fileName: string,
  originalName: string,
  userId: string
) {
  const startTime = Date.now();
  console.log(`[TIMING] [Doc: ${documentId}] Pipeline started for ${originalName} (${fileName})`);
  try {
    // Step 1: OCR
    const ocrStart = Date.now();
    const ocrResult = await ocrService.processFile(fileName);
    const ocrDuration = Date.now() - ocrStart;
    console.log(`[TIMING] [Doc: ${documentId}] OCR completed in ${ocrDuration}ms (Engine: ${ocrResult.engine}, Conf: ${(ocrResult.confidence * 100).toFixed(1)}%, Chars: ${ocrResult.text?.length || 0})`);

    if (!ocrResult.text || ocrResult.text.trim().length === 0) {
      console.warn(`[TIMING] [Doc: ${documentId}] No text extracted from image`);
      await prisma.medicalDocument.update({
        where: { id: documentId },
        data: {
          processingStatus: 'FAILED',
          processingError: 'No text could be extracted from the document. The image may be blurry, unreadable, or blank.',
        },
      });
      return;
    }

    // Step 2: Save extracted text
    const textSaveStart = Date.now();
    await prisma.extractedText.upsert({
      where: { documentId },
      update: {
        text: ocrResult.text,
        confidence: ocrResult.confidence,
        pageCount: ocrResult.pageCount,
      },
      create: {
        documentId,
        text: ocrResult.text,
        confidence: ocrResult.confidence,
        pageCount: ocrResult.pageCount,
      },
    });
    console.log(`[TIMING] [Doc: ${documentId}] Extracted text persisted in ${Date.now() - textSaveStart}ms`);    // Clear previous tags and measurements for this document on retry/re-process
    await prisma.healthMeasurement.deleteMany({ where: { documentId } });
    await prisma.documentTag.deleteMany({ where: { documentId } });

    // Step 3: Categorize document (Prescription, Lab Report, Blood Test, Scan Report, Discharge Summary, Medical Bill, General, Other)
    const catStart = Date.now();
    const categorization = categorizerService.categorize(ocrResult.text, originalName);
    
    let categoryId: string | null = null;
    if (categorization.categoryName) {
      const category = await prisma.medicalCategory.findFirst({
        where: {
          OR: [
            { name: categorization.categoryName },
            { name: 'General' },
            { name: 'Other' },
          ]
        },
      });
      categoryId = category?.id || null;
    }

    // Add clean category-relevant tags (never noise tokens like single "mg")
    for (const tag of categorization.tags) {
      await prisma.documentTag.upsert({
        where: { documentId_tag: { documentId, tag } },
        update: {},
        create: { documentId, tag },
      });
    }
    console.log(`[TIMING] [Doc: ${documentId}] Categorized as "${categorization.categoryName}" & tags saved in ${Date.now() - catStart}ms`);

    // Step 4: Extract health parameters (strictly guarded: skipped for non-medical/general docs)
    const paramsStart = Date.now();
    const extractedParams = paramExtractorService.extract(ocrResult.text, categorization.categoryName);
    console.log(`[TIMING] [Doc: ${documentId}] Extracted ${extractedParams.length} parameters in ${Date.now() - paramsStart}ms`);

    if (extractedParams.length > 0) {
      // Get parameter definitions from DB
      const paramDefs = await prisma.healthParameter.findMany();
      const paramMap = new Map(paramDefs.map(p => [p.name, p]));

      // Save health measurements
      for (const param of extractedParams) {
        const paramDef = paramMap.get(param.parameterName);
        if (!paramDef) continue;

        await prisma.healthMeasurement.create({
          data: {
            userId,
            parameterId: paramDef.id,
            documentId,
            value: param.value,
            unit: param.unit,
            measuredAt: new Date(),
            confidence: param.confidence,
            originalText: param.originalText,
          },
        });
      }
    }

    // Step 6: Update document status
    await prisma.medicalDocument.update({
      where: { id: documentId },
      data: {
        processingStatus: 'COMPLETED',
        categoryId,
        processingError: ocrResult.isLowConfidence ? (ocrResult.warning || 'Low confidence extraction. Text may be inaccurate.') : null,
      },
    });

    console.log(`[TIMING] [Doc: ${documentId}] Total pipeline duration: ${Date.now() - startTime}ms. Status: COMPLETED`);
  } catch (error) {
    console.error(`[TIMING] [Doc: ${documentId}] Processing failed after ${Date.now() - startTime}ms:`, error);
    await prisma.medicalDocument.update({
      where: { id: documentId },
      data: {
        processingStatus: 'FAILED',
        processingError: (error as Error).message || 'Processing failed. Please retry.',
      },
    });
  }
}

export async function getDocumentText(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const document = await prisma.medicalDocument.findUnique({
      where: { id: req.params.id as string },
      include: { extractedText: true },
    });

    if (!document) {
      throw new NotFoundError('Document not found');
    }

    if (document.userId !== req.userId) {
      throw new ForbiddenError('Access denied');
    }

    res.json({
      documentId: document.id,
      processingStatus: document.processingStatus,
      // @ts-ignore
      extractedText: document.extractedText,
    });
  } catch (error) {
    next(error);
  }
}

export async function updateCategory(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { categoryId } = req.body;

    const document = await prisma.medicalDocument.findUnique({
      where: { id: req.params.id as string },
    });

    if (!document) {
      throw new NotFoundError('Document not found');
    }

    if (document.userId !== req.userId) {
      throw new ForbiddenError('Access denied');
    }

    // Verify category exists
    if (categoryId) {
      const category = await prisma.medicalCategory.findUnique({ where: { id: categoryId } });
      if (!category) {
        throw new ValidationError('Invalid category');
      }
    }

    const updated = await prisma.medicalDocument.update({
      where: { id: document.id },
      data: { categoryId: categoryId || null },
      include: { category: true },
    });

    res.json({ message: 'Category updated', document: updated });
  } catch (error) {
    next(error);
  }
}

export async function updateDocumentText(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { text, confidence, categoryName, tags, parameters, summary } = req.body;
    const documentId = req.params.id as string;
    const userId = req.userId!;

    const document = await prisma.medicalDocument.findUnique({
      where: { id: documentId },
    });

    if (!document) {
      throw new NotFoundError('Document not found');
    }

    if (document.userId !== userId) {
      throw new ForbiddenError('Access denied');
    }

    // 1. Upsert extracted text with AI summary header
    let fullText = text || '';
    if (summary && !fullText.includes(summary)) {
      fullText = `> **AI Clinical Summary**: ${summary}\n\n${fullText}`;
    }

    await prisma.extractedText.upsert({
      where: { documentId },
      update: {
        text: fullText,
        confidence: confidence != null ? parseFloat(confidence) : 0.95,
      },
      create: {
        documentId,
        text: fullText,
        confidence: confidence != null ? parseFloat(confidence) : 0.95,
      },
    });

    // 2. Resolve category
    let categoryId = document.categoryId;
    if (categoryName) {
      const category = await prisma.medicalCategory.findFirst({
        where: {
          OR: [
            { name: categoryName },
            { name: { equals: categoryName, mode: 'insensitive' } },
            { name: 'General' },
            { name: 'Other' },
          ]
        },
      });
      if (category) categoryId = category.id;
    }

    // 3. Update tags
    if (Array.isArray(tags)) {
      await prisma.documentTag.deleteMany({ where: { documentId } });
      for (const tag of tags) {
        if (typeof tag === 'string' && tag.trim().length > 0) {
          await prisma.documentTag.upsert({
            where: { documentId_tag: { documentId, tag: tag.trim() } },
            update: {},
            create: { documentId, tag: tag.trim() },
          });
        }
      }
    }

    // 4. Save Health Measurements (Clear previous for this doc first)
    await prisma.healthMeasurement.deleteMany({ where: { documentId } });

    // Standard parameter canonical mappings
    const standardMap: Record<string, { name: string; displayName: string; defaultUnit: string; normalMin?: number; normalMax?: number }> = {
      blood_glucose: { name: 'glucose', displayName: 'Blood Glucose', defaultUnit: 'mg/dL', normalMin: 70, normalMax: 100 },
      glucose: { name: 'glucose', displayName: 'Blood Glucose', defaultUnit: 'mg/dL', normalMin: 70, normalMax: 100 },
      fbs: { name: 'glucose', displayName: 'Fasting Blood Glucose', defaultUnit: 'mg/dL', normalMin: 70, normalMax: 100 },
      fasting_blood_sugar: { name: 'glucose', displayName: 'Fasting Blood Sugar', defaultUnit: 'mg/dL', normalMin: 70, normalMax: 100 },
      hemoglobin: { name: 'hemoglobin', displayName: 'Hemoglobin', defaultUnit: 'g/dL', normalMin: 12, normalMax: 17.5 },
      hb: { name: 'hemoglobin', displayName: 'Hemoglobin', defaultUnit: 'g/dL', normalMin: 12, normalMax: 17.5 },
      hgb: { name: 'hemoglobin', displayName: 'Hemoglobin', defaultUnit: 'g/dL', normalMin: 12, normalMax: 17.5 },
      systolic_bp: { name: 'systolic_bp', displayName: 'Systolic Blood Pressure', defaultUnit: 'mmHg', normalMin: 90, normalMax: 120 },
      diastolic_bp: { name: 'diastolic_bp', displayName: 'Diastolic Blood Pressure', defaultUnit: 'mmHg', normalMin: 60, normalMax: 80 },
      cholesterol: { name: 'cholesterol', displayName: 'Total Cholesterol', defaultUnit: 'mg/dL', normalMin: 0, normalMax: 200 },
      total_cholesterol: { name: 'cholesterol', displayName: 'Total Cholesterol', defaultUnit: 'mg/dL', normalMin: 0, normalMax: 200 },
      heart_rate: { name: 'heart_rate', displayName: 'Heart Rate', defaultUnit: 'bpm', normalMin: 60, normalMax: 100 },
      pulse: { name: 'heart_rate', displayName: 'Pulse / Heart Rate', defaultUnit: 'bpm', normalMin: 60, normalMax: 100 },
      hba1c: { name: 'hba1c', displayName: 'HbA1c', defaultUnit: '%', normalMin: 4, normalMax: 5.6 },
      creatinine: { name: 'creatinine', displayName: 'Creatinine', defaultUnit: 'mg/dL', normalMin: 0.7, normalMax: 1.3 },
      serum_creatinine: { name: 'creatinine', displayName: 'Serum Creatinine', defaultUnit: 'mg/dL', normalMin: 0.7, normalMax: 1.3 },
      wbc: { name: 'wbc', displayName: 'White Blood Cells', defaultUnit: 'cells/mcL', normalMin: 4500, normalMax: 11000 },
      white_blood_cells: { name: 'wbc', displayName: 'White Blood Cells', defaultUnit: 'cells/mcL', normalMin: 4500, normalMax: 11000 },
      tlc: { name: 'wbc', displayName: 'Total Leucocyte Count (TLC)', defaultUnit: 'cells/mcL', normalMin: 4500, normalMax: 11000 },
      platelets: { name: 'platelets', displayName: 'Platelets', defaultUnit: 'cells/mcL', normalMin: 150000, normalMax: 400000 },
      platelet_count: { name: 'platelets', displayName: 'Platelet Count', defaultUnit: 'cells/mcL', normalMin: 150000, normalMax: 400000 },
    };

    if (Array.isArray(parameters) && parameters.length > 0) {
      for (const p of parameters) {
        if (!p) continue;
        const rawName = String(p.name || p.displayName || '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '_');
        if (!rawName) continue;

        const canonical = standardMap[rawName] || {
          name: rawName,
          displayName: p.displayName || rawName.replace(/_/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()),
          defaultUnit: p.unit || '',
        };

        const paramDef = await prisma.healthParameter.upsert({
          where: { name: canonical.name },
          update: {
            displayName: canonical.displayName,
            defaultUnit: p.unit || canonical.defaultUnit,
          },
          create: {
            name: canonical.name,
            displayName: canonical.displayName,
            defaultUnit: p.unit || canonical.defaultUnit,
            normalMin: canonical.normalMin,
            normalMax: canonical.normalMax,
          },
        });

        const numVal = typeof p.value === 'number' ? p.value : parseFloat(String(p.value).replace(/,/g, ''));
        if (isNaN(numVal)) continue;

        await prisma.healthMeasurement.create({
          data: {
            userId,
            parameterId: paramDef.id,
            documentId,
            value: numVal,
            unit: p.unit || paramDef.defaultUnit,
            measuredAt: new Date(),
            confidence: p.confidence != null ? parseFloat(p.confidence) : 0.95,
            originalText: p.originalText || `${p.displayName || paramDef.displayName}: ${numVal} ${p.unit || paramDef.defaultUnit}`,
          },
        });
      }
    } else if (text && text.trim().length > 0) {
      // Fallback: Run regex parameter extractor if parameters array was not provided
      const extractedParams = paramExtractorService.extract(text, categoryName);
      if (extractedParams.length > 0) {
        const paramDefs = await prisma.healthParameter.findMany();
        const paramMap = new Map(paramDefs.map(p => [p.name, p]));

        for (const ep of extractedParams) {
          const paramDef = paramMap.get(ep.parameterName);
          if (!paramDef) continue;

          await prisma.healthMeasurement.create({
            data: {
              userId,
              parameterId: paramDef.id,
              documentId,
              value: ep.value,
              unit: ep.unit,
              measuredAt: new Date(),
              confidence: ep.confidence,
              originalText: ep.originalText,
            },
          });
        }
      }
    }

    const updatedDoc = await prisma.medicalDocument.update({
      where: { id: documentId },
      data: {
        processingStatus: 'COMPLETED',
        processingError: null,
        categoryId,
      },
      include: {
        category: true,
        tags: true,
        extractedText: true,
        healthMeasurements: {
          include: { parameter: true },
          orderBy: { measuredAt: 'desc' },
        },
      },
    });

    res.json({
      message: 'Document text and parameters updated successfully',
      document: updatedDoc,
    });
  } catch (error) {
    next(error);
  }
}
