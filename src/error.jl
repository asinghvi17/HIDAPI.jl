"""
    HIDAPIError <: Exception

Exception thrown when an HIDAPI function returns an error.
"""
struct HIDAPIError <: Exception
    msg::String
end

Base.showerror(io::IO, e::HIDAPIError) = print(io, "HIDAPIError: ", e.msg)

"""
    unsafe_wstring(ptr::Ptr{Cwchar_t}) -> String

Convert a `wchar_t*` pointer to a Julia `String`. Reads until NUL terminator.
The pointer is not freed -- HIDAPI owns the memory.
"""
function unsafe_wstring(ptr::Ptr{Cwchar_t})
    ptr == C_NULL && return ""
    len = 0
    while unsafe_load(ptr, len + 1) != Cwchar_t(0)
        len += 1
    end
    return String(Char[Char(unsafe_load(ptr, i)) for i in 1:len])
end

"""
    check_result(ret::Integer, dev_ptr::Ptr{hid_device})

Check an HIDAPI return code. If `ret == -1`, read the error string from the
device and throw an `HIDAPIError`. Many HIDAPI functions return -1 on error.
"""
function check_result(ret::Integer, dev_ptr::Ptr{hid_device})
    ret == -1 || return ret
    err_ptr = hid_error(dev_ptr)
    msg = err_ptr == C_NULL ? "Unknown HIDAPI error" : unsafe_wstring(err_ptr)
    throw(HIDAPIError(msg))
end
