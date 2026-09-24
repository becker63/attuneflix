"""Build repository-native structural evidence from fixed Grit programs."""

import itertools
import json
import pathlib
import posixpath
from typing import NamedTuple, cast

import rote

from attune_radii.algebra.relation import (
    FileId,
    LocationId,
    Relation,
    Relations,
    SymbolId,
)
from attune_radii.grit import (
    SOURCE_SUFFIXES,
    EvidenceRecord,
    Fact,
    Grit,
    PrimitiveEvidence,
)

GRIT_ROOT = pathlib.Path("grit/typescript")
ENCODING = "utf-8"
JSON_SEPARATORS = (",", ":")
JSON_LOAD = json.loads
FACT_BUCKETS = 64
type FactRecord = tuple[str, str, int, int, str]
type SourceRecord = tuple[str, str]
type FactBatches = tuple[tuple[SourceRecord, ...], ...]
type SymbolRecord = tuple[str, str, int, int]
type IntEdge = tuple[int, int]
type Identity = tuple[Fact, SymbolId]
type Owners = dict[str, tuple[Identity, ...]]
type Targets = dict[str | tuple[str, str], tuple[SymbolId, ...]]
type FrozenIndex[Key, Value] = dict[Key, tuple[Value, ...]]
type MutableCallIndexes = tuple[
    dict[str, list[Identity]],
    dict[tuple[str, str], list[SymbolId]],
    dict[str, list[SymbolId]],
]
type Rejections = tuple[tuple[str, int], ...]
type EdgeResolution = tuple[IntEdge | None, str]
type Resolutions = tuple[EdgeResolution, ...]
type Evidence = tuple[PrimitiveEvidence, PrimitiveEvidence, PrimitiveEvidence]
type ResolvedEdges = tuple[tuple[IntEdge, ...], PrimitiveEvidence]
type ParentState = tuple[int, tuple[IntEdge, ...]]
type DefinitionState = tuple[
    tuple[str, ...],
    tuple["Symbol", ...],
    tuple[Identity, ...],
    ResolvedEdges,
    ParentState,
]
type RepositoryPayloads = tuple[str, str, str, str]
type Directories = tuple[tuple[str, ...], ...]


class Source(NamedTuple):
    """One repository-relative source path and its contents."""

    path: str
    content: str

    @classmethod
    def fact_batches(
        cls,
        sources: list[SourceRecord],
    ) -> FactBatches:
        """Group facts without coupling unrelated revision shards."""
        buckets: dict[int, list[SourceRecord]] = {}
        for source in sources:
            encoded = map(ord, source[0])
            identity = sum(encoded) % FACT_BUCKETS
            if identity not in buckets:
                buckets[identity] = []
            buckets[identity].append(source)
        values = buckets.values()
        return tuple(map(tuple, values))

    @classmethod
    def directories(cls, paths: tuple[str, ...]) -> Directories:
        """Return every repository directory prefix in stable order."""
        directories: set[tuple[str, ...]] = {()}
        for path in paths:
            parent = pathlib.PurePosixPath(path).parent.parts
            limit = len(parent) + 1
            for depth in range(1, limit):
                directories.add(parent[:depth])
        return tuple(sorted(directories))

    def excluded(self, prefixes: tuple[str, ...]) -> bool:
        """Return whether this path lies below an excluded prefix."""
        return any(
            self.path == prefix
            or self.path.startswith(
                prefix + "/",
            )
            for prefix in map(
                str.rstrip,
                prefixes,
                ("/",) * len(prefixes),
            )
        )

    def import_target(
        self,
        specifier: str,
        files: dict[str, FileId],
    ) -> FileId | None:
        """Resolve one relative module specifier conservatively."""
        specifier = specifier.strip("\"'")
        base = posixpath.normpath(
            posixpath.join(
                posixpath.dirname(self.path),
                specifier,
            ),
        )
        for candidate in itertools.chain(
            (base,),
            (base + suffix for suffix in SOURCE_SUFFIXES),
            (base + "/index" + suffix for suffix in SOURCE_SUFFIXES),
        ):
            target = files.get(candidate)
            if target is not None:
                return target
        return None

    @classmethod
    def import_edge(
        cls,
        fact: Fact,
        files: dict[str, FileId],
    ) -> EdgeResolution:
        """Resolve one static module observation or classify rejection."""
        specifier = fact.value.strip()
        if not (
            len(specifier) > 1
            and specifier[0] in "\"'"
            and specifier[-1] == specifier[0]
        ):
            return None, "unsupported module syntax"
        module = specifier[1:-1]
        if module.startswith("."):
            target = cls(
                fact.path,
                "",
            ).import_target(
                specifier,
                files,
            )
        else:
            return None, "external package"
        return (
            None
            if target is None
            else (
                int(files[fact.path]),
                int(target),
            ),
            "relative target absent" if target is None else "",
        )

    @classmethod
    def _rejections(cls, reasons: tuple[str, ...]) -> Rejections:
        """Compress repeated rejection reasons deterministically."""
        rejected: dict[str, int] = {}
        for reason in reasons:
            count = rejected.get(reason, 0)
            rejected[reason] = count + 1
        ordered = sorted(rejected.items())
        return tuple(ordered)

    @classmethod
    def summary(
        cls,
        facts: tuple[Fact, ...],
        resolved: Resolutions,
    ) -> ResolvedEdges:
        """Summarize resolved edges and rejected observations."""
        if not resolved:
            observations = len(facts)
            empty_record = observations, 0, 0, ()
            return (), PrimitiveEvidence(*empty_record)
        edge_values, reasons = zip(
            *resolved,
            strict=True,
        )
        edges = cast(
            "tuple[IntEdge, ...]",
            tuple(filter(bool, edge_values)),
        )
        return (
            edges,
            PrimitiveEvidence(
                len(facts),
                len({fact.path for fact in facts}),
                len(set(edges)),
                cls._rejections(
                    tuple(filter(None, reasons)),
                ),
            ),
        )


