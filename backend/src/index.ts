import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import path from 'path';
import { config } from './config/env';
import { AppError } from './utils/errors';

// Import routes
import authRoutes from './routes/auth';
import profileRoutes from './routes/profile';
import documentRoutes from './routes/documents';
import searchRoutes from './routes/search';
import categoryRoutes from './routes/categories';
import healthParamRoutes from './routes/healthParams';
import healthTrendRoutes from './routes/healthTrends';
import ocrRoutes from './routes/ocr';

const app = express();

// =============================================
// MIDDLEWARE
// =============================================

// CORS
app.use(cors({
  origin: config.frontendUrl,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Serve uploaded files (with auth in production, open for dev)
app.use('/uploads', express.static(path.resolve(config.uploadDir)));

// =============================================
// ROUTES
// =============================================

app.get('/api/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/health-parameters', healthParamRoutes);
app.use('/api/health-trends', healthTrendRoutes);
app.use('/api/ocr', ocrRoutes);

// =============================================
// ERROR HANDLING
// =============================================

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    code: 'ROUTE_NOT_FOUND',
    error: 'Route not found',
    message: 'Route not found',
  });
});

// Global error handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('Error occurred:', err.name, '-', err.message);

  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      code: err.code || 'ERROR',
      error: err.message,
      message: err.message,
    });
  }

  // Database / Prisma errors
  const isDbError =
    err.name === 'PrismaClientInitializationError' ||
    err.name === 'PrismaClientKnownRequestError' ||
    err.name === 'PrismaClientRustPanicError' ||
    err.name === 'PrismaClientUnknownRequestError' ||
    err.message.includes("Can't reach database server") ||
    err.message.includes('Error querying the database') ||
    err.message.includes('tenant/user') ||
    err.message.includes('connection refused') ||
    err.message.includes('ENOTFOUND');

  if (isDbError) {
    return res.status(503).json({
      success: false,
      code: 'DATABASE_UNAVAILABLE',
      error: 'The database service is temporarily unavailable. Please try again later.',
      message: 'The database service is temporarily unavailable. Please try again later.',
    });
  }

  // Multer errors
  if (err.message && err.message.includes('Invalid file type')) {
    return res.status(400).json({
      success: false,
      code: 'INVALID_FILE_TYPE',
      error: err.message,
      message: err.message,
    });
  }

  if ((err as any).code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({
      success: false,
      code: 'FILE_TOO_LARGE',
      error: `File too large. Maximum size: ${config.maxFileSizeMB}MB`,
      message: `File too large. Maximum size: ${config.maxFileSizeMB}MB`,
    });
  }

  // Generic error - never expose stack traces or raw details to client
  res.status(500).json({
    success: false,
    code: 'INTERNAL_SERVER_ERROR',
    error: 'An unexpected error occurred. Please try again later.',
    message: 'An unexpected error occurred. Please try again later.',
  });
});

// =============================================
// START SERVER
// =============================================

app.listen(config.port, () => {
  console.log(`
╔══════════════════════════════════════════════════╗
║  MedRecord Backend Server                        ║
║  Running on: http://localhost:${config.port}              ║
║  Environment: ${config.nodeEnv.padEnd(32)}║
╚══════════════════════════════════════════════════╝
  `);
});

export default app;
