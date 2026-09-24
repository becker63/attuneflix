"""Tracked Bazel graph for the frozen 78-snapshot Atlas census."""

load(
    "//build:attune.bzl",
    "attune_atlas_aggregate",
    "attune_atlas_report",
    "attune_atlas_signature",
    "attune_atlas_signature_summaries",
    "attune_atlas_signature_summary",
    "attune_atlas_signatures",
)

# Ordered exactly like the frozen 78-case manifest. The labels point at typed,
# content-addressed Repository.World tables; neither these labels nor their
# identity metadata contain a Nix store path.
_WORLDS = [
    "//.attune/repository-world-v1/4b14c05228d2c59e68c2aaa978fb7d655aed032a75804f35ac94389520607084:world",
    "//.attune/repository-world-v1/43d1969f5d5b33ddcee39867475aaf1fdde2042171e2425b339e9b2fbffb8e5a:world",
    "//.attune/repository-world-v1/d60aff465833ebc595c2c3681e87a2a8fd3b352c0d45499f29deeec2a410e609:world",
    "//.attune/repository-world-v1/b01273c831ecb224f2c459aedf2020d5487d20ec961426026d93b25e015c4186:world",
    "//.attune/repository-world-v1/55d7a8cefbffbce2fd6aed9ed500e8473d5dc49b8f9308f1eede358dd1593911:world",
    "//.attune/repository-world-v1/8d83c99061722a8356c0ffdcb23976f0af9c6dc2d77131116cf5bff1dc031c0c:world",
    "//.attune/repository-world-v1/d13b9c7923b4753ff87cabfe722a0c6b928a50ed9dffebbda85ccb8d3641d9ed:world",
    "//.attune/repository-world-v1/0a4d2c8aacbbd3762bd6976bcf91866f819881ab0aad5580d9fadfdc6bbbd973:world",
    "//.attune/repository-world-v1/29e9da075af8f7bed29e7fdc29b7239fc39b633ef37658be4dd3200802df24f7:world",
    "//.attune/repository-world-v1/47676c68fbccfe9e87212f9d2225a33ccc4d975a182f5c7d99742069c6bb02e0:world",
    "//.attune/repository-world-v1/945252fe6e867e4d406e48af8ec2d7e9b025c4b63a1f878af2a976945021a29b:world",
    "//.attune/repository-world-v1/d81af495867cd7415488f697c081ce31ea2241c54bced4a8b496d67a894d2178:world",
    "//.attune/repository-world-v1/8037ac6f92441b6ba2c9c85ca3cdd7f469430c8c1337a783b44985f6b180829e:world",
    "//.attune/repository-world-v1/cb161a51dc34e3348154b57d2c4e6882552e5d5e5c9253dfd0e867c6aea5251b:world",
    "//.attune/repository-world-v1/bb174a00f1122b9df7e4ebb958bbcad8e5bd9c1842bb8da9add37a00f034747d:world",
    "//.attune/repository-world-v1/72a6fb2a39b820e1d21bb2059d937358647faf44982002ab988da1df6e04b459:world",
    "//.attune/repository-world-v1/962ea6c586b06ccf757b5a22fc7d8eb6a6d69f549949ecd15bfe7b58d5279621:world",
    "//.attune/repository-world-v1/f73daccf345e592d08fdcb534b830943dbe1a30c60b1b9cefbd1cbfa6d97ed33:world",
    "//.attune/repository-world-v1/f4f3fb7417a2711fb1cf379687841dab491f79755758f47824920cb11ea7b0ed:world",
    "//.attune/repository-world-v1/2d10a775f9683c1ae129907d2ed2345469363a0553b9cee91c210413aacf6c8e:world",
    "//.attune/repository-world-v1/ee4256c77f74bb7406db66a8f952d5caad16e8616072c92c82384dfe873797f7:world",
    "//.attune/repository-world-v1/c39f4787c4aad99b5033c759a3a9acb952f98d199b06d58ffdb231f058760d4e:world",
    "//.attune/repository-world-v1/1e44a1c45ec4a91bb7774dc6d37a2846a5f56262b6fa7ae5722bcbcc15ba10c7:world",
    "//.attune/repository-world-v1/af4495290bbce5f65c9fd59841254c0fb0460bda2f72ba2cb42658416c3520a6:world",
    "//.attune/repository-world-v1/002a462e6f58440bbf60071f1e945b38bb304fe46a38ca6fdfd578248693cf01:world",
    "//.attune/repository-world-v1/1f1fb6e8cbfb38f8d2f6f641fba3fbce89a1adfde8e9fd6b73cefd08611df23e:world",
    "//.attune/repository-world-v1/2ad7fd77595ba90034705832a91f64bf65800349797341182501c44b6d5c2075:world",
    "//.attune/repository-world-v1/8c478416d0cc6588a78c78756fd0579c1c84043c8113b9a67734eb2964f912e4:world",
    "//.attune/repository-world-v1/5d4287f3c0aaa688c773bd0f4684e2da11fac9a699e511a5c0a49e36e68937a0:world",
    "//.attune/repository-world-v1/482aa007034c4569f2c8f66ea1b732faa197ceab18938fa4fbdd2cd559701987:world",
    "//.attune/repository-world-v1/18c7f4c0686bfee7d0ffe6a5a8a503e14957c7896396801aa9bccfee501cdb94:world",
    "//.attune/repository-world-v1/be4b21ddb7b9f5c36b7d8004dee3a4592466219b32245d5d58b7e012b2a6bc8d:world",
    "//.attune/repository-world-v1/ea7c1240175d2dd358d6d532075055d20eeb1d10169b4fd814a0f41dd009cb1e:world",
    "//.attune/repository-world-v1/25054646c3f316d59634b7ef351e4cceae0e15c1ed4ad6e7b6a9e6ea07f4629f:world",
    "//.attune/repository-world-v1/a2fdbccfb962d71870ef586d45621dd5428a00118b09379d96cde4d4e33ef505:world",
    "//.attune/repository-world-v1/ff2df8a191125982b3f81183d8edba47888468c0feff1dfd555217faa858a779:world",
    "//.attune/repository-world-v1/e5bfbed1587a474108acc0a043858b1b6c6f118463bcafd6344a0d6e47e4af70:world",
    "//.attune/repository-world-v1/19fa623c87d7c746cf5b4af08f5b92c9fede4cd02f2e0772da95d223c1b52313:world",
    "//.attune/repository-world-v1/b9dd309ede3789e905993b104f3d9ff206a8810300c413fc3d467bbb1c2a1780:world",
    "//.attune/repository-world-v1/bc01d02e8d9bea47c2f2f8628d391c32e7b56a072143f6cdc24f027c51384113:world",
    "//.attune/repository-world-v1/f0d3c13774ad53f40a97c6e74c61e2705718cdd2b215560b9ede898df79c22da:world",
    "//.attune/repository-world-v1/975db8fff535fc05f8590cff0927c3023de27ade911bc314ae3f9a1bbc39fffe:world",
    "//.attune/repository-world-v1/c09c5aceb7270db20383531fa1c5f16b9e592b3592cabb62da376e8a9a41a872:world",
    "//.attune/repository-world-v1/0ba18a217eefcafd6ba5afe527e293f53643e7b6d5d6e3ae48cf9ad2e5e3171a:world",
    "//.attune/repository-world-v1/6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9:world",
    "//.attune/repository-world-v1/7dcd08c6dcd8558e051002333932a19ab74ee48fe7d3e288acda54dad1129b89:world",
    "//.attune/repository-world-v1/80b1792c54806b7f668cfe99126d221f59f280188794510cb57425a54dc9bf26:world",
    "//.attune/repository-world-v1/4fdaac70f41803332ccc735c2a6991132882f2bdb909d1450b287b9f38b9a24d:world",
    "//.attune/repository-world-v1/1044506ddb4491ea06a20209ab5bce6b7a278ee23a14e5db259d9a33d6241dcf:world",
    "//.attune/repository-world-v1/197d5a4deb6c1c7827e89304714830aa9be2c3f01b252d834427cb9a96ac402b:world",
    "//.attune/repository-world-v1/69e49acea3491b2e42ca15990b137fed59d69f5d9fcb8022a5d91b33722e49f9:world",
    "//.attune/repository-world-v1/8708b4d618d69f1f77980c37d9d04e2c0f4f346fd094745a72cf97861d10762a:world",
    "//.attune/repository-world-v1/000365e13105629d144db298591cebfc4c6cd58e546ab24d4f3bf6e836a14efe:world",
    "//.attune/repository-world-v1/c1e88c310b4d2d00ca66f8b05c98726c0a3ccbc6285496f796377029d53b75ac:world",
    "//.attune/repository-world-v1/409e2753ea0dddfc0db2fd2c60a4cd260302ac9e8ef1ef8a5603151a030d23df:world",
    "//.attune/repository-world-v1/54bbe0595be03ec61e2571706708686925ddbc600bbb001d6d60942dc6e71ede:world",
    "//.attune/repository-world-v1/e798747366601b55aa909a8724b64a2949accb6421a45f773251055d1e0313fa:world",
    "//.attune/repository-world-v1/a57d483946f45be372495cb0243cf4b5903726bdfea1909b01ff6a161864659a:world",
    "//.attune/repository-world-v1/bde468c0e909ebddbe2138914e2caa0619df93dbeac23ba765a4c701c6554e80:world",
    "//.attune/repository-world-v1/2d1fa59b3248944c7ea360bc178a689cddf1fe733db9d3dca1e34529c1939157:world",
    "//.attune/repository-world-v1/e37e024c1844c2b2f4e4221ead91b3aa396db23e7a4fa1b6e9bbe12238bfa1dc:world",
    "//.attune/repository-world-v1/e87245df2ce6b98863e6644cf146b0cc6992c7a5fdce6a067b997b3e75004230:world",
    "//.attune/repository-world-v1/d88ee1076ffd84be98861f5002bbc14c55d667dd31ac773911c490f8cd33d41d:world",
    "//.attune/repository-world-v1/0cc7b7c20b18e7bd7980c4510936b82c6d2a42556bbf86bacb56c23cfd87e6f1:world",
    "//.attune/repository-world-v1/5186c9010641e075f7ffc0d7b0f0752b8260f64862e3e5e9f1ec6b592313844f:world",
    "//.attune/repository-world-v1/262ffb4d4159c53a19b0a2d0e17ba255ad915e6c6c658c91b680e42aa3f6d5d1:world",
    "//.attune/repository-world-v1/accf5131f33552a6d04eff95d31291c1a10f47a2ac05b625004fd7e50da33881:world",
    "//.attune/repository-world-v1/50b27b40a91c9d9267da9d5b2620101e4798ef8f819c6e549f32b5f0da02d0ca:world",
    "//.attune/repository-world-v1/e340eb56a90c936d4a5879ec37f471260b07abeb021a11a29e2f3db0d1e35520:world",
    "//.attune/repository-world-v1/38cc6652f9833888aecbff584b825a5baadde579abb249860e0a6157d7221839:world",
    "//.attune/repository-world-v1/1dd4f1023c7ec84511b472dc4d888f653fcba7c3cfa07bed8fd24b19f3b5c166:world",
    "//.attune/repository-world-v1/45b8021a93812ab4080edeb1f8ebfcb1acad5ffe4d6d7122a30179a7e409c578:world",
    "//.attune/repository-world-v1/6fa65b34fcfd9e959d1cbf442c513bc2648cae8fe87ddd0c4a1217206d65ad17:world",
    "//.attune/repository-world-v1/1b1bc8349e395c8776a0ad6200d81355c753e089ef067543ebf37cbba0949171:world",
    "//.attune/repository-world-v1/96c87d8880052c38779278f3f6da6b143c57f5f8fc252f529321c73fdfb32510:world",
    "//.attune/repository-world-v1/9335add06b4ab87b65c8dbffb8aae507f77073e0b89eab4dcd8e1842782e8232:world",
    "//.attune/repository-world-v1/3b5f437f41ce2dfe1328116a893b4cada05008f1210045630bef2ed1546038d3:world",
    "//.attune/repository-world-v1/678f8ed4bfb9dda19f2f538fe1248da1ae809a11675498575a989b3b3744a9f3:world",
]

