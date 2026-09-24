# Atlas and localization

This directory joins two independently frozen results:

- the issue-blind `atlas-signature-swe-explore-v1` census;
- the official 61-case SWE-Explore localization evaluation.

The Bazel target is:

```text
//.attune:atlas_localization_analysis
```

It consumes only the two canonical aggregate providers. It cannot change the
prior, iteration-013 policy, Atlas protocol, predictions, official evaluator,
or either frozen input. The exact `snapshot_id` is the join key.

Outputs:

- [REPORT.md](REPORT.md) is the readable, explicitly post-hoc analysis;
- `cases.parquet` is the typed 61-row data plane under
  `attune-atlas-localization-posthoc-v1`.

The two censored Three.js cases still have Atlas signatures, but they do not
appear here because the frozen localization protocol produced no prediction or
official evaluation for them.
