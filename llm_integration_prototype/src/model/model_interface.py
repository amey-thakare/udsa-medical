from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Optional, Dict, Any


class ModelInterfaceError(Exception):
    """Base exception for all model interface errors."""
    pass


class ModelNotConfiguredError(ModelInterfaceError):
    """Raised when the model interface is invoked without valid configuration."""
    pass


class WeightsNotFoundError(ModelInterfaceError):
    """Raised when specified GGUF weight files cannot be found on disk."""
    pass


class RuntimeUnavailableError(ModelInterfaceError):
    """Raised when the required inference runtime (e.g. llama-cpp-python) is not installed."""
    pass


class InferenceExecutionError(ModelInterfaceError):
    """Raised when the underlying runtime encounters an error during prompt evaluation."""
    pass


@dataclass
class ModelResponse:
    """
    Standardized response returned by any BaseModelInterface implementation.
    """
    text: str
    raw_output: Dict[str, Any] = field(default_factory=dict)
    prompt_tokens: Optional[int] = None
    completion_tokens: Optional[int] = None
    latency_ms: Optional[float] = None
    model_name: Optional[str] = None


class BaseModelInterface(ABC):
    """
    Common abstract interface for language model inference.
    Defines how text is submitted for analysis and how generated responses are returned.
    Ensures that experimental components interact through a uniform API regardless of whether
    inference is powered by llama.cpp, an internal server, or a remote endpoint.
    """

    @abstractmethod
    def analyze_text(self, prompt: str, **kwargs) -> ModelResponse:
        """
        Submits text/prompt for model analysis and returns a standardized ModelResponse.
        
        Raises:
            ModelNotConfiguredError: If configuration is missing or invalid.
            WeightsNotFoundError: If local weight files do not exist.
            RuntimeUnavailableError: If required runtime library is not installed.
            InferenceExecutionError: If runtime execution fails.
        """
        pass

    @abstractmethod
    def is_configured(self) -> bool:
        """
        Checks whether the model runtime and weights are properly configured and available.
        """
        pass

    @abstractmethod
    def get_model_metadata(self) -> Dict[str, Any]:
        """
        Returns runtime configuration metadata (architecture, context length, quant, etc.).
        """
        pass
