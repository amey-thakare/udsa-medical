import pytest
from src.categorization.document_classifier import DocumentClassifier
from src.schemas.medical_parameters import MedicalCategory
from src.model.model_interface import BaseModelInterface, ModelResponse


class MockClassifierModel(BaseModelInterface):
    def __init__(self, json_response: str):
        self._resp = json_response

    def is_configured(self) -> bool:
        return True

    def get_model_metadata(self):
        return {"model_name": "mock-qwen"}

    def analyze_text(self, prompt: str, **kwargs) -> ModelResponse:
        return ModelResponse(text=self._resp, model_name="mock-qwen")


def test_classifier_normalization():
    assert DocumentClassifier._normalize_category("Blood Test") == MedicalCategory.BLOOD_TEST
    assert DocumentClassifier._normalize_category("scan report") == MedicalCategory.SCAN_REPORT
    assert DocumentClassifier._normalize_category("unknown random") == MedicalCategory.GENERAL_OR_OTHER


def test_classifier_with_model():
    mock_json = '{"category": "Blood Test", "confidence": 0.95, "tags": ["CBC", "Hematology"], "reasoning": "Contains CBC metrics"}'
    classifier = DocumentClassifier(model_interface=MockClassifierModel(mock_json))

    category, tags, confidence, reasoning = classifier.classify_with_model("Sample CBC text")
    assert category == MedicalCategory.BLOOD_TEST
    assert "CBC" in tags
    assert confidence == 0.95
    assert "CBC metrics" in reasoning


def test_classifier_unconfigured_model_raises_runtime_error():
    classifier = DocumentClassifier(model_interface=None)
    with pytest.raises(RuntimeError):
        classifier.classify_with_model("Some text")
