using CEnum: CEnum, @cenum

"""
    hid_api_version

A structure to hold the version numbers.
"""
struct hid_api_version
    major::Cint
    minor::Cint
    patch::Cint
end

const hid_device_ = Cvoid

const hid_device = hid_device_

"""
    hid_bus_type

HID underlying bus types.

` API`
"""
@cenum hid_bus_type::UInt32 begin
    HID_API_BUS_UNKNOWN = 0
    HID_API_BUS_USB = 1
    HID_API_BUS_BLUETOOTH = 2
    HID_API_BUS_I2C = 3
    HID_API_BUS_SPI = 4
end

"""
    hid_device_info

hidapi info structure
"""
struct hid_device_info
    path::Cstring
    vendor_id::Cushort
    product_id::Cushort
    serial_number::Ptr{Cwchar_t}
    release_number::Cushort
    manufacturer_string::Ptr{Cwchar_t}
    product_string::Ptr{Cwchar_t}
    usage_page::Cushort
    usage::Cushort
    interface_number::Cint
    next::Ptr{hid_device_info}
    bus_type::hid_bus_type
end

"""
    hid_init()

Initialize the HIDAPI library.

This function initializes the HIDAPI library. Calling it is not	strictly necessary, as it will be called automatically by	[`hid_enumerate`](@ref)() and any of the hid\\_open\\_*() functions if it is	needed. This function should be called at the beginning of	execution however, if there is a chance of HIDAPI handles	being opened by different threads simultaneously.

` API`

# Returns
This function returns 0 on success and -1 on error.	Call [`hid_error`](@ref)(NULL) to get the failure reason.
"""
function hid_init()
    @ccall hidapi.hid_init()::Cint
end

"""
    hid_exit()

Finalize the HIDAPI library.

This function frees all of the static data associated with	HIDAPI. It should be called at the end of execution to avoid	memory leaks.

` API`

# Returns
This function returns 0 on success and -1 on error.
"""
function hid_exit()
    @ccall hidapi.hid_exit()::Cint
end

"""
    hid_enumerate(vendor_id, product_id)

Enumerate the HID Devices.

This function returns a linked list of all the HID devices	attached to the system which match vendor\\_id and product\\_id.	If `vendor_id` is set to 0 then any vendor matches.	If `product_id` is set to 0 then any product matches.	If `vendor_id` and `product_id` are both set to 0, then	all HID devices will be returned.

` API`

!!! note

    The returned value by this function must to be freed by calling [`hid_free_enumeration`](@ref)(),	when not needed anymore.

# Arguments
* `vendor_id`: The Vendor ID (VID) of the types of device	to open.
* `product_id`: The Product ID (PID) of the types of	device to open.
# Returns
This function returns a pointer to a linked list of type	struct #[`hid_device_info`](@ref), containing information about the HID devices	attached to the system,	or NULL in the case of failure or if no HID devices present in the system.	Call [`hid_error`](@ref)(NULL) to get the failure reason.
"""
function hid_enumerate(vendor_id, product_id)
    @ccall hidapi.hid_enumerate(
        vendor_id::Cushort,
        product_id::Cushort,
    )::Ptr{hid_device_info}
end

"""
    hid_free_enumeration(devs)

Free an enumeration Linked List

This function frees a linked list created by [`hid_enumerate`](@ref)().

` API`

# Arguments
* `devs`: Pointer to a list of struct\\_device returned from	[`hid_enumerate`](@ref)().
"""
function hid_free_enumeration(devs)
    @ccall hidapi.hid_free_enumeration(devs::Ptr{hid_device_info})::Cvoid
end

"""
    hid_open(vendor_id, product_id, serial_number)

Open a HID device using a Vendor ID (VID), Product ID	(PID) and optionally a serial number.

If `serial_number` is NULL, the first device with the	specified VID and PID is opened.

` API`

!!! note

    The returned object must be freed by calling [`hid_close`](@ref)(),	when not needed anymore.

# Arguments
* `vendor_id`: The Vendor ID (VID) of the device to open.
* `product_id`: The Product ID (PID) of the device to open.
* `serial_number`: The Serial Number of the device to open	(Optionally NULL).
# Returns
This function returns a pointer to a #[`hid_device`](@ref) object on	success or NULL on failure.	Call [`hid_error`](@ref)(NULL) to get the failure reason.
"""
function hid_open(vendor_id, product_id, serial_number)
    @ccall hidapi.hid_open(
        vendor_id::Cushort,
        product_id::Cushort,
        serial_number::Ptr{Cwchar_t},
    )::Ptr{hid_device}
