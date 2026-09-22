# Tree reuse experiment

## Hypothesis

A complete compositional policy family evaluated in one `Semantics.evaluateAll` region should perform much less physical repository work than the same normalized expressions evaluated one at a time in fresh regions.

## Implementation

- **SHARED:** one `Semantics.evaluateAll(world, input, candidates)` call.
- **INDEPENDENT:** one `Semantics.evaluateAll(world, input, expr :: Nil)` call per identical compatible expression, with metrics summed and result maps combined.
- The Flix test compares the complete normalized-expression result maps extensionally before reporting a cell.
- Candidate enumeration, Nix acquisition, Grit observation, repository admission, physical-world construction, and seed choice are outside policy timers.
- Each repository gets one untimed cost-4 SHARED/INDEPENDENT warmup. Normal cells use three repetitions in alternating S→I, I→S, S→I order and report medians; no treatment exceeded 60 seconds, so all completed cells used three repetitions.
- Independent tiers over 5,000 compatible policies are skipped without sampling. Each treatment has a 300-second deadline.
- Seeds are the four deduplicated quantile indices of ordered File and Symbol identity vectors.

No production semantic module differs from the active checkout. The only experiment code is `src/TreeReuse.flix`; `Policy`, `Synthesis`, `Semantics`, `Physical`, `Repository`, `Atlas`, and `Main` are byte-identical to the source checkout.

## Semantic parity

- Completed comparisons: **208**
- Result-map parity failures: **0**
- Predeclared policy-ceiling skips: **16** (all four Symbol seeds × four repositories at cost 7)
- Treatment time censoring: **0**
- Every repository run reports `Passed: 22, Failed: 0, Skipped: 0` from the Flix test runner.

## Candidate language

| Max cost | All normalized | File-compatible | Symbol-compatible | Location-compatible |
|---:|---:|---:|---:|---:|
| 1 | 11 | 3 | 6 | 2 |
| 2 | 12 | 3 | 6 | 3 |
| 3 | 73 | 16 | 49 | 8 |
| 4 | 79 | 16 | 49 | 14 |
| 5 | 910 | 164 | 701 | 45 |
| 6 | 961 | 164 | 701 | 96 |
| 7 | 15,683 | 2,463 | 12,885 | 335 |

For File and Symbol inputs the compatible family only grows at costs 1, 3, 5, and 7/5 respectively; identical cost-1/2, 3/4, and 5/6 work counts are therefore expected, not duplicated sampling.

## Axios

Snapshot: `/nix/store/2lrvyhagkbmid94r6186m7p9s9qhk5p8-source` at `c30252f685e8f4326722de84923fcbc8cf557f06`

World: 114 files, 295 symbols, 295 defines, 140 imports, 220 calls, 148 parents.

Acquisition 0.012s; Grit observation 16.761s; admission 0.048s; physical-world construction 0.007s; complete experiment test 18.3s.

### FILE 0: `.eslintrc.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.49× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.32× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 35 | 3 | 11.67× | 1.98× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 35 | 3 | 11.67× | 2.08× |
| 5 | 164 | 444 | 12 | 37.00× | 753 | 229 | 3.29× | 384 | 3 | 128.00× | 2.76× |
| 6 | 164 | 444 | 12 | 37.00× | 753 | 229 | 3.29× | 384 | 3 | 128.00× | 2.69× |
| 7 | 2,463 | 8,599 | 12 | 716.58× | 15,805 | 3,328 | 4.75× | 5,966 | 3 | 1988.67× | 2.92× |

### FILE 37: `lib/helpers/isAxiosError.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 4.40× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.31× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 44 | 12 | 3.67× | 2.50× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 44 | 12 | 3.67× | 2.09× |
| 5 | 164 | 458 | 48 | 9.54× | 767 | 278 | 2.76× | 586 | 42 | 13.95× | 3.45× |
| 6 | 164 | 458 | 48 | 9.54× | 767 | 278 | 2.76× | 586 | 42 | 13.95× | 3.49× |
| 7 | 2,463 | 9,199 | 168 | 54.76× | 16,404 | 3,839 | 4.27× | 10,363 | 139 | 74.55× | 5.97× |

