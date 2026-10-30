import os
import time
from typing import Optional, Dict, Any
import yaml

from .model_interface import (
    BaseModelInterface,
    ModelResponse,
    ModelNotConfiguredError,
    WeightsNotFoundError,
    RuntimeUnavailableError,
    InferenceExecutionError,
)


class GGUFRuntimeAdapter(BaseModelInterface):
    """
    Adapter for running quantized GGUF models using llama.cpp via llama-cpp-python.
    Designed for alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF or compatible models.
    
    Strict Error-Handling Principle:
    If weights or the runtime library are missing, this adapter raises explicit configuration
    errors. It NEVER invents, mocks, or substitutes fake model completions.
    """

    def __init__(self, config_path: Optional[str] = None):
        if config_path is None:
            config_path = os.path.join(
                os.path.dirname(__file__), "../../config/model_config.yaml"
            )

        self.config_path = os.path.abspath(config_path)
        self.config = self._load_config()
        self._llm_instance = None

    def _load_config(self) -> Dict[str, Any]:
        if not os.path.exists(self.config_path):
            return {}
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
        except Exception as e:
            raise ModelNotConfiguredError(f"Failed to read model configuration: {e}")

    def is_configured(self) -> bool:
        """
        Returns True ONLY if model weights path is set, exists on disk, and runtime is importable.
        """
        weights_path = self.config.get("model", {}).get("local_weights_path")
        if not weights_path or not os.path.exists(weights_path):
            return False

        try:
            import llama_cpp  # noqa: F401
            return True
        except ImportError:
            return False

    def _get_llama_class(self):
        try:
            from llama_cpp import Llama
            return Llama
        except ImportError:
            raise RuntimeUnavailableError(
                "The 'llama-cpp-python' library is not installed.\n"
                "To execute GGUF models locally, install it via:\n"
                "  CPU: pip install llama-cpp-python\n"
                "  Apple Silicon: CMAKE_ARGS=\"-DGGML_METAL=on\" pip install llama-cpp-python\n"
                "  NVIDIA CUDA: CMAKE_ARGS=\"-DGGML_CUDA=on\" pip install llama-cpp-python"
            )

    def _initialize_runtime(self):
        if self._llm_instance is not None:
            return

        weights_path = self.config.get("model", {}).get("local_weights_path")
        if not weights_path:
            raise ModelNotConfiguredError(
                "Model weights path is not configured.\n"
                "Please specify 'model.local_weights_path' in config/model_config.yaml\n"
                "pointing to the downloaded .gguf file (e.g. IQ3_S/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-00001-of-00002.gguf).\n"
                "Weights are not downloaded automatically to avoid consuming hundreds of gigabytes."
            )

        if not os.path.exists(weights_path):
            raise WeightsNotFoundError(
                f"Model weights file not found at: {weights_path}\n"
                "Ensure you have downloaded the GGUF file from Hugging Face into your local directory."
            )

        Llama = self._get_llama_class()
        runtime_cfg = self.config.get("runtime", {})

        try:
            self._llm_instance = Llama(
                model_path=weights_path,
                n_ctx=runtime_cfg.get("context_length", 8192),
                n_threads=runtime_cfg.get("n_threads", 8),
                n_gpu_layers=runtime_cfg.get("n_gpu_layers", 0),
                n_batch=runtime_cfg.get("n_batch", 512),
                verbose=runtime_cfg.get("verbose", False),
            )
        except Exception as e:
            raise InferenceExecutionError(f"Failed to initialize llama.cpp model runtime: {e}")

    def analyze_text(self, prompt: str, **kwargs) -> ModelResponse:
        """
        Submits prompt to llama.cpp runtime for analysis.
        Strictly requires real model weights and runtime.
        """
        self._initialize_runtime()

        runtime_cfg = self.config.get("runtime", {})
        max_tokens = kwargs.get("max_tokens", runtime_cfg.get("max_output_tokens", 2048))
        temperature = kwargs.get("temperature", runtime_cfg.get("temperature", 0.1))
        top_p = kwargs.get("top_p", runtime_cfg.get("top_p", 0.95))
        repeat_penalty = kwargs.get("repeat_penalty", runtime_cfg.get("repeat_penalty", 1.05))

        start_time = time.perf_counter()
        try:
            output = self._llm_instance(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                top_p=top_p,
                repeat_penalty=repeat_penalty,
                stop=["<|im_end|>", "<|endoftext|>", "```\n\n"],
            )
            elapsed_ms = (time.perf_counter() - start_time) * 1000.0

            text_content = output.get("choices", [{}])[0].get("text", "").strip()
            usage = output.get("usage", {})

            return ModelResponse(
                text=text_content,
                raw_output=output,
                prompt_tokens=usage.get("prompt_tokens"),
                completion_tokens=usage.get("completion_tokens"),
                latency_ms=round(elapsed_ms, 2),
                model_name=self.config.get("model", {}).get("repository_id"),
            )
        except Exception as e:
            raise InferenceExecutionError(f"GGUF inference failed during execution: {e}")

    def get_model_metadata(self) -> Dict[str, Any]:
        return {
            "repository_id": self.config.get("model", {}).get("repository_id"),
            "base_model": self.config.get("model", {}).get("base_model"),
            "format": self.config.get("model", {}).get("format", "GGUF"),
            "recommended_quantization": self.config.get("model", {}).get("quantizations", {}).get("recommended"),
            "context_length": self.config.get("runtime", {}).get("context_length"),
            "is_configured": self.is_configured(),
            "local_weights_path": self.config.get("model", {}).get("local_weights_path"),
        }