end

"""
    hid_open_path(path)

Open a HID device by its path name.

The path name be determined by calling [`hid_enumerate`](@ref)(), or a	platform-specific path name can be used (eg: /dev/hidraw0 on	Linux).

` API`

!!! note

    The returned object must be freed by calling [`hid_close`](@ref)(),	when not needed anymore.

# Arguments
* `path`: The path name of the device to open
# Returns
This function returns a pointer to a #[`hid_device`](@ref) object on	success or NULL on failure.	Call [`hid_error`](@ref)(NULL) to get the failure reason.
"""
function hid_open_path(path)
    @ccall hidapi.hid_open_path(path::Cstring)::Ptr{hid_device}
end

"""
    hid_write(dev, data, length)

Write an Output report to a HID device.

The first byte of `data`[] must contain the Report ID. For	devices which only support a single report, this must be set	to 0x0. The remaining bytes contain the report data. Since	the Report ID is mandatory, calls to [`hid_write`](@ref)() will always	contain one more byte than the report contains. For example,	if a hid report is 16 bytes long, 17 bytes must be passed to	[`hid_write`](@ref)(), the Report ID (or 0x0, for devices with a	single report), followed by the report data (16 bytes). In	this example, the length passed in would be 17.

[`hid_write`](@ref)() will send the data on the first interrupt OUT 	endpoint, if one exists. If it does not the behaviour is as 	hid_send_output_report

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: The data to send, including the report number as	the first byte.
* `length`: The length in bytes of the data to send.
# Returns
This function returns the actual number of bytes written and	-1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_write(dev, data, length)
    @ccall hidapi.hid_write(dev::Ptr{hid_device}, data::Ptr{Cuchar}, length::Csize_t)::Cint
end

"""
    hid_read_timeout(dev, data, length, milliseconds)

Read an Input report from a HID device with timeout.

Input reports are returned	to the host through the INTERRUPT IN endpoint. The first byte will	contain the Report number if the device uses numbered reports.

` API`

!!! note

    This function doesn't change the buffer returned by the [`hid_error`](@ref)(dev).

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: A buffer to put the read data into.
* `length`: The number of bytes to read. For devices with	multiple reports, make sure to read an extra byte for	the report number.
* `milliseconds`: timeout in milliseconds or -1 for blocking wait.
# Returns
This function returns the actual number of bytes read and	-1 on error.	Call [`hid_read_error`](@ref)(dev) to get the failure reason.	If no packet was available to be read within	the timeout period, this function returns 0.
"""
function hid_read_timeout(dev, data, length, milliseconds)
    @ccall hidapi.hid_read_timeout(
        dev::Ptr{hid_device},
        data::Ptr{Cuchar},
        length::Csize_t,
        milliseconds::Cint,
    )::Cint
end

"""
    hid_read(dev, data, length)

Read an Input report from a HID device.

Input reports are returned	to the host through the INTERRUPT IN endpoint. The first byte will	contain the Report number if the device uses numbered reports.

` API`

!!! note

    This function doesn't change the buffer returned by the [`hid_error`](@ref)(dev).

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: A buffer to put the read data into.
* `length`: The number of bytes to read. For devices with	multiple reports, make sure to read an extra byte for	the report number.
# Returns
This function returns the actual number of bytes read and	-1 on error.	Call [`hid_read_error`](@ref)(dev) to get the failure reason.	If no packet was available to be read and	the handle is in non-blocking mode, this function returns 0.
"""
function hid_read(dev, data, length)
    @ccall hidapi.hid_read(dev::Ptr{hid_device}, data::Ptr{Cuchar}, length::Csize_t)::Cint
end

"""
    hid_read_error(dev)

