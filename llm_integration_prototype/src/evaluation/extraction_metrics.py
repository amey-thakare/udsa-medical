import math
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Set
from ..schemas.medical_parameters import ExtractedParameter, MedicalCategory


@dataclass
class ParameterEvaluationScore:
    """Detailed evaluation score for a single parameter key."""
    parameter_key: str
    true_positive: int = 0
    false_positive: int = 0
    false_negative: int = 0
    exact_value_matches: int = 0
    numeric_tolerance_matches: int = 0
    unit_matches: int = 0
    reference_range_matches: int = 0
    hallucinations: int = 0


@dataclass
class BenchmarkMetricsSummary:
    """
    Mathematical metrics aggregating performance across an evaluation dataset.
    All fields are computed deterministically from predictions vs ground-truth.
    """
    total_documents: int = 0
    total_ground_truth_parameters: int = 0
    total_predicted_parameters: int = 0
    
    # Classification metrics
    precision: float = 0.0
    recall: float = 0.0
    f1_score: float = 0.0
    
    # Value & Unit extraction accuracy
    exact_value_accuracy: float = 0.0
    numeric_tolerance_accuracy: float = 0.0  # within 1% relative tolerance
    unit_agreement_rate: float = 0.0
    
    # Safety & Reliability metrics
    hallucination_rate: float = 0.0  # Percentage of predictions without supporting source text
    categorization_accuracy: float = 0.0
    
    # Resource metrics
    mean_latency_ms: Optional[float] = None
    peak_memory_mb: Optional[float] = None
    
    per_parameter_scores: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    execution_status: str = "PENDING"  # Marked PENDING until a real benchmark is run


