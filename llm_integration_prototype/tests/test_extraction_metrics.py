import pytest
from src.evaluation.extraction_metrics import (
    ExtractionMetricsCalculator,
    BenchmarkMetricsSummary,
)
from src.schemas.medical_parameters import ExtractedParameter, MedicalCategory


def test_unit_normalization():
    calc = ExtractionMetricsCalculator()
    assert calc.normalize_unit("gm/dL") == "g/dl"
    assert calc.normalize_unit("g/dl") == "g/dl"
    assert calc.normalize_unit("cells/uL") == "cells/ul"
    assert calc.normalize_unit("cells/cumm") == "cells/ul"


def test_numeric_closeness():
    calc = ExtractionMetricsCalculator()
    assert calc.is_numeric_close(14.2, 14.2) is True
    assert calc.is_numeric_close(14.2, 14.21, rel_tol=0.01) is True
    assert calc.is_numeric_close(14.2, 18.0) is False
    assert calc.is_numeric_close("positive", "Positive") is True


def test_single_document_evaluation():
    calc = ExtractionMetricsCalculator()
    source_text = "Hemoglobin: 14.2 g/dL. Fasting Glucose: 95 mg/dL."
    
    preds = [
        ExtractedParameter(
            parameter_key="hemoglobin",
            display_name="Hemoglobin",
            value=14.2,
            unit="g/dL",
            supporting_source_text="Hemoglobin: 14.2 g/dL",
        ),
        ExtractedParameter(
            parameter_key="glucose",
            display_name="Blood Glucose",
            value=95.0,
            unit="mg/dL",
            supporting_source_text="Fasting Glucose: 95 mg/dL",
        ),
    ]
    
    ground_truth = [
        {"parameter_key": "hemoglobin", "value": 14.2, "unit": "g/dL"},
        {"parameter_key": "glucose", "value": 95.0, "unit": "mg/dL"},
    ]
    
    eval_res = calc.evaluate_single_document(
        predicted_params=preds,
        ground_truth_params=ground_truth,
        predicted_category=MedicalCategory.BLOOD_TEST,
        ground_truth_category="Blood Test",
        source_text=source_text,
    )
    
    assert eval_res["tp"] == 2
    assert eval_res["fp"] == 0
    assert eval_res["fn"] == 0
    assert eval_res["exact_matches"] == 2
    assert eval_res["unit_matches"] == 2
    assert eval_res["hallucinations"] == 0
    assert eval_res["category_match"] is True


def test_aggregate_metrics_calculation():
    calc = ExtractionMetricsCalculator()
    doc_evals = [
        {
            "tp": 2, "fp": 0, "fn": 0,
            "exact_matches": 2, "tolerance_matches": 2,
            "unit_matches": 2, "hallucinations": 0,
            "category_match": True, "total_gt": 2, "total_pred": 2
        },
        {
            "tp": 1, "fp": 1, "fn": 0,
            "exact_matches": 1, "tolerance_matches": 1,
            "unit_matches": 1, "hallucinations": 1,
            "category_match": False, "total_gt": 1, "total_pred": 2
        }
    ]
    
    summary = calc.compute_aggregate_metrics(doc_evals, execution_times=[100.0, 120.0])
    
    assert isinstance(summary, BenchmarkMetricsSummary)
    assert summary.total_documents == 2
    assert summary.total_ground_truth_parameters == 3
    assert summary.total_predicted_parameters == 4
    # Precision: 3 / 4 = 0.75
    assert summary.precision == 0.75
    # Recall: 3 / 3 = 1.0
    assert summary.recall == 1.0
    # F1: 2 * (0.75 * 1.0) / 1.75 = 0.8571
    assert summary.f1_score == 0.8571
    assert summary.mean_latency_ms == 110.0
    assert summary.hallucination_rate == 0.25  # 1 hallucination out of 4 predictions