class Symbol(NamedTuple):
    """One stable repository symbol admitted from a definition fact."""

    path: str
    name: str
    start_byte: int
    end_byte: int

    @classmethod
    def select(
        cls,
        candidates: tuple[SymbolId, ...],
        missing: str,
        ambiguous: str,
    ) -> tuple[SymbolId | None, str]:
        """Admit exactly one symbol candidate or classify rejection."""
        if len(candidates) == 1:
            return candidates[0], ""
        return None, ambiguous if candidates else missing


class CallIndex(NamedTuple):
    """Definition indexes used for conservative local call resolution."""

    owners: Owners
    local: Targets
    global_: Targets

    @classmethod
    def _freeze[Key, Value](
        cls,
        index: dict[Key, list[Value]],
    ) -> FrozenIndex[Key, Value]:
        """Freeze one temporary repeated-value index."""
        frozen: dict[Key, tuple[Value, ...]] = {}
        for key, values in index.items():
            frozen[key] = tuple(values)
        return frozen

    @classmethod
    def build(cls, identities: tuple[Identity, ...]) -> "CallIndex":
        """Index admitted definitions for repeated call resolution."""
        indexes: MutableCallIndexes = ({}, {}, {})
        for item in identities:
            indexes[0].setdefault(
                item[0].path,
                [],
            ).append(item)
            indexes[1].setdefault(
                (
                    item[0].path,
                    item[0].value,
                ),
                [],
            ).append(item[1])
            indexes[2].setdefault(
                item[0].value,
                [],
            ).append(item[1])
        return cls(
            cls._freeze(indexes[0]),
            cast(
                "Targets",
                cls._freeze(indexes[1]),
            ),
            cast(
                "Targets",
                cls._freeze(indexes[2]),
            ),
        )

    @classmethod
    def facts(cls, payload: str) -> tuple[Fact, ...]:
        """Decode one stable fact payload."""
        records = cast("list[FactRecord]", JSON_LOAD(payload))
        return tuple(itertools.starmap(Fact, records))

    def _target(
        self,
        path: str,
        callee: str,
    ) -> tuple[SymbolId | None, str]:
        """Resolve one simple callee name through local then global scope."""
        name = callee.rsplit(
            ".",
            1,
        )[-1]
        local = self.local.get(
            (
                path,
                name,
            ),
            (),
        )
        if local:
            return Symbol.select(
                local,
                "",
                "same-file target ambiguous",
            )
        missing = (
            "imported/member target requires binding resolution"
            if "." in callee
            else "same-file target absent"
        )
        candidates = self.global_.get(
            name,
            (),
        )
        return Symbol.select(
            candidates,
            missing,
            "global target ambiguous",
        )

    def _owner(self, call: Fact) -> SymbolId | None:
        """Return the innermost callable enclosing one call."""
        enclosed = (
            (definition.end_byte - definition.start_byte, identity)
            for definition, identity in self.owners.get(
                call.path,
                (),
            )
            if definition.start_byte <= call.start_byte
            if call.end_byte <= definition.end_byte
        )
        caller = min(
            enclosed,
            default=None,
        )
        if caller is None:
            return None
        return caller[1]

    def edge(self, call: Fact) -> EdgeResolution:
        """Resolve one enclosed call or explain its conservative rejection."""
        caller = self._owner(call)
        if caller is None:
            return None, "no lexical owner"

        callee = call.value.replace(
            "?.",
            ".",
        )
        if set(callee).intersection("([{'\"`\n"):
            return None, "dynamic target"

        target = self._target(
            call.path,
            callee,
        )
        return (
            None
            if target[0] is None
            else (
                int(caller),
                int(target[0]),
            ),
            target[1],
        )

    def resolve(self, payload: str) -> ResolvedEdges:
        """Resolve every call fact and count rejected observations."""
        facts = self.facts(payload)
        return Source.summary(
            facts,
            tuple(
                map(
                    self.edge,
                    facts,
                ),
            ),
        )


