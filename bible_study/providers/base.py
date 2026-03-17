"""Abstract base class for LLM providers."""

from __future__ import annotations
from abc import ABC, abstractmethod


class LLMProvider(ABC):
    @abstractmethod
    def generate(self, system: str, user: str) -> str:
        """
        Generate a response given a system prompt and user message.

        Returns the raw string response from the model.
        """
        ...