### FILE 75: `test/specs/headers.spec.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 3.95× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.83× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 2.37× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 2.44× |
| 5 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.97× |
| 6 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.96× |
| 7 | 2,463 | 8,909 | 18 | 494.94× | 16,114 | 3,377 | 4.77× | 7,377 | 4 | 1844.25× | 2.69× |

### FILE 113: `webpack.config.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 3.10× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.58× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 2.36× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 2.38× |
| 5 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.94× |
| 6 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 3.05× |
| 7 | 2,463 | 8,909 | 18 | 494.94× | 16,114 | 3,377 | 4.77× | 7,377 | 4 | 1844.25× | 2.27× |

### SYMBOL 0: `dist/axios.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 5 | 2.40× | 2.80× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 5 | 2.40× | 1.82× |
| 3 | 49 | 92 | 27 | 3.41× | 135 | 70 | 1.93× | 121 | 8 | 15.12× | 1.61× |
| 4 | 49 | 92 | 27 | 3.41× | 135 | 70 | 1.93× | 121 | 8 | 15.12× | 1.65× |
| 5 | 701 | 1,967 | 42 | 46.83× | 3,314 | 879 | 3.77× | 1,951 | 19 | 102.68× | 3.01× |
| 6 | 701 | 1,967 | 42 | 46.83× | 3,314 | 879 | 3.77× | 1,951 | 19 | 102.68× | 3.75× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 98: `dist/axios.min.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 5 | 2.40× | 1.32× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 5 | 2.40× | 2.34× |
| 3 | 49 | 92 | 27 | 3.41× | 135 | 70 | 1.93× | 122 | 9 | 13.56× | 1.75× |
| 4 | 49 | 92 | 27 | 3.41× | 135 | 70 | 1.93× | 122 | 9 | 13.56× | 1.74× |
| 5 | 701 | 1,969 | 48 | 41.02× | 3,316 | 885 | 3.75× | 1,972 | 14 | 140.86× | 2.70× |
| 6 | 701 | 1,969 | 48 | 41.02× | 3,316 | 885 | 3.75× | 1,972 | 14 | 140.86× | 2.73× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 196: `lib/platform/browser/classes/URLSearchParams.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 6 | 2.00× | 2.63× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 6 | 2.00× | 2.56× |
| 3 | 49 | 92 | 33 | 2.79× | 135 | 76 | 1.78× | 130 | 17 | 7.65× | 1.78× |
| 4 | 49 | 92 | 33 | 2.79× | 135 | 76 | 1.78× | 130 | 17 | 7.65× | 1.85× |
| 5 | 701 | 1,977 | 90 | 21.97× | 3,324 | 970 | 3.43× | 2,249 | 75 | 29.99× | 4.52× |
| 6 | 701 | 1,977 | 90 | 21.97× | 3,324 | 970 | 3.43× | 2,249 | 75 | 29.99× | 2.77× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 294: `webpack.config.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 3 | 3.67× | 2.58× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 3 | 3.67× | 2.40× |
| 3 | 49 | 91 | 15 | 6.07× | 134 | 58 | 2.31× | 102 | 4 | 25.50× | 2.52× |
| 4 | 49 | 91 | 15 | 6.07× | 134 | 58 | 2.31× | 102 | 4 | 25.50× | 2.55× |
| 5 | 701 | 1,922 | 18 | 106.78× | 3,269 | 769 | 4.25× | 1,528 | 4 | 382.00× | 2.53× |
| 6 | 701 | 1,922 | 18 | 106.78× | 3,269 | 769 | 4.25× | 1,528 | 4 | 382.00× | 2.57× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### Repository summary at largest completed tiers

| Seeds | Tier | n | PT median | PT min | PT max | PE median | State median | Wall median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| File | 7 | 4 | 494.94× | 54.76× | 716.58× | 4.76× | 1844.25× | 2.80× |
| Symbol | 6 | 4 | 43.93× | 21.97× | 106.78× | 3.76× | 121.77× | 2.75× |
| Combined | File 7 / Symbol 6 | 8 | 80.77× | 21.97× | 716.58× | 4.26× | 261.43× | 2.75× |

Median transition compression by tier: c1 1.00×, c2 1.00×, c3 2.60×, c4 2.60×, c5 31.00×, c6 31.00×, c7 494.94×.

## Immutable

Snapshot: `/nix/store/fpqr6ffwj4fa2r6rx7qdbzni9b7gim72-source` at `493afba6ec17d9c999dc5a15ac80c71c6bdba1c3`

World: 195 files, 618 symbols, 618 defines, 358 imports, 799 calls, 213 parents.

Acquisition 0.038s; Grit observation 34.784s; admission 0.236s; physical-world construction 0.030s; complete experiment test 43.2s.

### FILE 0: `__tests__/ArraySeq.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 1.70× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.41× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 1.12× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 2.06× |
| 5 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.05× |
| 6 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.70× |
| 7 | 2,463 | 8,909 | 18 | 494.94× | 16,114 | 3,377 | 4.77× | 7,377 | 4 | 1844.25× | 2.51× |

