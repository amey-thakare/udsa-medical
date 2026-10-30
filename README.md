# 🏥 MyHealthMitra — Smart Medical Record Management System

> **An intelligent mobile application that digitizes, organizes, and analyzes medical records using OCR-powered text extraction, automated health parameter detection, and interactive health trend visualization.**

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Key Features](#-key-features)
3. [System Architecture](#-system-architecture)
4. [Technology Stack](#-technology-stack)
5. [Project Structure](#-project-structure)
6. [Backend — Deep Dive](#-backend--deep-dive)
   - [Server Setup](#server-setup-indexts)
   - [Database Schema (Prisma + PostgreSQL)](#database-schema-prisma--postgresql)
   - [Authentication System](#authentication-system-jwt)
   - [API Endpoints](#api-endpoints)
   - [OCR Pipeline](#ocr-pipeline)
   - [Health Parameter Extraction](#health-parameter-extraction)
   - [Smart Document Categorization](#smart-document-categorization)
   - [File Storage (Firebase Cloud Storage)](#file-storage-firebase-cloud-storage)
7. [Flutter Mobile App — Deep Dive](#-flutter-mobile-app--deep-dive)
   - [App Entry Point](#app-entry-point)
   - [State Management](#state-management-provider)
   - [Routing & Navigation](#routing--navigation-gorouter)
   - [Screens](#screens-12-total)
   - [Services Layer](#services-layer)
   - [Models](#data-models)
   - [Custom Theme](#custom-theme)
   - [Reusable Widgets](#reusable-widgets)
8. [Data Flow — End to End](#-data-flow--end-to-end)
9. [Database ER Diagram](#-database-er-diagram)
10. [Deployment Architecture](#-deployment-architecture)
11. [Setup & Installation](#-setup--installation)
12. [Running Locally](#-running-locally)
13. [Building the APK](#-building-the-apk)
14. [Environment Variables](#-environment-variables)
15. [Health Parameters Tracked](#-health-parameters-tracked)
16. [Security Measures](#-security-measures)
17. [Future Scope](#-future-scope)
18. [License](#-license)

---

## 📖 Project Overview

**MyHealthMitra** is a full-stack mobile health application that allows users to:

- **Upload** photos or scans of their medical reports (lab tests, prescriptions, discharge summaries, etc.)
- **Automatically extract text** from those documents using OCR (Optical Character Recognition)
- **Automatically detect and extract health parameters** (like blood glucose, hemoglobin, blood pressure, cholesterol, etc.) from the extracted text
- **Track health trends over time** with interactive graphs
- **Search, categorize, and tag** medical records for easy retrieval
- **Maintain a personal health parameter database** with normal range indicators

The system uses a **client-server architecture** with a **Flutter mobile app** as the frontend and a **Node.js/Express** API server as the backend, backed by **PostgreSQL** (via Supabase) for the database and **Firebase Cloud Storage** for file storage.

---

## ✅ Key Features

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| 1 | **User Authentication** | ✅ Working | Email/password signup and login with JWT tokens |
| 2 | **User Profile** | ✅ Working | View/edit name, phone, DOB, gender, profile photo |
| 3 | **Upload Medical Document** | ✅ Working | Camera capture or gallery pick (JPG, PNG, PDF) |
| 4 | **OCR Processing** | ✅ Working | Tesseract.js with Sharp image preprocessing |
| 5 | **Text Extraction** | ✅ Working | Full text extraction with confidence scoring |
| 6 | **Health Parameter Extraction** | ✅ Working | Extracts 10 health parameters with OCR-tolerant regex |
| 7 | **Store Extracted Information** | ✅ Working | All data persisted in PostgreSQL via Prisma ORM |
| 8 | **Display Uploaded Reports** | ✅ Working | List view with category, tags, processing status |
| 9 | **Search Medical Records** | ✅ Working | Full-text search across documents, tags, categories |
| 10 | **Smart Categorization/Tagging** | ✅ Working | Auto-categorizes into Blood Test, Prescription, Scan Report, etc. |
| 11 | **Health Parameter Database** | ✅ Working | 10 parameters with normal ranges and latest values |
| 12 | **Graphical Health Trends** | ✅ Working | Interactive line charts with normal range bands (fl_chart) |
| 13 | **Cloud Database/Storage** | ✅ Working | PostgreSQL on Supabase + Firebase Cloud Storage |
| 14 | **Basic Security/Authentication** | ✅ Working | JWT auth, bcrypt password hashing, route protection |
| 15 | **Clean Mobile UI** | ✅ Working | Material Design 3 with Google Fonts (Inter), custom theme |

---

## 🏗 System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT (Flutter App)                        │
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────────┐  │
│  │  Screens  │  │ Providers│  │ Services │  │      Widgets       │  │
│  │ (12 UI    │  │ (State   │  │ (API     │  │ (Reusable UI       │  │
│  │  pages)   │  │  Mgmt)   │  │  Calls)  │  │  Components)       │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────────────────┘  │
│       │              │              │                                │
│       └──────────────┴──────┬───────┘                                │
│                             │ HTTP (Dio)                             │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   REST API Layer   │
                    │  (Express.js +     │
                    │   TypeScript)      │
                    └────────┬──────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
  ┌───────▼──────┐  ┌───────▼───────┐  ┌───────▼───────┐
  │  OCR Engine  │  │   Database    │  │  File Storage │
  │              │  │               │  │               │
  │ Tesseract.js │  │  PostgreSQL   │  │   Firebase    │
  │   + Sharp    │  │  (Supabase)   │  │    Cloud      │
  │              │  │  via Prisma   │  │   Storage     │
  └──────┬───────┘  └───────────────┘  └───────────────┘
         │
  ┌──────▼───────┐  ┌───────────────┐
  │  Parameter   │  │  Categorizer  │
  │  Extractor   │  │  & Tagger     │
  │ (Regex NLP)  │  │ (Rule-based)  │
  └──────────────┘  └───────────────┘
```

---

## 🛠 Technology Stack

### Backend

| Technology | Version | Purpose |
|-----------|---------|---------|
| **Node.js** | v18+ | JavaScript runtime |
| **Express.js** | v5.1.0 | Web framework for REST API |
| **TypeScript** | v5.8.0 | Type-safe JavaScript |
| **Prisma ORM** | v6.9.0 | Database ORM & migrations |
| **PostgreSQL** | - | Relational database (hosted on Supabase) |
| **Tesseract.js** | v6.0.1 | OCR engine (LSTM-based deep learning) |
| **Sharp** | v0.35.4 | Image preprocessing (grayscale, sharpening, contrast normalization) |
| **bcrypt.js** | v3.0.2 | Password hashing (12 salt rounds) |
| **jsonwebtoken** | v9.0.2 | JWT token generation & verification |
| **Zod** | v3.25.67 | Request body validation schemas |
| **Multer** | v2.0.0 | Multipart file upload handling |
| **Firebase Admin** | v14.4.0 | Firebase Cloud Storage integration |
| **tsx** | v4.19.0 | TypeScript execution (dev server) |
| **dotenv** | v16.5.0 | Environment variable management |

### Frontend (Flutter Mobile App)

| Technology | Version | Purpose |
|-----------|---------|---------|
| **Flutter** | v3.12+ | Cross-platform mobile framework |
| **Dart** | v3.12+ | Programming language |
| **Dio** | v5.7.0 | HTTP client with interceptors |
| **Provider** | v6.1.2 | State management |
| **GoRouter** | v14.8.1 | Declarative routing with auth guards |
| **fl_chart** | v0.70.2 | Interactive health trend charts |
| **image_picker** | v1.1.2 | Camera & gallery image selection |
| **file_picker** | v8.1.7 | Document file selection |
| **flutter_secure_storage** | v9.2.4 | Encrypted JWT token storage |
| **Google Fonts** | v6.2.1 | Inter font family |
| **cached_network_image** | v3.4.1 | Image caching and loading |
| **Lucide Icons** | v0.257.0 | Modern icon set |
| **intl** | v0.19.0 | Date/time formatting |
| **mime** | v2.0.0 | MIME type detection |

### Cloud & Infrastructure

| Service | Purpose |
|---------|---------|
| **Supabase** | Managed PostgreSQL database (ap-south-1 region) |
| **Firebase Cloud Storage** | Medical document file storage |
| **Render** | Backend deployment (Node.js web service) |
| **GitHub** | Version control & CI/CD |

---

## 📁 Project Structure

```
medical/
├── README.md                    # This file
├── .gitignore
│
├── backend/                     # Node.js + Express + TypeScript API
│   ├── .env                     # Environment variables (local)
│   ├── .env.example             # Template for env variables
│   ├── package.json             # NPM dependencies & scripts
│   ├── tsconfig.json            # TypeScript configuration
│   ├── render.yaml              # Render deployment configuration
│   ├── eng.traineddata          # Tesseract English language model (~5MB)
│   ├── prisma/
│   │   ├── schema.prisma        # Database schema definition
│   │   ├── seed.ts              # Database seeding script
│   │   └── migrations/          # Auto-generated DB migrations
│   └── src/
│       ├── index.ts             # Express server entry point
│       ├── config/
│       │   ├── env.ts           # Environment configuration
│       │   └── firebase.ts      # Firebase Admin SDK initialization
│       ├── controllers/
│       │   ├── auth.ts          # Register, login, me, logout
│       │   ├── documents.ts     # Upload, list, get, delete, process
│       │   ├── health.ts        # Parameters, measurements, trends
│       │   ├── ocrController.ts # OCR processing endpoint
│       │   ├── profile.ts       # User profile management
│       │   └── search.ts        # Full-text document search
│       ├── middleware/
│       │   ├── auth.ts          # JWT authentication middleware
│       │   ├── upload.ts        # Multer file upload middleware
│       │   └── validate.ts      # Request validation middleware
│       ├── routes/
│       │   ├── auth.ts          # /api/auth/*
│       │   ├── documents.ts     # /api/documents/*
│       │   ├── healthParams.ts  # /api/health-parameters/*
│       │   ├── healthTrends.ts  # /api/health-trends/*
│       │   ├── categories.ts    # /api/categories/*
│       │   ├── ocr.ts           # /api/ocr/*
│       │   ├── profile.ts       # /api/profile/*
│       │   └── search.ts        # /api/search/*
│       ├── services/
│       │   ├── ocr.ts           # Tesseract OCR + Sharp preprocessing
│       │   ├── paramExtractor.ts # Health parameter regex extraction
│       │   ├── categorizer.ts   # Document categorization engine
│       │   └── storage.ts       # Firebase Storage file manager
│       └── utils/
│           └── errors.ts        # Custom error classes
│
├── flutter_app/                 # Flutter Mobile Application
│   ├── pubspec.yaml             # Flutter dependencies
│   ├── assets/
│   │   ├── app_logo.png         # App launcher icon
│   │   └── images/              # Static image assets
│   └── lib/
│       ├── main.dart            # App entry point
│       ├── config/
│       │   ├── api_config.dart  # Backend URL configuration
│       │   └── router.dart      # GoRouter route definitions
│       ├── models/
│       │   ├── user.dart        # User data model
│       │   ├── document.dart    # Medical document model
│       │   ├── health_parameter.dart  # Health parameter model
│       │   └── category.dart    # Category model
│       ├── providers/
│       │   └── auth_provider.dart # Authentication state (ChangeNotifier)
│       ├── screens/
│       │   ├── splash_screen.dart        # Loading/splash screen
│       │   ├── login_screen.dart         # Email/password login
│       │   ├── signup_screen.dart        # Registration form
│       │   ├── main_shell.dart           # Bottom navigation shell
│       │   ├── home_screen.dart          # Dashboard with stats
│       │   ├── records_screen.dart       # Document list + filters
│       │   ├── upload_screen.dart        # Camera/gallery upload + process
│       │   ├── document_detail_screen.dart # Document view + extracted data
│       │   ├── search_screen.dart        # Full-text search
│       │   ├── health_params_screen.dart # Health parameter cards
│       │   ├── health_trends_screen.dart # Interactive trend charts
│       │   └── profile_screen.dart       # User profile management
│       ├── services/
│       │   ├── api_client.dart       # Dio HTTP client with JWT interceptor
│       │   ├── auth_service.dart     # Auth API calls
│       │   ├── document_service.dart # Document API calls
│       │   ├── health_service.dart   # Health parameter API calls
│       │   ├── profile_service.dart  # Profile API calls
│       │   └── search_service.dart   # Search API calls
│       ├── theme/
│       │   └── app_theme.dart    # Material 3 custom theme
│       └── widgets/
│           ├── document_list_item.dart   # Document card widget
│           ├── loading_indicator.dart    # Shimmer loading
│           ├── param_card.dart           # Health parameter card
│           ├── stat_card.dart            # Dashboard stat card
│           └── status_badge.dart         # Processing status badge
│
├── dataset/                     # OCR training dataset (pre-downloaded)
├── docs/                        # Project documentation
├── frontend/                    # React web frontend (legacy)
└── ocr/                         # OCR training scripts (legacy)
```

---

## ⚙️ Backend — Deep Dive

### Server Setup (`index.ts`)

The Express server initializes with the following middleware chain:

```
Request → CORS → JSON Parser → URL Parser → Route Matching → Controller → Response
                                                    ↓ (if error)
                                             Error Handler → Error Response
```

- **CORS**: Configured to allow all origins (`*`) with full HTTP method support
- **Body Parsing**: JSON payloads up to 10MB (for base64-encoded images)
- **Static Files**: Uploaded files served from `/uploads` directory
- **Port**: 10000 (configurable via `PORT` env var)

### Database Schema (Prisma + PostgreSQL)

The application uses **6 database tables** with the following relationships:

#### Tables

| Table | Description | Key Fields |
|-------|-------------|------------|
| `User` | User accounts | id, email, passwordHash, name, phone, dateOfBirth, gender, profilePhoto |
| `MedicalDocument` | Uploaded documents | id, userId, fileName, originalName, fileType, fileSize, storagePath, processingStatus, categoryId |
| `ExtractedText` | OCR results | id, documentId, text, pageCount, confidence |
| `MedicalCategory` | Document categories | id, name, description, icon |
| `DocumentTag` | Auto-generated tags | id, documentId, tag |
| `HealthParameter` | Parameter definitions | id, name, displayName, defaultUnit, normalMin, normalMax |
| `HealthMeasurement` | Extracted values | id, userId, parameterId, documentId, value, unit, measuredAt, confidence, isManualEntry, originalText |

#### Relationships

```
User ──(1:N)──→ MedicalDocument ──(1:1)──→ ExtractedText
  │                    │
  │                    ├──(N:1)──→ MedicalCategory
  │                    │
  │                    ├──(1:N)──→ DocumentTag
  │                    │
  │                    └──(1:N)──→ HealthMeasurement ──(N:1)──→ HealthParameter
  │
  └──(1:N)──→ HealthMeasurement
```

#### Indexes

Optimized indexes are placed on:
- `User.email` — fast login lookups
- `MedicalDocument.userId` — user's document list
- `MedicalDocument.processingStatus` — filter by status
- `MedicalDocument.categoryId` — filter by category
- `MedicalDocument.uploadedAt` — sorting by date
- `DocumentTag.tag` — tag-based search
- `HealthMeasurement.userId` — user's measurements
- `HealthMeasurement.parameterId` — parameter lookups
- `HealthMeasurement.measuredAt` — chronological ordering
- `HealthMeasurement.(userId, parameterId)` — composite for trend queries

### Authentication System (JWT)

```
                    ┌──────────────┐
                    │   Register   │
                    │              │
   Email + Password ──→ Zod Validate
                    │              │
                    │  Hash (bcrypt, 12 rounds)
                    │              │
                    │  Create User in DB
                    │              │
                    │  Generate JWT (7d expiry)
                    │              │
                    └──→ Return { token, user }
                    
                    ┌──────────────┐
                    │    Login     │
                    │              │
   Email + Password ──→ Find user by email
                    │              │
                    │  bcrypt.compare(password, hash)
                    │              │
                    │  Generate JWT
                    │              │
                    └──→ Return { token, user }

                    ┌──────────────┐
                    │  Auth Guard  │
                    │  (Middleware) │
                    │              │
   Authorization: Bearer <token>
                    │              │
                    │  jwt.verify(token, secret)
                    │              │
                    │  req.userId = decoded.userId
                    │              │
                    └──→ next()
```

**Password Security:**
- Hashed with **bcrypt** using **12 salt rounds** (computationally expensive)
- Raw passwords are never stored or logged

**Token Security:**
- JWT signed with `JWT_SECRET` environment variable
- Tokens expire after **7 days** (`JWT_EXPIRES_IN=7d`)
- On the Flutter side, tokens are stored in **flutter_secure_storage** (encrypted platform keychain)
- `401 Unauthorized` automatically triggers logout on the client

### API Endpoints

#### Authentication (`/api/auth`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register` | ❌ | Create new account |
| POST | `/api/auth/login` | ❌ | Login and get JWT |
| GET | `/api/auth/me` | ✅ | Get current user info |
| POST | `/api/auth/logout` | ✅ | Logout (client-side token discard) |

#### Documents (`/api/documents`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/documents/upload` | ✅ | Upload a medical document (multipart/form-data) |
| GET | `/api/documents` | ✅ | List user's documents (paginated, filterable) |
| GET | `/api/documents/:id` | ✅ | Get single document with full details |
| DELETE | `/api/documents/:id` | ✅ | Delete document + file + related data |
| POST | `/api/documents/:id/process` | ✅ | Trigger OCR processing pipeline |
| GET | `/api/documents/:id/text` | ✅ | Get extracted text for a document |
| PATCH | `/api/documents/:id/category` | ✅ | Update document category |

#### Health Parameters (`/api/health-parameters`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/health-parameters` | ✅ | Get all parameters with latest values |
| GET | `/api/health-parameters/:type/measurements` | ✅ | Get all measurements for a parameter |
| PUT | `/api/health-parameters/measurements/:id/correct` | ✅ | Correct an OCR-extracted value |

#### Health Trends (`/api/health-trends`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/health-trends/:parameter` | ✅ | Get trend data for charting |

#### Other Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/api/search?q=<query>` | ✅ | Full-text search across documents |
| GET | `/api/categories` | ✅ | List all medical categories |
| GET | `/api/profile` | ✅ | Get user profile |
| PUT | `/api/profile` | ✅ | Update user profile |
| GET | `/api/health` | ❌ | Server health check |

### OCR Pipeline

The OCR (Optical Character Recognition) pipeline consists of two stages:

#### Stage 1: Image Preprocessing (Sharp)

```
Raw Phone Photo → Grayscale → Upscale (≥2000px wide) → Sharpen → Normalize Contrast → Linear Stretch → Clean PNG
```

| Step | Library | What It Does | Why |
|------|---------|-------------|-----|
| 1 | `sharp.grayscale()` | Convert to grayscale | Removes color noise, focuses on text |
| 2 | `sharp.resize()` | Upscale to ≥2000px wide (Lanczos3) | Small images have blurry characters |
| 3 | `sharp.sharpen({sigma: 1.5})` | Enhance text edges | OCR needs crisp letter boundaries |
| 4 | `sharp.normalize()` | Stretch histogram to full range | Maximizes contrast between text and background |
| 5 | `sharp.linear(1.5, -64)` | Linear contrast stretch | Makes darks darker, lights lighter |
| 6 | `sharp.png()` | Output as lossless PNG | No JPEG compression artifacts for OCR |

#### Stage 2: Text Recognition (Tesseract.js)

- **Engine**: Tesseract LSTM (Long Short-Term Memory neural network)
- **Language Model**: `eng.traineddata` (~5MB pre-trained English model)
- **Output**: Full extracted text + confidence score (0-100%)
- **Supported formats**: JPG, JPEG, PNG, BMP, TIFF, WebP, PDF

### Health Parameter Extraction

The `paramExtractor.ts` service uses **OCR-tolerant regular expressions** to extract structured health data from raw OCR text.

#### Supported Parameters (10 total)

| Parameter | Example Match | Unit | Normal Range |
|-----------|--------------|------|-------------|
| Blood Glucose | `Blood Sugar: 92 mg/dL` | mg/dL | 70–100 |
| Hemoglobin | `Hb: 14.2 g/dL` | g/dL | 12–17.5 |
| Systolic BP | `BP: 120/80 mmHg` | mmHg | 90–120 |
| Diastolic BP | `BP: 120/80 mmHg` | mmHg | 60–80 |
| Total Cholesterol | `Cholesterol: 185 mg/dL` | mg/dL | 0–200 |
| Heart Rate | `Pulse: 72 bpm` | bpm | 60–100 |
| HbA1c | `HbA1c: 5.4%` | % | 4–5.6 |
| Creatinine | `Creatinine: 0.9 mg/dL` | mg/dL | 0.7–1.3 |
| WBC Count | `WBC: 7500 cells/mcL` | cells/mcL | 4500–11000 |
| Platelets | `Platelets: 250000` | cells/mcL | 150000–400000 |

#### OCR Error Tolerance

The regex patterns are specifically designed to handle common OCR misreadings:

| OCR Confusion | Example | Pattern Solution |
|--------------|---------|-----------------|
| `0` ↔ `O` | "Bl00d" for "Blood" | `[oO0]` character class |
| `l` ↔ `1` ↔ `I` | "Hemog1obin" | `[il1I]` character class |
| Spacing issues | "B lood Sugar" | `\s*` flexible whitespace |
| Missing colons | "Glucose 92" vs "Glucose: 92" | `[^0-9]{0,15}?` flexible separator |
| Typos | "Hemeglobin" | Multiple spelling patterns |

#### Text Normalization

Before regex matching, the raw OCR text undergoes normalization:
- Standardize whitespace and line breaks
- Fix common OCR artifacts (double spaces, stray characters)
- Normalize punctuation

#### Confidence Scoring

Each extracted parameter receives a confidence score (0.0–1.0):
- **0.95**: Exact keyword match with clear numeric value
- **0.90**: Match with minor OCR variations
- **0.70**: Fuzzy/partial match

#### Plausibility Filtering

Every extracted value is checked against medically plausible ranges to reject false positives:
- Glucose: 30–600 mg/dL
- Hemoglobin: 3–25 g/dL
- Blood Pressure: 60–250 / 30–160 mmHg
- Heart Rate: 20–300 bpm
- etc.

### Smart Document Categorization

The `categorizer.ts` service automatically classifies documents into **7 categories** using weighted keyword scoring:

| Category | Example Keywords | Weight |
|----------|-----------------|--------|
| 🩸 Blood Test | hemoglobin, glucose, CBC, lipid profile, hba1c | 1.0 |
| 🔬 Lab Report | laboratory, pathology, specimen, reference range | 0.9 |
| 💊 Prescription | Rx, tablet, capsule, dosage, medication | 1.0 |
| 📷 Scan Report | X-ray, MRI, CT scan, ultrasound, ECG | 1.0 |
| 🏥 Discharge Summary | discharge, admission, ward, follow up | 1.0 |
| 💰 Medical Bill | bill, invoice, charges, insurance, claim | 0.9 |
| 📋 General | (fallback category) | - |

**How It Works:**
1. Combine OCR text + filename into a single search string
2. For each category, count how many keywords match
3. Multiply match count by category weight
4. Highest-scoring category wins
5. Matched keywords (up to 5 per category) become document tags
6. Confidence = min(score / 3, 1.0)

### File Storage (Firebase Cloud Storage)

The `storage.ts` service provides a **hybrid storage layer**:

| Mode | Condition | Storage Location |
|------|-----------|-----------------|
| **Cloud** | Firebase Admin SDK initialized | Firebase Cloud Storage bucket |
| **Local** | No Firebase (dev mode) | `./uploads/` directory |

**File Operations:**
- `uploadBuffer(buffer, originalName, mimeType)` → Generates UUID filename, uploads to cloud
- `getFileBuffer(fileName)` → Downloads file for OCR processing
- `getFileUrl(fileName)` → Returns public URL for frontend display
- `deleteFile(fileName)` → Removes file from storage
- `fileExists(fileName)` → Checks if file exists

---

## 📱 Flutter Mobile App — Deep Dive

### App Entry Point

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedRecordApp());
}
```

The app bootstraps with:
1. `ChangeNotifierProvider` wrapping `AuthProvider` (global auth state)
2. `MaterialApp.router` with custom theme and GoRouter
3. Auto-wiring of `ApiClient.onUnauthorized` callback → triggers logout on 401

### State Management (Provider)

**Architecture**: `ChangeNotifier` + `Provider` pattern

```
AuthProvider (ChangeNotifier)
├── isAuthenticated: bool
├── token: String?
├── user: User?
├── loading: bool
├── login(email, password)
├── register(email, password, name)
├── logout()
└── checkAuth() — reads stored token on app start
```

Token persistence uses `flutter_secure_storage` which stores the JWT in:
- **Android**: EncryptedSharedPreferences (AES)
- **iOS**: Keychain

### Routing & Navigation (GoRouter)

The app uses **declarative routing** with authentication guards:

```
/                    → SplashScreen (loading)
/login               → LoginScreen
/signup              → SignupScreen

Shell (Bottom Nav):
  /home              → HomeScreen (dashboard)
  /records           → RecordsScreen (document list)
  /health            → HealthParamsScreen (parameter cards)
  /profile           → ProfileScreen

Standalone:
  /upload            → UploadScreen
  /search            → SearchScreen
  /documents/:id     → DocumentDetailScreen
  /trends/:parameter → HealthTrendsScreen
```

**Route Guards:**
- Unauthenticated users → redirect to `/login`
- Authenticated users on auth routes → redirect to `/home`
- Loading state → show splash screen
- `refreshListenable: authProvider` — re-evaluates on auth state change

### Screens (12 Total)

| Screen | File | Description |
|--------|------|-------------|
| **Splash** | `splash_screen.dart` | Animated loading while checking auth state |
| **Login** | `login_screen.dart` | Email/password form with validation |
| **Signup** | `signup_screen.dart` | Registration form (name, email, password) |
| **Home** | `home_screen.dart` | Dashboard with document stats, quick actions |
| **Records** | `records_screen.dart` | Paginated document list with category filters |
| **Upload** | `upload_screen.dart` | Camera/gallery picker → upload → process → view results |
| **Document Detail** | `document_detail_screen.dart` | Full document view, extracted text, parameters, tags |
| **Search** | `search_screen.dart` | Real-time search with highlighted snippets |
| **Health Params** | `health_params_screen.dart` | Grid of health parameter cards with latest values |
| **Health Trends** | `health_trends_screen.dart` | Interactive line charts with normal range bands |
| **Profile** | `profile_screen.dart` | Edit name, phone, DOB, gender, profile photo |
| **Main Shell** | `main_shell.dart` | Bottom navigation bar (Home, Records, Health, Profile) |

### Services Layer

The services layer abstracts all API communication using **Dio** HTTP client:

| Service | Methods |
|---------|---------|
| `ApiClient` | Singleton Dio instance with JWT interceptor, base URL config |
| `AuthService` | `register()`, `login()`, `getMe()` |
| `DocumentService` | `upload()`, `getAll()`, `getOne()`, `delete()`, `process()`, `getText()` |
| `HealthService` | `getParameters()`, `getMeasurements()`, `getTrends()` |
| `SearchService` | `search(query)` |
| `ProfileService` | `getProfile()`, `updateProfile()` |

**ApiClient Features:**
- Automatic `Authorization: Bearer <token>` header injection
- Configurable connect timeout (15s) and receive timeout (30s)
- Max upload file size: 10MB
- Automatic logout on 401 responses

### Data Models

| Model | Key Fields |
|-------|------------|
| `User` | id, email, name, phone, dateOfBirth, gender, profilePhoto |
| `Document` | id, originalName, fileType, fileSize, storagePath, processingStatus, category, tags, extractedText, healthMeasurements |
| `HealthParameter` | id, name, displayName, defaultUnit, normalMin, normalMax, latestMeasurement, measurementCount |
| `Category` | id, name, description, icon |

### Custom Theme

The app uses a carefully crafted **Material Design 3** theme:

- **Primary**: `#2563EB` (Professional Blue)
- **Secondary**: `#0891B2` (Teal)
- **Accent**: `#7C3AED` (Purple)
- **Success/Warning/Danger**: Semantic color palette
- **Font**: Google Fonts **Inter** (clean, modern, readable)
- **Radii**: 8px (small), 12px (default), 16px (large)
- **Cards**: White with subtle border, no elevation
- **Buttons**: Rounded, no shadow, bold text

### Reusable Widgets

| Widget | Purpose |
|--------|---------|
| `DocumentListItem` | Card displaying document name, category, tags, status |
| `LoadingIndicator` | Shimmer/skeleton loading animation |
| `ParamCard` | Health parameter card with value, unit, normal range indicator |
| `StatCard` | Dashboard statistic card (icon + number + label) |
| `StatusBadge` | Processing status chip (Uploaded, Processing, Completed, Failed) |

---

## 🔄 Data Flow — End to End

Here is the complete flow when a user uploads a medical report:

```
1. USER captures photo of medical report
         │
         ▼
2. Flutter App → POST /api/documents/upload (multipart/form-data)
         │
         ▼
3. Multer Middleware → receives file buffer (max 10MB)
         │
         ▼
4. StorageService.uploadBuffer() → saves to Firebase Cloud Storage
         │
         ▼
5. Prisma → creates MedicalDocument record (status: UPLOADED)
         │
         ▼
6. Response → { document: { id, status: "UPLOADED" } }
         │
         ▼
7. Flutter App → POST /api/documents/:id/process
         │
         ▼
8. Set status → PROCESSING (async background processing starts)
         │
         ▼
9. OCR Pipeline (runs asynchronously):
         │
    ┌────▼────────────────────────────────────────┐
    │  a) StorageService.getFileBuffer(fileName)  │
    │  b) Sharp Preprocessing:                     │
    │     - Grayscale                              │
    │     - Upscale to ≥2000px                     │
    │     - Sharpen (sigma 1.5)                    │
    │     - Normalize contrast                     │
    │     - Linear stretch                         │
    │  c) Tesseract.recognize(processedBuffer)     │
    │  d) Returns: { text, confidence, pageCount } │
    └────┬────────────────────────────────────────┘
         │
         ▼
10. Save ExtractedText to DB
         │
         ▼
11. ParamExtractor.extract(text):
    ┌────────────────────────────────────────────────┐
    │  a) Normalize text (fix OCR artifacts)         │
    │  b) Run 10 parameter pattern configs           │
    │  c) For each match:                            │
    │     - Parse numeric value                      │
    │     - Check plausibility range                 │
    │     - Assign confidence score                  │
    │  d) Deduplicate (keep highest confidence)      │
    │  e) Return: [{ name, value, unit, confidence }]│
    └────┬───────────────────────────────────────────┘
         │
         ▼
12. Save HealthMeasurements to DB (linked to document + user + parameter)
         │
         ▼
13. Categorizer.categorize(text, fileName):
    ┌────────────────────────────────────────────┐
    │  a) Score keywords across 7 categories     │
    │  b) Highest score → assigned category      │
    │  c) Matched keywords → document tags       │
    └────┬───────────────────────────────────────┘
         │
         ▼
14. Save category + tags to DB
         │
         ▼
15. Set status → COMPLETED
         │
         ▼
16. Flutter App polls/refreshes → sees COMPLETED status
         │
         ▼
17. User views:
    - Extracted text
    - Detected health parameters
    - Category & tags
    - Health trends (if multiple reports uploaded)
```

---

## 📊 Database ER Diagram

```
┌─────────────────────┐       ┌─────────────────────────────────┐
│       User           │       │       MedicalCategory           │
├─────────────────────┤       ├─────────────────────────────────┤
│ id (PK, UUID)        │       │ id (PK, UUID)                   │
│ email (UNIQUE)       │       │ name (UNIQUE)                   │
│ passwordHash         │       │ description                     │
│ name                 │       │ icon                            │
│ phone?               │       └──────────────┬──────────────────┘
│ dateOfBirth?         │                      │ 1
│ gender?              │                      │
│ profilePhoto?        │                      │
│ createdAt            │                      │
│ updatedAt            │                      │
└──────┬───────────────┘                      │
       │ 1                                    │
       │                                      │
       │ N                                    │ N
┌──────▼───────────────────────────────────────▼──┐
│              MedicalDocument                     │
├──────────────────────────────────────────────────┤
│ id (PK, UUID)                                    │
│ userId (FK → User)                               │
│ fileName                                         │
│ originalName                                     │
│ fileType                                         │
│ fileSize                                         │
│ storagePath                                      │
│ uploadedAt                                       │
│ processingStatus (UPLOADED|PROCESSING|COMPLETED|FAILED) │
│ categoryId? (FK → MedicalCategory)               │
│ processingError?                                 │
└──────┬──────────────┬──────────────┬─────────────┘
       │ 1            │ 1            │ 1
       │              │              │
       │ 1            │ N            │ N
┌──────▼────────┐ ┌───▼──────────┐ ┌▼──────────────────┐
│ ExtractedText │ │ DocumentTag  │ │ HealthMeasurement  │
├───────────────┤ ├──────────────┤ ├────────────────────┤
│ id (PK)       │ │ id (PK)      │ │ id (PK)            │
│ documentId FK │ │ documentId FK│ │ userId (FK)         │
│ text          │ │ tag          │ │ parameterId (FK)    │
│ pageCount?    │ │ (UNIQUE pair)│ │ documentId? (FK)    │
│ confidence?   │ └──────────────┘ │ value               │
│ createdAt     │                  │ unit                │
│ updatedAt     │                  │ measuredAt          │
└───────────────┘                  │ confidence?         │
                                   │ isManualEntry       │
                                   │ originalText?       │
                                   │ createdAt           │
                                   │ updatedAt           │
                                   └────────┬───────────┘
                                            │ N
                                            │
                                            │ 1
                                   ┌────────▼───────────┐
                                   │  HealthParameter    │
                                   ├────────────────────┤
                                   │ id (PK)            │
                                   │ name (UNIQUE)      │
                                   │ displayName        │
                                   │ defaultUnit        │
                                   │ description?       │
                                   │ normalMin?         │
                                   │ normalMax?         │
                                   └────────────────────┘
```

---

## 🌐 Deployment Architecture

```
┌─────────────┐     HTTPS      ┌──────────────┐     TCP        ┌──────────────┐
│ Flutter App  │ ──────────────→│   Render     │ ──────────────→│  Supabase    │
│ (Android)    │                │  (Node.js)   │                │ (PostgreSQL) │
└─────────────┘                └──────┬───────┘                └──────────────┘
                                      │
                                      │ HTTPS
                                      ▼
                               ┌──────────────┐
                               │   Firebase   │
                               │ Cloud Storage│
                               └──────────────┘
```

| Component | Service | URL/Region |
|-----------|---------|------------|
| Backend API | Render.com (Web Service) | `https://medical-0n1w.onrender.com` |
| Database | Supabase PostgreSQL | `ap-south-1` (Mumbai) |
| File Storage | Firebase Cloud Storage | Google Cloud |
| Mobile App | Android APK (local install) | N/A |

---

## 🚀 Setup & Installation

### Prerequisites

- **Node.js** v18+ and npm
- **Flutter** v3.12+ and Dart v3.12+
- **Android Studio** (for Android SDK and emulator)
- **Git**

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/medical.git
cd medical
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy environment template and configure
cp .env.example .env
# Edit .env with your database URL, JWT secret, etc.

# Generate Prisma client
npx prisma generate

# Run database migrations
npx prisma migrate dev

# Seed the database (categories + health parameters)
npm run prisma:seed

# Start development server
npm run dev
```

### 3. Flutter App Setup

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Update API URL in lib/config/api_config.dart
# For local testing: http://<YOUR_IP>:10000/api
# For cloud: https://medical-0n1w.onrender.com/api

# Run on connected device
flutter run

# Or build APK
flutter build apk --release
```

---

## 💻 Running Locally

### Backend

```bash
cd backend
npm run dev
# Server starts on http://localhost:10000
```

### Flutter App (on physical device)

1. Enable **USB Debugging** on your Android phone:
   - Settings → About Phone → Tap Build Number 7 times
   - Settings → Developer Options → USB Debugging ON
2. Connect phone via USB cable
3. Accept the USB debugging prompt on the phone
4. Update `lib/config/api_config.dart`:
   ```dart
   static const String baseUrl = 'http://<YOUR_MAC_IP>:10000/api';
   ```
5. Run:
   ```bash
   cd flutter_app
   flutter run
   ```

### Flutter App (on emulator)

```bash
cd flutter_app
flutter run
# Uses http://10.0.2.2:10000/api for Android emulator → host machine
```

---

## 📦 Building the APK

```bash
cd flutter_app

# Debug build
flutter build apk --debug

# Release build (optimized, no debug info)
flutter build apk --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk (~53 MB)
```

---

## 🔐 Environment Variables

### Backend `.env`

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection URL (pooled) | `postgresql://user:pass@host:6543/db?pgbouncer=true` |
| `DIRECT_URL` | PostgreSQL direct connection URL | `postgresql://user:pass@host:5432/db` |
| `JWT_SECRET` | Secret key for JWT signing | `your-secret-key-here` |
| `JWT_EXPIRES_IN` | Token expiration duration | `7d` |
| `PORT` | Server port | `10000` |
| `NODE_ENV` | Environment mode | `development` or `production` |
| `FRONTEND_URL` | CORS allowed origin | `*` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to Firebase service account JSON | `/path/to/serviceAccount.json` |

---

## 💓 Health Parameters Tracked

| # | Parameter | Display Name | Unit | Normal Min | Normal Max |
|---|-----------|-------------|------|-----------|-----------|
| 1 | `glucose` | Blood Glucose | mg/dL | 70 | 100 |
| 2 | `hemoglobin` | Hemoglobin | g/dL | 12 | 17.5 |
| 3 | `systolic_bp` | Systolic Blood Pressure | mmHg | 90 | 120 |
| 4 | `diastolic_bp` | Diastolic Blood Pressure | mmHg | 60 | 80 |
| 5 | `cholesterol` | Total Cholesterol | mg/dL | 0 | 200 |
| 6 | `heart_rate` | Heart Rate | bpm | 60 | 100 |
| 7 | `hba1c` | HbA1c | % | 4 | 5.6 |
| 8 | `creatinine` | Creatinine | mg/dL | 0.7 | 1.3 |
| 9 | `wbc` | White Blood Cells | cells/mcL | 4,500 | 11,000 |
| 10 | `platelets` | Platelets | cells/mcL | 150,000 | 400,000 |

---

## 🔒 Security Measures

| Layer | Measure | Details |
|-------|---------|---------|
| **Passwords** | bcrypt hashing | 12 salt rounds, never stored in plain text |
| **Authentication** | JWT tokens | Signed with secret key, 7-day expiry |
| **Token Storage** | Encrypted | flutter_secure_storage (Android KeyStore / iOS Keychain) |
| **API Protection** | Auth middleware | All routes (except login/register/health-check) require valid JWT |
| **Authorization** | Owner checks | Every document/measurement access verifies `userId` matches |
| **Input Validation** | Zod schemas | All request bodies validated before processing |
| **File Uploads** | Size limits + type checks | Max 10MB, restricted to image/PDF MIME types |
| **CORS** | Configured | Origin-based access control |
| **Error Handling** | Safe errors | Production errors don't expose internal details |
| **Database** | Cascade deletes | Deleting a user removes all their data |

---

## 🔮 Future Scope

- **AI-powered analysis**: Use LLMs (Gemini) for intelligent medical document understanding
- **Multi-language OCR**: Support for Hindi, Marathi, and other regional languages
- **PDF text extraction**: Native PDF parser (pdf-parse) for digital PDFs (not scanned)
- **Doctor sharing**: Share medical records securely with healthcare providers
- **Medication reminders**: Push notifications for medication schedules
- **Emergency QR code**: Generate QR code with critical health info
- **iOS support**: Build and deploy for Apple App Store
- **Offline mode**: Cache documents locally for offline viewing
- **Data export**: Export health data as CSV/PDF reports
- **Integration with health APIs**: Connect to Google Health, Apple Health

---

## 📄 License

This project is developed as part of an academic project.

---

> **Built with ❤️ by the MyHealthMitra Team**
