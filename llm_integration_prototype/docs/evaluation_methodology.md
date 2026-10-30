# 📏 Evaluation Methodology & Ground-Truth Protocol

To scientifically compare the proposed open-source LLM against MyHealthMitra's production regex extractor (`backend/src/services/paramExtractor.ts`), this evaluation framework defines strict, reproducible metrics.

---

## 1. Ground-Truth Dataset Preparation

A credible benchmark requires a double-blind, verified evaluation dataset:

1. **Document Selection**: 50–100 diverse real-world medical documents spanning:
   - High-contrast printed laboratory reports (CBC, Lipid, LFT).
   - Poorly illuminated mobile camera photographs.
   - Prescriptions containing handwritten doctor notes.
   - Non-medical negative controls (grocery receipts, discharge bills, invoices).
2. **Annotation Protocol**:
   - Two independent human reviewers annotate the exact parameter keys, values, units, reference intervals, and supporting text.
   - Any disagreement is arbitrated by a clinical reviewer.
3. **Storage Format**:
   Standard JSON array of annotated document objects matching `examples/expected_output.example.json`.

---

## 2. Mathematical Metric Formulations

### 1. Parameter Key Detection (Precision, Recall, F1)
Evaluates whether the extractor correctly identifies the presence of a biomarker in the document:

$$\text{Precision} = \frac{\text{True Positives (TP)}}{\text{True Positives (TP)} + \text{False Positives (FP)}}$$

$$\text{Recall} = \frac{\text{True Positives (TP)}}{\text{True Positives (TP)} + \text{False Negatives (FN)}}$$

$$F_1 = 2 \times \frac{\text{Precision} \times \text{Recall}}{\text{Precision} + \text{Recall}}$$

- **TP**: Biomarker is present in Ground Truth and identified by the model.
- **FP**: Biomarker is extracted by the model but absent in Ground Truth.
- **FN**: Biomarker exists in Ground Truth but was missed by the model.

### 2. Exact Value Match Accuracy
For true-positive detections, checks whether the predicted string/number exactly matches Ground Truth:

$$\text{Exact Value Accuracy} = \frac{\sum \mathbb{I}(\text{Value}_{\text{pred}} = \text{Value}_{\text{gt}})}{\text{TP}}$$

### 3. Numeric Tolerance Accuracy (±1% Relative Error)
Accounts for minor floating point rounding differences (e.g. `14.2` vs `14.20`):

$$\text{Numeric Tolerance Accuracy} = \frac{\sum \mathbb{I}\left(\frac{|\text{Value}_{\text{pred}} - \text{Value}_{\text{gt}}|}{\text{Value}_{\text{gt}}} \le 0.01\right)}{\text{TP}}$$

### 4. Unit Agreement Rate
Evaluates clinical unit alignment after standardizing variants (e.g. `gm/dL` vs `g/dL`, `cells/mcL` vs `cells/uL`):

$$\text{Unit Agreement Rate} = \frac{\sum \mathbb{I}(\text{NormUnit}_{\text{pred}} = \text{NormUnit}_{\text{gt}})}{\text{TP}}$$

### 5. Hallucination / Unsupported Extraction Rate
Measures the proportion of extracted parameters where the cited `supporting_source_text` is NOT present in the raw OCR document:

$$\text{Hallucination Rate} = \frac{\text{Count of Predictions Missing from Source Text}}{\text{Total Predicted Parameters}}$$

*A viable clinical LLM must maintain a Hallucination Rate as close to 0.00% as possible.*

### 6. Document Categorization Accuracy
Evaluates classification correctness across the 7 established classes:

$$\text{Categorization Accuracy} = \frac{\text{Correct Document Category Predictions}}{\text{Total Evaluated Documents}}$$

### 7. Resource Consumption
- **Latency (ms)**: Measured from prompt dispatch to completion using high-resolution monotonic clocks (`time.perf_counter()`).
- **Peak Memory (MB)**: Measured using resident set size (`psutil.Process().memory_info().rss`).

---

## 3. Ground-Truth Data Policy

- All benchmark tables in `reports/evaluation_template.md` are marked **`PENDING`** until an actual dataset is loaded and physical weights are evaluated on target hardware.
- No synthetic scores, fabricated percentages, or assumed metrics are ever committed to the repository.
