from typing import Optional
from ..model.model_interface import BaseModelInterface
from ..preprocessing.document_preprocessor import PreprocessedDocument, DocumentPreprocessor
from ..schemas.medical_parameters import DocumentAnalysisResult
from .structured_output import StructuredOutputParser


EXTRACTION_SYSTEM_PROMPT = """You are a specialized clinical document extraction system.
Analyze the following OCR-extracted medical report text and extract structured health parameters and categorization.

RULES:
1. Extract ONLY information explicitly present in the source text.
2. NEVER invent, hallucinate, or assume missing values, units, dates, or reference ranges.
3. If a reference range is not stated in the source text, set "reference_range": null.
4. If a measurement date is not stated in the source text, set "measurement_date": null.
5. For "supporting_source_text", copy the EXACT text snippet from the document containing this measurement.
6. Target parameter keys to look for:
   - "glucose": Fasting or random blood sugar / glucose
   - "hemoglobin": Hemoglobin / Hb
   - "systolic_bp": Systolic blood pressure (e.g. 120 from 120/80 mmHg)
   - "diastolic_bp": Diastolic blood pressure (e.g. 80 from 120/80 mmHg)
   - "cholesterol": Total cholesterol
   - "heart_rate": Pulse / heart rate
   - "hba1c": Glycated hemoglobin / HbA1c
   - "creatinine": Serum creatinine
   - "wbc": Total WBC count / Leukocytes
   - "platelets": Platelet count
7. Document category MUST be strictly one of:
   - "Blood Test"
   - "Lab Report"
   - "Prescription"
   - "Scan Report"
   - "Discharge Summary"
   - "Medical Bill"
   - "General or Other"
8. Do NOT provide medical diagnoses, treatment advice, or speculative clinical commentary.

RESPONSE FORMAT:
You MUST respond with a single valid JSON object strictly matching this schema:
{
  "document_category": "Blood Test | Lab Report | Prescription | Scan Report | Discharge Summary | Medical Bill | General or Other",
  "category_confidence": null,
  "tags": ["Tag1", "Tag2"],
  "summary": "Factual 1-2 sentence neutral summary of document contents.",
  "parameters": [
    {
      "parameter_key": "glucose | hemoglobin | systolic_bp | diastolic_bp | cholesterol | heart_rate | hba1c | creatinine | wbc | platelets",
      "display_name": "Human-readable label",
      "value": 123.4,
      "unit": "standard clinical unit",
      "measurement_date": null,
      "reference_range": null,
      "supporting_source_text": "Exact text snippet from document",
      "model_confidence": null
    }
  ]
}
"""


class MedicalParameterExtractor:
    """
    Orchestrates prompt generation, model inference, and output validation for clinical parameter extraction.
    """

    def __init__(
        self,
        model_interface: BaseModelInterface,
        preprocessor: Optional[DocumentPreprocessor] = None,
        parser: Optional[StructuredOutputParser] = None,
        strict_grounding: bool = True,
    ):
        self.model = model_interface
        self.preprocessor = preprocessor or DocumentPreprocessor()
        self.parser = parser or StructuredOutputParser()
        self.strict_grounding = strict_grounding

    def build_prompt(self, document_text: str) -> str:
        """
        Builds the complete inference prompt embedding the OCR document text.
        """
        return f"{EXTRACTION_SYSTEM_PROMPT}\n\n--- DOCUMENT TEXT ---\n{document_text}\n--- END DOCUMENT TEXT ---\n\nJSON Output:"

    def extract_from_document(
        self, document: PreprocessedDocument
    ) -> DocumentAnalysisResult:
        """
        Extracts parameters and categorization from a preprocessed document.
        """
        prompt = self.build_prompt(document.cleaned_text)
        response = self.model.analyze_text(prompt)

        return self.parser.parse_and_validate(
            raw_model_output=response.text,
            source_document=document.raw_text,
            strict_grounding=self.strict_grounding,
        )

    def extract_from_raw_text(self, raw_ocr_text: str) -> DocumentAnalysisResult:
        """
        End-to-end convenience method: preprocesses raw text, invokes model, and parses result.
        """
        preprocessed = self.preprocessor.preprocess(raw_ocr_text)
        return self.extract_from_document(preprocessed)