### FILE 64: `src/Map.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 0.57× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.15× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 44 | 13 | 3.38× | 2.76× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 44 | 13 | 3.38× | 4.56× |
| 5 | 164 | 458 | 54 | 8.48× | 767 | 284 | 2.70× | 619 | 70 | 8.84× | 5.90× |
| 6 | 164 | 458 | 54 | 8.48× | 767 | 284 | 2.70× | 619 | 70 | 8.84× | 5.66× |
| 7 | 2,463 | 9,264 | 318 | 29.13× | 16,469 | 4,032 | 4.08× | 11,733 | 377 | 31.12× | 6.33× |

### FILE 129: `src/utils/isPlainObj.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 6.03× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.12× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 41 | 8 | 5.12× | 1.77× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 41 | 8 | 5.12× | 1.82× |
| 5 | 164 | 454 | 33 | 13.76× | 763 | 263 | 2.90× | 523 | 23 | 22.74× | 1.06× |
| 6 | 164 | 454 | 33 | 13.76× | 763 | 263 | 2.90× | 523 | 23 | 22.74× | 2.21× |
| 7 | 2,463 | 9,062 | 96 | 94.40× | 16,267 | 3,685 | 4.41× | 9,022 | 89 | 101.37× | 2.80× |

### FILE 194: `website/src/static/stripUndefineds.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 2.47× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.43× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 40 | 9 | 4.44× | 1.88× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 40 | 9 | 4.44× | 2.13× |
| 5 | 164 | 452 | 39 | 11.59× | 761 | 269 | 2.83× | 523 | 27 | 19.37× | 2.89× |
| 6 | 164 | 452 | 39 | 11.59× | 761 | 269 | 2.83× | 523 | 27 | 19.37× | 2.18× |
| 7 | 2,463 | 9,026 | 123 | 73.38× | 16,231 | 3,755 | 4.32× | 9,512 | 100 | 95.12× | 3.05× |

