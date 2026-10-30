# MyHealthMitra — Open-Source LLM Integration Prototype

> **Evaluation Sandbox for On-Device & Edge Clinical Document Analysis**  
> **Target Evaluated Model**: [`alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF`](https://huggingface.co/alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF)  
> **Status**: Architectural prototype complete, unit-tested (21 tests passing). Model inference marked **`PENDING`** awaiting local weights download.

---

## 1. Executive Summary & Purpose

This directory (`llm_integration_prototype/`) is a **strictly isolated experimental module** within the MyHealthMitra repository. Its purpose is to evaluate whether modern open-source Small Language Models (SLMs) running quantized GGUF weights can accurately, safely, and cost-effectively perform:

1. **Structured Parameter Extraction**: Extracting 10 core clinical biometric/biochemical parameters from unstructured OCR text.
2. **Clinical Document Categorization**: Classifying noisy medical documents into MyHealthMitra's 7 canonical categories.
3. **Safety & Grounding Verification**: Enforcing strict physiological boundary checks and string-level citation grounding to prevent clinical hallucinations.

### Core Architectural Guarantees
- **Zero Production Coupling**: Does NOT import, modify, or depend on `backend/`, `flutter_app/`, `frontend/`, `ocr/`, or `prisma/`.
- **No Automatic Weight Downloads**: The Hugging Face repository contains over 295 GB across all quantizations. This prototype never automatically downloads weights.
- **Honest Benchmark Reporting**: In accordance with scientific integrity guidelines, benchmark scores are **explicitly marked `PENDING`** until a user executes the pipeline with local weights.

---

## 2. Directory Structure

```
llm_integration_prototype/
├── README.md                           # This document (Architecture, setup, guide)
├── requirements.txt                    # Minimal Python dependencies (Pydantic, PyYAML, Pytest)
├── pytest.ini                          # Test configuration (pythonpath = .)
├── config/
│   └── model_config.yaml               # Model metadata, runtime settings, quantization targets
├── src/
│   ├── __init__.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── medical_parameters.py       # Pydantic models for parameters, categories, sanity ranges
│   ├── model/
│   │   ├── __init__.py
│   │   ├── model_interface.py          # Abstract base class (BaseModelInterface) & contracts
│   │   └── gguf_runtime_adapter.py     # llama-cpp-python adapter with fail-safe error handling
│   ├── preprocessing/
│   │   ├── __init__.py
│   │   └── document_preprocessor.py    # Non-destructive clinical text cleaner (preserves digits/units)
│   ├── extraction/
│   │   ├── __init__.py
│   │   ├── structured_output.py        # Strict JSON parser, source-grounding, range validation
│   │   └── medical_parameter_extractor.py # 10-parameter clinical extraction coordinator
│   ├── categorization/
│   │   ├── __init__.py
│   │   └── document_classifier.py      # 7-class clinical document classifier
│   └── evaluation/
│       ├── __init__.py
│       ├── extraction_metrics.py       # Math metrics (Precision, Recall, F1, tolerance, hallucination)
│       └── evaluation_runner.py        # Benchmark harness (LLM vs Regex baseline)
├── examples/
│   ├── sample_medical_text.txt         # Representative noisy OCR text (CBC & Biochemistry)
│   ├── sample_extraction_prompt.txt    # ChatML-formatted prompt sent to model
│   └── expected_output.example.json    # Target gold-standard JSON structure (non-generated)
├── reports/
│   └── evaluation_template.md          # Evaluation report template (all metrics marked PENDING)
├── docs/
│   ├── architecture.md                 # System architecture & Mermaid sequence diagram
│   ├── model_selection.md              # Technical breakdown of Qwen3.8-Flash-Next, GSQ, RCO, GGUF
│   ├── extraction_workflow.md          # 6-stage clinical parameter extraction pipeline
│   ├── evaluation_methodology.md       # Exact mathematical definitions for all evaluation metrics
│   └── production_integration_plan.md  # Hybrid cascade microservice architecture & deployment plan
└── tests/
    ├── README.md                       # Test suite documentation & coverage guide
    ├── __init__.py
    ├── test_document_preprocessor.py   # Tests for text normalization & preservation
    ├── test_structured_output.py       # Tests for JSON parsing, grounding, and safety checks
    ├── test_model_interface.py         # Tests for abstract interface and adapter error handling
    ├── test_document_classifier.py     # Tests for category mapping and model classification
    ├── test_extraction_metrics.py      # Tests for mathematical precision, recall, F1, and tolerance
    └── test_evaluation_runner.py       # Tests for Regex baseline extractor & PENDING benchmark status
```

---

## 3. Evaluated Model & GGUF Runtime Architecture

### Why GGUF?
The evaluated model is [`alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF`](https://huggingface.co/alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF).

| Characteristic | Hugging Face Transformers (`safetensors`) | `llama.cpp` Runtime (`GGUF`) |
| :--- | :--- | :--- |
| **File Format** | Directory with `model.safetensors`, `config.json`, `tokenizer.json` | Single binary container (`.gguf`) with weights, hyperparams, vocab, metadata |
| **Memory Architecture** | Requires allocating full unquantized or 4-bit bitsandbytes weights into GPU VRAM | Direct memory mapping (`mmap`), CPU offloading, zero-copy inference |
| **Edge Feasibility** | Heavy PyTorch/CUDA stack (~4GB+ overhead just for runtime) | Lightweight C++ library, executable on macOS Metal, Linux CPU/CUDA, Android |
| **Hugging Face Loading** | Direct support via `AutoModelForCausalLM.from_pretrained` | **Cannot load directly** without `llama.cpp` bindings or specialized GGUF backend |

### Recommended Quantizations for Evaluation
For consumer laptops and edge servers (8GB–16GB RAM):
- **`IQ3_S` (~2.1 GB)**: Recommended balance of clinical syntax retention and perplexity.
- **`IQ2_XS` (~1.6 GB)**: Ultra-compact quantization for extreme edge/mobile memory envelopes.
- **`Q2_0` (~1.8 GB)**: Legacy standard 2-bit quantization for cross-device baseline benchmarking.

### Downloading Model Weights (Manual Only)
To test with actual model weights, download a single quantization file using the `huggingface-hub` CLI:

```bash
# Install Hugging Face Hub CLI
pip install huggingface-hub

# Download ONLY the IQ3_S quantization (~2.1 GB) into a local models/ directory:
huggingface-cli download alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF \
  Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-IQ3_S.gguf \
  --local-dir ./models --local-dir-use-symlinks False
```

Then update `config/model_config.yaml` to point `model_path` to `./models/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-IQ3_S.gguf`.

---

## 4. Supported Clinical Tasks

### A. 10 Core Clinical Parameters
The extractor extracts and validates the exact parameters tracked by MyHealthMitra:

| # | Parameter Key | Display Name | Canonical Unit | Physiological Range |
|---|---|---|---|---|
| 1 | `glucose` | Blood Glucose | `mg/dL` | 30.0 – 600.0 |
| 2 | `hemoglobin` | Hemoglobin | `g/dL` | 3.0 – 25.0 |
| 3 | `systolic_bp` | Systolic Blood Pressure | `mmHg` | 60.0 – 250.0 |
| 4 | `diastolic_bp` | Diastolic Blood Pressure | `mmHg` | 30.0 – 160.0 |
| 5 | `cholesterol` | Total Cholesterol | `mg/dL` | 50.0 – 500.0 |
| 6 | `heart_rate` | Heart Rate | `bpm` | 30.0 – 250.0 |
| 7 | `hba1c` | Glycated Hemoglobin | `%` | 3.0 – 18.0 |
| 8 | `creatinine` | Serum Creatinine | `mg/dL` | 0.1 – 20.0 |
| 9 | `wbc` | Total Leukocyte Count | `cells/uL` | 500.0 – 100,000.0 |
| 10 | `platelets` | Platelet Count | `lakh/uL` | 0.1 – 20.0 |

### B. 7 Canonical Document Categories
The classifier maps documents directly to MyHealthMitra's categorization schema:
- `Blood Test`
- `Lab Report`
- `Prescription`
- `Scan Report`
- `Discharge Summary`
- `Medical Bill`
- `General or Other`

---

## 5. Quickstart & Verification

### Step 1: Environment Setup
Ensure Python 3.10+ is installed:
```bash
cd /Users/ameythakare/medical/medical/llm_integration_prototype

# Optional: create a virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Run Unit Test Suite
Run the 21 automated unit tests verifying preprocessors, schema validators, adapters, metrics, and classifiers:
```bash
python3 -m pytest tests/ -v
```
Expected output:
```
tests/test_document_classifier.py::test_classifier_normalization PASSED
tests/test_document_classifier.py::test_classifier_with_model PASSED
tests/test_document_classifier.py::test_classifier_unconfigured_model_raises_runtime_error PASSED
tests/test_document_preprocessor.py::test_empty_document PASSED
tests/test_document_preprocessor.py::test_unicode_and_space_normalization PASSED
tests/test_document_preprocessor.py::test_clinical_numbers_and_symbols_preserved PASSED
tests/test_evaluation_runner.py::test_regex_baseline_extraction PASSED
tests/test_evaluation_runner.py::test_evaluation_runner_unconfigured_llm_returns_pending PASSED
tests/test_evaluation_runner.py::test_evaluation_runner_regex_baseline_benchmark PASSED
tests/test_extraction_metrics.py::test_unit_normalization PASSED
tests/test_extraction_metrics.py::test_numeric_closeness PASSED
tests/test_extraction_metrics.py::test_single_document_evaluation PASSED
tests/test_extraction_metrics.py::test_aggregate_metrics_calculation PASSED
tests/test_model_interface.py::test_mock_model_interface_contract PASSED
tests/test_model_interface.py::test_gguf_adapter_unconfigured_raises_error PASSED
tests/test_model_interface.py::test_gguf_adapter_missing_file_raises_weights_not_found PASSED
tests/test_structured_output.py::test_json_payload_extraction PASSED
tests/test_structured_output.py::test_valid_parsing_and_grounding PASSED
tests/test_structured_output.py::test_unsupported_source_text_flagged PASSED
tests/test_structured_output.py::test_physiological_range_warning PASSED
tests/test_structured_output.py::test_malformed_json_raises_value_error PASSED

============================== 21 passed in 0.13s ==============================
```

---

## 6. Safety & Grounding Pipeline

To eliminate hallucinations in medical reports, extracted parameters pass through a **3-stage verification filter**:

```
[Raw OCR Text]
      │
      ▼
[Document Preprocessor] ── Clean Unicode, normalize spaces, preserve symbols & units
      │
      ▼
[Model Ingestion (ChatML)] ── Low-temperature structured JSON prompting
      │
      ▼
[Structured Output Parser] 
      ├─ 1. Exact Substring Grounding: Does `supporting_source_text` exist in the document?
      │     └─ No ➔ Flag as UNVERIFIED (Hallucination Candidate)
      ├─ 2. Canonical Unit Normalization: Map `gm%` ➔ `g/dL`, `cells/cumm` ➔ `cells/uL`
      └─ 3. Biological Sanity Boundaries: Check value against `PHYSIOLOGICAL_LIMITS`
            └─ Out of bounds ➔ Flag as OUT_OF_RANGE with warning
```

---

## 7. Documentation Index

For in-depth technical references, consult the dedicated guides in `docs/`:
- **[System Architecture](docs/architecture.md)**: Component interactions, class hierarchy, and execution flow.
- **[Model Selection & GGUF Analysis](docs/model_selection.md)**: Deep dive into Qwen3.8-Flash-Next, GSQ, RCO, Strata, abliteration, and quantizations.
- **[Extraction Workflow Guide](docs/extraction_workflow.md)**: 6-stage clinical data extraction and prompt engineering strategy.
- **[Evaluation Methodology](docs/evaluation_methodology.md)**: Mathematical definitions for Precision, Recall, F1, tolerance, and hallucination scoring.
- **[Production Integration Plan](docs/production_integration_plan.md)**: 3-tier hybrid cascade (Regex ➔ SLM ➔ Physician) and FastAPI microservice blueprint.

---

## 8. Current Benchmark Status

| Evaluation Run | Target Model | Dataset Size | Status | Report Link |
| :--- | :--- | :--- | :--- | :--- |
| **Baseline Heuristics** | Python Regex Comparator | Sample corpus | Configured | [`reports/evaluation_template.md`](reports/evaluation_template.md) |
| **Qwen3.8-Flash-Next** | `IQ3_S` GGUF | Evaluator Ready | **`PENDING`** (Weights not downloaded) | [`reports/evaluation_template.md`](reports/evaluation_template.md) |
| **Qwen3.8-Flash-Next** | `IQ2_XS` GGUF | Evaluator Ready | **`PENDING`** (Weights not downloaded) | [`reports/evaluation_template.md`](reports/evaluation_template.md) |
