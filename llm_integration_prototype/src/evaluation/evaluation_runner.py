import os
import re
from typing import List, Dict, Any, Optional
from ..extraction.medical_parameter_extractor import MedicalParameterExtractor
from ..preprocessing.document_preprocessor import DocumentPreprocessor
from ..schemas.medical_parameters import ExtractedParameter, MedicalCategory
from .extraction_metrics import ExtractionMetricsCalculator, BenchmarkMetricsSummary


class RegexBaselineExtractor:
    """
    Python reference implementation of MyHealthMitra's production regex extractor
    (backend/src/services/paramExtractor.ts). Used as a direct benchmark baseline.
    """

    def extract(self, text: str) -> List[ExtractedParameter]:
        results: List[ExtractedParameter] = []

        # 1. Glucose
        m = re.search(r"\b(?:glucose|blood\s*sugar|fasting\s*glucose)\b[^0-9]{0,20}?(\d+(?:[.,]\d+)?)\s*(mg\s*/\s*dL)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", "."))
            if 30 <= val <= 600:
                results.append(ExtractedParameter(
                    parameter_key="glucose",
                    display_name="Blood Glucose",
                    value=val,
                    unit="mg/dL",
                    supporting_source_text=m.group(0),
                ))

        # 2. Hemoglobin
        m = re.search(r"\b(?:hemoglobin|haemoglobin|hb)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(g\s*/\s*dL|gm\s*%)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", "."))
            if 3 <= val <= 25:
                results.append(ExtractedParameter(
                    parameter_key="hemoglobin",
                    display_name="Hemoglobin",
                    value=val,
                    unit="g/dL",
                    supporting_source_text=m.group(0),
                ))

        # 3. Blood Pressure
        m = re.search(r"\b(?:blood\s*pressure|bp)\b[^0-9]{0,15}?(\d{2,3})\s*[\/\\|]\s*(\d{2,3})\s*(mmHg)?", text, re.I)
        if m:
            sys_val = float(m.group(1))
            dia_val = float(m.group(2))
            if 60 <= sys_val <= 250:
                results.append(ExtractedParameter(
                    parameter_key="systolic_bp",
                    display_name="Systolic Blood Pressure",
                    value=sys_val,
                    unit="mmHg",
                    supporting_source_text=m.group(0),
                ))
            if 30 <= dia_val <= 160:
                results.append(ExtractedParameter(
                    parameter_key="diastolic_bp",
                    display_name="Diastolic Blood Pressure",
                    value=dia_val,
                    unit="mmHg",
                    supporting_source_text=m.group(0),
                ))

        # 4. Cholesterol
        m = re.search(r"\b(?:cholesterol|total\s*cholesterol)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(mg\s*/\s*dL)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", "."))
            if 50 <= val <= 500:
                results.append(ExtractedParameter(
                    parameter_key="cholesterol",
                    display_name="Total Cholesterol",
                    value=val,
                    unit="mg/dL",
                    supporting_source_text=m.group(0),
                ))

        # 5. Heart Rate
        m = re.search(r"\b(?:heart\s*rate|pulse)\b[^0-9]{0,15}?(\d{2,3})\s*(bpm|beats\s*/\s*min)?", text, re.I)
        if m:
            val = float(m.group(1))
            if 30 <= val <= 250:
                results.append(ExtractedParameter(
                    parameter_key="heart_rate",
                    display_name="Heart Rate",
                    value=val,
                    unit="bpm",
                    supporting_source_text=m.group(0),
                ))

        # 6. HbA1c
        m = re.search(r"\b(?:hba1c|glycated\s*hemoglobin)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(%)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", "."))
            if 3 <= val <= 18:
                results.append(ExtractedParameter(
                    parameter_key="hba1c",
                    display_name="HbA1c",
                    value=val,
                    unit="%",
                    supporting_source_text=m.group(0),
                ))

        # 7. Creatinine
        m = re.search(r"\b(?:creatinine|serum\s*creatinine)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(mg\s*/\s*dL)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", "."))
            if 0.1 <= val <= 20:
                results.append(ExtractedParameter(
                    parameter_key="creatinine",
                    display_name="Serum Creatinine",
                    value=val,
                    unit="mg/dL",
                    supporting_source_text=m.group(0),
                ))

        # 8. WBC
        m = re.search(r"\b(?:wbc|wbc\s*count|white\s*blood\s*cells?)\b[^0-9]{0,15}?(\d{1,3}(?:,\d{3})+|\d+)\s*(cells\s*/\s*uL|/uL|/cumm)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", ""))
            if 500 <= val <= 100000:
                results.append(ExtractedParameter(
                    parameter_key="wbc",
                    display_name="WBC Count",
                    value=val,
                    unit="cells/uL",
                    supporting_source_text=m.group(0),
                ))

        # 9. Platelets
        m = re.search(r"\b(?:platelet|platelet\s*count)\b[^0-9]{0,15}?(\d+(?:[.,]\d+)?)\s*(lakh\s*/\s*uL|lakhs)?", text, re.I)
        if m:
            val = float(m.group(1).replace(",", "."))
            if 0.1 <= val <= 20:
                results.append(ExtractedParameter(
                    parameter_key="platelets",
                    display_name="Platelet Count",
                    value=val,
                    unit="lakh/uL",
                    supporting_source_text=m.group(0),
                ))

        return results


class EvaluationRunner:
    """
    Executes comparative benchmarks between the Regex baseline and LLM extractor.
    Enforces the rule that pending experiments are explicitly reported as PENDING.
    """

    def __init__(self, llm_extractor: Optional[MedicalParameterExtractor] = None):
        self.llm_extractor = llm_extractor
        self.regex_extractor = RegexBaselineExtractor()
        self.preprocessor = DocumentPreprocessor()
        self.calculator = ExtractionMetricsCalculator()

    def evaluate_regex_baseline(self, dataset: List[Dict[str, Any]]) -> BenchmarkMetricsSummary:
        """
        Runs the Regex baseline extractor across an annotated dataset.
        """
        doc_evals = []
        for sample in dataset:
            text = sample["text"]
            gt_params = sample.get("ground_truth_parameters", [])
            gt_category = sample.get("ground_truth_category")

            preds = self.regex_extractor.extract(text)
            eval_res = self.calculator.evaluate_single_document(
                predicted_params=preds,
                ground_truth_params=gt_params,
                predicted_category=None,
                ground_truth_category=gt_category,
                source_text=text,
            )
            doc_evals.append(eval_res)

        return self.calculator.compute_aggregate_metrics(doc_evals)

    def evaluate_llm(self, dataset: List[Dict[str, Any]]) -> BenchmarkMetricsSummary:
        """
        Evaluates the LLM extractor. If weights are not configured, returns PENDING.
        """
        if not self.llm_extractor or not self.llm_extractor.model.is_configured():
            return BenchmarkMetricsSummary(
                total_documents=len(dataset),
                execution_status="PENDING (Model weights or GGUF runtime not configured)",
            )

        doc_evals = []
        latencies = []

        for sample in dataset:
            text = sample["text"]
            gt_params = sample.get("ground_truth_parameters", [])
            gt_category = sample.get("ground_truth_category")

            result = self.llm_extractor.extract_from_raw_text(text)
            eval_res = self.calculator.evaluate_single_document(
                predicted_params=result.parameters,
                ground_truth_params=gt_params,
                predicted_category=result.document_category,
                ground_truth_category=gt_category,
                source_text=text,
            )
            doc_evals.append(eval_res)

        return self.calculator.compute_aggregate_metrics(doc_evals, execution_times=latencies)
