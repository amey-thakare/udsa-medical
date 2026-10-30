import json
import re
from typing import Optional, List, Dict, Any, Tuple
from ..model.model_interface import BaseModelInterface
from ..schemas.medical_parameters import MedicalCategory


CLASSIFICATION_PROMPT = """You are a medical document classifier.
Classify the following medical document text into exactly ONE of the following categories:
- "Blood Test" (e.g. CBC, lipid profile, blood glucose, LFT, KFT)
- "Lab Report" (e.g. urinalysis, biopsy, culture, stool test, pathology)
- "Prescription" (doctor Rx, medications, dosages, frequency)
- "Scan Report" (X-ray, MRI, CT, ultrasound, PET scan)
- "Discharge Summary" (hospital admission/discharge, surgical summary)
- "Medical Bill" (invoices, hospital pharmacy bills, receipt)
- "General or Other" (non-medical text, administrative notes, or unclassifiable)

Also provide 1 to 5 relevant clinical tags.

Respond ONLY with a valid JSON object matching:
{
  "category": "Blood Test | Lab Report | Prescription | Scan Report | Discharge Summary | Medical Bill | General or Other",
  "confidence": null,
  "tags": ["Tag1", "Tag2"],
  "reasoning": "Brief 1-sentence justification"
}
"""


class DocumentClassifier:
    """
    Independent document classification interface.
    Separated from the production categorizer (backend/src/services/categorizer.ts)
    to enable unbiased comparative evaluation between rule-based heuristics and LLMs.
    """

    def __init__(self, model_interface: Optional[BaseModelInterface] = None):
        self.model = model_interface

    def build_classification_prompt(self, document_text: str) -> str:
        return f"{CLASSIFICATION_PROMPT}\n\n--- DOCUMENT TEXT ---\n{document_text}\n--- END DOCUMENT TEXT ---\n\nJSON Output:"

    def classify_with_model(self, document_text: str) -> Tuple[MedicalCategory, List[str], Optional[float], str]:
        """
        Classifies document using the configured language model.
        Returns (category, tags, confidence, reasoning).
        """
        if not self.model:
            raise RuntimeError("Model interface is not configured for DocumentClassifier.")

        prompt = self.build_classification_prompt(document_text)
        response = self.model.analyze_text(prompt)

        text = response.text.strip()
        fence_match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text, re.IGNORECASE)
        if fence_match:
            text = fence_match.group(1).strip()
        elif "{" in text and "}" in text:
            brace_match = re.search(r"(\{[\s\S]*\})", text)
            if brace_match:
                text = brace_match.group(1).strip()

        data = json.loads(text)
        raw_category = data.get("category", "General or Other")

        # Map to enum safely
        category = self._normalize_category(raw_category)
        tags = data.get("tags", [])
        confidence = data.get("confidence")
        reasoning = data.get("reasoning", "")

        return category, tags, confidence, reasoning

    @staticmethod
    def _normalize_category(category_str: str) -> MedicalCategory:
        norm = category_str.strip().lower()
        mapping = {
            "blood test": MedicalCategory.BLOOD_TEST,
            "lab report": MedicalCategory.LAB_REPORT,
            "prescription": MedicalCategory.PRESCRIPTION,
            "scan report": MedicalCategory.SCAN_REPORT,
            "discharge summary": MedicalCategory.DISCHARGE_SUMMARY,
            "medical bill": MedicalCategory.MEDICAL_BILL,
            "general or other": MedicalCategory.GENERAL_OR_OTHER,
            "general": MedicalCategory.GENERAL_OR_OTHER,
            "other": MedicalCategory.GENERAL_OR_OTHER,
        }
        return mapping.get(norm, MedicalCategory.GENERAL_OR_OTHER)