### SYMBOL 0: `__tests__/ArraySeq.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 3 | 3.67× | 0.59× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 3 | 3.67× | 2.44× |
| 3 | 49 | 91 | 15 | 6.07× | 134 | 58 | 2.31× | 102 | 4 | 25.50× | 2.05× |
| 4 | 49 | 91 | 15 | 6.07× | 134 | 58 | 2.31× | 102 | 4 | 25.50× | 2.39× |
| 5 | 701 | 1,922 | 18 | 106.78× | 3,269 | 769 | 4.25× | 1,528 | 4 | 382.00× | 2.11× |
| 6 | 701 | 1,922 | 18 | 106.78× | 3,269 | 769 | 4.25× | 1,528 | 4 | 382.00× | 2.30× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 205: `src/List.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.66× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.40× |
| 3 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 138 | 29 | 4.76× | 2.41× |
| 4 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 138 | 29 | 4.76× | 2.52× |
| 5 | 701 | 1,985 | 156 | 12.72× | 3,332 | 1,079 | 3.09× | 2,605 | 165 | 15.79× | 3.29× |
| 6 | 701 | 1,985 | 156 | 12.72× | 3,332 | 1,079 | 3.09× | 2,605 | 165 | 15.79× | 3.66× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 411: `src/Stack.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 2.09× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.89× |
| 3 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 139 | 33 | 4.21× | 2.46× |
| 4 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 139 | 33 | 4.21× | 2.47× |
| 5 | 701 | 1,985 | 177 | 11.21× | 3,332 | 1,100 | 3.03× | 2,629 | 199 | 13.21× | 3.38× |
| 6 | 701 | 1,985 | 177 | 11.21× | 3,332 | 1,100 | 3.03× | 2,629 | 199 | 13.21× | 3.48× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 617: `website/src/static/stripUndefineds.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 6 | 2.00× | 2.46× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 6 | 2.00× | 1.93× |
| 3 | 49 | 92 | 33 | 2.79× | 135 | 76 | 1.78× | 129 | 15 | 8.60× | 1.68× |
| 4 | 49 | 92 | 33 | 2.79× | 135 | 76 | 1.78× | 129 | 15 | 8.60× | 0.43× |
| 5 | 701 | 1,975 | 81 | 24.38× | 3,322 | 961 | 3.46× | 2,266 | 54 | 41.96× | 2.42× |
| 6 | 701 | 1,975 | 81 | 24.38× | 3,322 | 961 | 3.46× | 2,266 | 54 | 41.96× | 3.18× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### Repository summary at largest completed tiers

| Seeds | Tier | n | PT median | PT min | PT max | PE median | State median | Wall median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| File | 7 | 4 | 83.89× | 29.13× | 494.94× | 4.37× | 98.25× | 2.92× |
| Symbol | 6 | 4 | 18.55× | 11.21× | 106.78× | 3.27× | 28.88× | 3.33× |
| Combined | File 7 / Symbol 6 | 8 | 51.26× | 11.21× | 494.94× | 4.17× | 68.54× | 3.12× |

Median transition compression by tier: c1 1.00×, c2 1.00×, c3 2.36×, c4 2.36×, c5 13.24×, c6 13.24×, c7 83.89×.

## Preact

Snapshot: `/nix/store/dsw6bgb3qb7m1xvh3xrn325lfbfdfbp2-source` at `b17a932342bfdeeaf1dc0fbe4f436c83e258d6c8`

World: 210 files, 1,623 symbols, 1,623 defines, 205 imports, 604 calls, 251 parents.

Acquisition 0.071s; Grit observation 98.390s; admission 2.567s; physical-world construction 0.083s; complete experiment test 114.3s.

### FILE 0: `babel.config.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.99× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.07× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 35 | 3 | 11.67× | 2.44× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 35 | 3 | 11.67× | 2.35× |
| 5 | 164 | 444 | 12 | 37.00× | 753 | 229 | 3.29× | 384 | 3 | 128.00× | 2.86× |
| 6 | 164 | 444 | 12 | 37.00× | 753 | 229 | 3.29× | 384 | 3 | 128.00× | 2.41× |
| 7 | 2,463 | 8,599 | 12 | 716.58× | 15,805 | 3,328 | 4.75× | 5,966 | 3 | 1988.67× | 3.60× |

### FILE 69: `debug/test/browser/debug-suspense.test.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 2.28× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 2.56× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 41 | 9 | 4.56× | 2.32× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 41 | 9 | 4.56× | 1.58× |
| 5 | 164 | 454 | 39 | 11.64× | 763 | 269 | 2.84× | 536 | 28 | 19.14× | 3.60× |
| 6 | 164 | 454 | 39 | 11.64× | 763 | 269 | 2.84× | 536 | 28 | 19.14× | 3.37× |
| 7 | 2,463 | 9,087 | 129 | 70.44× | 16,292 | 3,761 | 4.33× | 9,545 | 115 | 83.00× | 8.86× |

### FILE 139: `src/diff/catch-error.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.93× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.66× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 40 | 7 | 5.71× | 1.98× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 40 | 7 | 5.71× | 2.03× |
| 5 | 164 | 452 | 30 | 15.07× | 761 | 260 | 2.93× | 503 | 20 | 25.15× | 2.37× |
| 6 | 164 | 452 | 30 | 15.07× | 761 | 260 | 2.93× | 503 | 20 | 25.15× | 2.38× |
| 7 | 2,463 | 9,007 | 90 | 100.08× | 16,211 | 3,666 | 4.42× | 8,530 | 77 | 110.78× | 3.58× |

### FILE 209: `test/ts/refs.tsx`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 4.07× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 3.65× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 1.84× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 38 | 4 | 9.50× | 1.82× |
| 5 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.72× |
| 6 | 164 | 450 | 18 | 25.00× | 759 | 235 | 3.23× | 455 | 4 | 113.75× | 2.72× |
| 7 | 2,463 | 8,909 | 18 | 494.94× | 16,114 | 3,377 | 4.77× | 7,377 | 4 | 1844.25× | 2.77× |

