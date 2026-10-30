# Project Audit: Medical Records Organizer / MyHealthMitra

## 1. Existing Architecture
The project follows a standard client-server architecture with a mobile frontend and a RESTful backend API. The system is designed to allow users to upload medical documents, extract text via OCR, and parse specific health parameters (like Hemoglobin, WBC, etc.) which are then categorized and stored in a relational database for health trend analysis.

## 2. Existing Backend
- **Framework**: Node.js with Express and TypeScript.
- **ORM**: Prisma for database access.
- **Hosting**: Deployed on Render.
- **Key Modules**:
  - `src/index.ts`: Main entry point and Express server setup.
  - `src/routes/`: Route definitions for auth, medical records, OCR endpoints.
  - `src/controllers/`: Business logic for handling requests.
  - `src/services/`: Services for OCR processing (`ocr.ts`), parameter extraction (`paramExtractor.ts`), and categorization (`categorizer.ts`).

## 3. Existing Flutter App
- **Framework**: Flutter.
- **State Management**: Provider (likely used for user state and auth).
- **Navigation**: `go_router` or standard Navigator (checked in code, `go_router` is used for declarative navigation).
- **Key Screens**: Splash Screen, Login Screen, Signup Screen, Home Screen (Dashboard).
- **Recent Updates**: "MyHealthMitra" branding and logo integrated across splash, login, signup, and home screens. App launcher icon updated.

## 4. Existing Database
- **Database Engine**: PostgreSQL (hosted on Supabase).
- **Schema Key Entities**:
  - `User`: Handles user authentication and profile data.
  - `MedicalRecord`: Stores uploaded documents and parsed structured data.
  - `HealthParameter`: Master list of trackable health parameters (e.g., Hemoglobin, Glucose).
  - `RecordParameter`: Junction table linking `MedicalRecord` to `HealthParameter` with specific extracted values.
  - `Category`: Categories for medical records (e.g., Blood Test, Prescription).

## 5. Existing Authentication
- **Mechanism**: JWT (JSON Web Tokens) issued by the backend upon successful login/signup.
- **Frontend Storage**: `flutter_secure_storage` is used in the Flutter app to securely store the authentication token.
- **Backend Middleware**: Protects specific routes (like uploading records or fetching user data) by verifying the JWT.

## 6. Existing Document Upload System
- **Flow**:
  - Flutter app picks an image/document using `image_picker` or `file_picker`.
  - Sends a `multipart/form-data` POST request to the backend.
  - Backend uses `multer` to handle file uploads.
  - Currently configured to store files on the local filesystem of the server (e.g., Render disk).

## 7. Existing OCR Functionality
- **Technology**: Currently using `tesseract.js` for basic optical character recognition.
- **Extraction Logic**: After text is extracted by Tesseract, `paramExtractor.ts` uses Regular Expressions (Regex) to find specific medical parameters and their values.
- **Limitation**: Tesseract.js out of the box is often not highly robust for varied real-world medical report photographs (issues with skew, noise, specific formatting).

## 8. Existing Dependencies
- **Backend**: `express`, `prisma`, `@prisma/client`, `tesseract.js`, `multer`, `jsonwebtoken`, `bcrypt`.
- **Frontend**: `flutter`, `http` / `dio`, `flutter_secure_storage`, `go_router`, `image_picker`, `file_picker`, `fl_chart`.

## 9. Existing APIs
- `POST /api/auth/register`: User signup.
- `POST /api/auth/login`: User login.
- `POST /api/records/upload`: Upload document and trigger OCR.
- `GET /api/records`: Fetch user's medical records.
- `GET /api/records/trends`: Fetch data for charts.

## 10. Where OCR should be integrated
- **Backend Service**: The new custom ML OCR pipeline should eventually replace or augment the `tesseract.js` call inside `src/services/ocr.ts`.
- **API Endpoint**: We need to update `POST /api/records/upload` or add a dedicated `POST /ocr` endpoint that the mobile app can call.
- **ML Subsystem**: The new OCR logic will live inside the `ocr/` directory, exposing an interface (potentially a Python Flask/FastAPI microservice or a command-line interface called from Node.js) that processes the image and returns structured JSON with text, confidence, and bounding boxes.
