"""Laws for durable replayable model observations."""

import typing
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import effect_py as effects
from pydantic_ai import embeddings, messages, models, usage
from pydantic_ai.models.test import TestModel

import attune_radii.model as model_boundary
import attune_radii.observation as observation_boundary

models.ALLOW_MODEL_REQUESTS = False

SELECTED = "selected"
OBSERVATIONS = "observations"
OPENROUTER = "openrouter"

REQUEST = model_boundary.SelectionRequest(
    "Choose candidate indices.",
    '{"candidates":[0,1,2]}',
    3,
)

EMBEDDING_TEXT = "Where is the authentication logic?"


def _resolve(
    effect: effects.Effect[
        model_boundary.SelectionResult,
        model_boundary.ModelError,
        models.Model | observation_boundary.ObservationStore,
    ],
    model: models.Model,
    store: observation_boundary.ObservationStore,
) -> effects.Effect[
    model_boundary.SelectionResult,
    model_boundary.ModelError,
    typing.Never,
]:
    """Provide one complete model environment."""
    services = effects.layer.merge(
        effects.layer.succeed(
            models.Model,
            model,
        ),
        effects.layer.succeed(
            observation_boundary.ObservationStore,
            store,
        ),
    )

    return effect.pipe(
        effects.provide(
            services,
        ),
    )


def _race(
    root: str,
    selected: int,
) -> tuple[tuple[int, ...], str]:
    """Acquire one shared identity from an independent process."""
    model = TestModel(
        custom_output_args={
            SELECTED: [selected],
        },
    )

    result = REQUEST.execute(
        model,
        observation_boundary.FileObservationStore(
            Path(root),
        ),
        observation_boundary.ACQUIRE,
    )

    return result[0], result[3]


if typing.TYPE_CHECKING:
    _ = typing.assert_type(
        model_boundary.select(REQUEST),
        effects.Effect[
            model_boundary.SelectionResult,
            model_boundary.ModelError,
            models.Model | observation_boundary.ObservationStore,
        ],
    )

    _ = typing.assert_type(
        model_boundary.embed(
            EMBEDDING_TEXT,
            input_type="query",
        ),
        effects.Effect[
            model_boundary.EmbeddingObservation,
            model_boundary.ModelError,
            embeddings.EmbeddingModel | observation_boundary.ObservationStore,
        ],
    )


def test_embedding_observation_replays_native_pydantic_result(
    tmp_path: Path,
) -> None:
    """Embedding replay retains exact float32 vectors without provider work."""
    embedding_settings: embeddings.EmbeddingSettings = {
        "dimensions": 4,
        "extra_body": {
            "provider": {
                "order": [
                    "deepinfra",
                ],
                "allow_fallbacks": False,
            },
        },
    }

    model = embeddings.TestEmbeddingModel(
        model_name="qwen-test",
        provider_name=OPENROUTER,
        dimensions=4,
    )

    first = effects.run_sync(
        model_boundary.embed(
            EMBEDDING_TEXT,
            input_type="query",
            embedding_settings=embedding_settings,
            mode=observation_boundary.ACQUIRE,
        )
        .pipe(
            effects.provide(
                effects.layer.merge(
                    effects.layer.succeed(
                        embeddings.EmbeddingModel,
                        model,
                    ),
                    effects.layer.succeed(
                        observation_boundary.ObservationStore,
                        observation_boundary.FileObservationStore(
                            tmp_path / OBSERVATIONS,
                        ),
                    ),
                ),
            ),
        )
        .or_die(),
    )

    replay_model = embeddings.TestEmbeddingModel(
        model_name="qwen-test",
        provider_name=OPENROUTER,
        dimensions=4,
    )

    second = effects.run_sync(
        model_boundary.embed(
            EMBEDDING_TEXT,
            input_type="query",
            embedding_settings=embedding_settings,
        )
        .pipe(
            effects.provide(
                effects.layer.merge(
                    effects.layer.succeed(
                        embeddings.EmbeddingModel,
                        replay_model,
                    ),
                    effects.layer.succeed(
                        observation_boundary.ObservationStore,
                        observation_boundary.FileObservationStore(
                            tmp_path / OBSERVATIONS,
                        ),
                    ),
                ),
            ),
        )
        .or_die(),
    )

    assert (
        tuple(
            memoryview(
                first[0].read_bytes(),
            ).cast(
                "f",
            ),
        ),
        first[2],
        second[0],
        second[2],
        replay_model.last_settings,
    ) == (
        (
            1.0,
            1.0,
            1.0,
            1.0,
        ),
        observation_boundary.ACQUIRE,
        first[0],
        observation_boundary.REPLAY,
        None,
    )

    assert model.last_settings == embedding_settings