### SYMBOL 0: `benches/scripts/bench.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 5 | 2.20× | 2.67× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 5 | 2.20× | 2.29× |
| 3 | 49 | 91 | 27 | 3.37× | 134 | 70 | 1.91× | 118 | 16 | 7.38× | 2.14× |
| 4 | 49 | 91 | 27 | 3.37× | 134 | 70 | 1.91× | 118 | 16 | 7.38× | 2.20× |
| 5 | 701 | 1,944 | 84 | 23.14× | 3,291 | 921 | 3.57× | 2,095 | 31 | 67.58× | 2.72× |
| 6 | 701 | 1,944 | 84 | 23.14× | 3,291 | 921 | 3.57× | 2,095 | 31 | 67.58× | 2.69× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 540: `hooks/test/browser/combinations.test.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 6 | 2.00× | 1.84× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 6 | 2.00× | 2.29× |
| 3 | 49 | 92 | 33 | 2.79× | 135 | 76 | 1.78× | 131 | 20 | 6.55× | 1.25× |
| 4 | 49 | 92 | 33 | 2.79× | 135 | 76 | 1.78× | 131 | 20 | 6.55× | 1.25× |
| 5 | 701 | 1,977 | 108 | 18.31× | 3,324 | 988 | 3.36× | 2,301 | 91 | 25.29× | 3.83× |
| 6 | 701 | 1,977 | 108 | 18.31× | 3,324 | 988 | 3.36× | 2,301 | 91 | 25.29× | 3.77× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 1081: `test/browser/fragments.test.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 5 | 2.40× | 2.00× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 5 | 2.40× | 1.75× |
| 3 | 49 | 92 | 27 | 3.41× | 135 | 70 | 1.93× | 122 | 13 | 9.38× | 1.33× |
| 4 | 49 | 92 | 27 | 3.41× | 135 | 70 | 1.93× | 122 | 13 | 9.38× | 1.33× |
| 5 | 701 | 1,967 | 69 | 28.51× | 3,314 | 906 | 3.66× | 2,040 | 54 | 37.78× | 3.86× |
| 6 | 701 | 1,967 | 69 | 28.51× | 3,314 | 906 | 3.66× | 2,040 | 54 | 37.78× | 3.84× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 1622: `test/ts/refs.tsx`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 4 | 3.00× | 2.60× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 4 | 3.00× | 2.23× |
| 3 | 49 | 92 | 21 | 4.38× | 135 | 64 | 2.11× | 114 | 5 | 22.80× | 2.14× |
| 4 | 49 | 92 | 21 | 4.38× | 135 | 64 | 2.11× | 114 | 5 | 22.80× | 2.38× |
| 5 | 701 | 1,959 | 24 | 81.62× | 3,306 | 818 | 4.04× | 1,729 | 5 | 345.80× | 2.63× |
| 6 | 701 | 1,959 | 24 | 81.62× | 3,306 | 818 | 4.04× | 1,729 | 5 | 345.80× | 2.59× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### Repository summary at largest completed tiers

| Seeds | Tier | n | PT median | PT min | PT max | PE median | State median | Wall median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| File | 7 | 4 | 297.51× | 70.44× | 716.58× | 4.59× | 977.51× | 3.59× |
| Symbol | 6 | 4 | 25.83× | 18.31× | 81.62× | 3.62× | 52.68× | 3.23× |
| Combined | File 7 / Symbol 6 | 8 | 76.03× | 18.31× | 716.58× | 4.19× | 96.89× | 3.59× |

Median transition compression by tier: c1 1.00×, c2 1.00×, c3 2.60×, c4 2.60×, c5 24.07×, c6 24.07×, c7 297.51×.

## Vue

Snapshot: `/nix/store/a96wb59vjms2wx87nwq2z4wix3km9vms-source` at `3653bc0f45d6fedf84e29b64ca52584359c383c0`

World: 516 files, 4,149 symbols, 4,149 defines, 1,177 imports, 4,594 calls, 594 parents.

Acquisition 0.131s; Grit observation 264.020s; admission 21.423s; physical-world construction 0.258s; complete experiment test 296.5s.

