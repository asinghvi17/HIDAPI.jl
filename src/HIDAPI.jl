module HIDAPI

using CEnum

# Resolve path to the locally-built HIDAPI shared library at precompile time.
const libhidapi = let
    candidates = [
        joinpath(@__DIR__, "..", "..", "hidapi", "build", "src", "mac", "libhidapi.dylib"),
        joinpath(@__DIR__, "..", "..", "hidapi", "build", "src", "mac", "libhidapi.0.dylib"),
        joinpath(@__DIR__, "..", "..", "hidapi", "build", "libhidapi.dylib"),
    ]
    idx = findfirst(isfile, candidates)
    if idx === nothing
        error("libhidapi.dylib not found. Build HIDAPI first.")
    end
    normpath(candidates[idx])
end

include("generated/libhidapi.jl")  # Auto-generated raw @ccall bindings
include("error.jl")                # HIDAPIError, unsafe_wstring, check_result
include("devices.jl")              # High-level Julian API

export HIDAPIError, HIDDevice, HIDDeviceInfo
export init, shutdown, version
export set_nonblocking
export send_feature_report, get_feature_report, get_input_report, get_report_descriptor
export get_manufacturer, get_product, get_serial, get_indexed_string
# Note: enumerate, open, read, write, close are intentionally not exported
# because they shadow Base functions. Use HIDAPI.enumerate(), HIDAPI.open(), etc.

include("dualsense/DualSense.jl")

end # module HIDAPI
