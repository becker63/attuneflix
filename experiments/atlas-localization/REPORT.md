# Atlas geometry and localization regime

This is a deterministic **post-hoc** join of two experiments that were sealed first: the issue-blind Atlas census and the official 61-case SWE-Explore localization result. It did not change the frozen prior, iteration-013 policy, Atlas protocol, or either result.

The snapshot is the join key. Every completed localization case has exactly one frozen Atlas signature for the same repository revision and admitted fact identity. The 61 cases cover seven repositories, so snapshot-level correlations are descriptive and are not 61 independent repository experiments.

## Repository regimes

`013 delta` is iteration-013 F1 minus the untouched prior. `Headroom` is the structural oracle F1 minus prior F1. Extinction, reach, and recurrence are issue-blind Atlas signature medians for File/Symbol seeds.

| Repository | Cases | Prior F1 | 013 F1 | Oracle F1 | 013 delta | Headroom | Context delta | Regressions | Extinction F/S | Reach F/S | Recurrence F/S | Physical compression |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| NodeBB/NodeBB | 22 | 0.04346670659721726 | 0.05114441785848756 | 0.10051311914125405 | 0.007677711261270315 | 0.0570464125440368 | 0.057092876016367984 | 1 | 0.7503049710277524 / 0.601555352241537 | 0.30619345859429364 / 0.2399193548387097 | 6.965480616038237 / 6.379377431906615 | 4.425101214574899 |
| babel/babel | 1 | 0.026241799437675725 | 0.02788104089219331 | 0.19914163090128756 | 0.0016392414545175864 | 0.17289983146361182 | 0.16666666666666663 | 0 | 0.9947773711497407 / 0.6941903019213175 | 0.0 / 0.009504565184852567 | 2623.2 / 6.971033749667818 | 273.25 |
| element-hq/element-web | 12 | 0.1515553190654268 | 0.14316885122683423 | 0.292403500133004 | -0.008386467838592595 | 0.14084818106757716 | 0.013506240053040769 | 3 | 0.2711192436718512 / 0.4919563891430314 | 0.706097714934983 / 0.5920190589636688 | 2.2888055143530233 / 3.053428006052846 | 2.248971193415638 |
| facebook/docusaurus | 3 | 0.21248570092700403 | 0.16206770229997722 | 0.37697285481558507 | -0.05041799862702683 | 0.16448715388858104 | -0.07121174033250115 | 1 | 0.7259835315645013 / 0.7735590118938701 | 0.010305028854080791 / 0.031777557100297914 | 10.254886630179827 / 18.617459190915543 | 9.587719298245615 |
| protonmail/webclients | 14 | 0.2576772141997115 | 0.16914673880644676 | 0.3826105638131869 | -0.08853047539326471 | 0.12493334961347549 | -0.05019210942924405 | 7 | 0.5410186032326929 / 0.5596599573040562 | 0.12080536912751678 / 0.08277027027027027 | 3.932833583208396 / 3.76139948379696 | 3.46984126984127 |
| tutao/tutanota | 5 | 0.07800384559493388 | 0.12726341063316857 | 0.25946164202073735 | 0.0492595650382347 | 0.18145779642580345 | 0.03790621488350523 | 0 | 0.5074717901799329 / 0.6512656297651723 | 0.4232649071358749 / 0.33621517771373677 | 3.723491838183109 / 4.887646730016769 | 3.3425076452599387 |
| vuejs/core | 4 | 0.08575355405641828 | 0.11342950743567967 | 0.4318850300654767 | 0.02767595337926138 | 0.3461314760090584 | 0.3837673611111111 | 1 | 0.6307944495272949 / 0.5149435803598658 | 0.16377649325626203 / 0.1926782273603083 | 5.5848413881200765 / 5.059209257473481 | 3.3425076452599387 |

## Snapshot-level relationships

Each value is a Pearson correlation over the 61 exact snapshot/case joins. Positive means the outcome tends to rise with the signature feature; negative means it tends to fall. These measurements locate follow-up questions. They do not establish cause, and the repeated revisions from the same repositories make naive significance claims inappropriate.

| Signature feature | Prior F1 | 013 delta | Oracle headroom | Context-efficiency delta |
| --- | ---: | ---: | ---: | ---: |
| File extinction | -0.22860336537378936 | 0.020787689525862615 | -0.23512698220703654 | 0.0995342634171778 |
| Symbol extinction | -0.08548662204771294 | -0.057110788349685644 | -0.23509240800097367 | -0.12217972389201712 |
| File reach p90 | -0.14475129049573765 | 0.2169625952682046 | -0.004855118411231714 | -0.0020364549275612045 |
| Symbol reach p90 | -0.14943157818167943 | 0.24313300037672567 | 0.05010260775032575 | 0.06096460418143343 |
| File recurrence | -0.08286458606302173 | 0.02232073507113784 | 0.04709972050946016 | 0.06846444519540798 |
| Symbol recurrence | -0.027138510474409638 | -0.019771826417074347 | -0.0910268266531879 | -0.04003361877739606 |
| Physical compression | -0.0817837097691305 | 0.018179868563538745 | 0.04197467215474678 | 0.06506249479015314 |
| Physical reuse | -0.18733085687552456 | 0.0010075681326362155 | -0.2043796180471885 | 0.04843369080140244 |

## Localization-side recurrence

The official oracle evaluator considered 100223.0 logical routes, 67354.0 unique semantic states, 18325.0 unique top-five projections, and performed 18386.0 official score evaluations. Mean route/state compression was 1.6491630359817582x; mean state/projection compression was 4.888358749447559x. These are application-side counts and remain separate from the issue-blind Atlas signature.

## Limits

This analysis uses the completed 61-case JS/TS subset. The two Three.js localization censors remain absent because no frozen prediction/evaluation exists for them, even though their issue-blind Atlas signatures exist. The result is exploratory, not a retuning dataset for iteration 013. A future claim about prediction should be preregistered and tested on new repositories.
