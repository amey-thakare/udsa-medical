# 🔄 Clinical Information Extraction Workflow

This document details the multi-stage clinical extraction pipeline implemented in `llm_integration_prototype/`.

---

## 1. Stage-by-Stage Workflow

```
[Raw OCR Document Text]
          │
          ▼
┌───────────────────────────────────────────────────────────┐
│ Stage 1: Conservative Preprocessing                       │
│ • NFKC Unicode normalization                              │
│ • Control character removal (preserving \n and \t)        │
│ • White-space collapse (preserving paragraph breaks)      │
│ • CRITICAL: Zero modification of digits, units, or dates  │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│ Stage 2: Prompt Construction                              │
│ • Injects system prompt with extraction rules             │
│ • Outlines 10 core target biomarkers                      │
│ • Enforces 7 discrete document categories                 │
│ • Mandates single valid JSON output matching Pydantic DTO │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│ Stage 3: Deterministic Model Inference                    │
│ • Temperature: 0.1 (minimizes hallucination)              │
│ • Top-P: 0.95                                             │
│ • Repetition Penalty: 1.05                                │
│ • Stop tokens: <|im_end|>, <|endoftext|>                  │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│ Stage 4: Structural & Schema Validation                   │
│ • Strips markdown fences (```json ... ```)                │
│ • Pydantic model validation (DocumentAnalysisResult)      │
│ • Rejects malformed JSON with explicit error traces       │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│ Stage 5: Grounding Verification (Anti-Hallucination)      │
│ • Takes each parameter's `supporting_source_text`         │
│ • Verifies verbatim substring presence in raw OCR text    │
│ • If NOT found: validation_status =                       │
│   UNSUPPORTED_SOURCE_TEXT                                 │
└─────────────────────────────┬─────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│ Stage 6: Physiological Boundary Filter                    │
│ • Compares numeric values against biological limits       │
│ • Catches OCR/LLM digit drops (e.g. 142 vs 14.2 g/dL)     │
│ • If outside limits: validation_status =                  │
│   PLAUSIBLE_RANGE_WARNING                                 │
│ • If within limits: validation_status = VALID             │
└───────────────────────────────────────────────────────────┘
```

---

## 2. Core Guardrails & Safety Filters

### 1. No Invented Reference Ranges
In many lab reports, reference ranges are omitted or printed only on the header page. Standard LLMs often fabricate generic adult reference ranges (e.g. inventing `"12.0 - 16.0 g/dL"` for hemoglobin).
- **Rule**: If the document does not explicitly state the reference interval, the model MUST emit `"reference_range": null`.

### 2. No Invented Dates
If an old blood test slip has an unreadable or omitted date stamp, the model MUST emit `"measurement_date": null`.

### 3. Traceability to Source Text
Every extracted biomarker MUST include a `supporting_source_text` field. If the parser cannot locate this exact text inside the original document, the parameter is immediately flagged with `UNSUPPORTED_SOURCE_TEXT`.

### 4. Physiological Plausibility Limits
The system applies biological sanity checks (matching `backend/src/services/paramExtractor.ts`):

```python
PHYSIOLOGICAL_LIMITS = {
    "glucose": {"min": 30.0, "max": 600.0, "default_unit": "mg/dL"},
    "hemoglobin": {"min": 3.0, "max": 25.0, "default_unit": "g/dL"},
    "systolic_bp": {"min": 60.0, "max": 250.0, "default_unit": "mmHg"},
    "diastolic_bp": {"min": 30.0, "max": 160.0, "default_unit": "mmHg"},
    "cholesterol": {"min": 50.0, "max": 500.0, "default_unit": "mg/dL"},
    "heart_rate": {"min": 30.0, "max": 250.0, "default_unit": "bpm"},
    "hba1c": {"min": 3.0, "max": 18.0, "default_unit": "%"},
    "creatinine": {"min": 0.1, "max": 20.0, "default_unit": "mg/dL"},
    "wbc": {"min": 500.0, "max": 100000.0, "default_unit": "cells/uL"},
    "platelets": {"min": 0.1, "max": 20.0, "default_unit": "lakh/uL"},
}
```

These checks prevent corrupted values from skewing longitudinal health trend charts in the mobile app.
