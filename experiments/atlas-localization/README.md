# Atlas and localization

This directory joins two independently frozen results:

- the issue-blind `atlas-signature-swe-explore-v1` census;
- the official 61-case SWE-Explore localization evaluation.

The analysis was frozen after consuming the two canonical typed aggregates.
Its executable implementation is preserved by the scientific checkpoint and
version history rather than kept as dormant machinery in current HEAD. The
exact `snapshot_id` was the join key, so neither experiment was retuned.

Outputs:

- [REPORT.md](REPORT.md) is the readable, explicitly post-hoc analysis;
- `cases.parquet` is the typed 61-row data plane under
  `attune-atlas-localization-posthoc-v1`.

The two censored Three.js cases still have Atlas signatures, but they do not
appear here because the frozen localization protocol produced no prediction or
official evaluation for them.
