"""Bazel graph for replaying the frozen localization evidence."""

load(
    "//build:attune.bzl",
    "attune_atlas_localization_analysis",
    "attune_decision_bundle",
    "attune_decision_bundles",
    "attune_localization_evaluation",
    "attune_localization_evaluations",
    "attune_localization_data",
    "attune_localization_replay",
    "attune_localization_replays",
)
load("//experiments/atlas-swe-explore/census:census.bzl", "ATLAS_WORLDS")

# Frozen manifest index, scientific instance identity, and base revision. The
# two censored Three.js cases (42 and 43) are deliberately absent.
_CASES = [
    ("00", "NodeBB__NodeBB-05f2236193f407cf8e2072757fbd6bb170bc13f0-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "c5ae8a70e1b0305af324ad7b1b0911d4023f1338"),
    ("01", "NodeBB__NodeBB-0c81642997ea1d827dbd02c311db9d4976112cd4-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "03a98f4de484f16d038892a0a9d2317a45e79df1"),
    ("02", "NodeBB__NodeBB-1ea9481af6125ffd6da0592ed439aa62af0bca11-vd59a5728dfc977f44533186ace531248c2917516", "bbaf26cedc3462ef928906dc90db5cb98a3ec22e"),
    ("03", "NodeBB__NodeBB-22368b996ee0e5f11a5189b400b33af3cc8d925a-v4fbcfae8b15e4ce5d132c408bca69ebb9cf146ed", "88aee439477603da95beb8a1cc23d43b9d6d482c"),
    ("04", "NodeBB__NodeBB-2657804c1fb6b84dc76ad3b18ecf061aaab5f29f-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "3ecbb624d892b9fce078304cf89c0fe94f8ab3be"),
    ("05", "NodeBB__NodeBB-397835a05a8e2897324e566b41c5e616e172b4af-v89631a1cdb318276acb48860c5d78077211397c6", "7f48edc02aa68c547d96ad7d6432ff8c1e359742"),
    ("06", "NodeBB__NodeBB-4327a09d76f10a79109da9d91c22120428d3bdb9-vnan", "754965b572f33bfd864e98e4805e1182c1960080"),
    ("07", "NodeBB__NodeBB-51d8f3b195bddb13a13ddc0de110722774d9bb1b-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "da2441b9bd293d7188ee645be3322a7305a43a19"),
    ("08", "NodeBB__NodeBB-6489e9fd9ed16ea743cc5627f4d86c72fbdb3a8a-v2c59007b1005cd5cd14cbb523ca5229db1fd2dd8", "84dfda59e6a0e8a77240f939a7cb8757e6eaf945"),
    ("09", "NodeBB__NodeBB-6ea3b51f128dd270281db576a1b59270d5e45db0-vnan", "d9c42c000cd6c624794722fd55a741aff9d18823"),
    ("10", "NodeBB__NodeBB-70b4a0e2aebebe8f2f559de6680093d96a697b2f-vnan", "6bbe3d1c4cefe56f81629dfa3343fd0a875d9cf1"),
    ("11", "NodeBB__NodeBB-767973717be700f46f06f3e7f4fc550c63509046-vnan", "a2ebf53b6098635c3abcab3fd9144c766e32b350"),
    ("12", "NodeBB__NodeBB-76c6e30282906ac664f2c9278fc90999b27b1f48-vd59a5728dfc977f44533186ace531248c2917516", "a3e1a666b876e0b3ccbb5284dd826c8c90c113b4"),
    ("13", "NodeBB__NodeBB-7b8bffd763e2155cf88f3ebc258fa68ebe18188d-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "e0149462b3f4e7c843d89701ad9edd2e744d7593"),
    ("14", "NodeBB__NodeBB-8168c6c40707478f71b8af60300830fe554c778c-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "ab5e2a416324ec56cea44b79067ba798f8394de1"),
    ("15", "NodeBB__NodeBB-82562bec444940608052f3e4149e0c61ec80bf3f-vd59a5728dfc977f44533186ace531248c2917516", "779c73eadea5d4246a60ab60486d5e49164884db"),
    ("16", "NodeBB__NodeBB-84e065752f6d7fbe5c08cbf50cb173ffb866b8fa-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "50e1a1a7ca1d95cbf82187ff685bea8cf3966cd0"),
    ("17", "NodeBB__NodeBB-97c8569a798075c50e93e585ac741ab55cb7c28b-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "d9e2190a6b4b6bef2d8d2558524dd124be33760f"),
    ("18", "NodeBB__NodeBB-b1f9ad5534bb3a44dab5364f659876a4b7fe34c1-vnan", "6ecc791db9bfbb2a22e113e4630071da87ce3c1e"),
    ("19", "NodeBB__NodeBB-bad15643013ca15affe408b75eba9e47cc604bb2-vd59a5728dfc977f44533186ace531248c2917516", "be86d8efc7fb019e707754b8b64dd6cf3517e8c7"),
    ("20", "NodeBB__NodeBB-da0211b1a001d45d73b4c84c6417a4f1b0312575-vf2cf3cbd463b7ad942381f1c6d077626485a1e9e", "f8cfe64c7e5243ac394695293d7517b0b509a4b3"),
    ("21", "NodeBB__NodeBB-f083cd559d69c16481376868c8da65172729c0ca-vnan", "163c977d2f4891fa7c4372b9f6a686b1fa34350f"),
    ("24", "babel__babel-13928", "5134505bf93013c5fa7df66704df8d04becb7f7d"),
    ("25", "element-hq__element-web-18c03daa865d3c5b10e52b669cd50be34c67b2e5-vnan", "212233cb0b9127c95966492175a730d5b954690f"),
    ("26", "element-hq__element-web-33e8edb3d508d6eefb354819ca693b7accc695e7", "83612dd4adeb2a4dad77655ec8969fcb1c555e6f"),
    ("27", "element-hq__element-web-494d9de6f0a94ffb491e74744d2735bce02dc0ab-vnan", "28f7aac9a5970d27ff3757875b464a5a58a1eb1a"),
    ("28", "element-hq__element-web-53a9b6447bd7e6110ee4a63e2ec0322c250f08d1-vnan", "97f6431d60ff5e3f9168948a306036402c316fa1"),
    ("29", "element-hq__element-web-53b42e321777a598aaf2bb3eab22d710569f83a8-vnan", "53415bfdfeb9f25e6755dde2bc41e9dbca4fa791"),
    ("30", "element-hq__element-web-880428ab94c6ea98d3d18dcaeb17e8767adcb461-vnan", "e6fe7b7ea8aad2672854b96b5eb7fb863e19cf92"),
    ("31", "element-hq__element-web-923ad4323b2006b2b180544429455ffe7d4a6cc3-vnan", "19b81d257f7b8b134bf5d7e555c9d5fca3570f69"),
    ("32", "element-hq__element-web-b007ea81b2ccd001b00f332bee65070aa7fc00f9-vnan", "c2ae6c279b8c80ea5bd58f3354e5949a9fa5ee41"),
    ("33", "element-hq__element-web-ca8b1b04effb4fec0e1dd3de8e3198eeb364d50e-vnan", "372720ec8bab38e33fa0c375ce231c67792f43a4"),
    ("34", "element-hq__element-web-ce554276db97b9969073369fefa4950ca8e54f84-vnan", "16e92a4d8cb66c10c46eb9d94d9e2b82d612108a"),
    ("35", "element-hq__element-web-ee13e23b156fbad9369d6a656c827b6444343d4f-vnan", "8ebdcab7d92f90422776c4390363338dcfd98ba5"),
    ("36", "element-hq__element-web-f14374a51c153f64f313243f2df6ea4971db4e15", "8c13a0f8d48441eccdd69e41e76251478bdeab8c"),
    ("37", "facebook__docusaurus-10130", "02e38d8ccf7811af27a9c15ddbadf4d26cfc0eab"),
    ("38", "facebook__docusaurus-10309", "5e9e1d051b2217b95498ecbc10f7e33f64e7a4d3"),
    ("39", "facebook__docusaurus-9897", "0589b1475d56b0b541348aa56f201ec7c56c56d5"),
    ("55", "protonmail__webclients-01b519cd49e6a24d9a05d2eb97f54e420740072e", "a118161e912592cc084945157b713050ca7ea4ba"),
    ("56", "protonmail__webclients-09fcf0dbdb87fa4f4a27700800ee4a3caed8b413", "41f29d1c8dad68d693d2e3e10e5c65b6fb780142"),
    ("57", "protonmail__webclients-0d0267c4438cf378bda90bc85eed3a3615871ac4", "782d01551257eb0a373db3b2d5c39612b87fa7e9"),
    ("58", "protonmail__webclients-2c3559cad02d1090985dba7e8eb5a129144d9811", "c35133622a7950d2aa96d1db03ad8b96ccd65df9"),
    ("59", "protonmail__webclients-32ff10999a06455cb2147f6873d627456924ae13", "c40dccc34870418e29f51861a38647bc1cbdf0a8"),
    ("60", "protonmail__webclients-3a6790f480309130b5d6332dce6c9d5ccca13ee3", "e131cde781c398b38f649501cae5f03cf77e75bd"),
    ("61", "protonmail__webclients-708ed4a299711f0fa79a907cc5847cfd39c0fc71", "3f9771dd682247118e66e9e27bc6ef677ef5214d"),
    ("62", "protonmail__webclients-7b833df125859e5eb98a826e5b83efe0f93a347b", "7264c6bd7f515ae4609be9a5f0c3032ae6fe486a"),
    ("63", "protonmail__webclients-815695401137dac2975400fc610149a16db8214b", "21b45bd4378834403ad9e69dc91605c21f43438b"),
    ("64", "protonmail__webclients-8afd9ce04c8dde9e150e1c2b50d32e7ee2efa3e7", "7ff95b70115415f47b89c81a40e90b60bcf3dbd8"),
    ("65", "protonmail__webclients-bf2e89c0c488ae1a87d503e5b09fe9dd2f2a635f", "a5e37d3fe77abd2279bea864bf57f8d641e1777b"),
    ("66", "protonmail__webclients-e9677f6c46d5ea7d277a4532a4bf90074f125f31", "078178de4df1ffb606f1fc5a46bebe6c31d06b4a"),
    ("67", "protonmail__webclients-f161c10cf7d31abf82e8d64d7a99c9fac5acfa18", "52ada0340f0ae0869ef1e3b92e1cc4c799b637cf"),
    ("68", "protonmail__webclients-fc9d535e9beb3ae30a52a7146398cadfd6e30606", "ebed8ea9f69216d3ce996dd88457046c0a033caf"),
    ("69", "tutao__tutanota-1e516e989b3c0221f4af6b297d9c0e4c43e4adc3-vbc0d9ba8f0071fbe982809910959a6ff8884dbbf", "7ebf14a3432c8f0d8b31d48968a08d055bec2002"),
    ("70", "tutao__tutanota-219bc8f05d7b980e038bc1524cb021bf56397a1b-vee878bb72091875e912c52fc32bc60ec3760227b", "9dfb7c231f98a2d3bf48a99577d8a55cfdb2480b"),
    ("71", "tutao__tutanota-befce4b146002b9abc86aa95f4d57581771815ce-vee878bb72091875e912c52fc32bc60ec3760227b", "26c98dd37701c1c657edec33465d52e43e4a05cb"),
    ("72", "tutao__tutanota-da4edb7375c10f47f4ed3860a591c5e6557f7b5c-vbc0d9ba8f0071fbe982809910959a6ff8884dbbf", "5f77040986114d0ed019e58cab6ddf5152e55dbb"),
    ("73", "tutao__tutanota-f3ffe17af6e8ab007e8d461355057ad237846d9d-vbc0d9ba8f0071fbe982809910959a6ff8884dbbf", "376d4f298af944bda3e3207ab03de0fcbfc13b2f"),
    ("74", "vuejs__core-11589", "3653bc0f45d6fedf84e29b64ca52584359c383c0"),
    ("75", "vuejs__core-11739", "cb843e0be31f9e563ccfc30eca0c06f2a224b505"),
    ("76", "vuejs__core-11870", "67d6596d40b1807b9cd8eb0d9282932ea77be3c0"),
    ("77", "vuejs__core-11915", "d0b513eb463f580e29378e43d112ff6859aa366e"),
]

def frozen_localization(enabled):
    """Declares the private-evidence graph when its two root inputs exist."""
    if not enabled:
        native.filegroup(
            name = "localization_evidence_unavailable",
            srcs = [],
            visibility = ["//visibility:public"],
        )
        return

    native.filegroup(
        name = "retained_scale_decision_envelopes",
        srcs = native.glob([
            "experiments/swe-explore-js-ts-scale/003-force-first-macro/raw/*.json",
            "experiments/swe-explore-js-ts-scale/012-pruned-planner-portfolio/raw/*.json",
            "experiments/swe-explore-js-ts-scale/013-deep-planner-portfolio/raw/*.json",
        ]),
    )
    typed_data = []
    for key, instance_id, revision in _CASES:
        data = "localization_data_" + key
        attune_localization_data(
            name = data,
            instance_id = instance_id,
            legacy_prediction = "experiments/swe-explore-js-ts-scale/013-predictions/%s.parquet" % revision,
            legacy_prior = "semantic-prior-js-ts-scale-v1/rankings/%s.parquet" % revision,
            tool = "//migration/localization_data:localization_data",
        )
        typed_data.append(":" + data)

    attune_decision_bundles(
        name = "localization_decision_bundles",
        base_revisions = [case[2] for case in _CASES],
        case_keys = [case[0] for case in _CASES],
        predictions = typed_data,
        raw_envelopes = [":retained_scale_decision_envelopes"],
        tool = "//migration/localization:decision_bundle",
    )

    replays = []
    evaluations = []
    for key, instance_id, revision in _CASES:
        decisions = "localization_decisions_" + key
        replay = "localization_replay_" + key
        evaluation = "localization_evaluation_" + key
        world = ATLAS_WORLDS[int(key)]
        data = ":localization_data_" + key
        attune_decision_bundle(
            name = decisions,
            bundles = ":localization_decision_bundles",
            case_key = key,
        )
        attune_localization_replay(
            name = replay,
            data = data,
            decisions = ":" + decisions,
            instance_id = instance_id,
            issues = "localization-inputs/issues.json",
            tool = "//experiments/localization-swe-explore:replay",
            world = world,
        )
        attune_localization_evaluation(
            name = evaluation,
            data = data,
            frozen_results = "//experiments/swe-explore-js-ts-scale:results-censored.parquet",
            geometry = "evaluation-inputs/geometry/%s.parquet" % key,
            gold = "evaluation-inputs/gold.parquet",
            instance_id = instance_id,
            issues = "localization-inputs/issues.json",
            replay = ":" + replay,
            tool = "//experiments/localization-swe-explore:evaluate",
            world = world,
        )
        replays.append(":" + replay)
        evaluations.append(":" + evaluation)

    native.filegroup(
        name = "localization_replay_cases",
        srcs = replays,
        visibility = ["//visibility:public"],
    )
    attune_localization_replays(
        name = "localization_replay",
        replays = replays,
        tool = "//experiments/localization-swe-explore:aggregate",
        visibility = ["//visibility:public"],
    )
    native.filegroup(
        name = "localization_evaluation_cases",
        srcs = evaluations,
        visibility = ["//visibility:public"],
    )
    attune_localization_evaluations(
        name = "localization_evaluation",
        evaluations = evaluations,
        tool = "//experiments/localization-swe-explore:aggregate_evaluation",
        visibility = ["//visibility:public"],
    )
    attune_atlas_localization_analysis(
        name = "atlas_localization_analysis",
        atlas = "//experiments/atlas-swe-explore/census:atlas_data",
        localization = ":localization_evaluation",
        tool = "//experiments/atlas-localization:analysis",
        visibility = ["//visibility:public"],
    )