Get a string describing the last error which occurred during [`hid_read`](@ref)/[`hid_read_timeout`](@ref).

Since version 0.15.0, HID_API_VERSION >= [`HID_API_MAKE_VERSION`](@ref)(0, 15, 0)

This function is intended for logging/debugging purposes.

This function guarantees to never return NULL for a valid dev.	If there was no error in the last call to [`hid_read`](@ref)/[`hid_read_error`](@ref) -	the returned string clearly indicates that.

Strings returned from [`hid_read_error`](@ref)() must not be freed by the user,	i.e. owned by HIDAPI library.	Device-specific error string may remain allocated at most until [`hid_close`](@ref)() is called.

` API`

# Arguments
* `dev`: A device handle. Shall never be NULL.
# Returns
A string describing the [`hid_read`](@ref)/[`hid_read_timeout`](@ref) error (if any).
"""
function hid_read_error(dev)
    @ccall hidapi.hid_read_error(dev::Ptr{hid_device})::Ptr{Cwchar_t}
end

"""
    hid_set_nonblocking(dev, nonblock)

Set the device handle to be non-blocking.

In non-blocking mode calls to [`hid_read`](@ref)() will return	immediately with a value of 0 if there is no data to be	read. In blocking mode, [`hid_read`](@ref)() will wait (block) until	there is data to read before returning.

Nonblocking can be turned on and off at any time.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `nonblock`: enable or not the nonblocking reads	- 1 to enable nonblocking	- 0 to disable nonblocking.
# Returns
This function returns 0 on success and -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_set_nonblocking(dev, nonblock)
    @ccall hidapi.hid_set_nonblocking(dev::Ptr{hid_device}, nonblock::Cint)::Cint
end

"""
    hid_send_feature_report(dev, data, length)

Send a Feature report to the device.

Feature reports are sent over the Control endpoint as a	Set\\_Report transfer. The first byte of `data`[] must	contain the Report ID. For devices which only support a	single report, this must be set to 0x0. The remaining bytes	contain the report data. Since the Report ID is mandatory,	calls to [`hid_send_feature_report`](@ref)() will always contain one	more byte than the report contains. For example, if a hid	report is 16 bytes long, 17 bytes must be passed to	[`hid_send_feature_report`](@ref)(): the Report ID (or 0x0, for	devices which do not use numbered reports), followed by the	report data (16 bytes). In this example, the length passed	in would be 17.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: The data to send, including the report number as	the first byte.
* `length`: The length in bytes of the data to send, including	the report number.
# Returns
This function returns the actual number of bytes written and	-1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_send_feature_report(dev, data, length)
    @ccall hidapi.hid_send_feature_report(
        dev::Ptr{hid_device},
        data::Ptr{Cuchar},
        length::Csize_t,
    )::Cint
end

"""
    hid_get_feature_report(dev, data, length)

Get a feature report from a HID device.

Set the first byte of `data`[] to the Report ID of the	report to be read. Make sure to allow space for this	extra byte in `data`[]. Upon return, the first byte will	still contain the Report ID, and the report data will	start in data[1].

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: A buffer to put the read data into, including	the Report ID. Set the first byte of `data`[] to the	Report ID of the report to be read, or set it to zero	if your device does not use numbered reports.
* `length`: The number of bytes to read, including an	extra byte for the report ID. The buffer can be longer	than the actual report.
# Returns
This function returns the number of bytes read plus	one for the report ID (which is still in the first	byte), or -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_get_feature_report(dev, data, length)
    @ccall hidapi.hid_get_feature_report(
        dev::Ptr{hid_device},
        data::Ptr{Cuchar},
        length::Csize_t,
    )::Cint
end

