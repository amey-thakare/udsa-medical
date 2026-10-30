# 🏥 MyHealthMitra — Complete Project Master Guide & Learning Manual

Welcome to the definitive learning document for **MyHealthMitra** (Smart Medical Record Management & Health Analytics System). This document is written to give you a complete, end-to-end understanding of how every single part of this project works: from the mobile app and web frontend to the Node.js backend, PostgreSQL database, AI-powered OCR engines, and PyTorch machine learning pipelines.

---

## 📑 Table of Contents

1. [Executive Summary & Problem Statement](#1-executive-summary--problem-statement)
2. [High-Level System Architecture](#2-high-level-system-architecture)
3. [Full Project Directory Structure](#3-full-project-directory-structure)
4. [Backend Deep Dive (Node.js + Express + TypeScript)](#4-backend-deep-dive-nodejs--express--typescript)
   - 4.1 Server Lifecycle & Entrypoint
   - 4.2 Database Schema & ER Model (Prisma + PostgreSQL)
   - 4.3 Authentication & Security System (JWT + Bcrypt)
   - 4.4 Cloud Storage Pipeline (Firebase Cloud Storage)
   - 4.5 Multimodal AI OCR Engine (`ocr.ts` & Gemini Vision)
   - 4.6 Smart Categorization & Tagging (`categorizer.ts`)
   - 4.7 Clinical Health Parameter Extraction (`paramExtractor.ts`)
   - 4.8 Complete REST API Reference
5. [Flutter Mobile App Deep Dive (`flutter_app/`)](#5-flutter-mobile-app-deep-dive-flutter_app)
   - 5.1 Technology Stack & Architectural Pattern
   - 5.2 State Management (`Provider`) & Declarative Routing (`go_router`)
   - 5.3 Walkthrough of All 12 Screens
   - 5.4 Client-Side Gemini AI & Smart Offline Caching
   - 5.5 Interactive Graphical Health Trends (`fl_chart`)
6. [React Web Frontend Deep Dive (`frontend/`)](#6-react-web-frontend-deep-dive-frontend)
   - 6.1 Architecture & Setup (React 19 + Vite)
   - 6.2 Key Pages & Features
7. [Custom Deep Learning OCR Subsystem (`ocr/`)](#7-custom-deep-learning-ocr-subsystem-ocr)
   - 7.1 What is CRNN (CNN + BiLSTM + CTC)?
   - 7.2 Image Preprocessing & Region Detection (`preprocess.py`)
   - 7.3 Model Architecture (`model.py`)
   - 7.4 Training, Evaluation & CTC Decoding (`train.py`, `evaluate.py`)
8. [End-to-End Life of a Document (Step-by-Step Flow)](#8-end-to-end-life-of-a-document-step-by-step-flow)
9. [Tracked Clinical Biomarkers & Reference Ranges](#9-tracked-clinical-biomarkers--reference-ranges)
10. [Local Development & Setup Guide](#10-local-development--setup-guide)
11. [Production Deployment & Building APKs](#11-production-deployment--building-apks)
12. [Troubleshooting, Gotchas & FAQ](#12-troubleshooting-gotchas--faq)

---

## 1. Executive Summary & Problem Statement

### The Problem
Patients and families frequently accumulate hundreds of physical, paper-based medical reports over time: blood test slips, doctor prescriptions, radiology reports (X-rays, MRIs), discharge summaries, and medical bills. This leads to critical challenges:
- **Lost or Damaged Records**: Paper fades, gets misplaced, or is unavailable during emergencies.
- **Unreadable Doctor Handwriting**: Prescriptions and handwritten clinical notes are notoriously hard to decipher.
- **Hidden Health Trends**: Changes in critical biomarkers (such as HbA1c, fasting blood sugar, creatinine, or blood pressure) over months or years are impossible to visualize across dozens of scattered paper slips.
- **No Quick Search**: Finding a specific prescription from six months ago requires digging through stacks of paper.

### The Solution: MyHealthMitra
**MyHealthMitra** ("My Health Friend") transforms how individuals manage personal healthcare:
1. **Snap & Digitize**: Capture or upload any medical document (JPG, PNG, PDF) using a mobile camera or web browser.
2. **AI Multimodal OCR**: Transcribes both printed lab reports and handwritten prescriptions into clean, formatted text and Markdown tables.
3. **Automated Categorization**: Automatically categorizes records into *Blood Test*, *Lab Report*, *Prescription*, *Scan Report*, *Discharge Summary*, or *Medical Bill* with intelligent tagging.
4. **Biomarker Extraction**: Automatically detects and extracts clinical parameters (e.g., Blood Glucose, Hemoglobin, Blood Pressure, Cholesterol, Platelets, Creatinine) and checks them against normal physiological ranges.
5. **Interactive Health Trends**: Plots longitudinal interactive charts showing how a patient's vitals evolve over time, with color-coded normal reference bands.

---

## 2. High-Level System Architecture

MyHealthMitra employs a modular, four-tier client-server-AI architecture:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT TIER                                        │
│                                                                                 │
│   ┌───────────────────────────────────┐     ┌───────────────────────────────┐   │
│   │    Flutter Mobile Application     │     │      React + Vite Web App     │   │
│   │   (Android & iOS Cross-Platform)  │     │       (Desktop/Browser)       │   │
│   │  • Provider State Management      │     │  • React Context API          │   │
│   │  • go_router Navigation           │     │  • Tailwind / Custom CSS      │   │
│   │  • fl_chart Interactive Trends    │     │  • Responsive Dashboard       │   │
│   │  • Direct Client Gemini Fallback  │     │                               │   │
│   └─────────────────┬─────────────────┘     └───────────────┬───────────────┘   │
└─────────────────────┼───────────────────────────────────────┼───────────────────┘
                      │                                       │
                      └───────────────────┬───────────────────┘
                                          │ HTTPS / REST API (JSON & Multipart)
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND API TIER                                   │
│                     (Node.js v18+ • Express.js • TypeScript)                    │
│                                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │ Express REST API Routers:                                               │   │
│   │ /api/auth   • /api/documents   • /api/health   • /api/search   • /ocr   │   │
│   └──────────────────────┬──────────────────────────────────────────────────┘   │
│                          │                                                       │
│   ┌──────────────────────┼──────────────────────────────────────────────────┐   │
│   │ Core Services Layer: │                                                  │   │
│   │                      ▼                                                  │   │
│   │  ┌───────────────────────┐   ┌───────────────────────┐                  │   │
│   │  │   OCR Engine Service  │   │  Smart Categorizer    │                  │   │
│   │  │   • Sharp Prep        │   │  • Weighted Heuristic │                  │   │
│   │  │   • Gemini Vision     │   │  • Clinical Anchors   │                  │   │
│   │  │   • Model Fallbacks   │   │  • Auto-Tagging       │                  │   │
│   │  └───────────┬───────────┘   └───────────┬───────────┘                  │   │
│   │              │                           │                              │   │
│   │              ▼                           ▼                              │   │
│   │  ┌───────────────────────┐   ┌───────────────────────┐                  │   │
│   │  │  Parameter Extractor  │   │   Storage Service     │                  │   │
│   │  │  • Regex Clinical NLP │   │   • Firebase Storage  │                  │   │
│   │  │  • Boundary Filtering │   │   • Local Disk Backup │                  │   │
│   │  └───────────────────────┘   └───────────────────────┘                  │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────┬─────────────────────────────────┬────────────────────┘
                           │                                 │
                           ▼                                 ▼
┌───────────────────────────────────────┐   ┌─────────────────────────────────────┐
│             DATABASE TIER             │   │            AI & ML TIER             │
│   PostgreSQL (Hosted on Supabase)     │   │                                     │
│   • Managed via Prisma ORM            │   │ 1. Google Gemini 3 Vision API       │
│   • Relational Integrity & Cascades   │   │    Multimodal Vision-Language OCR   │
│   • User-isolated Health Measurements │   │                                     │
│   • Extracted Text & Medical Tags     │   │ 2. PyTorch Deep Learning Pipeline   │
│                                       │   │    CRNN + CTC for Custom Training   │
└───────────────────────────────────────┘   └─────────────────────────────────────┘
```

---

## 3. Full Project Directory Structure

```
medical/
├── README.md                   # Quickstart documentation & overview
├── learn.md                    # This master learning guide
├── app-release.apk             # Compiled Android APK (fat universal build)
├── app-arm64-v8a-release.apk   # Optimized 64-bit Android release APK
│
├── backend/                    # Node.js + Express + TypeScript API Server
│   ├── package.json            # Backend dependencies & run scripts
│   ├── tsconfig.json           # TypeScript configuration
│   ├── .env.example            # Environment variables template
│   ├── prisma/
│   │   ├── schema.prisma       # Prisma ORM database models & relations
│   │   └── seed.ts             # Seeds 10 core health parameters & categories
│   ├── src/
│   │   ├── index.ts            # Server entrypoint, CORS, rate limits, routes
│   │   ├── config/             # Environment & Firebase config
│   │   ├── controllers/        # Business logic controllers
│   │   │   ├── auth.ts         # User registration, login, token refresh
│   │   │   ├── documents.ts    # Upload, OCR queue, delete, detail fetch
│   │   │   ├── health.ts       # Biomarker aggregation, latest vitals, charts
│   │   │   ├── search.ts       # Full-text search across documents & tags
│   │   │   └── profile.ts      # Profile viewing & editing
│   │   ├── middleware/
│   │   │   ├── auth.ts         # JWT token verification & userId injection
│   │   │   ├── validation.ts   # Zod request schema validation
│   │   │   └── errorHandler.ts # Global error handler with custom error types
│   │   ├── routes/             # Express route mappings
│   │   │   ├── auth.ts, documents.ts, healthParams.ts, healthTrends.ts...
│   │   ├── services/           # Reusable service classes
│   │   │   ├── ocr.ts          # Sharp preprocessing + Gemini Vision OCR
│   │   │   ├── paramExtractor.ts # Clinical regex parameter extraction
│   │   │   ├── categorizer.ts  # Document classification & tagging
│   │   │   └── storage.ts      # Firebase Storage + Local upload fallback
│   │   └── utils/
│   │       └── errors.ts       # Custom HTTP error classes (NotFoundError, etc.)
│   └── uploads/                # Local disk staging directory for file uploads
│
├── flutter_app/                # Flutter Mobile Application (Cross-Platform)
│   ├── pubspec.yaml            # Flutter packages & asset declarations
│   ├── lib/
│   │   ├── main.dart           # App entrypoint, Provider setup, Theme init
│   │   ├── config/
│   │   │   ├── api_config.dart # Base URLs, endpoint constants, timeout settings
│   │   │   └── router.dart     # Declarative GoRouter routing with Auth guards
│   │   ├── models/             # Strongly typed Dart data models
│   │   │   ├── user.dart, document.dart, health_param.dart, category.dart
│   │   ├── providers/          # ChangeNotifier state providers
│   │   │   ├── auth_provider.dart      # User auth state & secure token storage
│   │   │   ├── document_provider.dart  # Documents list, upload progress, detail
│   │   │   └── health_provider.dart    # Biomarkers, latest vitals, trend series
│   │   ├── screens/            # 12 UI screens
│   │   │   ├── splash_screen.dart          # App load animation & session check
│   │   │   ├── login_screen.dart           # Email/password authentication
│   │   │   ├── signup_screen.dart          # New patient account registration
│   │   │   ├── main_shell.dart             # Persistent bottom navigation shell
│   │   │   ├── home_screen.dart            # Dashboard with stats & quick actions
│   │   │   ├── records_screen.dart         # Filterable list of medical documents
│   │   │   ├── upload_screen.dart          # Camera/gallery capture & file upload
│   │   │   ├── document_detail_screen.dart # Document viewer, OCR text & params
│   │   │   ├── health_params_screen.dart   # Biomarker cards with normal ranges
│   │   │   ├── health_trends_screen.dart   # fl_chart interactive trend charts
│   │   │   ├── search_screen.dart          # Real-time search across all records
│   │   │   └── profile_screen.dart         # User profile & logout
│   │   ├── services/           # HTTP clients & API wrappers
│   │   │   ├── api_client.dart             # Dio HTTP client with JWT interceptor
│   │   │   ├── gemini_service.dart         # Direct Gemini multimodal AI engine
│   │   │   ├── medical_history_cache.dart  # Offline local persistence
│   │   │   └── document_service.dart       # Document API interactions
│   │   ├── theme/
│   │   │   ├── app_colors.dart             # Curated clinical color palette
│   │   │   └── app_theme.dart              # Material Design 3 theme system
│   │   └── widgets/                        # Modular reusable UI widgets
│   │       ├── document_list_item.dart, param_card.dart, custom_button.dart...
│   └── assets/                 # App logo, icons, clinical placeholder graphics
│
├── frontend/                   # Modern React + Vite Web Dashboard
│   ├── package.json            # React 19, Lucide Icons, Vite
│   ├── vite.config.js          # Vite build config
│   ├── index.html              # Web entry HTML
│   └── src/
│       ├── main.jsx            # React root mount
│       ├── App.jsx             # React routing & state providers
│       ├── index.css           # Global typography & CSS styling
│       ├── api/                # Axios/Fetch API client wrappers
│       ├── context/            # React Context for Auth & Documents
│       └── pages/              # Matching screens: HomeScreen, UploadScreen, etc.
│
├── ocr/                        # Standalone PyTorch Deep Learning OCR Subsystem
│   ├── configs/                # Dataset & training YAML configuration
│   ├── src/
│   │   ├── model.py            # CRNN (CNN + BiLSTM + CTC) PyTorch architecture
│   │   ├── preprocess.py       # Deskewing, Gaussian blur, adaptive thresholding
│   │   ├── dataset_loader.py   # Medical text image data loader
│   │   ├── train.py            # Training loop with CTC Loss & Adam optimizer
│   │   ├── evaluate.py         # Character Error Rate (CER) & Word Error Rate (WER)
│   │   └── medical_ocr_pipeline.py # End-to-end Python inference pipeline
│   ├── models/                 # Saved PyTorch checkpoint weights (.pth)
│   └── evaluation/             # Test evaluation scripts
│
├── dataset/                    # Training images & annotations for custom OCR
└── docs/                       # Project audits and technical architecture notes
```

---

## 4. Backend Deep Dive (Node.js + Express + TypeScript)

The backend is built with **Node.js v18+**, **Express.js v5**, and **TypeScript v5.8**, giving you high developer ergonomics, strong compile-time typing, and robust performance.

### 4.1 Server Lifecycle & Entrypoint (`src/index.ts`)
When the server boots up:
1. **Environment Initialization**: `dotenv.config()` loads variables (`PORT`, `DATABASE_URL`, `JWT_SECRET`, `GEMINI_API_KEY`, etc.).
2. **Security & Middleware Stack**:
   - `cors({ origin: '*' })`: Enables cross-origin requests from Flutter Web and React.
   - `helmet()`: Sets HTTP security headers (HSTS, X-Content-Type-Options, etc.).
   - `express.json({ limit: '15mb' })`: Parses incoming JSON payloads.
   - `express.urlencoded({ extended: true })`: Handles form-encoded inputs.
   - Request Logger: Logs every incoming HTTP method, path, and response time.
3. **Route Mounting**:
   - `/api/auth` -> User registration, login, profile retrieval.
   - `/api/documents` -> Upload, document detail, delete, OCR reprocessing.
   - `/api/health-params` -> Master health parameters list & normal ranges.
   - `/api/health-trends` -> Aggregated time-series trend values for charts.
   - `/api/search` -> Query text across documents, tags, and categories.
   - `/ocr` -> Standalone OCR endpoint.
4. **Global Error Handling**: Any rejected promise or thrown error lands in `errorHandler.ts`, mapping specific error types (`ValidationError`, `NotFoundError`, `OCRError`) to appropriate HTTP status codes (400, 404, 422, 500).

---

### 4.2 Database Schema & ER Model (`backend/prisma/schema.prisma`)
The database is hosted on **PostgreSQL** (via Supabase) and managed using **Prisma ORM**.

#### Entity Relationship (ER) Diagram
```
  ┌──────────────┐
  │     User     │
  └──────┬───────┘
         │ 1
         │
         │ has many (Cascade Delete)
         ▼ *
  ┌──────────────────────┐          ┌────────────────────┐
  │   MedicalDocument    ├─────────►│  MedicalCategory   │
  └──────┬───────────────┘ *      1 └────────────────────┘
         │
         ├─── 1:1 ──────────────► ┌────────────────────┐
         │                        │   ExtractedText    │
         │                        └────────────────────┘
         ├─── 1:N ──────────────► ┌────────────────────┐
         │                        │    DocumentTag     │
         │                        └────────────────────┘
         └─── 1:N ──────────────► ┌────────────────────┐
                                  │ HealthMeasurement  │◄────────┐
                                  └────────────────────┘         │
                                             ▲                   │
                                             │ *                 │ *
                                  ┌──────────┴─────────┐ ┌───────┴──────┐
                                  │  HealthParameter   │ │     User     │
                                  └────────────────────┘ └──────────────┘
```

#### Detailed Model Breakdown

1. **`User`**:
   - Primary key: `id` (UUID).
   - `email` (Unique, indexed).
   - `passwordHash` (Bcrypt hashed string, never plain text).
   - Profile fields: `name`, `phone`, `dateOfBirth`, `gender`, `profilePhoto`.
   - Has many `MedicalDocument` records and many `HealthMeasurement` records.

2. **`MedicalDocument`**:
   - Primary key: `id` (UUID).
   - Foreign key: `userId` (Links to `User`, cascade delete).
   - `fileName`: Generated unique storage name (e.g., `uuid.jpg`).
   - `originalName`: Human-readable filename (e.g., `Blood_Report_Oct2026.pdf`).
   - `fileType`: MIME type (`image/jpeg`, `image/png`, `application/pdf`).
   - `fileSize`: Size in bytes.
   - `storagePath`: Full URL or storage path.
   - `processingStatus`: Enum string (`UPLOADED` -> `PROCESSING` -> `COMPLETED` or `FAILED`).
   - `categoryId`: Optional foreign key to `MedicalCategory`.
   - `processingError`: Detailed diagnostic error message if OCR fails.

3. **`ExtractedText`**:
   - One-to-one relationship with `MedicalDocument` (`documentId` is unique).
   - `text`: Complete transcription generated by OCR (markdown format with preserved tables and headers).
   - `confidence`: Calculated confidence score (0.00 to 1.00).
   - `pageCount`: Number of pages (default 1 for images).

4. **`MedicalCategory`**:
   - Primary key: `id` (UUID).
   - `name`: Category name (e.g., `Blood Test`, `Prescription`, `Lab Report`, `Scan Report`, `Discharge Summary`, `Medical Bill`).
   - `icon`: Icon identifier for Flutter and React UI.
   - `description`: Clinical description.

5. **`DocumentTag`**:
   - Many-to-one with `MedicalDocument`.
   - Composite unique constraint `@@unique([documentId, tag])` to prevent duplicate tags on the same document.
   - Fast lookup index on `tag`.

6. **`HealthParameter`** (Master Biomarker Catalog):
   - Unique identifier `name`: e.g. `glucose`, `hemoglobin`, `systolic_bp`, `diastolic_bp`, `cholesterol`, `heart_rate`, `hba1c`, `creatinine`, `wbc`, `platelets`.
   - `displayName`: e.g. "Fasting Blood Glucose", "Hemoglobin".
   - `defaultUnit`: e.g. `mg/dL`, `g/dL`, `mmHg`, `bpm`.
   - `normalMin` and `normalMax`: Clinically standard physiological bounds (e.g., Hemoglobin normal range: 12.0 - 17.5 g/dL).

7. **`HealthMeasurement`** (Individual Patient Data Points):
   - Foreign keys: `userId`, `parameterId`, `documentId`.
   - `value`: Numerical measurement (Float, e.g., 14.2).
   - `unit`: Measurement unit (e.g., `g/dL`).
   - `measuredAt`: Timestamp of the test.
   - `confidence`: Confidence score of the extraction.
   - `isManualEntry`: Boolean flag (true if manually edited or entered by the user, false if automatically extracted via OCR).
   - `originalText`: Traceable raw text snippet (e.g., `"Hemoglobin: 14.2 g/dL"`), allowing doctors to verify the source text.

---

### 4.3 Authentication & Security System (JWT + Bcrypt)
- **Password Protection**: Passwords are encrypted using `bcrypt.hash(password, 12)`. 12 salt rounds provide strong resistance against brute-force attacks while maintaining fast response times on modern servers.
- **Token Generation**: Upon successful login or registration, the backend signs a JSON Web Token (JWT) with `jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '30d' })`.
- **Route Guarding**: The `authMiddleware` intercepts requests, extracts `Authorization: Bearer <token>`, verifies the signature, and attaches `req.userId` to the request.
- **Tenant Isolation**: Every query in `documents.ts`, `health.ts`, and `profile.ts` enforces `where: { userId: req.userId }` or verifies that `document.userId === req.userId`. Users can never view, edit, or delete another user's documents.

---

### 4.4 Cloud Storage Pipeline (`services/storage.ts`)
The storage service provides a dual-mode storage engine:
1. **Firebase Cloud Storage (Production)**:
   - Uses `firebase-admin/storage`.
   - Uploads file buffers directly to a secure Google Cloud Storage bucket.
   - Generates signed URLs or public download tokens for client viewing.
2. **Local Filesystem Fallback (Development)**:
   - If Firebase credentials are not configured, files are securely saved to `backend/uploads/` using unique UUID filenames (`uuidv4() + ext`).
   - Served statically via `express.static('/uploads')`.
   - Sanitizes filenames to prevent directory traversal attacks (`../`).

---

### 4.5 Multimodal AI OCR Engine (`services/ocr.ts`)
The OCR pipeline in MyHealthMitra is designed specifically for complex medical documents, which often suffer from poor lighting, crumpled paper, angled camera shots, and faint handwriting.

#### 1. Sharp Image Preprocessing Pipeline
Before sending the image to the AI vision model, it passes through an image enhancement pipeline:
```
Raw Image Buffer 
  ──► EXIF Auto-Rotation (sharp.rotate())
  ──► Resolution Optimization (Lanczos3 kernel: upscales low-res pen strokes, downsizes huge 4K images to 2500px)
  ──► Contrast Normalization (Gentle histogram stretching, avoiding destructive thresholding)
  ──► JPEG/PNG Encoding (Quality 90)
```
*Why this matters*: Medical prescriptions often use thin ballpoint or gel pen strokes. Standard binarization (converting to strict black & white) often destroys faint handwriting. Sharp's gentle contrast normalization preserves ink strokes while eliminating paper shadows.

#### 2. Gemini 3 Vision Transcriber
The preprocessed image is base64-encoded and sent to Google's Gemini Vision API with a clinical transcription prompt:
- **Verbatim Rule**: "Preserve reading order, headings, paragraphs, bullet points, numbering, punctuation, mathematical symbols, dates, numbers, and units."
- **Tables**: "Preserve tables using Markdown tables when their row and column structure is reasonably clear."
- **Clinical Honesty**: "Do not summarize, explain, correct, or rewrite the author's content. Do not invent missing words. If a word or passage cannot be read confidently, mark it as [unclear]."

#### 3. Automatic Model Fallback Ladder
In high-demand scenarios or cloud service spikes, the service automatically fails over through a priority ladder:
1. `gemini-3-flash-preview` (Primary fast vision model)
2. `gemini-3.5-flash`
3. `gemini-3.6-flash`
4. `gemini-3.1-flash-lite`

Each model is attempted with exponential backoff on transient 503 errors.

#### 4. Honest Confidence Scoring Algorithm
Instead of fabricating 99% accuracy, the OCR service inspects the resulting transcription:
- Counts the number of `[unclear]` tags in the text.
- Penalizes the confidence score: `confidence = 0.95 - (unclearCount * 0.08)`.
- If the extracted text is suspiciously short (< 30 characters), the confidence is capped at 0.60.
- Labels the status as `HIGH` (>= 0.85), `MEDIUM` (0.65 - 0.84), or `LOW_REVIEW_NEEDED` (< 0.65).

---

### 4.6 Smart Categorization & Tagging (`services/categorizer.ts`)
Once text is extracted, `categorizerService.categorize(text, originalFileName)` determines what kind of medical record it is:

1. **Clinical Anchor Verification**:
   The engine first looks for medical anchor keywords:
   `hospital`, `clinic`, `patient`, `doctor`, `physician`, `dr.`, `mbbs`, `pathology`, `prescription`, `diagnosis`, `symptoms`, `hemoglobin`, `glucose`.
   *Non-medical documents (like receipts, invoices, random notes) that lack clinical anchors are automatically classified as `General` or `Other`, preventing false alarms.*

2. **Weighted Scoring for 6 Clinical Categories**:
   - **Blood Test**: Matches `Complete Blood Count (CBC)`, `Hemoglobin`, `Platelets`, `WBC/RBC`, `Blood Sugar (FBS/PPBS)`, `Lipid Profile`, `HbA1c`, `LFT/KFT`.
   - **Lab Report**: Matches `Culture & Sensitivity`, `Urinalysis`, `Pathology Report`, `Microbiology`, `Biochemistry`.
   - **Prescription**: Matches `Rx`, `Tablets (tab)`, `Capsules (cap)`, `Syrup`, `mg/mcg/ml`, `once/twice daily`, `before/after food`.
   - **Scan Report**: Matches `X-Ray`, `MRI`, `CT Scan`, `Ultrasound (USG)`, `Radiology`.
   - **Discharge Summary**: Matches `Date of Admission (DOA)`, `Date of Discharge (DOD)`, `Chief Complaints`, `Diagnosis at Discharge`, `Course in Hospital`.
   - **Medical Bill**: Matches `Invoice`, `Bill No`, `Subtotal`, `Amount Paid`, `Consultation Fee`.

3. **Tag Generation**: Automatically attaches clean, relevant tags (e.g., `["Complete Blood Count", "Hemoglobin", "Platelets"]`).

---

### 4.7 Clinical Health Parameter Extraction (`services/paramExtractor.ts`)
The parameter extractor extracts numerical vitals from the unstructured OCR text.

#### Challenges Handled:
1. **OCR Noise Tolerance**: In poor scans, `"Blood"` often gets scanned as `"bl00d"`, `"Hemoglobin"` as `"h4emoglobin"`, or `"Glucose"` as `"gluo0se"`. The regex patterns tolerate common optical misrecognitions.
2. **Context Requirement**: Abbreviations like `"HR"` (Heart Rate) require a clinical unit (like `bpm` or `beats/min`) so they do not falsely trigger on words like "Human Resources".
3. **Plausible Physiological Boundaries**:
   If an OCR error reads `"Hemoglobin: 142 g/dL"` instead of `14.2 g/dL`, the system checks against the plausible clinical range (3.0 to 25.0 g/dL). If the value falls outside plausible biological bounds, it is discarded to prevent dangerous erroneous data from corrupting patient charts.

```typescript
// Sample Pattern Definition from paramExtractor.ts
{
  parameterName: 'glucose',
  patterns: [
    /\b(?:bl[o0]{2}d\s*)?(?:gl[uo]c[o0]se|sugar)\b[^0-9]{0,25}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])?/gi,
    /\b(?:FBS|RBS|PPBS|FPG)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(?:mg\s*\/?\s*d[lL1])/gi,
  ],
  unit: 'mg/dL',
  minPlausible: 30,
  maxPlausible: 600,
}
```

---

### 4.8 Complete REST API Reference

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/auth/register` | Public | Register new user (email, password, name) |
| `POST` | `/api/auth/login` | Public | Authenticate user & return JWT token |
| `GET` | `/api/auth/profile` | Bearer | Retrieve authenticated user profile |
| `PUT` | `/api/auth/profile` | Bearer | Update profile (name, phone, DOB, gender) |
| `POST` | `/api/documents/upload` | Bearer | Multipart upload of document (creates `UPLOADED` record) |
| `POST` | `/api/documents/:id/process` | Bearer | Triggers async OCR, categorizer & parameter pipeline |
| `GET` | `/api/documents` | Bearer | List user documents (paginated, filter by status/category) |
| `GET` | `/api/documents/:id` | Bearer | Get document details, OCR text & extracted measurements |
| `DELETE` | `/api/documents/:id` | Bearer | Delete document from storage and database |
| `GET` | `/api/health-params` | Bearer | List all trackable parameters with normal reference ranges |
| `GET` | `/api/health-params/summary` | Bearer | Latest value and status (NORMAL/HIGH/LOW) for each vital |
| `GET` | `/api/health-trends/:paramName`| Bearer | Time-series data points for plotting trend charts |
| `GET` | `/api/search` | Bearer | Full-text search across documents, categories, and tags |
| `POST` | `/ocr` | Public/Bearer | Standalone OCR transcription endpoint |

---

## 5. Flutter Mobile App Deep Dive (`flutter_app/`)

The mobile application is built using **Flutter 3.12+** and **Dart**, compiling natively to both **Android** and **iOS**.

### 5.1 Technology Stack & Architectural Pattern
- **Architectural Pattern**: Layered UI -> Provider (State) -> Service (Data/API) -> Model.
- **HTTP Client**: `Dio` with interceptors for automatic JWT header injection and global error handling.
- **Secure Token Storage**: `flutter_secure_storage` encrypts the JWT token inside Android Keystore / iOS Keychain.
- **Design System**: Material Design 3 with custom brand colors (`#00897B` Medical Teal, `#1E88E5` Clinical Blue), smooth rounded card geometry, and clean Inter typography.

---

### 5.2 State Management (`Provider`) & Routing (`go_router`)

#### State Providers
1. **`AuthProvider`**: Manages user login state, token persistence, and profile data. When the app boots, it reads the encrypted token from secure storage and automatically logs the user in if the token is valid.
2. **`DocumentProvider`**: Manages the list of documents, upload progress, OCR processing status polling, and active document detail views.
3. **`HealthProvider`**: Manages health parameters, latest biomarker cards, and time-series data for charting.

#### Declarative Routing (`config/router.dart`)
Uses `go_router` with declarative redirect logic:
- If a user is not authenticated and attempts to access `/home`, `/records`, or `/upload`, the router automatically redirects them to `/login`.
- If an authenticated user visits `/login` or `/signup`, they are automatically redirected to `/home`.

```dart
// Route Definitions
/splash           -> SplashScreen
/login            -> LoginScreen
/signup           -> SignupScreen
/home             -> MainShell(HomeScreen)
/records          -> MainShell(RecordsScreen)
/upload           -> MainShell(UploadScreen)
/trends           -> MainShell(HealthTrendsScreen)
/profile          -> MainShell(ProfileScreen)
/document/:id     -> DocumentDetailScreen
/health-params    -> HealthParamsScreen
/search           -> SearchScreen
```

---

### 5.3 Walkthrough of All 12 Screens

1. **`SplashScreen`**: Displays the animated MyHealthMitra logo, initializes dependencies, checks token validity, and transitions to `/home` or `/login`.
2. **`LoginScreen`**: Clean, accessible login form with email & password fields, validation, loading indicator, and "Create Account" link.
3. **`SignupScreen`**: Registration form collecting Name, Email, Password, and Confirmation with input validation.
4. **`HomeScreen`**: The central dashboard featuring:
   - Greeting & quick stats (Total Documents, Normal Vitals, Attention Needed).
   - Quick Action buttons: "Scan Document", "View Records", "Health Trends".
   - Recent Biomarkers preview carousel.
   - Recent Documents list.
5. **`RecordsScreen`**: The digital medical filing cabinet:
   - Filter chips: *All, Blood Test, Prescription, Lab Report, Scan Report, Discharge Summary*.
   - Search bar.
   - Document cards showing thumbnail, original title, category badge, upload date, and processing status chip.
6. **`UploadScreen`**:
   - Choice of Camera capture or Gallery selection.
   - Image preview with cropping and retake options.
   - Category pre-selection (or auto-detect).
   - Upload progress bar.
7. **`DocumentDetailScreen`**:
   - Full image/PDF viewer with zoom capability.
   - Tab 1: **Extracted Biomarkers** — Cards showing detected parameters (e.g. Glucose 110 mg/dL), status badge (NORMAL/HIGH/LOW), and ability to edit or add new measurements manually.
   - Tab 2: **OCR Transcription** — Full Markdown transcription with preserved tables and headers.
   - Metadata: Upload date, file size, category, and tags.
8. **`HealthParamsScreen`**:
   - Master list of all tracked biomarkers.
   - Shows current value, measurement date, and normal reference range (e.g., `12.0 - 17.5 g/dL`).
   - Color-coded status dots (Green = Normal, Orange = High, Blue = Low).
9. **`HealthTrendsScreen`**:
   - Dropdown to select parameter (e.g., Fasting Glucose).
   - Interactive line chart plotted over time using `fl_chart`.
   - Shaded horizontal band indicating the healthy reference range.
   - Touch tooltip showing exact date and value of historical readings.
10. **`SearchScreen`**: Real-time debounce search across document titles, OCR transcriptions, categories, and tags.
11. **`ProfileScreen`**: Displays user info, health summary statistics, app version, theme settings, and secure sign-out.
12. **`MainShell`**: Persistent bottom navigation bar wrapping Home, Records, Upload, Trends, and Profile.

---

### 5.4 Client-Side Gemini AI & Smart Offline Caching (`gemini_service.dart`)
In addition to the backend OCR pipeline, the Flutter app includes a direct client-side AI engine (`GeminiService`):
- **Direct Vision Analysis**: Can analyze a document photo directly on the client using the Gemini API.
- **Structured JSON Schema**: Prompts Gemini to return a structured JSON response containing category, tags, patient-friendly summary, and extracted biomarker values in a single pass.
- **Offline Resiliency (`medical_history_cache.dart`)**: Caches previous OCR responses and health parameters locally so users can access their medical records without an active internet connection.

---

## 6. React Web Frontend Deep Dive (`frontend/`)

The web frontend provides desktop users with an interface matching the mobile experience.

### 6.1 Architecture & Setup
- Built with **React 19** and **Vite**.
- Styled using vanilla and modern utility CSS (`index.css`), featuring glassmorphism, responsive navigation drawers, and accessible color schemes.
- Uses **Lucide React** for clinical icons.

### 6.2 Key Pages
- `HomeScreen.jsx`: Metric counters, recent uploads, and quick upload trigger.
- `UploadScreen.jsx`: Drag-and-drop file uploader supporting PNG, JPG, and PDF.
- `RecordsScreen.jsx`: Multi-column grid of document cards with live search and category filters.
- `DocumentDetailScreen.jsx`: Side-by-side view featuring document preview on the left and extracted OCR text / clinical biomarkers on the right.
- `HealthTrendsScreen.jsx`: SVG/Canvas interactive time-series charts showing biomarker trends.
- `HealthParamsScreen.jsx`: Metric cards displaying healthy reference ranges.

---

## 7. Custom Deep Learning OCR Subsystem (`ocr/`)

While Gemini Vision handles general cloud OCR, the project also contains an in-house **PyTorch Deep Learning OCR model** located in `ocr/`. This allows offline or on-premises deployment without external API dependencies.

### 7.1 What is CRNN (CNN + BiLSTM + CTC)?
CRNN is the gold standard neural network architecture for text recognition:
1. **CNN (Convolutional Neural Network)**: Extracts visual features from the image (edges, curves, stroke intersections).
2. **Map-to-Sequence**: Converts 2D spatial feature maps into a 1D sequential representation along the width of the text line.
3. **BiLSTM (Bidirectional Long Short-Term Memory)**: Recurrent neural network that reads the text sequence forward and backward, learning character context (e.g., in medical text, `'m'` is likely followed by `'g'`).
4. **CTC (Connectionist Temporal Classification) Loss**: Solves the alignment problem between input image slices and variable-length text strings without needing character-level bounding box annotations.

```
Input Image (1x32x100)
       │
       ▼
 ┌───────────┐
 │    CNN    │  (Conv2d + BatchNorm + ReLU + MaxPool)
 └─────┬─────┘
       │  Feature Map
       ▼
 ┌───────────┐
 │  BiLSTM   │  (2-layer Bidirectional LSTM, hidden size 256)
 └─────┬─────┘
       │  Sequential Predictions
       ▼
 ┌───────────┐
 │ CTC Loss  │  Decodes character probabilities into text string
 └───────────┘
```

---

### 7.2 Image Preprocessing & Region Detection (`ocr/src/preprocess.py`)
- **Deskewing**: Uses image moments or Hough line transforms to compute the document's skew angle and rotate it back to 0 degrees.
- **Grayscale & Adaptive Thresholding**: Normalizes varying page brightness.
- **Morphological Bounding**: Dilates horizontal text regions to segment lines and words into bounding boxes for recognition.

---

### 7.3 Training & Evaluation (`train.py`, `evaluate.py`)
- **CTC Greedy & Beam Search Decoding**: Converts raw model output tensors into human-readable text strings.
- **Metrics Tracked**:
  - **CER (Character Error Rate)**: Percentage of incorrect characters (insertions, deletions, substitutions).
  - **WER (Word Error Rate)**: Percentage of incorrectly predicted words.

---

## 8. End-to-End Life of a Document (Step-by-Step Flow)

Here is exactly what happens when a patient uploads a lab report:

```
[User takes photo of Blood Test]
               │
               ▼
   [Flutter App / Web Frontend]
   • User clicks "Upload"
   • Sends multipart POST /api/documents/upload
               │
               ▼
      [Node.js API Server]
   • Multer receives file buffer
   • storageService uploads to Firebase Cloud Storage (or local disk)
   • Prisma creates MedicalDocument with status: 'UPLOADED'
   • Immediately returns 201 Created to client with documentId
               │
               ▼
   [Async Processing Queue: POST /api/documents/:id/process]
   • Status updated to: 'PROCESSING'
   • Step 1: sharp loads image buffer -> auto-rotates -> normalizes contrast -> Lanczos3 upscale
   • Step 2: ocrService calls Gemini 3 Vision API -> returns verbatim transcription & confidence
   • Step 3: Prisma upserts ExtractedText (saving full text & confidence)
   • Step 4: categorizerService inspects text -> detects CBC/Hemoglobin patterns -> assigns "Blood Test"
   • Step 5: DocumentTag table populated with tags (e.g., "Complete Blood Count", "Hemoglobin")
   • Step 6: paramExtractorService applies medical regex:
             - Detects "Hemoglobin: 13.8 g/dL" -> Valid (in range 3-25)
             - Detects "Fasting Blood Sugar: 104 mg/dL" -> Valid (in range 30-600)
   • Step 7: Prisma creates HealthMeasurement records linked to user & document
   • Step 8: MedicalDocument status updated to: 'COMPLETED'
               │
               ▼
   [Client App Updates via Polling / Refetch]
   • Shows Green "Completed" badge
   • Document detail view displays formatted OCR text & parameter cards
   • Health Trends chart immediately includes new data points!
```

---

## 9. Tracked Clinical Biomarkers & Reference Ranges

The system tracks 10 core health parameters seeded via `backend/prisma/seed.ts`:

| Parameter Key | Display Name | Unit | Normal Min | Normal Max | Clinical Significance |
|---|---|---|---|---|---|
| `glucose` | Fasting Blood Sugar | mg/dL | 70.0 | 99.0 | Diabetes screening & glycemic control |
| `hemoglobin` | Hemoglobin | g/dL | 12.0 | 17.5 | Oxygen-carrying capacity, anemia screening |
| `systolic_bp` | Systolic Blood Pressure | mmHg | 90.0 | 120.0 | Peak arterial pressure during heartbeat |
| `diastolic_bp` | Diastolic Blood Pressure | mmHg | 60.0 | 80.0 | Resting arterial pressure between beats |
| `cholesterol` | Total Cholesterol | mg/dL | 125.0 | 200.0 | Cardiovascular risk assessment |
| `heart_rate` | Resting Heart Rate | bpm | 60.0 | 100.0 | Cardiac rhythm & fitness evaluation |
| `hba1c` | Glycated Hemoglobin | % | 4.0 | 5.6 | 3-month average blood glucose |
| `creatinine` | Serum Creatinine | mg/dL | 0.6 | 1.2 | Kidney filtration efficiency |
| `wbc` | Total WBC Count | cells/µL | 4,000 | 11,000 | Immune response & infection detection |
| `platelets` | Platelet Count | lakh/µL | 1.5 | 4.5 | Blood clotting & coagulation ability |

---

## 10. Local Development & Setup Guide

### Prerequisites
- Node.js v18+ and npm
- Flutter SDK v3.12+ and Dart
- PostgreSQL instance (or free Supabase project)
- Google Gemini API Key

---

### Step 1: Backend Setup
```bash
# Navigate to backend directory
cd medical/backend

# Install dependencies
npm install

# Create .env file from template
cp .env.example .env
```

Edit `.env` with your values:
```env
PORT=5000
NODE_ENV=development
DATABASE_URL="postgresql://postgres:YOUR_PASSWORD@db.YOUR_SUPABASE.supabase.co:5432/postgres?sslmode=require"
DIRECT_URL="postgresql://postgres:YOUR_PASSWORD@db.YOUR_SUPABASE.supabase.co:5432/postgres?sslmode=require"
JWT_SECRET="your-super-secret-jwt-key-min-32-chars"
GEMINI_API_KEY="your-google-gemini-api-key"
```

Initialize the database:
```bash
# Push schema to database
npx prisma db push

# Seed categories and 10 default health parameters
npx prisma db seed

# Start development server
npm run dev
```
The backend will be running at `http://localhost:5000`.

---

### Step 2: Flutter App Setup
```bash
# Navigate to flutter directory
cd ../flutter_app

# Fetch Flutter packages
flutter pub get

# Verify connected devices
flutter devices

# Run on Chrome (Web)
flutter run -d chrome

# Or run on Android Emulator / USB Device
flutter run -d android
```

---

### Step 3: React Web Frontend Setup
```bash
# Navigate to frontend directory
cd ../frontend

# Install packages
npm install

# Start Vite dev server
npm run dev
```
The web dashboard will be accessible at `http://localhost:5173`.

---

### Step 4: Python OCR Setup (Optional / Advanced)
```bash
cd ../ocr
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt # PyTorch, torchvision, opencv-python, pyyaml
python src/medical_ocr_pipeline.py
```

---

## 11. Production Deployment & Building APKs

### 1. Building the Android Release APK
To compile an Android APK for distribution:
```bash
cd medical/flutter_app

# Build universal release APK
flutter build apk --release

# Or build optimized split-per-ABI APKs (smaller file size)
flutter build apk --split-per-abi --release
```
The compiled APK will be output to:
`flutter_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

### 2. Deploying Backend to Render
1. Create a **Web Service** on [Render.com](https://render.com).
2. Connect your GitHub repository.
3. Root Directory: `backend`
4. Build Command: `npm install && npx prisma generate && npm run build`
5. Start Command: `node dist/index.js`
6. Add Environment Variables: `DATABASE_URL`, `JWT_SECRET`, `GEMINI_API_KEY`.

---

## 12. Troubleshooting, Gotchas & FAQ

### Q1: Git complains about "fatal: .git/index: index file smaller than expected" or lock files
**Cause**: Git index became corrupted or locked during an interrupted operation.
**Fix**:
```bash
rm -f .git/index.lock
rm -f .git/index
git reset
```

### Q2: OCR returns "LOW_REVIEW_NEEDED" or low confidence
**Cause**: The uploaded photo is blurry, has severe glare, or has dark shadows.
**Fix**:
1. Sharp will auto-orient and contrast-normalize, but good lighting is critical.
2. The user can review the extracted text and edit the numerical values directly in `DocumentDetailScreen`.

### Q3: Why use Gemini Vision instead of only local Tesseract.js?
**Explanation**:
- Traditional Tesseract OCR fails on complex document layouts, multi-column lab reports, medical terminology, and cursive handwriting.
- Gemini 3 Vision understands the *semantic meaning* of medical documents, correctly reading tables, doctor signatures, and handwritten prescription dosages.
- The project maintains `ocr/` (PyTorch CRNN) as an optional local alternative.

### Q4: Are user medical documents private?
**Yes**:
- Every database query enforces tenant isolation (`where: { userId }`).
- Direct access to document IDs belonging to another user results in an immediate `403 Forbidden` error.

---

*This guide covers the complete architecture, data models, and implementation details of MyHealthMitra. Keep this document updated as you add new features!*
