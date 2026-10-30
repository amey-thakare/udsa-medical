# 🔬 Model Selection & Technical Analysis: Qwen3.8-Flash-Next GGUF

## 1. Upstream Model Identification

- **Repository**: [`alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF`](https://huggingface.co/alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF)
- **Base Model**: `ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF`
- **Architecture**: Large-scale Mixture-of-Experts (MoE) Multimodal Vision-Language Model
- **Pipeline Tag**: `image-text-to-text`
- **License**: `qwen-community-license-1.0`

---

## 2. Technical Anatomy: Decoding the Model Name

The name represents several advanced engineering techniques:

### 1. Qwen3.8-Flash-Next
A high-throughput Mixture-of-Experts (MoE) foundation model designed for ultra-long context understanding (up to 131K-262K tokens) and high inference velocity.

### 2. Abliterated
- **Mechanism**: The model has undergone directional abliteration (orthogonal projection of refusal vectors, e.g. using `Huihui-Qwen3.8-Flash-Next-refusal-direction-r.gguf` across layers 1–47).
- **Clinical Relevance**: Standard commercial alignment often triggers false-positive refusals when encountering sensitive medical reports (e.g. mentions of narcotic painkillers, toxicology panels, lethal overdoses, controlled substances, or end-of-life discharge summaries). An abliterated model reliably processes clinical documents without censoring diagnostic terminology.

### 3. GSQ (Gumbel-Softmax Quantization)
- **Research**: *GSQ: Highly-Accurate Low-Precision Scalar Quantization for LLMs via Gumbel-Softmax Sampling* (arXiv:2604.18556, ISTA-DASLab).
- **Function**: Uses differentiable relaxation during quantization, allowing weights to be compressed down to 2–3 bits per parameter while avoiding the steep accuracy drop typical of naive post-training rounding.

### 4. RCO (Riemannian Constrained Optimization)
- **Research**: *Model Compression with Exact Budget Constraints via Riemannian Manifolds* (arXiv:2605.00649).
- **Function**: Constrains the compressed weight manifolds geometrically, preserving critical expert routing channels in the MoE layers.

### 5. Strata
A tiered memory-allocation and tensor-mapping layout that optimizes page-fault handling and token generation across unified memory (e.g. Apple Silicon Metal) and split host RAM/VRAM configurations.

### 6. GGUF
The universal binary format developed by the `llama.cpp` community, packing tensor metadata, tokenizer vocabulary, and quantized weights into self-contained shards.

---

## 3. Hugging Face Transformers vs. GGUF: Key Differences

| Dimension | Hugging Face Transformers (`safetensors`) | GGUF Quantized Format (`.gguf`) |
|---|---|---|
| **Weight Format** | FP16, BF16, or FP8 unquantized tensor shards | Block-quantized integer tensors (2-bit, 3-bit, 4-bit, 8-bit) |
| **Direct Loader** | `AutoModelForCausalLM.from_pretrained()` | Requires `llama.cpp` / `llama-cpp-python` / `ollama` / `vLLM` |
| **Memory Footprint** | Extremely heavy (30GB - 70GB+ VRAM required) | Highly compressed (8GB - 24GB total RAM/VRAM) |
| **Hardware Target** | High-end GPU clusters (A100, H100) | Local workstations, Apple Silicon Macs, consumer GPUs |
| **Why Not Transformers?** | GGUF files CANNOT be loaded directly via vanilla `AutoModelForCausalLM` without a specialized C++ GGML backend. | Native execution engine built from the ground up for CPU/GPU hybrid offloading. |

---

## 4. Available Shards & Quantization Comparison

The upstream Hugging Face repository provides the following quantized arms:

| Quantization Arm | Approximate Bits/Weight | Memory Footprint | Decode Speed (tokens/s) | Top-1 Match vs. BF16 | Recommended Use Case |
|---|---|---|---|---|---|
| **`IQ2_XS`** | ~2.2 bits | ~10 - 14 GB | 84 - 87 t/s | 87.4% - 87.8% | Memory-constrained workstations; ultra-fast inference |
| **`IQ3_S`** | ~3.3 bits | ~16 - 20 GB | 58 - 59 t/s | **92.8% - 93.0%** | **Recommended Sweet Spot**: Highest clinical fidelity |
| **`IQ3_XXS`** | ~3.1 bits | ~14 - 18 GB | ~65 t/s | ~90.5% | Intermediate balance |
| **`Q2_0`** | 2.0 bits (Legacy) | ~11 - 15 GB | ~75 t/s | ~85.0% | Legacy compatibility |

### Additional Shards in Repository:
- **`mmproj-Qwen3.8-Flash-Next-BF16.gguf`**: The multimodal vision projector. Required ONLY if feeding raw images directly to llama.cpp instead of text. In this prototype, our primary design pattern feeds already-extracted OCR text to the language model, making this optional.
- **`Huihui-Qwen3.8-Flash-Next-refusal-direction-r.gguf`**: The refusal direction vector applied during abliteration.

---

## 5. Context Window & Needle-in-a-Haystack Verification

The upstream card confirms:
- **Maximum Context**: 131,072 to 262,144 tokens.
- **Needle-in-a-Haystack**: 6 of 6 needles successfully retrieved at 32K and 115K prompt depths.
- **Prototype Setting**: For medical documents, we configure `context_length: 8192` in `config/model_config.yaml`. This comfortably handles multi-page lab reports (typically 500 to 2,500 tokens) with minimal KV-cache memory overhead.

---

## 6. Model Weight Acquisition Policy

**Policy**: Model weights are NOT automatically downloaded during repository checkout, setup, or test execution.
- Total repository size exceeds 295 GB across all quant variants.
- Individual sharded files for `IQ3_S` require ~16–20 GB of bandwidth and disk space.
- To use local inference, the user manually downloads their chosen variant using the Hugging Face CLI:
  ```bash
  huggingface-cli download alesha-pro/Qwen3.8-Flash-Next-abliterated-GSQ-RCO-Strata-GGUF \
    --include "IQ3_S/*" \
    --local-dir ./weights/IQ3_S
  ```
- Until weights are provided, all prototype tests run cleanly using mocked adapters, and benchmark metrics remain marked as `PENDING`.
