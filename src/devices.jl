"""
    HIDDeviceInfo

Julia-native struct holding device enumeration info. Converted from the
C linked-list `hid_device_info` returned by `hid_enumerate`.
"""
struct HIDDeviceInfo
    path::String
    vendor_id::UInt16
    product_id::UInt16
    serial_number::String
    release_number::UInt16
    manufacturer::String
    product::String
    usage_page::UInt16
    usage::UInt16
    interface_number::Int32
    bus_type::hid_bus_type
end

"""
    HIDDevice

Wrapper around an open `hid_device*` handle. Closes the device on finalization.
"""
mutable struct HIDDevice
    ptr::Ptr{hid_device}

    function HIDDevice(ptr::Ptr{hid_device})
        ptr == C_NULL && throw(HIDAPIError("Failed to open HID device (NULL pointer)"))
        dev = new(ptr)
        finalizer(close, dev)
        return dev
    end
end

Base.isopen(dev::HIDDevice) = dev.ptr != C_NULL
Base.unsafe_convert(::Type{Ptr{hid_device}}, dev::HIDDevice) = dev.ptr

_check_open(dev::HIDDevice) = isopen(dev) || throw(HIDAPIError("Device is closed"))

# ---------- Lifecycle ----------

"""
    init()

Initialize the HIDAPI library. Call this before any other HIDAPI function.
"""
function init()
    ret = hid_init()
    ret == 0 || throw(HIDAPIError("hid_init failed with code $ret"))
    return nothing
end

"""
    shutdown()

Finalize the HIDAPI library. Call when done using HIDAPI.
"""
function shutdown()
    ret = hid_exit()
    ret == 0 || throw(HIDAPIError("hid_exit failed with code $ret"))
    return nothing
end

# ---------- Enumeration ----------

"""
    enumerate(vendor_id=0x0000, product_id=0x0000) -> Vector{HIDDeviceInfo}

Enumerate connected HID devices. Pass `0x0000` for vid/pid to match all.
"""
function enumerate(vendor_id::Integer=0x0000, product_id::Integer=0x0000)
    head = hid_enumerate(UInt16(vendor_id), UInt16(product_id))
    head == C_NULL && return HIDDeviceInfo[]

    devices = HIDDeviceInfo[]
    cur = head
    while cur != C_NULL
        info = unsafe_load(cur)
        push!(devices, HIDDeviceInfo(
            info.path == C_NULL ? "" : unsafe_string(info.path),
            info.vendor_id,
            info.product_id,
            unsafe_wstring(info.serial_number),
            info.release_number,
            unsafe_wstring(info.manufacturer_string),
            unsafe_wstring(info.product_string),
            info.usage_page,
            info.usage,
            info.interface_number,
            info.bus_type,
        ))
        cur = info.next
    end
    hid_free_enumeration(head)
    return devices
end

# ---------- Open / Close ----------

"""
    open(vendor_id, product_id; serial=nothing) -> HIDDevice

Open a HID device by vendor/product ID and optional serial number.
"""
function open(vendor_id::Integer, product_id::Integer; serial::Union{Nothing,AbstractString}=nothing)
    if serial === nothing
        ptr = hid_open(UInt16(vendor_id), UInt16(product_id), Ptr{Cwchar_t}(C_NULL))
    else
        wchars = Cwchar_t[Cwchar_t(c) for c in serial]
        push!(wchars, Cwchar_t(0))
        ptr = GC.@preserve wchars hid_open(UInt16(vendor_id), UInt16(product_id), pointer(wchars))
    end
    return HIDDevice(ptr)
end

"""
    open(path::AbstractString) -> HIDDevice

Open a HID device by its platform-specific path.
"""
function open(path::AbstractString)
    ptr = hid_open_path(path)
    return HIDDevice(ptr)
end

"""
    close(dev::HIDDevice)

Explicitly close an open HID device.
"""
function Base.close(dev::HIDDevice)
    if dev.ptr != C_NULL
        hid_close(dev.ptr)
        dev.ptr = C_NULL
    end
    return nothing
end

# ---------- I/O ----------

"""
    write(dev::HIDDevice, data::AbstractVector{UInt8}) -> Int

Send an output report. The first byte should be the report ID (0x00 if unused).
Returns the number of bytes written.
"""
function write(dev::HIDDevice, data::AbstractVector{UInt8})
    _check_open(dev)
    ret = GC.@preserve data hid_write(dev.ptr, pointer(data), length(data))
    check_result(ret, dev.ptr)
    return Int(ret)
end

