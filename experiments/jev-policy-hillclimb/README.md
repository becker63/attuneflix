# Jev Policy Hill Climb

This experiment treats the frozen fifteen-case SWE-Explore population as an
explicit optimization/development set. Its purpose is to recover as much of the
already-computed structural-oracle quality as possible with a policy that uses
only deployment-visible information at runtime.

The machine remains fixed: repository snapshots, admitted facts, semantic
prior, six structural atoms, depth seven, center count eight, compiled Radii
semantics, and the official scorer do not change. Gold and oracle values are
teachers and evaluators only; they are never candidate-policy inputs.

Each evaluated policy has one numbered directory, a predeclared hypothesis, a
machine-readable result, retained observations under `.attune/experiments/`,
and one independently recoverable Jujutsu checkpoint. Failed policies remain
part of the record.

Primary objective: aggregate official line F1. Near ties prefer context
efficiency, then HitFile, then fewer model calls.

See [INDEX.md](INDEX.md) for the chronological leaderboard.
