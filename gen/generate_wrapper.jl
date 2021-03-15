using Clang

all_headers = readdir(joinpath(SOPLEX_DIR, "src", "soplex"))
soplex_headers = vcat(
    filter(h -> startswith(h, "type_"), all_headers),
    filter(h -> startswith(h, "pub_"), all_headers),
    filter(h -> startswith(h, "scip_"), all_headers),
    "scipdefplugins.h",
    filter(h -> startswith(h, "cons_"), all_headers),
    "intervalarith.h",                                 # for nlpi/pub_expr
