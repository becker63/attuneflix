type NativeSpan = tuple[str, int, int]
type NativeLog = tuple[str, int, int]
type NativeEvaluation = tuple[
    bool,
    list[NativeSpan],
    list[NativeLog],
]

def run(
    program: str,
    path: str,
    content: str,
    /,
) -> NativeEvaluation: ...
