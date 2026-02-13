using Clang
using Clang.Generators
using MacroTools: @capture, prettify
using JuliaFormatter: format

cd(@__DIR__)

# --- Locate the HIDAPI header from the local build ---
hidapi_include_dir = normpath(joinpath(@__DIR__, "..", "..", "hidapi", "hidapi"))
headers = [joinpath(hidapi_include_dir, "hidapi.h")]

# Verify header exists
for h in headers
    isfile(h) || error("Header not found: $h")
end

# --- Load Clang.jl configuration ---
options = load_options(joinpath(@__DIR__, "generator.toml"))

# --- Compiler arguments ---
args = get_default_args()
push!(args, "-I$hidapi_include_dir")

# --- Create context ---
ctx = create_context(headers, args, options)

# --- Stage 1: Parse headers and build expression DAG (no printing) ---
build!(ctx, BUILDSTAGE_NO_PRINTING)

# --- Rewriter: transform the DAG before printing ---
function rewrite_expr(ex::Expr)
    # Match function definitions with @ccall
    if @capture(ex, function fname_(fargs__)
        @ccall lib_.cname_(cargs__)::rettype_
    end)
        cc = :(@ccall $lib.$cname($(cargs...))::$rettype)

        # Wrap Cstring returns in unsafe_string
        cc_wrapped = if rettype == :Cstring
            :(unsafe_string($cc))
        else
            cc
        end

        return prettify(:(function $fname($(fargs...))
            $cc_wrapped
        end))
    end
    return ex
end

for node in get_nodes(ctx.dag)
    for (i, ex) in enumerate(node.exprs)
        node.exprs[i] = rewrite_expr(ex)
    end
end

# --- Stage 2: Print the transformed DAG to output file ---
build!(ctx, BUILDSTAGE_PRINTING_ONLY)

# --- Format the generated code ---
output_path = normpath(joinpath(@__DIR__, "..", "src", "generated"))
format(output_path)

println("Generation complete!")