"""
    read(dev::HIDDevice, maxlength::Integer; timeout_ms::Integer=-1) -> Vector{UInt8}

Read an input report. `timeout_ms=-1` blocks, `0` is non-blocking, `>0` waits that many ms.
Returns the data read (may be shorter than `maxlength`).
"""
function read(dev::HIDDevice, maxlength::Integer; timeout_ms::Integer=-1)
    _check_open(dev)
    buf = Vector{UInt8}(undef, maxlength)
    ret = GC.@preserve buf hid_read_timeout(dev.ptr, pointer(buf), length(buf), Int(timeout_ms))
    check_result(ret, dev.ptr)
    return resize!(buf, ret)
end

"""
    set_nonblocking(dev::HIDDevice, nonblock::Bool)

Set whether `read` calls are non-blocking.
"""
function set_nonblocking(dev::HIDDevice, nonblock::Bool)
    _check_open(dev)
    ret = hid_set_nonblocking(dev.ptr, nonblock ? 1 : 0)
    check_result(ret, dev.ptr)
    return nothing
end

# ---------- Feature / Output Reports ----------

"""
    send_feature_report(dev::HIDDevice, data::AbstractVector{UInt8}) -> Int

Send a feature report. First byte is the report ID.
"""
function send_feature_report(dev::HIDDevice, data::AbstractVector{UInt8})
    _check_open(dev)
    ret = GC.@preserve data hid_send_feature_report(dev.ptr, pointer(data), length(data))
    check_result(ret, dev.ptr)
    return Int(ret)
end

"""
    get_feature_report(dev::HIDDevice, report_id::UInt8, maxlength::Integer) -> Vector{UInt8}

Get a feature report. `report_id` is placed in the first byte of the buffer.
"""
function get_feature_report(dev::HIDDevice, report_id::UInt8, maxlength::Integer)
    _check_open(dev)
    buf = Vector{UInt8}(undef, maxlength)
    buf[1] = report_id
    ret = GC.@preserve buf hid_get_feature_report(dev.ptr, pointer(buf), length(buf))
    check_result(ret, dev.ptr)
    return resize!(buf, ret)
end

"""
    get_input_report(dev::HIDDevice, report_id::UInt8, maxlength::Integer) -> Vector{UInt8}

Get an input report.
"""
function get_input_report(dev::HIDDevice, report_id::UInt8, maxlength::Integer)
    _check_open(dev)
    buf = Vector{UInt8}(undef, maxlength)
    buf[1] = report_id
    ret = GC.@preserve buf hid_get_input_report(dev.ptr, pointer(buf), length(buf))
    check_result(ret, dev.ptr)
    return resize!(buf, ret)
end

"""
    get_report_descriptor(dev::HIDDevice) -> Vector{UInt8}

Get the raw HID report descriptor (up to 4096 bytes).
"""
function get_report_descriptor(dev::HIDDevice)
    _check_open(dev)
    buf = Vector{UInt8}(undef, HID_API_MAX_REPORT_DESCRIPTOR_SIZE)
    ret = GC.@preserve buf hid_get_report_descriptor(dev.ptr, pointer(buf), length(buf))
    check_result(ret, dev.ptr)
    return resize!(buf, ret)
end

# ---------- Device Strings ----------

function _get_wstring(f::Function, dev::HIDDevice, maxlen::Integer=256)
    _check_open(dev)
    buf = Vector{Cwchar_t}(undef, maxlen)
    ret = GC.@preserve buf f(dev.ptr, pointer(buf), length(buf))
    check_result(ret, dev.ptr)
    len = something(findfirst(==(Cwchar_t(0)), buf), length(buf) + 1) - 1
    return String(Char.(buf[1:len]))
end

"""
    get_manufacturer(dev::HIDDevice) -> String
"""
get_manufacturer(dev::HIDDevice) = _get_wstring(hid_get_manufacturer_string, dev)

"""
    get_product(dev::HIDDevice) -> String
"""
get_product(dev::HIDDevice) = _get_wstring(hid_get_product_string, dev)

"""
    get_serial(dev::HIDDevice) -> String
"""
get_serial(dev::HIDDevice) = _get_wstring(hid_get_serial_number_string, dev)

"""
    get_indexed_string(dev::HIDDevice, index::Integer) -> String
"""
get_indexed_string(dev::HIDDevice, index::Integer) =
    _get_wstring((ptr, buf, len) -> hid_get_indexed_string(ptr, Int32(index), buf, len), dev)

# ---------- Version ----------

"""
    version() -> VersionNumber

Return the HIDAPI runtime version.
"""
function version()
    v = unsafe_load(hid_version())
    return VersionNumber(v.major, v.minor, v.patch)
end