"""
    hid_send_output_report(dev, data, length)

Send a Output report to the device.

Since version 0.15.0, HID_API_VERSION >= [`HID_API_MAKE_VERSION`](@ref)(0, 15, 0)

Output reports are sent over the Control endpoint as a	Set\\_Report transfer. The first byte of `data`[] must	contain the Report ID. For devices which only support a	single report, this must be set to 0x0. The remaining bytes	contain the report data. Since the Report ID is mandatory,	calls to [`hid_send_output_report`](@ref)() will always contain one	more byte than the report contains. For example, if a hid	report is 16 bytes long, 17 bytes must be passed to	[`hid_send_output_report`](@ref)(): the Report ID (or 0x0, for	devices which do not use numbered reports), followed by the	report data (16 bytes). In this example, the length passed	in would be 17.

This function sets the return value of [`hid_error`](@ref)().

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: The data to send, including the report number as	the first byte.
* `length`: The length in bytes of the data to send, including	the report number.
# Returns
This function returns the actual number of bytes written and	-1 on error.
# See also
hid_write
"""
function hid_send_output_report(dev, data, length)
    @ccall hidapi.hid_send_output_report(
        dev::Ptr{hid_device},
        data::Ptr{Cuchar},
        length::Csize_t,
    )::Cint
end

"""
    hid_get_input_report(dev, data, length)

Get a input report from a HID device.

Since version 0.10.0, HID_API_VERSION >= [`HID_API_MAKE_VERSION`](@ref)(0, 10, 0)

Set the first byte of `data`[] to the Report ID of the	report to be read. Make sure to allow space for this	extra byte in `data`[]. Upon return, the first byte will	still contain the Report ID, and the report data will	start in data[1].

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `data`: A buffer to put the read data into, including	the Report ID. Set the first byte of `data`[] to the	Report ID of the report to be read, or set it to zero	if your device does not use numbered reports.
* `length`: The number of bytes to read, including an	extra byte for the report ID. The buffer can be longer	than the actual report.
# Returns
This function returns the number of bytes read plus	one for the report ID (which is still in the first	byte), or -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_get_input_report(dev, data, length)
    @ccall hidapi.hid_get_input_report(
        dev::Ptr{hid_device},
        data::Ptr{Cuchar},
        length::Csize_t,
    )::Cint
end

"""
    hid_close(dev)

Close a HID device.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
"""
function hid_close(dev)
    @ccall hidapi.hid_close(dev::Ptr{hid_device})::Cvoid
end

"""
    hid_get_manufacturer_string(dev, string, maxlen)

Get The Manufacturer String from a HID device.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `string`: A wide string buffer to put the data into.
* `maxlen`: The length of the buffer in multiples of wchar\\_t.
# Returns
This function returns 0 on success and -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_get_manufacturer_string(dev, string, maxlen)
    @ccall hidapi.hid_get_manufacturer_string(
        dev::Ptr{hid_device},
        string::Ptr{Cwchar_t},
        maxlen::Csize_t,
    )::Cint
end

"""
    hid_get_product_string(dev, string, maxlen)

Get The Product String from a HID device.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `string`: A wide string buffer to put the data into.
* `maxlen`: The length of the buffer in multiples of wchar\\_t.
# Returns
This function returns 0 on success and -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_get_product_string(dev, string, maxlen)
    @ccall hidapi.hid_get_product_string(
        dev::Ptr{hid_device},
        string::Ptr{Cwchar_t},
        maxlen::Csize_t,
    )::Cint
end

"""
    hid_get_serial_number_string(dev, string, maxlen)

Get The Serial Number String from a HID device.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `string`: A wide string buffer to put the data into.
* `maxlen`: The length of the buffer in multiples of wchar\\_t.
# Returns
This function returns 0 on success and -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_get_serial_number_string(dev, string, maxlen)
    @ccall hidapi.hid_get_serial_number_string(
        dev::Ptr{hid_device},
        string::Ptr{Cwchar_t},
        maxlen::Csize_t,
    )::Cint
end

"""
    hid_get_device_info(dev)

Get The struct #[`hid_device_info`](@ref) from a HID device.

Since version 0.13.0, HID_API_VERSION >= [`HID_API_MAKE_VERSION`](@ref)(0, 13, 0)

` API`

!!! note

    The returned object is owned by the `dev`, and SHOULD NOT be freed by the user.

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
# Returns
This function returns a pointer to the struct #[`hid_device_info`](@ref)	for this [`hid_device`](@ref), or NULL in the case of failure.	Call [`hid_error`](@ref)(dev) to get the failure reason.	This struct is valid until the device is closed with [`hid_close`](@ref)().
"""
function hid_get_device_info(dev)
    @ccall hidapi.hid_get_device_info(dev::Ptr{hid_device})::Ptr{hid_device_info}
