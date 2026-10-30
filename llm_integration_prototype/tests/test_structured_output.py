import pytest
from src.extraction.structured_output import StructuredOutputParser
from src.schemas.medical_parameters import (
    DocumentAnalysisResult,
    MedicalCategory,
    ValidationStatus,
)


SAMPLE_SOURCE_DOC = """
Complete Blood Count
Hemoglobin: 13.8 g/dL
WBC Count: 7,200 cells/uL
Fasting Blood Glucose: 104 mg/dL
"""

VALID_MODEL_JSON = """```json
{
  "document_category": "Blood Test",
  "category_confidence": null,
  "tags": ["Complete Blood Count"],
  "summary": "Routine blood count.",
  "parameters": [
    {
      "parameter_key": "hemoglobin",
      "display_name": "Hemoglobin",
      "value": 13.8,
      "unit": "g/dL",
      "measurement_date": null,
      "reference_range": null,
      "supporting_source_text": "Hemoglobin: 13.8 g/dL",
      "model_confidence": null
    },
    {
      "parameter_key": "glucose",
      "display_name": "Fasting Blood Glucose",
      "value": 104,
      "unit": "mg/dL",
      "measurement_date": null,
      "reference_range": null,
      "supporting_source_text": "Fasting Blood Glucose: 104 mg/dL",
      "model_confidence": null
    }
  ]
}
```"""


def test_json_payload_extraction():
    parser = StructuredOutputParser()
    payload = parser.extract_json_payload(VALID_MODEL_JSON)
    assert payload["document_category"] == "Blood Test"
    assert len(payload["parameters"]) == 2


def test_valid_parsing_and_grounding():
    parser = StructuredOutputParser()
    result = parser.parse_and_validate(VALID_MODEL_JSON, SAMPLE_SOURCE_DOC)
    
    assert isinstance(result, DocumentAnalysisResult)
    assert result.document_category == MedicalCategory.BLOOD_TEST
    assert len(result.parameters) == 2
    assert result.parameters[0].validation_status == ValidationStatus.VALID
    assert result.parameters[1].validation_status == ValidationStatus.VALID
    assert result.traceability_verified is True


def test_unsupported_source_text_flagged():
    parser = StructuredOutputParser()
    # Model hallucinated Cholesterol which is NOT in SAMPLE_SOURCE_DOC
    hallucinated_json = """{
      "document_category": "Blood Test",
      "parameters": [
        {
          "parameter_key": "cholesterol",
          "display_name": "Total Cholesterol",
          "value": 240,
          "unit": "mg/dL",
          "supporting_source_text": "Cholesterol: 240 mg/dL"
        }
      ]
    }"""
    result = parser.parse_and_validate(hallucinated_json, SAMPLE_SOURCE_DOC, strict_grounding=True)
    assert len(result.parameters) == 1
    assert result.parameters[0].validation_status == ValidationStatus.UNSUPPORTED_SOURCE_TEXT
    assert result.traceability_verified is False


def test_physiological_range_warning():
    parser = StructuredOutputParser()
    # Source contains an erroneous Hemoglobin reading of 138 (dropped decimal point from 13.8)
    corrupted_source = "Hemoglobin: 138 g/dL"
    corrupted_json = """{
      "document_category": "Blood Test",
      "parameters": [
        {
          "parameter_key": "hemoglobin",
          "display_name": "Hemoglobin",
          "value": 138.0,
          "unit": "g/dL",
          "supporting_source_text": "Hemoglobin: 138 g/dL"
        }
      ]
    }"""
    result = parser.parse_and_validate(corrupted_json, corrupted_source)
    assert len(result.parameters) == 1
    # Grounding succeeds, but physiological range check flags it!
    assert result.parameters[0].validation_status == ValidationStatus.PLAUSIBLE_RANGE_WARNING


def test_malformed_json_raises_value_error():
    parser = StructuredOutputParser()
    with pytest.raises(ValueError, match="No valid JSON object could be parsed"):
        parser.parse_and_validate("This is plain text with no JSON at all.", SAMPLE_SOURCE_DOC)
