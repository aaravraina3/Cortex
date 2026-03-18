import asyncio
import base64
import os
from enum import Enum

from litellm import acompletion, aembedding
from litellm.types.utils import EmbeddingResponse, ModelResponse

CHAT_MODEL_FALLBACK_CHAIN = [
    "gemini/gemini-2.5-flash",
    "gemini/gemini-2.0-flash",
    "gemini/gemini-2.5-flash-lite",
    "gemini/gemini-3-flash-preview",
    "gemini/gemini-3.1-flash-lite-preview",
    "gemini/gemini-2.5-pro",
]


class ModelType(Enum):
    """Available LLM models."""

    GEMINI_PRO = "gemini/gemini-2.5-pro"
    GEMINI_FLASH = "gemini/gemini-2.5-flash-lite"


class EmbeddingModelType(Enum):
    """Available embedding models."""

    GEMINI_TEXT_EMBEDDING = "gemini/gemini-embedding-001"

    # OpenAI models
    OPENAI_SMALL = "text-embedding-3-small"  # 1536 dimensions
    OPENAI_LARGE = "text-embedding-3-large"  # 3072 dimensions


def _is_rate_limit(exc: Exception) -> bool:
    msg = str(exc).lower()
    return "429" in msg or "rate" in msg or "quota" in msg


class LLMClient:
    """Simplified LLM client for agentic workflows."""

    def __init__(self):
        self.model = ModelType.GEMINI_FLASH
        self.embedding_model = EmbeddingModelType.GEMINI_TEXT_EMBEDDING
        self.system_prompt: str | None = None
        self._load_api_keys()

    def _load_api_keys(self) -> None:
        for key in ["GEMINI_API_KEY", "OPENAI_API_KEY", "ANTHROPIC_API_KEY"]:
            if key in os.environ:
                os.environ[key] = os.environ[key]

    def set_model(self, model: ModelType) -> None:
        self.model = model

    def set_embedding_model(self, model: EmbeddingModelType) -> None:
        self.embedding_model = model

    def set_system_prompt(self, system_prompt: str) -> None:
        self.system_prompt = system_prompt

    async def embed(
        self,
        input_text: str | list[str],
        model: EmbeddingModelType | None = None,
    ) -> list[float] | list[list[float]]:
        """
        Generate embeddings for text.
        Returns 768-dimensional vectors to match the DB vector column.
        """
        embed_model = model.value if model else self.embedding_model.value
        inputs = [input_text] if isinstance(input_text, str) else input_text

        response: EmbeddingResponse = await aembedding(
            model=embed_model, input=inputs, dimensions=768
        )

        embeddings = [data.embedding for data in response.data]
        return embeddings[0] if isinstance(input_text, str) else embeddings

    async def chat(
        self,
        content: str,
        pdf_bytes: bytes | None = None,
        max_tokens: int | None = None,
        json_response: bool = False,
    ) -> ModelResponse:
        """
        Send a completion request with automatic model fallback on rate-limit.
        Tries the primary model first, then walks the fallback chain.
        """
        messages = self._build_messages(content, pdf_bytes)
        kwargs = {
            "messages": messages,
            "max_tokens": max_tokens,
            "response_format": {"type": "json_object"} if json_response else None,
        }

        models_to_try = [self.model.value] + [
            m for m in CHAT_MODEL_FALLBACK_CHAIN if m != self.model.value
        ]

        last_exc: Exception | None = None
        for model_name in models_to_try:
            try:
                return await acompletion(model=model_name, **kwargs)
            except Exception as e:
                if _is_rate_limit(e):
                    print(f"Rate limited on {model_name}, trying next...", flush=True)
                    last_exc = e
                    await asyncio.sleep(1)
                    continue
                raise

        raise last_exc  # type: ignore[misc]

    def _build_messages(self, content: str, pdf_bytes: bytes | None) -> list[dict]:
        messages = []
        if self.system_prompt:
            messages.append({"role": "system", "content": self.system_prompt})

        if pdf_bytes:
            encoded = base64.b64encode(pdf_bytes).decode("utf-8")
            base64_pdf = f"data:application/pdf;base64,{encoded}"
            messages.append(
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": content},
                        {"type": "image_url", "image_url": {"url": base64_pdf}},
                    ],
                }
            )
        else:
            messages.append({"role": "user", "content": content})

        return messages