def test_observation_replay_and_admission_identity(
    tmp_path: Path,
) -> None:
    """Replay stays local while provider-visible changes alter identity."""
    store = observation_boundary.FileObservationStore(
        tmp_path / OBSERVATIONS,
    )

    model = TestModel(
        custom_output_args={
            SELECTED: [1, 2],
        },
    )

    first = effects.run_sync(
        _resolve(
            model_boundary.select(
                REQUEST,
                mode=observation_boundary.ACQUIRE,
            ),
            model,
            store,
        ).or_die(),
    )

    model = TestModel(
        custom_output_args={
            SELECTED: [0],
        },
    )

    second = effects.run_sync(
        _resolve(
            model_boundary.select(
                REQUEST,
            ),
            model,
            store,
        ).or_die(),
    )

    failures = (
        effects.run_sync_exit(
            _resolve(
                model_boundary.select(
                    REQUEST._replace(
                        limit=1,
                    ),
                ),
                model,
                store,
            ),
        ),
        effects.run_sync_exit(
            _resolve(
                model_boundary.select(
                    REQUEST._replace(
                        prompt="changed",
                    ),
                ),
                model,
                store,
            ),
        ),
    )

    assert (
        first[0],
        first[3],
        second[0],
        second[3],
        model.last_model_request_parameters,
    ) == (
        (1, 2),
        observation_boundary.ACQUIRE,
        (1, 2),
        observation_boundary.REPLAY,
        None,
    )

    assert all(isinstance(failure, effects.Failure) for failure in failures)

    assert REQUEST.identity(
        model,
    ) == REQUEST._replace(
        limit=1,
    ).identity(
        model,
    )

    assert REQUEST.identity(
        model,
    ) != REQUEST._replace(
        prompt="changed",
    ).identity(
        model,
    )

    assert REQUEST.identity(
        model,
    ) != REQUEST._replace(
        model_settings={
            "temperature": 1,
        },
    ).identity(
        model,
    )


def test_observation_preserves_native_kv_usage(
    tmp_path: Path,
) -> None:
    """Retained Pydantic messages preserve provider KV accounting."""
    store = observation_boundary.FileObservationStore(
        tmp_path / OBSERVATIONS,
    )

    model = TestModel()

    observation: list[messages.ModelMessage] = [
        messages.ModelResponse(
            parts=[
                messages.ToolCallPart(
                    tool_name="final_result",
                    args={
                        SELECTED: [2],
                    },
                ),
            ],
            usage=usage.RequestUsage(
                input_tokens=100,
                cache_read_tokens=80,
                cache_write_tokens=10,
                output_tokens=4,
            ),
            model_name=model.model_name,
            provider_name=model.system,
        ),
    ]

    _ = store.path(
        REQUEST.identity(
            model,
        ),
    ).write_bytes(
        messages.ModelMessagesTypeAdapter.dump_json(
            observation,
        ),
    )

    result = effects.run_sync(
        _resolve(
            model_boundary.select(
                REQUEST,
            ),
            model,
            store,
        ).or_die(),
    )

    assert tuple(
        (
            message.usage.input_tokens,
            message.usage.cache_read_tokens,
            message.usage.cache_write_tokens,
            message.usage.output_tokens,
        )
        for message in result[1]
        if isinstance(message, messages.ModelResponse)
    ) == ((100, 80, 10, 4),)


def _race_summary(
    root: Path,
) -> tuple[int, frozenset[str], int]:
    """Summarize one four-process cold acquisition race."""
    with ProcessPoolExecutor(
        max_workers=4,
    ) as pool:
        results = tuple(
            pool.map(
                _race,
                (str(root),) * 4,
                (0, 1, 2, 0),
            ),
        )

    return (
        sum(item[1] == observation_boundary.ACQUIRE for item in results),
        frozenset(item[1] for item in results),
        len(frozenset(item[0] for item in results)),
    )


def test_observation_store_collapses_process_races(
    tmp_path: Path,
) -> None:
    """Concurrent cold acquisitions retain exactly one provider result."""
    assert _race_summary(
        tmp_path / OBSERVATIONS,
    ) == (
        1,
        frozenset(
            (
                observation_boundary.ACQUIRE,
                observation_boundary.REPLAY,
            ),
        ),
        1,
    )
