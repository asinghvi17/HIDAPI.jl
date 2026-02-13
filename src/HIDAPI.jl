module HIDAPI

using CEnum
using Libdl

using hidapi_jll: hidapi

include("generated/hidapi.jl")  # Auto-generated raw @ccall bindings
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
