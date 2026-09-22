# Frozen localization usage and latency evidence

This report records provider usage and the latency evidence retained by the
frozen SWE-Explore JavaScript/TypeScript localization run. Provider acquisition,
keyless prediction replay, and official evaluation are sealed. The generated
`REPORT.md` joins these measurements to the complete accuracy and ranking
metrics without changing the frozen policy.

## Scope

The scale population contains 63 new cases. Sixty-one are scientifically
admissible under the frozen semantic-prior condition. The two censored
Three.js cases exceeded the provider/model context limit by one token and made
no admitted embedding or decision contribution:

- `mrdoob__three.js-26589`
- `mrdoob__three.js-27395`

Their exact 48,000-codepoint inputs tokenize to 40,961 tokens against the
40,960-token provider/model context limit. No clipping, model, or document
population was changed to force them through.

The retained provider is OpenRouter. The semantic prior uses
`qwen/qwen3-embedding-8b`. The decision request identity uses
`typesafe/jev-1.13`; admitted responses identify the concrete served revision
as `typesafe/jev-1.13-20260917`. These are the frozen identities, not current
provider defaults.

The usage totals below are derived from immutable admitted provider response
envelopes and the canonical prediction Parquets, not estimated from prompts or
price tables. The final-condition table counts observations referenced by the
61 frozen predictions. A second table reports every admitted observation in
the durable scale stores, including valid work retained across a failed shard
and its resume.

## Scale provider usage

| Stage | Provider observations | Input tokens | Output tokens | Total tokens | Provider-reported cost |
| --- | ---: | ---: | ---: | ---: | ---: |
| Semantic-prior embeddings | 2,089 batches | 27,858,287 | 0 | 27,858,287 | unavailable |
| Jev decisions referenced by frozen predictions | 3,911 | 13,842,402 | 806,338 | 14,648,740 | $0.581380884 |
| **Frozen-condition total** | **6,000** | **41,700,689** | **806,338** | **42,507,027** | **$0.581380884 plus unreported embedding cost** |

The average admitted embedding batch contained 13,335.70 input tokens. The
average Jev decision referenced by a frozen prediction used 3,539.61 input
tokens and 206.17 output tokens, or 3,745.78 total tokens, at a
provider-reported mean cost of $0.000148632.

At the case level, the frozen condition averages 240,143.28 Jev tokens and
$0.009530834 of reported decision cost per completed localization. Including
semantic-prior embedding tokens, but still excluding unreported embedding
cost, the retained condition averages 696,836.51 provider tokens per case.
This arithmetic mean describes the run; it does not imply that repository-level
embedding work would need to be reacquired for each future issue.

The final predictions also preserve the per-case distribution:

| Per-case Jev quantity | Minimum | p50 | p90 | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Decisions | 5 | 71 | 78 | 80 | 84 |
| Input tokens | 16,878 | 233,515 | 332,138 | 348,576 | 433,223 |
| Output tokens | 867 | 14,298 | 16,789 | 17,350 | 17,601 |
| Provider-reported cost | $0.000708876 | $0.009807630 | $0.013949796 | $0.014640192 | $0.018195366 |

Percentiles use the nearest-rank definition over the 61 completed cases.

The provider returned a cost for every Jev observation. It returned no cost
field for any of the 2,089 embedding observations. The report therefore does
not infer embedding spend from a mutable external price table. The defensible
condition-level statement is: **the Jev decisions selected by the completed
scale run cost $0.581380884; condition spend was that amount plus embedding
cost not reported in the retained responses.**

### Full retained evidence superset

| Evidence | Observations | Input tokens | Output tokens | Total tokens | Provider-reported cost |
| --- | ---: | ---: | ---: | ---: | ---: |
| All admitted scale Jev observations | 4,306 | 15,298,075 | 893,114 | 16,191,189 | $0.642519150 |
| Difference from frozen predictions | 395 | 1,455,673 | 86,776 | 1,542,449 | $0.061138266 |
| Embeddings plus all retained Jev evidence | 6,395 | 43,156,362 | 893,114 | 44,049,476 | $0.642519150 plus unreported embedding cost |

The 395-observation difference is retained valid evidence produced by the
restartable acquisition process, not a hidden addition to the final policy's
decision count. It remains valuable for reproducibility and must not be
deleted merely because the frozen predictions reference a smaller subset.

## Historical-development usage

The separately frozen 15-case historical-development evidence used 458,230
embedding input tokens. Its 78 Jev calls used 98,358 input and 3,503 output
tokens and reported $0.004131036 of decision cost.