end

"""
    hid_get_indexed_string(dev, string_index, string, maxlen)

Get a string from a HID device, based on its string index.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `string_index`: The index of the string to get.
* `string`: A wide string buffer to put the data into.
* `maxlen`: The length of the buffer in multiples of wchar\\_t.
# Returns
This function returns 0 on success and -1 on error.	Call [`hid_error`](@ref)(dev) to get the failure reason.
"""
function hid_get_indexed_string(dev, string_index, string, maxlen)
    @ccall hidapi.hid_get_indexed_string(
        dev::Ptr{hid_device},
        string_index::Cint,
        string::Ptr{Cwchar_t},
        maxlen::Csize_t,
    )::Cint
end

"""
    hid_get_report_descriptor(dev, buf, buf_size)

Get a report descriptor from a HID device.

Since version 0.14.0, HID_API_VERSION >= [`HID_API_MAKE_VERSION`](@ref)(0, 14, 0)

User has to provide a preallocated buffer where descriptor will be copied to.	The recommended size for preallocated buffer is HID_API_MAX_REPORT_DESCRIPTOR_SIZE bytes.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)().
* `buf`: The buffer to copy descriptor into.
* `buf_size`: The size of the buffer in bytes.
# Returns
This function returns non-negative number of bytes actually copied, or -1 on error.
"""
function hid_get_report_descriptor(dev, buf, buf_size)
    @ccall hidapi.hid_get_report_descriptor(
        dev::Ptr{hid_device},
        buf::Ptr{Cuchar},
        buf_size::Csize_t,
    )::Cint
end

"""
    hid_error(dev)

Get a string describing the last error which occurred.

This function is intended for logging/debugging purposes.

This function guarantees to never return NULL.	If there was no error in the last function call -	the returned string clearly indicates that.

Any HIDAPI function that can explicitly indicate an execution failure	(e.g. by an error code, or by returning NULL) - may set the error string,	to be returned by this function.

Strings returned from [`hid_error`](@ref)() must not be freed by the user,	i.e. owned by HIDAPI library.	Device-specific error string may remain allocated at most until [`hid_close`](@ref)() is called.	Global error string may remain allocated at most until [`hid_exit`](@ref)() is called.

` API`

# Arguments
* `dev`: A device handle returned from [`hid_open`](@ref)(),	or NULL to get the last non-device-specific error	(e.g. for errors in [`hid_open`](@ref)() or [`hid_enumerate`](@ref)()).
# Returns
A string describing the last error (if any).
"""
function hid_error(dev)
    @ccall hidapi.hid_error(dev::Ptr{hid_device})::Ptr{Cwchar_t}
end

"""
    hid_version()

Get a runtime version of the library.

This function is thread-safe.

` API`

# Returns
Pointer to statically allocated struct, that contains version.
"""
function hid_version()
    @ccall hidapi.hid_version()::Ptr{hid_api_version}
end

"""
    hid_version_str()

Get a runtime version string of the library.

This function is thread-safe.

` API`

# Returns
Pointer to statically allocated string, that contains version string.
"""
function hid_version_str()
    unsafe_string(@ccall(hidapi.hid_version_str()::Cstring))
end

# const HID_API_EXPORT_CALL = HID_API_EXPORT(HID_API_CALL)

# const HID_API_VERSION_MAJOR = 0

# const HID_API_VERSION_MINOR = 15

# const HID_API_VERSION_PATCH = 0

# const HID_API_VERSION = HID_API_MAKE_VERSION(
#     HID_API_VERSION_MAJOR,
#     HID_API_VERSION_MINOR,
#     HID_API_VERSION_PATCH,
# )

# const HID_API_VERSION_STR = HID_API_TO_VERSION_STR(
#     HID_API_VERSION_MAJOR,
#     HID_API_VERSION_MINOR,
#     HID_API_VERSION_PATCH,
# )

const HID_API_MAX_REPORT_DESCRIPTOR_SIZE = 4096
