"""Replayable typed model observations."""

import typing
from array import array

import effect_py as effects
from pydantic import create_model
from pydantic_ai import Agent, ToolOutput, embeddings, messages, models, settings

from .observation import (
    REPLAY,
    Mode,
    ObservationError,
    ObservationPath,
    ObservationStore,
    RequestId,
    identify,
)

type ErrorKind = typing.Literal["missing", "selection", "model"]


@typing.final
class ModelError(RuntimeError):
    """Typed failure at the replayable model boundary."""

    MISSING: typing.ClassVar[ErrorKind] = "missing"
    SELECTION: typing.ClassVar[ErrorKind] = "selection"
    MODEL: typing.ClassVar[ErrorKind] = "model"

    def __init__(
        self,
        kind: ErrorKind,
        message: str,
    ) -> None:
        """Create one classified model failure."""
        super().__init__(message)
        self.kind = kind

    @classmethod
    def catch(
        cls,
        error: Exception,
    ) -> "ModelError":
        """Keep model failures in the typed error channel."""
        if isinstance(error, cls):
            return error

        if isinstance(error, ObservationError):
            return cls(
                cls.MISSING,
                str(error),
            )

        message = f"{type(error).__name__}: {error}"
        return cls(
            cls.MODEL,
            message,
        )


type SelectionResult = tuple[
    tuple[int, ...],
    tuple[messages.ModelMessage, ...],
    RequestId,
    Mode,
]

type EmbeddingObservation = tuple[
    ObservationPath,
    RequestId,
    Mode,
]

Selection = create_model(
    "Selection",
    selected=(
        tuple[int, ...],
        ...,
    ),
)


class _Embedding(typing.NamedTuple):
    """One lazy Pydantic AI embedding acquisition."""

    model: embeddings.EmbeddingModel
    text: str
    input_type: typing.Literal["query", "document"]
    settings: embeddings.EmbeddingSettings | None

    def __call__(self) -> bytes:
        """Acquire and encode one float32 vector."""
        vector = (
            embeddings.Embedder(
                self.model,
            )
            .embed_sync(
                self.text,
                input_type=self.input_type,
                settings=self.settings,
            )
            .embeddings[0]
        )
        return array("f", vector).tobytes()


class SelectionRequest(typing.NamedTuple):
    """Provider request plus local admission constraints."""

    instructions: str
    prompt: str
    candidate_count: int
    model_settings: settings.ModelSettings | None = None
    limit: int | None = None
    sample: str = "0"

    def identity(
        self,
        model: models.Model,
    ) -> RequestId:
        """Identify provider work, excluding local admission."""
        return identify(
            (
                "selection-tool-v2",
                model.model_id,
                model.settings,
                self.model_settings,
                self.instructions,
                self.prompt,
                Selection.model_json_schema(),
                self.sample,
            ),
        )

    def _admit(
        self,
        observation: list[messages.ModelMessage],
    ) -> tuple[int, ...]:
        """Decode and validate one retained selection."""
        parts = tuple(
            part
            for message in observation
            if isinstance(message, messages.ModelResponse)
            for part in message.parts
            if isinstance(part, messages.ToolCallPart)
            and part.tool_name == "final_result"
        )

        if not parts:
            message = "Observation has no final selection."
            raise ModelError(
                ModelError.SELECTION,
                message,
            )

        try:
            output = Selection.model_validate(
                parts[-1].args_as_dict(),
            ).model_dump()
        except ValueError as error:
            message = "Model selection payload is invalid."
            raise ModelError(
                ModelError.SELECTION,
                message,
            ) from error

        selected = typing.cast(
            "tuple[int, ...]",
            output["selected"],
        )

        invalid = (
            len(selected) != len(set(selected))
            or any(index < 0 or index >= self.candidate_count for index in selected)
            or (self.limit is not None and len(selected) > self.limit)
        )

        if invalid:
            message = "Model selection failed local admission."
            raise ModelError(
                ModelError.SELECTION,
                message,
            )

        return selected

    def execute(
        self,
        model: models.Model,
        store: ObservationStore,
        mode: Mode,
    ) -> SelectionResult:
        """Replay or acquire, then deterministically admit."""
        identity = self.identity(
            model,
        )

        payload, origin = store.observe(
            identity,
            mode,
            lambda: messages.ModelMessagesTypeAdapter.dump_json(
                Agent(
                    model,
                    output_type=ToolOutput(Selection),
                    retries=2,
                )
                .run_sync(
                    self.prompt,
                    instructions=self.instructions,
                    model_settings=self.model_settings,
                )
                .new_messages(),
            ),
        )

        observation = messages.ModelMessagesTypeAdapter.validate_json(
            payload,
        )

        return (
            self._admit(
                observation,
            ),
            tuple(
                observation,
            ),
            identity,
            origin,
        )


@effects.fn("model.embed")
def embed(
    text: str,
    *,
    input_type: typing.Literal["query", "document"] = "document",
    embedding_settings: embeddings.EmbeddingSettings | None = None,
    sample: str = "0",
    mode: Mode = REPLAY,
) -> effects.EffectGen[
    EmbeddingObservation,
    ModelError,
    embeddings.EmbeddingModel | ObservationStore,
]:
    """Embed through explicit model and observation capabilities."""
    service = effects.service
    model = yield from service(embeddings.EmbeddingModel)
    store = yield from service(ObservationStore)

    identity = identify(
        (
            "embedding-f32-v1",
            model.system,
            model.base_url,
            model.model_name,
            model.settings,
            embedding_settings,
            input_type,
            text,
            sample,
        ),
    )

    _, origin = yield from effects.try_(
        lambda: store.observe(
            identity,
            mode,
            _Embedding(
                model,
                text,
                input_type,
                embedding_settings,
            ),
        ),
        ModelError.catch,
    )

    return (
        store.path(identity),
        identity,
        origin,
    )


@effects.fn("model.select")
def select(
    request: SelectionRequest,
    *,
    mode: Mode = REPLAY,
) -> effects.EffectGen[
    SelectionResult,
    ModelError,
    models.Model | ObservationStore,
]:
    """Select through explicit model and observation capabilities."""
    service = effects.service
    model = yield from service(models.Model)
    store = yield from service(ObservationStore)

    return (
        yield from effects.try_(
            lambda: request.execute(
                model,
                store,
                mode,
            ),
            ModelError.catch,
        )
    )
