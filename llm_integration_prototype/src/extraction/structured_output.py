import json
import re
from typing import Dict, Any, Tuple, Optional, List
from pydantic import ValidationError

from ..schemas.medical_parameters import (
    DocumentAnalysisResult,
    ExtractedParameter,
    ValidationStatus,
    PHYSIOLOGICAL_LIMITS,
)


class StructuredOutputParser:
    """
    Parses and validates model-generated text into strict DocumentAnalysisResult schemas.
    Applies grounding verification against the source document and physiological sanity checks.
    """

    @staticmethod
    def extract_json_payload(raw_text: str) -> Dict[str, Any]:
        """
        Extracts JSON object from model output, handling markdown code fences or conversational text.
        """
        if not raw_text or not raw_text.strip():
            raise ValueError("Model output is empty or whitespace only.")

        text = raw_text.strip()

        # 1. Check for markdown code fences ```json ... ``` or ``` ... ```
        fence_match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text, re.IGNORECASE)
        if fence_match:
            candidate = fence_match.group(1).strip()
            try:
                return json.loads(candidate)
            except json.JSONDecodeError:
                pass

        # 2. Check for outermost balanced curly braces
        brace_match = re.search(r"(\{[\s\S]*\})", text)
        if brace_match:
            candidate = brace_match.group(1).strip()
            try:
                return json.loads(candidate)
            except json.JSONDecodeError as err:
                raise ValueError(f"Extracted JSON block is malformed: {err}") from err

        # 3. Direct JSON load attempt
        try:
            return json.loads(text)
        except json.JSONDecodeError as err:
            raise ValueError(f"No valid JSON object could be parsed from model response: {err}") from err

    @staticmethod
    def verify_grounding(supporting_text: str, source_document: str) -> bool:
        """
        Verifies whether the supporting text cited by the model actually exists in the source document.
        Case-insensitive and whitespace-flexible matching.
        """
        if not supporting_text or not source_document:
            return False

        # Normalize whitespace in both for honest matching
        norm_support = re.sub(r"\s+", " ", supporting_text.strip().lower())
        norm_source = re.sub(r"\s+", " ", source_document.strip().lower())

        return norm_support in norm_source

    @staticmethod
    def validate_physiological_range(param_key: str, value: Any) -> Tuple[bool, Optional[str]]:
        """
        Checks if a numerical value is within biologically plausible boundaries.
        Returns (is_valid, warning_message).
        """
        limits = PHYSIOLOGICAL_LIMITS.get(param_key.lower())
        if not limits:
            return True, None

        try:
            num_val = float(value)
        except (ValueError, TypeError):
            # Non-numeric value (e.g. text status)
            return True, None

        min_val = limits["min"]
        max_val = limits["max"]

        if num_val < min_val or num_val > max_val:
            warning = (
                f"Value {num_val} for {limits['display_name']} is outside plausible bounds "
                f"({min_val} - {max_val} {limits['default_unit']}). Potential OCR/LLM digit error."
            )
            return False, warning

        return True, None

    def parse_and_validate(
        self,
        raw_model_output: str,
        source_document: str,
        strict_grounding: bool = True,
    ) -> DocumentAnalysisResult:
        """
        Parses raw text, validates against schema, applies safety checks, and returns DocumentAnalysisResult.
        """
        payload = self.extract_json_payload(raw_model_output)

        try:
            result = DocumentAnalysisResult.model_validate(payload)
        except ValidationError as e:
            raise ValueError(f"Model JSON failed schema validation: {e}") from e

        result.raw_model_response = raw_model_output
        all_grounded = True

        # Process each extracted parameter through safety & grounding checks
        validated_parameters: List[ExtractedParameter] = []
        for param in result.parameters:
            # 1. Grounding check
            is_grounded = self.verify_grounding(param.supporting_source_text, source_document)
            if not is_grounded:
                all_grounded = False
                if strict_grounding:
                    param.validation_status = ValidationStatus.UNSUPPORTED_SOURCE_TEXT
            else:
                # 2. Physiological boundary check
                is_plausible, _ = self.validate_physiological_range(param.parameter_key, param.value)
                if not is_plausible:
                    param.validation_status = ValidationStatus.PLAUSIBLE_RANGE_WARNING
                else:
                    param.validation_status = ValidationStatus.VALID

            validated_parameters.append(param)

        result.parameters = validated_parameters
        result.traceability_verified = all_grounded and len(validated_parameters) > 0

        return result
