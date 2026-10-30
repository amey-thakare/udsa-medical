# 📊 Model Evaluation & Benchmark Report (Template)

> **Evaluation Status**: `PENDING — Awaiting Model Weights & Hardware Execution`  
> **Notice**: No synthetic or fabricated performance metrics are reported in this document. Real metrics are populated only after executing `src/evaluation/evaluation_runner.py` with physical model weights.

---

## 1. Experiment Overview

| Property | Value |
|---|---|
| **Evaluation Date** | `[PENDING]` |
| **Model Evaluated** | `alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF` |
| **Quantization Arm** | `IQ3_S` (Planned) / `IQ2_XS` |
| **Inference Runtime** | `llama.cpp` (`llama-cpp-python`) |
| **Evaluation Platform** | `[PENDING: Hardware specification e.g. Apple M-Series / Linux NVIDIA CUDA]` |
| **Baseline Comparator** | `backend/src/services/paramExtractor.ts` (Regex clinical extractor) |
| **Dataset Size** | `[PENDING: Number of verified ground-truth clinical documents]` |

---

## 2. Comparative Benchmark Summary

| Evaluation Metric | Production Regex Baseline | Experimental Qwen GGUF | Delta (%) |
|---|---|---|---|
| **Parameter Detection Precision** | `[PENDING]` | `[PENDING]` | `—` |
| **Parameter Detection Recall** | `[PENDING]` | `[PENDING]` | `—` |
| **Parameter Detection F1-Score** | `[PENDING]` | `[PENDING]` | `—` |
| **Exact Value Match Accuracy** | `[PENDING]` | `[PENDING]` | `—` |
| **Numeric Tolerance Accuracy (±1%)** | `[PENDING]` | `[PENDING]` | `—` |
| **Unit Agreement Rate** | `[PENDING]` | `[PENDING]` | `—` |
| **Reference Range Match Rate** | `[PENDING]` | `[PENDING]` | `—` |
| **Document Categorization Accuracy** | `[PENDING]` | `[PENDING]` | `—` |
| **Hallucination / Unsupported Rate** | `[PENDING]` | `[PENDING]` | `—` |
| **Mean Latency per Document** | `[PENDING: < 10ms typical for regex]` | `[PENDING]` | `—` |
| **Peak Memory Consumption** | `[PENDING: ~50MB Node.js process]` | `[PENDING]` | `—` |

---

## 3. Parameter-Level Breakdown

| Parameter Key | Ground Truth Count | Regex TP | LLM TP | Regex F1 | LLM F1 | Notes |
|---|---|---|---|---|---|---|
| `glucose` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Fasting / Random Blood Sugar |
| `hemoglobin` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Hb / Haemoglobin |
| `systolic_bp` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Arterial Systolic Pressure |
| `diastolic_bp` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Arterial Diastolic Pressure |
| `cholesterol` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Total Serum Cholesterol |
| `heart_rate` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Pulse / Heart Rate |
| `hba1c` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Glycated Hemoglobin |
| `creatinine` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Renal Serum Creatinine |
| `wbc` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | White Blood Cell Count |
| `platelets` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | `[PENDING]` | Platelet / Thrombocyte Count |

---

## 4. Qualitative Failure Analysis

### Common Regex Extraction Failures
1. Complex tabular layouts where parameter names and values are separated by multiple columns.
2. Unconventional doctor notations (e.g. handwriting shorthand or unusual measurement units).
3. Ambiguous abbreviations where medical context anchor is distant.

### Potential LLM Failure Modes (To Evaluate)
1. Inadvertent hallucination of reference ranges when omitted in source text.
2. Minor formatting deviations in JSON key names if strict constrained decoding is not enforced.
3. Latency overhead compared to millisecond regex execution.

---

## 5. Instructions to Generate Live Report

Once weights are downloaded to `llm_integration_prototype/weights/`:
```bash
cd llm_integration_prototype
python -m src.evaluation.evaluation_runner --dataset data/ground_truth.json --output reports/latest_run.md
```
