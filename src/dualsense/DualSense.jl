module DualSense

using ..HIDAPI

include("types.jl")
include("input.jl")
include("output.jl")

export DualSenseState, DualSenseStick, DualSenseButtons, DualSenseTouchpad, DualSenseTouchPoint
export DualSenseIMU, DualSenseBattery, DualSenseEffects, TriggerEffect, LightConfig
export TriggerMode, LedOption, PulseOption, Brightness, PlayerID, BatteryState, ConnectionType
export DUALSENSE_VENDOR_ID, DUALSENSE_PRODUCT_ID, DUALSENSE_EDGE_PRODUCT_ID
export parse_input_report, build_output_report
# Enum values
export BT, USB
export TriggerOff, Rigid, Pulse, Rigid_A, Rigid_B, Rigid_AB, Pulse_A, Pulse_B, Pulse_AB, Calibration
export LedOff, PlayerLedBrightness, UninterruptableLed, LedBoth
export PulseOff, FadeBlue, FadeOut
export High, Medium, Low
export PLAYER_1, PLAYER_2, PLAYER_3, PLAYER_4, PLAYER_ALL
export Discharging, Charging, BatteryFull, TempOrVoltageOutOfRange, NotCharging, BatteryError

"""
    find_dualsense() -> Vector{HIDDeviceInfo}

Enumerate connected DualSense and DualSense Edge controllers.
"""
function find_dualsense()
    devices = HIDAPI.enumerate(DUALSENSE_VENDOR_ID, UInt16(0))
    return filter(d -> d.product_id in (DUALSENSE_PRODUCT_ID, DUALSENSE_EDGE_PRODUCT_ID), devices)
end

"""
    open_dualsense(; serial=nothing) -> HIDDevice

Open the first DualSense controller found, or a specific one by serial number.
"""
function open_dualsense(; serial=nothing)
    return HIDAPI.open(DUALSENSE_VENDOR_ID, DUALSENSE_PRODUCT_ID; serial)
end

export find_dualsense, open_dualsense

end # module DualSense