### FILE 0: `eslint.config.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 1.92× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 3 | 2.00× | 2.43× |
| 3 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 35 | 3 | 11.67× | 2.44× |
| 4 | 16 | 29 | 12 | 2.42× | 42 | 25 | 1.68× | 35 | 3 | 11.67× | 2.39× |
| 5 | 164 | 444 | 12 | 37.00× | 753 | 229 | 3.29× | 384 | 3 | 128.00× | 2.95× |
| 6 | 164 | 444 | 12 | 37.00× | 753 | 229 | 3.29× | 384 | 3 | 128.00× | 2.73× |
| 7 | 2,463 | 8,599 | 12 | 716.58× | 15,805 | 3,328 | 4.75× | 5,966 | 3 | 1988.67× | 2.76× |

### FILE 171: `packages/compiler-ssr/__tests__/ssrScopeId.spec.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 7.90× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 2.76× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 38 | 7 | 5.43× | 1.31× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 38 | 7 | 5.43× | 2.53× |
| 5 | 164 | 448 | 27 | 16.59× | 757 | 257 | 2.95× | 437 | 17 | 25.71× | 3.87× |
| 6 | 164 | 448 | 27 | 16.59× | 757 | 257 | 2.95× | 437 | 17 | 25.71× | 3.85× |
| 7 | 2,463 | 8,720 | 66 | 132.12× | 15,926 | 3,612 | 4.41× | 6,948 | 52 | 133.62× | 3.71× |

### FILE 343: `packages/runtime-core/src/warning.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.69× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 2.51× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 43 | 12 | 3.58× | 1.16× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 43 | 12 | 3.58× | 1.14× |
| 5 | 164 | 458 | 51 | 8.98× | 767 | 281 | 2.73× | 606 | 60 | 10.10× | 4.02× |
| 6 | 164 | 458 | 51 | 8.98× | 767 | 281 | 2.73× | 606 | 60 | 10.10× | 3.33× |
| 7 | 2,463 | 9,259 | 282 | 32.83× | 16,464 | 3,983 | 4.13× | 11,545 | 319 | 36.19× | 7.40× |

### FILE 515: `vitest.unit.config.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 4.75× |
| 2 | 3 | 3 | 3 | 1.00× | 3 | 3 | 1.00× | 6 | 4 | 1.50× | 3.34× |
| 3 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 38 | 6 | 6.33× | 1.91× |
| 4 | 16 | 29 | 15 | 1.93× | 42 | 28 | 1.50× | 38 | 6 | 6.33× | 2.37× |
| 5 | 164 | 448 | 21 | 21.33× | 757 | 251 | 3.02× | 428 | 11 | 38.91× | 2.33× |
| 6 | 164 | 448 | 21 | 21.33× | 757 | 251 | 3.02× | 428 | 11 | 38.91× | 2.26× |
| 7 | 2,463 | 8,700 | 39 | 223.08× | 15,906 | 3,542 | 4.49× | 6,559 | 16 | 409.94× | 2.31× |