def atlas_census():
    """Expands the frozen manifest into independent Atlas actions."""
    signatures = []
    summaries = []
    for index, world in enumerate(_WORLDS):
        key = ("0" if index < 10 else "") + str(index)
        world_name = "world_" + key
        signature_name = "signature_" + key
        summary_name = "summary_" + key
        native.alias(name = world_name, actual = world)
        attune_atlas_signature(
            name = signature_name,
            tool = "//experiments/atlas-swe-explore:signature",
            world = ":" + world_name,
        )
        attune_atlas_signature_summary(
            name = summary_name,
            signature = ":" + signature_name,
            tool = "//experiments/atlas-swe-explore:summary",
        )
        signatures.append(":" + signature_name)
        summaries.append(":" + summary_name)

    native.filegroup(
        name = "worlds",
        srcs = [
            ":world_" + ("0" if index < 10 else "") + str(index)
            for index in range(len(_WORLDS))
        ],
        visibility = ["//visibility:public"],
    )
    attune_atlas_signatures(
        name = "signatures",
        signatures = signatures,
        visibility = ["//visibility:public"],
    )
    attune_atlas_signature_summaries(
        name = "signature_summaries",
        summaries = summaries,
        visibility = ["//visibility:public"],
    )
    attune_atlas_aggregate(
        name = "atlas_data",
        summaries = summaries,
        tool = "//experiments/atlas-swe-explore:aggregate",
        visibility = ["//visibility:public"],
    )
    attune_atlas_report(
        name = "report",
        aggregate = ":atlas_data",
        tool = "//experiments/atlas-swe-explore:report",
        visibility = ["//visibility:public"],
    )
