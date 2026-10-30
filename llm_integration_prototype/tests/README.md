# 🧪 Test Suite for LLM Integration Prototype

This directory contains standalone unit and validation tests for the experimental prototype.

## Running Tests

From the `llm_integration_prototype/` directory:

```bash
# Run all unit tests
pytest tests/ -v

# Run a specific test module
pytest tests/test_document_preprocessor.py -v
pytest tests/test_structured_output.py -v
pytest tests/test_model_interface.py -v
pytest tests/test_extraction_metrics.py -v
```

## Test Coverage
- **Preprocessing**: Verifies safe character normalization without altering numbers, decimals, or units.
- **Structured Output**: Verifies JSON decoding, Pydantic schema validation, grounding checks, and physiological boundary warnings.
- **Model Interface**: Verifies error handling when model weights or GGUF runtimes are not configured.
- **Evaluation Metrics**: Verifies mathematical accuracy of Precision, Recall, F1, exact match, and unit normalization.
