# 🏛️ Architecture & System Design: Open-Source LLM Integration

## 1. Executive Context

In MyHealthMitra, the active production pipeline relies on a two-tier cloud architecture:
1. **Multimodal OCR**: Google Gemini 3 Vision (`backend/src/services/ocr.ts`) transcribes document images/PDFs into text.
2. **Clinical Extraction**: A fast, deterministic regex parser (`backend/src/services/paramExtractor.ts`) extracts 10 core biomarkers.
3. **Categorization**: A weighted heuristic engine (`backend/src/services/categorizer.ts`) classifies documents into 6 clinical categories.

This experimental module (`llm_integration_prototype/`) investigates how a locally hosted, quantized open-source Large Language Model (specifically **Qwen3.8-Flash-Next GGUF**) can be evaluated as an alternative or augmentation for complex, unstructured medical text interpretation.

---

## 2. Experimental Data Flow & System Diagram

```mermaid
flowchart TD
    subgraph Input["1. Input Source"]
        A["Medical Document Image / PDF"] --> B["Existing OCR Engine (Gemini / PyTorch CRNN)"]
        B --> C["Raw OCR Transcription Text"]
    end

    subgraph Preprocessing["2. Text Normalization"]
        C --> D["Document Preprocessor (document_preprocessor.py)"]
        D --> E["Cleaned Normalized Text (Preserving Numbers, Units, Dates)"]
        D --> F["Original Raw Text (Preserved for Traceability)"]
    end

    subgraph Inference["3. Model Inference (GGUF Runtime)"]
        E --> G["Prompt Builder (EXTRACTION_SYSTEM_PROMPT)"]
        G --> H["GGUF Runtime Adapter (gguf_runtime_adapter.py)"]
        H --> I["llama.cpp Engine (Qwen3.8-Flash-Next GGUF)"]
        I --> J["Raw Model Output (JSON string)"]
    end

    subgraph Validation["4. Schema & Safety Verification"]
        J --> K["Structured Output Parser (structured_output.py)"]
        K --> L["Pydantic Schema Validation (DocumentAnalysisResult)"]
        L --> M{"Grounding Check against Source"}
        F -.-> M
        M -- "Missing from Source" --> N["Flag: UNSUPPORTED_SOURCE_TEXT"]
        M -- "Found in Source" --> O{"Physiological Boundary Check"}
        O -- "Outside Bounds" --> P["Flag: PLAUSIBLE_RANGE_WARNING"]
        O -- "Within Bounds" --> Q["Status: VALID"]
    end

    subgraph Evaluation["5. Comparative Evaluation Harness"]
        Q --> R["Extraction Metrics Calculator (extraction_metrics.py)"]
        N --> R
        P --> R
        S["Ground-Truth Annotated Dataset"] --> T["Evaluation Runner (evaluation_runner.py)"]
        U["Regex Baseline Extractor (paramExtractor.ts replica)"] --> T
        T --> R
        R --> V["Evaluation Report (evaluation_template.md)"]
    end

    style Input fill:#e1f5fe,stroke:#0288d1
    style Preprocessing fill:#e8f5e9,stroke:#388e3c
    style Inference fill:#fff3e0,stroke:#f57c00
    style Validation fill:#fce4ec,stroke:#c2185b
    style Evaluation fill:#ede7f6,stroke:#512da8
```

---

## 3. Production vs. Prototype Isolation

To protect the integrity of MyHealthMitra's production application:
- **Zero Production Changes**: No files in `backend/`, `flutter_app/`, `frontend/`, `ocr/`, or `prisma/` are modified or replaced.
- **No Shared Network Port**: The experimental prototype runs as an offline Python evaluation framework.
- **No Live Ingestion**: The prototype does not receive live patient uploads or write to the Supabase PostgreSQL database.
- **Explicit Fallback Protocol**: If model weights or the `llama-cpp-python` runtime are not installed, the prototype fails fast with informative configuration errors, never emitting simulated or fabricated outputs.
