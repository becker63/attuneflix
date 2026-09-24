from collections.abc import Callable
from ctypes import c_void_p

type StringReceiver = Callable[[c_void_p, int, c_void_p], None]

NIX_TYPE_STRING: int

def nix_get_string_callback(
    function: StringReceiver,
    /,
) -> object: ...
def nix_c_context_create() -> object: ...
def nix_c_context_free(context: object, /) -> None: ...
def nix_err_code(context: object, /) -> int: ...
def nix_err_info_msg(
    context: object,
    read_context: object,
    callback: object,
    user_data: None,
    /,
) -> int: ...
def nix_libutil_init(context: object, /) -> int: ...
def nix_libstore_init(context: object, /) -> int: ...
def nix_libexpr_init(context: object, /) -> int: ...
def nix_store_open(
    context: object,
    uri: object,
    params: None,
    /,
) -> object: ...
def nix_store_free(store: object, /) -> None: ...
def nix_store_get_uri(
    context: object,
    store: object,
    callback: object,
    user_data: None,
    /,
) -> int: ...
def nix_store_get_version(
    context: object,
    store: object,
    callback: object,
    user_data: None,
    /,
) -> int: ...
def nix_store_get_storedir(
    context: object,
    store: object,
    callback: object,
    user_data: None,
    /,
) -> int: ...
def nix_store_parse_path(
    context: object,
    store: object,
    path: object,
    /,
) -> object: ...
def nix_store_is_valid_path(
    context: object,
    store: object,
    path: object,
    /,
) -> bool: ...
def nix_store_real_path(
    context: object,
    store: object,
    path: object,
    callback: object,
    user_data: None,
    /,
) -> int: ...
def nix_store_path_name(
    path: object,
    callback: object,
    user_data: None,
    /,
) -> None: ...
def nix_store_path_free(
    path: object,
    /,
) -> None: ...
def nix_eval_state_builder_new(context: object, store: object, /) -> object: ...
def nix_eval_state_builder_free(builder: object, /) -> None: ...
def nix_eval_state_build(context: object, builder: object, /) -> object: ...
def nix_flake_settings_new(context: object, /) -> object: ...
def nix_flake_settings_free(settings: object, /) -> None: ...
def nix_flake_settings_add_to_eval_state_builder(
    context: object,
    settings: object,
    builder: object,
    /,
) -> int: ...
def nix_state_free(state: object, /) -> None: ...
def nix_alloc_value(
    context: object,
    state: object,
    /,
) -> object: ...
def nix_value_decref(
    context: object,
    value: object,
    /,
) -> int: ...
def nix_expr_eval_from_string(
    context: object,
    state: object,
    expression: object,
    path: object,
    value: object,
    /,
) -> int: ...
def nix_value_force(
    context: object,
    state: object,
    value: object,
    /,
) -> int: ...
def nix_get_type(
    context: object,
    value: object,
    /,
) -> int: ...
def nix_get_string(
    context: object,
    value: object,
    callback: object,
    user_data: None,
    /,
) -> int: ...
def nix_string_realise(
    context: object,
    state: object,
    value: object,
    is_ifd: bool,
    /,
) -> object: ...
def nix_realised_string_get_buffer_start(
    realised: object,
    /,
) -> c_void_p: ...
def nix_realised_string_get_buffer_size(
    realised: object,
    /,
) -> int: ...
def nix_realised_string_get_store_path_count(
    realised: object,
    /,
) -> int: ...
def nix_realised_string_get_store_path(
    realised: object,
    index: int,
    /,
) -> object: ...
def nix_realised_string_free(
    realised: object,
    /,
) -> None: ...
