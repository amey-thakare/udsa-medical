import pytest
from src.model.model_interface import (
    BaseModelInterface,
    ModelResponse,
    ModelNotConfiguredError,
    WeightsNotFoundError,
)
from src.model.gguf_runtime_adapter import GGUFRuntimeAdapter


class DummyMockModel(BaseModelInterface):
    """Simple mock implementing BaseModelInterface for testing."""
    def analyze_text(self, prompt: str, **kwargs) -> ModelResponse:
        return ModelResponse(
            text='{"document_category": "Blood Test", "parameters": []}',
            raw_output={"mock": True},
            prompt_tokens=15,
            completion_tokens=20,
            latency_ms=12.5,
            model_name="mock-model",
        )

    def is_configured(self) -> bool:
        return True

    def get_model_metadata(self):
        return {"mock": True}


def test_mock_model_interface_contract():
    model = DummyMockModel()
    assert model.is_configured() is True
    res = model.analyze_text("Test prompt")
    assert isinstance(res, ModelResponse)
    assert res.prompt_tokens == 15
    assert res.latency_ms == 12.5


def test_gguf_adapter_unconfigured_raises_error():
    # Adapter initialized with empty or non-existent weight config
    adapter = GGUFRuntimeAdapter()
    # By default in config/model_config.yaml, local_weights_path is null
    assert adapter.is_configured() is False

    with pytest.raises(ModelNotConfiguredError, match="Model weights path is not configured"):
        adapter.analyze_text("Hello model")


def test_gguf_adapter_missing_file_raises_weights_not_found(tmp_path):
    # Create temporary config pointing to a file that does not exist
    fake_config = tmp_path / "model_config.yaml"
    fake_config.write_text("""
model:
  repository_id: "test/repo"
  local_weights_path: "/non/existent/path/weights.gguf"
runtime:
  context_length: 2048
""")
    adapter = GGUFRuntimeAdapter(config_path=str(fake_config))
    assert adapter.is_configured() is False

    with pytest.raises(WeightsNotFoundError, match="Model weights file not found"):
        adapter.analyze_text("Hello model")
