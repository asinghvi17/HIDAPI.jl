# DualSense Input Report Parser
# All functions are pure — no hardware dependency.

"""
    parse_dpad(nibble::UInt8) -> NamedTuple{(:up,:down,:left,:right), NTuple{4,Bool}}

Decode the D-pad nibble (lower 4 bits of button byte) into directional booleans.
"""
function parse_dpad(nibble::UInt8)
    # 0=up, 1=up+right, 2=right, 3=down+right, 4=down, 5=down+left, 6=left, 7=up+left, 8=released
    up    = nibble in (0, 1, 7)
    right = nibble in (1, 2, 3)
    down  = nibble in (3, 4, 5)
    left  = nibble in (5, 6, 7)
    return (; up, down, left, right)
end

"""
    le_int16(lo::UInt8, hi::UInt8) -> Int16

Read a little-endian Int16 from two bytes.
"""
le_int16(lo::UInt8, hi::UInt8) = reinterpret(Int16, UInt16(lo) | UInt16(hi) << 8)

"""
    parse_touch_point(data::AbstractVector{UInt8}, offset::Int) -> DualSenseTouchPoint

Parse a touchpad touch point starting at `offset` (1-indexed).
Byte layout: [active/id] [x_lo] [x_hi_y_lo] [y_hi]
"""
function parse_touch_point(data::AbstractVector{UInt8}, offset::Int)
    id_byte = data[offset]
    id = id_byte & 0x7F
    active = (id_byte & 0x80) == 0  # inverted: bit 7 = 0 means touching
    x = UInt16(data[offset + 1]) | (UInt16(data[offset + 2] & 0x0F) << 8)
    y = (UInt16(data[offset + 2] & 0xF0) >> 4) | (UInt16(data[offset + 3]) << 4)
    return DualSenseTouchPoint(id, active, x, y)
end

"""
    parse_input_report(data::AbstractVector{UInt8}) -> DualSenseState

Parse a 64-byte USB input report into a `DualSenseState`.
The first byte is the report ID (0x01), followed by 63 bytes of data.
"""
function parse_input_report(data::AbstractVector{UInt8})
    length(data) >= 64 || throw(ArgumentError("Input report must be at least 64 bytes, got $(length(data))"))

    # Analog sticks (centered at 128 → Int8 range -128..127)
    left_stick = DualSenseStick(Int8(Int(data[2]) - 128), Int8(Int(data[3]) - 128))
    right_stick = DualSenseStick(Int8(Int(data[4]) - 128), Int8(Int(data[5]) - 128))

    # Triggers
    l2_trigger = data[6]
    r2_trigger = data[7]

    # data[8] = sequence counter (ignored)

    # Buttons — data[9]
    btn9 = data[9]
    dpad = parse_dpad(btn9 & 0x0F)
    triangle = (btn9 & 0x80) != 0
    circle   = (btn9 & 0x40) != 0
    cross    = (btn9 & 0x20) != 0
    square   = (btn9 & 0x10) != 0

    # Shoulder/misc — data[10]
    btn10 = data[10]
    r3      = (btn10 & 0x80) != 0
    l3      = (btn10 & 0x40) != 0
    options = (btn10 & 0x20) != 0
    share   = (btn10 & 0x10) != 0
    r2_btn  = (btn10 & 0x08) != 0
    l2_btn  = (btn10 & 0x04) != 0
    r1      = (btn10 & 0x02) != 0
    l1      = (btn10 & 0x01) != 0

    # Special — data[11]
    btn11 = data[11]
    ps       = (btn11 & 0x01) != 0
    touchbtn = (btn11 & 0x02) != 0
    mic      = (btn11 & 0x04) != 0

    buttons = DualSenseButtons(
        cross, circle, square, triangle,
        l1, r1, l2_btn, r2_btn, l3, r3,
        share, options, ps, touchbtn, mic,
        dpad.up, dpad.down, dpad.left, dpad.right,
    )

    # IMU
    imu = DualSenseIMU(
        le_int16(data[17], data[18]),  # accel_x
        le_int16(data[19], data[20]),  # accel_y
        le_int16(data[21], data[22]),  # accel_z
        le_int16(data[23], data[24]),  # gyro_pitch
        le_int16(data[25], data[26]),  # gyro_yaw
        le_int16(data[27], data[28]),  # gyro_roll
    )

    # Touchpad
    tp = DualSenseTouchpad(
        parse_touch_point(data, 34),
        parse_touch_point(data, 38),
    )

    # Battery — data[54]
    bat_byte = data[54]
    bat_state_raw = (bat_byte & 0xF0) >> 4
    bat_level = min((bat_byte & 0x0F) * 10 + 5, 100)
    battery = DualSenseBattery(UInt8(bat_level), BatteryState(bat_state_raw))

    return DualSenseState(left_stick, right_stick, l2_trigger, r2_trigger,
                          buttons, tp, imu, battery)
end
