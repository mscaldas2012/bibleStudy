from bible_study.providers.base import LLMProvider
from bible_study.providers.mlx_provider import MLXProvider
from bible_study.providers.claude_provider import ClaudeProvider

__all__ = ["LLMProvider", "MLXProvider", "ClaudeProvider"]


def get_provider(name: str | None = None) -> LLMProvider:
    """
    Return an LLMProvider instance based on name or BIBLE_LLM_PROVIDER env var.

    name: "mlx" | "claude" (overrides env var if provided)
    """
    import os

    provider_name = (name or os.environ.get("BIBLE_LLM_PROVIDER", "mlx")).lower()

    if provider_name == "mlx":
        model_path = os.environ.get(
            "MLX_MODEL_PATH", "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
        )
        return MLXProvider(model_path=model_path)

    if provider_name == "claude":
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        model = os.environ.get("CLAUDE_MODEL", "claude-sonnet-4-6")
        return ClaudeProvider(api_key=api_key, model=model)

    raise ValueError(f"Unknown LLM provider: '{provider_name}'. Use 'mlx' or 'claude'.")