class ExtractionMetricsCalculator:
    """
    Computes rigorous clinical information extraction metrics.
    Compares predicted parameters against curated ground-truth records.
    """

    @staticmethod
    def normalize_unit(unit: str) -> str:
        """
        Normalizes clinical unit strings for fair evaluation (e.g., 'gm/dl' -> 'g/dl').
        """
        u = unit.strip().lower()
        u = u.replace("gm", "g").replace(" ", "")
        u = u.replace("micro", "u").replace("µ", "u").replace("mc", "u")
        u = u.replace("/ul", "/ul").replace("/cumm", "/ul")
        return u

    @staticmethod
    def is_numeric_close(v1: Any, v2: Any, rel_tol: float = 0.01) -> bool:
        """
        Checks if two numbers are within relative tolerance (default 1%).
        """
        try:
            n1 = float(v1)
            n2 = float(v2)
            return math.isclose(n1, n2, rel_tol=rel_tol)
        except (ValueError, TypeError):
            return str(v1).strip().lower() == str(v2).strip().lower()

    def evaluate_single_document(
        self,
        predicted_params: List[ExtractedParameter],
        ground_truth_params: List[Dict[str, Any]],
        predicted_category: Optional[MedicalCategory],
        ground_truth_category: Optional[str],
        source_text: str,
    ) -> Dict[str, Any]:
        """
        Evaluates predictions for a single document against ground truth.
        """
        # Map parameters by key
        pred_map: Dict[str, ExtractedParameter] = {p.parameter_key: p for p in predicted_params}
        gt_map: Dict[str, Dict[str, Any]] = {}
        for g in ground_truth_params:
            if isinstance(g, ExtractedParameter):
                gt_map[g.parameter_key] = {"parameter_key": g.parameter_key, "value": g.value, "unit": g.unit}
            elif isinstance(g, dict):
                gt_map[g["parameter_key"]] = g

        all_keys: Set[str] = set(pred_map.keys()) | set(gt_map.keys())

        tp = 0
        fp = 0
        fn = 0
        exact_matches = 0
        tolerance_matches = 0
        unit_matches = 0
        hallucinations = 0

        for key in all_keys:
            pred = pred_map.get(key)
            gt = gt_map.get(key)

            if pred and gt:
                tp += 1
                # Value check
                if str(pred.value).strip() == str(gt.get("value")).strip():
                    exact_matches += 1
                if self.is_numeric_close(pred.value, gt.get("value")):
                    tolerance_matches += 1

                # Unit check
                if self.normalize_unit(pred.unit) == self.normalize_unit(gt.get("unit", "")):
                    unit_matches += 1

                # Hallucination check: is supporting text missing from source?
                if pred.supporting_source_text and pred.supporting_source_text.lower() not in source_text.lower():
                    hallucinations += 1
            elif pred and not gt:
                fp += 1
                if pred.supporting_source_text and pred.supporting_source_text.lower() not in source_text.lower():
                    hallucinations += 1
            elif gt and not pred:
                fn += 1

        category_match = False
        if predicted_category and ground_truth_category:
            category_match = predicted_category.value.lower() == ground_truth_category.lower()

        return {
            "tp": tp,
            "fp": fp,
            "fn": fn,
            "exact_matches": exact_matches,
            "tolerance_matches": tolerance_matches,
            "unit_matches": unit_matches,
            "hallucinations": hallucinations,
            "category_match": category_match,
            "total_gt": len(gt_map),
            "total_pred": len(pred_map),
        }

    def compute_aggregate_metrics(
        self,
        document_evaluations: List[Dict[str, Any]],
        execution_times: Optional[List[float]] = None,
        peak_memory_mb: Optional[float] = None,
    ) -> BenchmarkMetricsSummary:
        """
        Aggregates document evaluations into full precision, recall, F1, and accuracy scores.
        """
        if not document_evaluations:
            return BenchmarkMetricsSummary(execution_status="PENDING")

        total_tp = sum(d["tp"] for d in document_evaluations)
        total_fp = sum(d["fp"] for d in document_evaluations)
        total_fn = sum(d["fn"] for d in document_evaluations)
        total_exact = sum(d["exact_matches"] for d in document_evaluations)
        total_tolerance = sum(d["tolerance_matches"] for d in document_evaluations)
        total_unit = sum(d["unit_matches"] for d in document_evaluations)
        total_hallucinations = sum(d["hallucinations"] for d in document_evaluations)
        total_gt = sum(d["total_gt"] for d in document_evaluations)
        total_pred = sum(d["total_pred"] for d in document_evaluations)
        category_matches = sum(1 for d in document_evaluations if d.get("category_match"))

        # Precision, Recall, F1
        precision = total_tp / (total_tp + total_fp) if (total_tp + total_fp) > 0 else 0.0
        recall = total_tp / (total_tp + total_fn) if (total_tp + total_fn) > 0 else 0.0
        f1 = (2 * precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0

        exact_acc = total_exact / total_tp if total_tp > 0 else 0.0
        tolerance_acc = total_tolerance / total_tp if total_tp > 0 else 0.0
        unit_acc = total_unit / total_tp if total_tp > 0 else 0.0
        hallucination_rate = total_hallucinations / total_pred if total_pred > 0 else 0.0
        cat_acc = category_matches / len(document_evaluations) if document_evaluations else 0.0

        mean_latency = sum(execution_times) / len(execution_times) if execution_times else None

        return BenchmarkMetricsSummary(
            total_documents=len(document_evaluations),
            total_ground_truth_parameters=total_gt,
            total_predicted_parameters=total_pred,
            precision=round(precision, 4),
            recall=round(recall, 4),
            f1_score=round(f1, 4),
            exact_value_accuracy=round(exact_acc, 4),
            numeric_tolerance_accuracy=round(tolerance_acc, 4),
            unit_agreement_rate=round(unit_acc, 4),
            hallucination_rate=round(hallucination_rate, 4),
            categorization_accuracy=round(cat_acc, 4),
            mean_latency_ms=round(mean_latency, 2) if mean_latency is not None else None,
            peak_memory_mb=round(peak_memory_mb, 2) if peak_memory_mb is not None else None,
            execution_status="COMPLETED" if total_pred > 0 else "PENDING",
        )