class Atlas(NamedTuple):
    """Issue-blind repository structure compiled from source evidence."""

    files: tuple[str, ...]
    symbols: tuple[Symbol, ...]
    relations: Relations
    evidence: Evidence

    @classmethod
    def build(
        cls,
        root: pathlib.Path,
        grit_root: pathlib.Path = GRIT_ROOT,
        *,
        exclude: tuple[str, ...] = (),
    ) -> "Atlas":
        """Build one structural atlas directly from admitted repository source."""
        sources = cls._sources(root, exclude)
        if not sources:
            message = "Repository has no supported JavaScript or TypeScript source."
            raise ValueError(message)

        programs = tuple(
            (grit_root / name).read_text(encoding=ENCODING)
            for name in ("defines.grit", "imports.grit", "calls.grit")
        )
        snapshot = json.dumps(sources, separators=JSON_SEPARATORS)
        payloads = cast(
            "RepositoryPayloads",
            (
                json.dumps(
                    tuple(source.path for source in sources),
                ),
                *map(
                    _primitive_fact_payload,
                    itertools.repeat(snapshot),
                    programs,
                ),
            ),
        )
        return cls._decode(
            _resolved_repository_payload(payloads),
        )

    @classmethod
    def _sources(
        cls,
        root: pathlib.Path,
        exclude: tuple[str, ...],
    ) -> tuple[Source, ...]:
        """Read one explicitly admitted supported-source snapshot."""
        sources: list[Source] = []
        for path in sorted(root.rglob("*")):
            supported = all(
                (
                    path.is_file(),
                    path.suffix in SOURCE_SUFFIXES,
                ),
            )
            if not supported:
                continue
            source = Source(
                path.relative_to(root).as_posix(),
                path.read_text(encoding=ENCODING),
            )
            if source.excluded(exclude):
                continue
            sources.append(source)
        return tuple(sources)

    @classmethod
    def _parent(cls, paths: tuple[str, ...]) -> ParentState:
        """Compile file and directory parenthood with aligned coordinates."""
        directories = Source.directories(paths)
        identities = {
            directory: len(paths) + index
            for index, directory in enumerate(
                directories,
            )
        }
        return (
            len(paths) + len(directories),
            tuple(
                itertools.chain(
                    (
                        (
                            index,
                            identities[pathlib.PurePosixPath(path).parent.parts],
                        )
                        for index, path in enumerate(paths)
                    ),
                    (
                        (
                            identities[directory],
                            identities[directory[:-1]],
                        )
                        for directory in directories
                        if directory
                    ),
                ),
            ),
        )

    @classmethod
    def _definitions(cls, payloads: tuple[str, str]) -> DefinitionState:
        """Normalize definition facts into symbols and dense identities."""
        evidence = (
            tuple(
                cast(
                    "list[str]",
                    json.loads(payloads[0]),
                ),
            ),
            tuple(
                sorted(
                    CallIndex.facts(payloads[1]),
                    key=lambda fact: (
                        fact.path,
                        fact.start_byte,
                        fact.end_byte,
                        fact.value,
                    ),
                ),
            ),
        )
        files: dict[str, FileId] = dict(
            zip(
                evidence[0],
                map(
                    FileId,
                    range(len(evidence[0])),
                ),
                strict=True,
            ),
        )
        identities: tuple[Identity, ...] = tuple(
            zip(
                evidence[1],
                map(
                    SymbolId,
                    range(len(evidence[1])),
                ),
                strict=True,
            ),
        )
        return (
            evidence[0],
            tuple(
                Symbol(
                    fact.path,
                    fact.value,
                    fact.start_byte,
                    fact.end_byte,
                )
                for fact in evidence[1]
            ),
            identities,
            Source.summary(
                evidence[1],
                tuple(
                    zip(
                        (
                            (
                                int(files[fact.path]),
                                int(identity),
                            )
                            for fact, identity in identities
                        ),
                        itertools.repeat(""),
                    ),
                ),
            ),
            cls._parent(evidence[0]),
        )

    @classmethod
    def _imports(
        cls,
        paths: tuple[str, ...],
        payload: str,
    ) -> ResolvedEdges:
        """Resolve repository-local relative import facts."""
        facts = CallIndex.facts(payload)
        files: dict[str, FileId] = dict(
            zip(
                paths,
                map(
                    FileId,
                    range(len(paths)),
                ),
                strict=True,
            ),
        )
        resolved = map(
            Source.import_edge,
            facts,
            itertools.repeat(files),
        )
        return Source.summary(facts, tuple(resolved))

    @classmethod
    def resolve(cls, payloads: RepositoryPayloads) -> str:
        """Resolve stable primitive facts into one repository payload."""
        definitions = cls._definitions(
            payloads[:2],
        )
        imports = cls._imports(
            definitions[0],
            payloads[2],
        )
        calls = CallIndex.build(
            definitions[2],
        ).resolve(
            payloads[3],
        )
        return json.dumps(
            {
                "files": definitions[0],
                "symbols": definitions[1],
                "defines": definitions[3][0],
                "imports": imports[0],
                "calls": calls[0],
                "parent_size": definitions[4][0],
                "parent": definitions[4][1],
                "evidence": (
                    definitions[3][1],
                    imports[1],
                    calls[1],
                ),
            },
            separators=JSON_SEPARATORS,
        )

    @classmethod
    def _decode(cls, payload: str) -> "Atlas":
        """Reconstruct cheap native indexes from resolved stable facts."""
        record = cast(
            "dict[str, object]",
            json.loads(payload),
        )
        stored_files = cast("list[str]", record["files"])
        files = tuple(stored_files)
        symbols = cast("list[SymbolRecord]", record["symbols"])
        parent_size = cast("int", record["parent_size"])
        return cls(
            files,
            tuple(
                itertools.starmap(
                    Symbol,
                    symbols,
                ),
            ),
            Relations(
                Relation(
                    len(files),
                    len(symbols),
                    cast("list[tuple[FileId, SymbolId]]", record["defines"]),
                ),
                Relation(
                    len(files),
                    len(files),
                    cast("list[tuple[FileId, FileId]]", record["imports"]),
                ),
                Relation(
                    len(symbols),
                    len(symbols),
                    cast("list[tuple[SymbolId, SymbolId]]", record["calls"]),
                ),
                Relation(
                    parent_size,
                    parent_size,
                    cast(
                        "list[tuple[LocationId, LocationId]]",
                        record["parent"],
                    ),
                ),
            ),
            cast(
                "Evidence",
                tuple(
                    map(
                        PrimitiveEvidence.decode,
                        cast(
                            "list[EvidenceRecord]",
                            record["evidence"],
                        ),
                    ),
                ),
            ),
        )


@rote.cache
def fact_payload(
    program: str,
    batch: tuple[SourceRecord, ...],
) -> str:
    """Persist one stable deterministic shard of Grit evidence."""
    grit = Grit()
    facts: list[Fact] = []
    for source in batch:
        extracted = grit.source_facts(program, *source)
        facts.extend(extracted)
    return json.dumps(facts, separators=JSON_SEPARATORS)


@rote.cache
def _primitive_fact_payload(snapshot: str, program: str) -> str:
    """Aggregate one primitive's durable per-source facts."""
    sources = cast("list[SourceRecord]", JSON_LOAD(snapshot))
    batches = Source.fact_batches(sources)
    programs = itertools.repeat(program)
    encoded = map(fact_payload, programs, batches)
    payloads = map(CallIndex.facts, encoded)
    return json.dumps(
        tuple(itertools.chain.from_iterable(payloads)),
        separators=JSON_SEPARATORS,
    )


@rote.cache
def _resolved_repository_payload(payloads: RepositoryPayloads) -> str:
    """Durably resolve explicit repository facts into stable relation data."""
    return Atlas.resolve(payloads)
