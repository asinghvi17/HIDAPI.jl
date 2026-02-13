# DualSense Output Report Builder
# All functions are pure — no hardware dependency.

"""
    crc32_dualsense(data::AbstractVector{UInt8}) -> UInt32

Compute CRC32 checksum for Bluetooth output reports.
Uses standard CRC32 polynomial (0xEDB88320) with seed 0xEADA2D49.
"""
function crc32_dualsense(data::AbstractVector{UInt8})
    crc = 0xEADA2D49 % UInt32
    for byte in data
        crc = xor(crc, UInt32(byte))
        for _ in 1:8
            if (crc & 1) != 0
                crc = xor(crc >> 1, 0xEDB88320 % UInt32)
            else
                crc >>= 1
            end
        end
    end
    return crc
end

"""
    build_output_report(effects::DualSenseEffects; connection::ConnectionType=USB) -> Vector{UInt8}

Build a DualSense output report from the given effects configuration.
Returns a 64-byte vector for USB or 78-byte vector for Bluetooth.
"""
function build_output_report(effects::DualSenseEffects; connection::ConnectionType=USB)
    if connection == USB
        return _build_usb_report(effects)
    else
        return _build_bt_report(effects)
    end
end

function _build_usb_report(effects::DualSenseEffects)
    report = zeros(UInt8, 64)

    report[1] = 0x02  # Report ID
    report[2] = 0xFF  # Feature flags 1 (enable all)
    report[3] = 0x57  # Feature flags 2

    # Rumble motors
    report[4] = effects.right_motor
    report[5] = effects.left_motor

    # Microphone
    report[10] = effects.mic_led ? 0x01 : 0x00
    report[11] = effects.mic_mute ? 0x10 : 0x00

    # Right trigger
    _write_trigger!(report, 12, effects.right_trigger)

    # Left trigger
    _write_trigger!(report, 23, effects.left_trigger)

    # LEDs
    _write_leds!(report, effects.light)

    return report
end

function _build_bt_report(effects::DualSenseEffects)
    report = zeros(UInt8, 78)

    report[1] = 0x31  # Report ID
    report[2] = 0x02  # BT sequence tag
    report[3] = 0xFF  # Feature flags 1
    report[4] = 0x57  # Feature flags 2

    # Rumble motors (+1 offset from USB)
    report[5] = effects.right_motor
    report[6] = effects.left_motor

    # Microphone
    report[11] = effects.mic_led ? 0x01 : 0x00
    report[12] = effects.mic_mute ? 0x10 : 0x00

    # Right trigger
    _write_trigger!(report, 13, effects.right_trigger)

    # Left trigger
    _write_trigger!(report, 24, effects.left_trigger)

    # LEDs (BT offsets)
    _write_leds_bt!(report, effects.light)

    # CRC32 checksum over first 74 bytes
    crc = crc32_dualsense(@view report[1:74])
    report[75] = UInt8(crc & 0xFF)
    report[76] = UInt8((crc >> 8) & 0xFF)
    report[77] = UInt8((crc >> 16) & 0xFF)
    report[78] = UInt8((crc >> 24) & 0xFF)

    return report
end

function _write_trigger!(report::Vector{UInt8}, offset::Int, trigger::TriggerEffect)
    report[offset] = UInt8(trigger.mode)
    for i in 1:6
        report[offset + i] = trigger.forces[i]
    end
    report[offset + 9] = trigger.forces[7]  # Gap at offset+7 and offset+8
end

function _write_leds!(report::Vector{UInt8}, light::LightConfig)
    report[40] = UInt8(light.led_option)
    report[43] = UInt8(light.pulse_option)
    report[44] = UInt8(light.brightness)
    report[45] = UInt8(light.player_id)
    report[46] = light.r
    report[47] = light.g
    report[48] = light.b
end

function _write_leds_bt!(report::Vector{UInt8}, light::LightConfig)
    report[41] = UInt8(light.led_option)
    report[44] = UInt8(light.pulse_option)
    report[45] = UInt8(light.brightness)
    report[46] = UInt8(light.player_id)
    report[47] = light.r
    report[48] = light.g
    report[49] = light.b
end
