from enum import Enum
from typing import List, Optional, Union, Dict, Any
from datetime import datetime, timezone
from pydantic import BaseModel, Field, field_validator


class MedicalCategory(str, Enum):
    """
    Standard medical document categories in MyHealthMitra.
    Preserves exact alignment with backend/src/services/categorizer.ts.
    """
    BLOOD_TEST = "Blood Test"
    LAB_REPORT = "Lab Report"
    PRESCRIPTION = "Prescription"
    SCAN_REPORT = "Scan Report"
    DISCHARGE_SUMMARY = "Discharge Summary"
    MEDICAL_BILL = "Medical Bill"
    GENERAL_OR_OTHER = "General or Other"


class ValidationStatus(str, Enum):
    """
    Status of extracted parameter validation against source text and physiological bounds.
    """
    VALID = "VALID"
    PLAUSIBLE_RANGE_WARNING = "PLAUSIBLE_RANGE_WARNING"
    UNSUPPORTED_SOURCE_TEXT = "UNSUPPORTED_SOURCE_TEXT"
    INVALID_FORMAT = "INVALID_FORMAT"


# Biologically plausible clinical limits matching backend/src/services/paramExtractor.ts
# Used strictly as safety filters to catch OCR/LLM digit corruption, never for clinical diagnosis.
PHYSIOLOGICAL_LIMITS: Dict[str, Dict[str, Any]] = {
    "glucose": {"min": 30.0, "max": 600.0, "default_unit": "mg/dL", "display_name": "Blood Glucose"},
    "hemoglobin": {"min": 3.0, "max": 25.0, "default_unit": "g/dL", "display_name": "Hemoglobin"},
    "systolic_bp": {"min": 60.0, "max": 250.0, "default_unit": "mmHg", "display_name": "Systolic Blood Pressure"},
    "diastolic_bp": {"min": 30.0, "max": 160.0, "default_unit": "mmHg", "display_name": "Diastolic Blood Pressure"},
    "cholesterol": {"min": 50.0, "max": 500.0, "default_unit": "mg/dL", "display_name": "Total Cholesterol"},
    "heart_rate": {"min": 30.0, "max": 250.0, "default_unit": "bpm", "display_name": "Heart Rate"},
    "hba1c": {"min": 3.0, "max": 18.0, "default_unit": "%", "display_name": "HbA1c"},
    "creatinine": {"min": 0.1, "max": 20.0, "default_unit": "mg/dL", "display_name": "Serum Creatinine"},
    "wbc": {"min": 500.0, "max": 100000.0, "default_unit": "cells/uL", "display_name": "WBC Count"},
    "platelets": {"min": 0.1, "max": 20.0, "default_unit": "lakh/uL", "display_name": "Platelet Count"},
}


class ExtractedParameter(BaseModel):
    """
    Structured representation of a single extracted clinical biomarker.
    Requires explicit supporting text from the source to prevent hallucinations.
    """
    parameter_key: str = Field(
        ...,
        description="Standardized biomarker key (e.g., glucose, hemoglobin, systolic_bp, etc.)"
    )
    display_name: str = Field(
        ...,
        description="Human-readable clinical label (e.g., Fasting Blood Glucose, Hemoglobin)"
    )
    value: Union[float, int, str] = Field(
        ...,
        description="Numeric measurement or explicitly verified non-numeric clinical value"
    )
    unit: str = Field(
        ...,
        description="Standard clinical unit (e.g., mg/dL, g/dL, mmHg, %, cells/uL, bpm)"
    )
    measurement_date: Optional[str] = Field(
        default=None,
        description="Date of measurement if explicitly stated in document, otherwise None. Never invented."
    )
    reference_range: Optional[str] = Field(
        default=None,
        description="Reference interval only if explicitly stated in source (e.g. '12.0 - 17.5'). Never invented."
    )
    supporting_source_text: str = Field(
        ...,
        description="Verbatim text snippet from OCR document containing this reading, for traceability"
    )
    validation_status: ValidationStatus = Field(
        default=ValidationStatus.VALID,
        description="Validation result based on grounding and physiological boundary check"
    )
    model_confidence: Optional[float] = Field(
        default=None,
        description="Calibrated probability score if produced by runtime, otherwise None. Never fabricated."
    )

    @field_validator("parameter_key")
    @classmethod
    def normalize_parameter_key(cls, v: str) -> str:
        return v.strip().lower()


class DocumentAnalysisResult(BaseModel):
    """
    Complete structured output schema for analyzed medical documents.
    """
    document_category: MedicalCategory = Field(
        ...,
        description="Classified medical document category"
    )
    category_confidence: Optional[float] = Field(
        default=None,
        description="Category confidence score if model provides calibrated output, otherwise None"
    )
    tags: List[str] = Field(
        default_factory=list,
        description="Relevant clinical tags (e.g., Complete Blood Count, Lipid Profile)"
    )
    summary: Optional[str] = Field(
        default=None,
        description="Factual, neutral summary grounded strictly in document contents"
    )
    parameters: List[ExtractedParameter] = Field(
        default_factory=list,
        description="List of extracted, grounded medical parameters"
    )
    raw_model_response: Optional[str] = Field(
        default=None,
        description="Raw output string from model for auditing"
    )
    extracted_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat(),
        description="UTC ISO timestamp of extraction"
    )
    traceability_verified: bool = Field(
        default=False,
        description="True if all extracted parameters were verified against source OCR text"
    )
