import pytest
from src.preprocessing.document_preprocessor import DocumentPreprocessor, PreprocessedDocument


def test_empty_document():
    preprocessor = DocumentPreprocessor()
    result = preprocessor.preprocess("")
    assert isinstance(result, PreprocessedDocument)
    assert result.cleaned_text == ""
    assert result.line_count == 0
    assert result.character_count == 0


def test_unicode_and_space_normalization():
    preprocessor = DocumentPreprocessor()
    # String containing non-breaking spaces, smart quotes, em-dash, and extra spaces
    sample = "Hemoglobin:\u00A0\u00A013.8\u201314.2\u00A0g/dL\r\nDoctor\u2019s Note:\u201CPatient normal\u201D"
    
    result = preprocessor.preprocess(sample)
    
    # Original raw text must be preserved exactly
    assert result.raw_text == sample
    
    # Cleaned text should replace NBSP with regular space and normalize quotes/dashes
    assert "13.8-14.2 g/dL" in result.cleaned_text
    assert "Doctor's Note" in result.cleaned_text
    assert '"Patient normal"' in result.cleaned_text
    assert "\r" not in result.cleaned_text


def test_clinical_numbers_and_symbols_preserved():
    preprocessor = DocumentPreprocessor()
    sample = """
    Complete Blood Count
    Hemoglobin: 13.8 g/dL
    WBC Count: 7,200 cells/uL
    Platelet Count: 2.5 lakh/uL
    Blood Pressure: 118/76 mmHg
    HbA1c: 5.4 %
    """
    result = preprocessor.preprocess(sample)
    
    assert "13.8 g/dL" in result.cleaned_text
    assert "7,200 cells/uL" in result.cleaned_text
    assert "2.5 lakh/uL" in result.cleaned_text
    assert "118/76 mmHg" in result.cleaned_text
    assert "5.4 %" in result.cleaned_text
    assert result.line_count == 6