### SYMBOL 0: `packages-private/dts-built-test/src/index.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 3 | 3.67× | 2.44× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 11 | 3 | 3.67× | 2.38× |
| 3 | 49 | 91 | 15 | 6.07× | 134 | 58 | 2.31× | 102 | 4 | 25.50× | 2.38× |
| 4 | 49 | 91 | 15 | 6.07× | 134 | 58 | 2.31× | 102 | 4 | 25.50× | 2.43× |
| 5 | 701 | 1,922 | 18 | 106.78× | 3,269 | 769 | 4.25× | 1,528 | 4 | 382.00× | 2.50× |
| 6 | 701 | 1,922 | 18 | 106.78× | 3,269 | 769 | 4.25× | 1,528 | 4 | 382.00× | 2.44× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 1382: `packages/runtime-core/__tests__/apiOptions.spec.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 4 | 3.00× | 1.51× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 4 | 3.00× | 1.47× |
| 3 | 49 | 92 | 21 | 4.38× | 135 | 64 | 2.11× | 114 | 7 | 16.29× | 1.06× |
| 4 | 49 | 92 | 21 | 4.38× | 135 | 64 | 2.11× | 114 | 7 | 16.29× | 1.15× |
| 5 | 701 | 1,959 | 36 | 54.42× | 3,306 | 830 | 3.98× | 1,775 | 20 | 88.75× | 2.44× |
| 6 | 701 | 1,959 | 36 | 54.42× | 3,306 | 830 | 3.98× | 1,775 | 20 | 88.75× | 2.65× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 2765: `packages/runtime-core/src/compat/renderHelpers.ts`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.58× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.60× |
| 3 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 146 | 34 | 4.29× | 1.24× |
| 4 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 146 | 34 | 4.29× | 1.34× |
| 5 | 701 | 1,993 | 192 | 10.38× | 3,340 | 1,115 | 3.00× | 2,815 | 217 | 12.97× | 2.89× |
| 6 | 701 | 1,993 | 192 | 10.38× | 3,340 | 1,115 | 3.00× | 2,815 | 217 | 12.97× | 2.88× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### SYMBOL 4148: `scripts/utils.js`

| Cost | Compatible | Independent PT | Shared PT | PT compression | Independent PE | Shared PE | PE compression | Independent Σstates | Shared states | State compression | Wall speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.77× |
| 2 | 6 | 6 | 6 | 1.00× | 6 | 6 | 1.00× | 12 | 7 | 1.71× | 1.87× |
| 3 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 140 | 32 | 4.38× | 1.43× |
| 4 | 49 | 92 | 39 | 2.36× | 135 | 82 | 1.65× | 140 | 32 | 4.38× | 1.56× |
| 5 | 701 | 1,987 | 174 | 11.42× | 3,334 | 1,097 | 3.04× | 2,618 | 186 | 14.08× | 2.59× |
| 6 | 701 | 1,987 | 174 | 11.42× | 3,334 | 1,097 | 3.04× | 2,618 | 186 | 14.08× | 2.51× |
| 7 | 12,885 | — | — | skipped >5,000 | — | — | — | — | — | — | — |

### Repository summary at largest completed tiers

| Seeds | Tier | n | PT median | PT min | PT max | PE median | State median | Wall median |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| File | 7 | 4 | 177.60× | 32.83× | 716.58× | 4.45× | 271.78× | 3.24× |
| Symbol | 6 | 4 | 32.92× | 10.38× | 106.78× | 3.51× | 51.41× | 2.58× |
| Combined | File 7 / Symbol 6 | 8 | 80.60× | 10.38× | 716.58× | 4.19× | 111.18× | 2.71× |

Median transition compression by tier: c1 1.00×, c2 1.00×, c3 2.36×, c4 2.36×, c5 18.96×, c6 18.96×, c7 177.60×.

## Cross-repository summary

Macro values first take the median over seeds within each repository/domain/tier, then the median over the four repositories. Thus repositories receive equal weight.

| Domain | Cost | Compatible policies | Repositories | PT compression | PE compression | State compression | Wall speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| File | 1 | 3 | 4 | 1.00× | 1.00× | 1.62× | 3.49× |
| File | 2 | 3 | 4 | 1.00× | 1.00× | 1.62× | 2.90× |
| File | 3 | 16 | 4 | 2.05× | 1.54× | 6.74× | 1.99× |
| File | 4 | 16 | 4 | 2.05× | 1.54× | 6.74× | 2.17× |
| File | 5 | 164 | 4 | 19.50× | 3.03× | 50.88× | 2.87× |
| File | 6 | 164 | 4 | 19.50× | 3.03× | 50.88× | 2.78× |
| File | 7 | 2,463 | 4 | 237.56× | 4.52× | 624.65× | 3.08× |
| Symbol | 1 | 6 | 4 | 1.00× | 1.00× | 2.33× | 2.09× |
| Symbol | 2 | 6 | 4 | 1.00× | 1.00× | 2.33× | 2.09× |
| Symbol | 3 | 49 | 4 | 3.38× | 1.90× | 9.36× | 1.75× |
| Symbol | 4 | 49 | 4 | 3.38× | 1.90× | 9.36× | 1.78× |
| Symbol | 5 | 701 | 4 | 29.37× | 3.56× | 52.05× | 2.85× |
| Symbol | 6 | 701 | 4 | 29.37× | 3.56× | 52.05× | 2.99× |
| Symbol | 7 | 12,885 | 0 | skipped >5,000 | — | — | — |

## What was reused

Exact per-key hit-frequency ranking would require changing `Semantics.Memos`, so it was deliberately not instrumented. Existing aggregate counters are sufficient to show the mechanism without touching the evaluator. For the second quantile File seed at cost 7:

| Repository | Seed | Shared unique states | Shared PT | Shared transition reuses | Shared subtree reuses | Subtree-hit fraction |
|---|---|---:|---:|---:|---:|---:|
| Axios | `lib/helpers/isAxiosError.js` | 139 | 168 | 0 | 5,966 | 60.8% |
| Immutable | `src/Map.js` | 377 | 318 | 0 | 5,859 | 59.2% |
| Preact | `debug/test/browser/debug-suspense.test.js` | 115 | 129 | 0 | 5,966 | 61.3% |
| Vue | `packages/compiler-ssr/__tests__/ssrScopeId.spec.ts` | 52 | 66 | 0 | 5,943 | 62.2% |

The dominant reuse is expression/subtree reuse: expression memo hits prevent repeated descent far enough upstream that the lower `(Step, State)` transition memo reports zero direct hits in these representative cells. This is still exactly the intended shared physical DAG behavior; the primitive transitions disappear because whole repeated subtrees are reused first.

## Wall clock and acquisition

| Repository | Grit | Admission | Physical world | Experiment test | Largest-tier combined wall median |
|---|---:|---:|---:|---:|---:|
| Axios | 16.76s | 0.05s | 0.007s | 18.3s | 2.75× |
| Immutable | 34.78s | 0.24s | 0.030s | 43.2s | 3.12× |
| Preact | 98.39s | 2.57s | 0.083s | 114.3s | 3.59× |
| Vue | 264.02s | 21.42s | 0.258s | 296.5s | 2.71× |

Policy wall speedup is secondary and much smaller than semantic-work compression (roughly 2.7–3.6× at each repository's largest completed tiers). Region creation, hash-table work, expression traversal, allocation, and JVM effects remain after primitive transition work collapses. Shared wall time was not worse at the largest completed tiers.

Peak RSS was not captured: GNU `time -v` was unavailable in the environment, and rerunning multi-minute Grit extraction solely for memory would violate the 'if cheaply available' condition. A live Vue process snapshot showed about 1.33 GB during Grit/test execution, but it was not a peak measurement and is not used as a result.

## Censoring and verification

- 208 completed repository × seed × tier cells; 16 predeclared Symbol cost-7 skips; no sampled replacement.
- No treatment reached the 300-second ceiling; all completed cells used three timed repetitions.
- `nix develop path:. -c flix check`: passed.
- Four `nix develop path:. -c flix test` runs: each passed 22/22 tests, including the experiment's full-map assertions and the unchanged semantic/parity suite.
- The test runner also executes the existing frozen Axios Nix/Grit test before the selected experiment. That work is outside all experiment timers; the selected repository itself is acquired/observed once and reused across every seed/tier.

Raw log SHA-256 values:

- `259332a111fd51d43af70f002ed942cdba543140e615db20009d2ca72ff12ac0`  `tree-reuse-axios.log`
- `08e7c73149f479d4b9713765c630e5dab9e06c908e154f234f169ce7438fb955`  `tree-reuse-immutable.log`
- `2c2516999fb2df1ea6343ef372e64564b778c643637a72ad69840230adb83625`  `tree-reuse-preact.log`
- `3dd65832cd67bd39c8f6d99c257a6096050cef3bd216d4798b0bf688bc9aaa34`  `tree-reuse-vue.log`

## Conclusion

**Yes: real-repository policy-tree evaluation collapses into a substantially smaller physical DAG.** At the largest completed File tier (2,463 expressions), the cross-repository macro median primitive-transition compression is **237.56×**; the repository medians range from **83.89×** (Immutable) to **494.94×** (Axios). At the largest completed Symbol tier (701 expressions), macro median transition compression is **29.37×**. Compression grows sharply with the policy family: macro File transition compression progresses from 1.00× at 3 candidates, to 2.05× at 16, 19.50× at 164, and 237.56× at 2,463.

The result is not merely a count artifact: all 208 completed cells produced exactly the same normalized-expression → exact-state map in SHARED and INDEPENDENT modes. The logical family grows much faster than the shared primitive-transition DAG.

## Implication

The measured process-local reuse is large enough to justify investigating durable memoization next, especially for exact `(WorldId, ExprId, StateId)` subtrees. It does **not** establish that persistence will pay after serialization, identity checking, invalidation, and storage costs; that must be measured independently.

## Next experiment (not started)

Measure durable reuse of exact deterministic subtree identities across fresh processes, with serialization and lookup overhead included.
