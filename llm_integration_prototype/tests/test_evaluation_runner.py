import pytest
from src.evaluation.evaluation_runner import RegexBaselineExtractor, EvaluationRunner
from src.schemas.medical_parameters import ExtractedParameter, MedicalCategory


def test_regex_baseline_extraction():
    extractor = RegexBaselineExtractor()
    sample_text = """
    Patient Report:
    Hemoglobin: 13.5 g/dL
    Fasting Blood Sugar: 98 mg/dL
    BP: 120/80 mmHg
    Serum Creatinine: 0.9 mg/dL
    WBC Count: 6800 cells/uL
    Platelet Count: 2.4 lakh/uL
    """
    extracted = extractor.extract(sample_text)
    keys = {p.parameter_key: p.value for p in extracted}

    assert "hemoglobin" in keys
    assert keys["hemoglobin"] == 13.5
    assert "glucose" in keys
    assert keys["glucose"] == 98.0
    assert "systolic_bp" in keys
    assert keys["systolic_bp"] == 120.0
    assert "diastolic_bp" in keys
    assert keys["diastolic_bp"] == 80.0
    assert "creatinine" in keys
    assert keys["creatinine"] == 0.9
    assert "wbc" in keys
    assert keys["wbc"] == 6800.0
    assert "platelets" in keys
    assert keys["platelets"] == 2.4


def test_evaluation_runner_unconfigured_llm_returns_pending():
    runner = EvaluationRunner(llm_extractor=None)
    dataset = [
        {
            "text": "Hemoglobin: 14 g/dL",
            "ground_truth_parameters": [
                ExtractedParameter(
                    parameter_key="hemoglobin",
                    display_name="Hb",
                    value=14.0,
                    unit="g/dL",
                    supporting_source_text="Hemoglobin: 14 g/dL",
                )
            ],
            "ground_truth_category": MedicalCategory.BLOOD_TEST,
        }
    ]
    summary = runner.evaluate_llm(dataset)
    assert "PENDING" in summary.execution_status
    assert summary.total_documents == 1
    assert summary.f1_score == 0.0


def test_evaluation_runner_regex_baseline_benchmark():
    runner = EvaluationRunner(llm_extractor=None)
    dataset = [
        {
            "text": "Hemoglobin: 14 g/dL, Glucose: 100 mg/dL",
            "ground_truth_parameters": [
                ExtractedParameter(
                    parameter_key="hemoglobin",
                    display_name="Hb",
                    value=14.0,
                    unit="g/dL",
                    supporting_source_text="Hemoglobin: 14 g/dL",
                ),
                ExtractedParameter(
                    parameter_key="glucose",
                    display_name="Glucose",
                    value=100.0,
                    unit="mg/dL",
                    supporting_source_text="Glucose: 100 mg/dL",
                ),
            ],
            "ground_truth_category": MedicalCategory.BLOOD_TEST,
        }
    ]
    summary = runner.evaluate_regex_baseline(dataset)
    assert summary.total_documents == 1
    assert summary.total_predicted_parameters == 2
    assert summary.precision == 1.0
    assert summary.recall == 1.0
    assert summary.f1_score == 1.0
