"""MLX local LLM provider using mlx-lm."""

from __future__ import annotations

from bible_study.providers.base import LLMProvider


class MLXProvider(LLMProvider):
    def __init__(self, model_path: str):
        self.model_path = model_path
        self._model = None
        self._tokenizer = None

    def _load(self):
        """Lazy-load the model on first use."""
        if self._model is not None:
            return
        try:
            from mlx_lm import load
        except ImportError as exc:
            raise RuntimeError(
                "mlx-lm is not installed. Run: pip install mlx-lm"
            ) from exc

        import os
        os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
        self._model, self._tokenizer = load(self.model_path)

    def generate(self, system: str, user: str) -> str:
        self._load()

        from mlx_lm import generate

        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ]

        # apply_chat_template returns a string (the formatted prompt)
        prompt = self._tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )

        return generate(
            self._model,
            self._tokenizer,
            prompt=prompt,
            max_tokens=1500,
            verbose=False,
        )