Across the historical and expanded frozen conditions, the selected evidence
therefore accounts for 43,067,118 tokens and $0.585511920 of reported Jev
decision cost, plus embedding cost that the provider did not return. Counting
the complete retained scale evidence superset instead gives 44,609,567 tokens
and $0.646650186 of reported Jev decision cost. The historical population
remains separate from the scale population in all scientific comparisons.

## Latency and compute evidence

The provider envelopes retain usage and cost but not request latency. Exact
provider p50/p90/p99 latency is therefore unavailable and is not reconstructed
from replay. The following operational timings *were* retained:

| Measurement | Cases | Retained wall/compute time | Per case | Interpretation |
| --- | ---: | ---: | ---: | --- |
| Successful decision-acquisition shards | 61 | 14,001.05 s (3 h 53 m 21 s) | 229.53 s | Whole shard processes: compilation, snapshot/fact loading, structural work, provider calls, validation, and persistence |
| Structural precompute inside acquisition | 61 | 148.795 s | 2.439 s | Sum of per-case `System.nanoTime` intervals; excludes provider waiting |
| Exact keyless decision replay | 61 | 2,500.90 s (41 m 41 s) | 41.00 s | Sequential migration-era shard runs, including process/compiler and retained-data overhead |
| Structural precompute inside keyless replay | 61 | 135.008 s | 2.213 s | Same in-program measurement as acquisition |
| Exact keyless semantic-prior replay | 61 | 4,474.40 s (1 h 14 m 34 s) | 73.35 s | Sequential shard runs over retained vectors/rankings; no network |
| Official evaluation | 61 | 4,301.12 s (1 h 11 m 41.12 s) | 70.51 s | Seven successful bounded-lifetime shards; exact rows merged by Flix |

The successful evaluator shards peaked at 7,498,976 KiB RSS among the shards
whose `/usr/bin/time` records included resident memory. The earlier monolithic
attempt was killed after 798.57 seconds at 8,158,112 KiB RSS after completing
34 cases in memory. The final result therefore preserves a measured baseline
for the planned one-case-per-Bazel-action evaluator.

One failed decision shard attempt added 1,100.99 seconds before its successful
resume. Including that attempt, observed decision-acquisition process time was
15,102.04 seconds. Semantic-prior acquisition was restartable and accumulated
valid observations over two failed processes plus the successful continuation;
their retained process wall times total 17,616.65 seconds. These attempt totals
are operational provenance, not provider latency.

The decision acquisition wall time corresponds to 3.580 seconds per Jev
decision referenced by the frozen predictions when total successful shard wall
time is divided by 3,911. That is a useful end-to-end throughput figure for this
run, but it is explicitly not a provider latency percentile: the numerator
contains non-provider work and the calls were embedded in sequential policy
execution.

## What the result supports

The strongest cost result is already sealed: 3,911 typed structural decisions
over 61 repository-localization cases cost $0.581380884 at the decision
endpoint. The token result is also exact. A comparison to a
full coding-agent workflow would require a separately measured coding-agent
baseline; this experiment does not manufacture one.

The strongest latency result is currently architectural rather than a provider
SLA: the expensive observations replay exactly with no network, and only about
2.2 seconds per case is measured inside the frozen structural precompute on the
current sequential implementation. Bazel/BuildBuddy will expose the 61 cases
as independent actions, so post-refactor wall time will measure parallel
critical-path execution rather than the sum of these migration-era loops.

## Provenance and limitations

- Semantic-prior usage is summed from the 2,089 immutable response envelopes
  under `.attune/semantic-prior-js-ts-scale-v1/observations/*/raw/`.
- Final-condition decision usage is summed from the `decisions` rows in all 61
  canonical frozen prediction Parquets. The retained-evidence superset is
  independently summed from the 4,306 immutable response envelopes in the
  scale stores for policy observations 003, 012, and 013.
- Whole-process wall times come from successful `/usr/bin/time` records under
  `.attune/logs/swe-explore-js-ts-scale/`.
- Structural precompute time comes from the frozen `SCALE_013` acquisition and
  replay summaries.
- Failed/restarted processes are reported separately so they cannot silently
  inflate scientific latency claims.
- Raw response envelopes contain no provider latency field. Future live
  acquisition should retain request start/end or duration at the native
  inference boundary, without changing request identity.
- `REPORT.md` is generated from the canonical evaluation Parquet. This document
  is the human-facing account of retained usage and timing evidence, not a
  second canonical dataset. Its tabular provenance will move to typed Parquet
  during the post-checkpoint schema migration.
