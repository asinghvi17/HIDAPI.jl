# DualSense (PS5 Controller) HID Protocol Types

# ── Constants ──

const DUALSENSE_VENDOR_ID = 0x054C
const DUALSENSE_PRODUCT_ID = 0x0CE6
const DUALSENSE_EDGE_PRODUCT_ID = 0x0DF2

# ── Enums ──

@enum ConnectionType::UInt8 BT=0 USB=1

@enum TriggerMode::UInt8 begin
    TriggerOff = 0x00
    Rigid = 0x01
    Pulse = 0x02
    Rigid_A = 0x21
    Rigid_B = 0x05
    Rigid_AB = 0x25
    Pulse_A = 0x22
    Pulse_B = 0x06
    Pulse_AB = 0x26
    Calibration = 0xFC
end

@enum LedOption::UInt8 LedOff=0x00 PlayerLedBrightness=0x01 UninterruptableLed=0x02 LedBoth=0x03

@enum PulseOption::UInt8 PulseOff=0x00 FadeBlue=0x01 FadeOut=0x02

@enum Brightness::UInt8 High=0x00 Medium=0x01 Low=0x02

@enum PlayerID::UInt8 PLAYER_1=4 PLAYER_2=10 PLAYER_3=21 PLAYER_4=27 PLAYER_ALL=31

@enum BatteryState::UInt8 begin
    Discharging = 0x00
    Charging = 0x01
    BatteryFull = 0x02
    TempOrVoltageOutOfRange = 0x0A
    NotCharging = 0x0B
    BatteryError = 0x0F
end

# ── Input State Structs ──

struct DualSenseStick
    x::Int8
    y::Int8
end

struct DualSenseButtons
    cross::Bool
    circle::Bool
    square::Bool
    triangle::Bool
    l1::Bool
    r1::Bool
    l2::Bool
    r2::Bool
    l3::Bool
    r3::Bool
    share::Bool
    options::Bool
    ps::Bool
    touchpad::Bool
    mic::Bool
    dpad_up::Bool
    dpad_down::Bool
    dpad_left::Bool
    dpad_right::Bool
end

struct DualSenseTouchPoint
    id::UInt8
    active::Bool
    x::UInt16
    y::UInt16
end

struct DualSenseTouchpad
    point1::DualSenseTouchPoint
    point2::DualSenseTouchPoint
end

struct DualSenseIMU
    accel_x::Int16
    accel_y::Int16
    accel_z::Int16
    gyro_pitch::Int16
    gyro_yaw::Int16
    gyro_roll::Int16
end

struct DualSenseBattery
    level::UInt8
    state::BatteryState
end

struct DualSenseState
    left_stick::DualSenseStick
    right_stick::DualSenseStick
    l2_trigger::UInt8
    r2_trigger::UInt8
    buttons::DualSenseButtons
    touchpad::DualSenseTouchpad
    imu::DualSenseIMU
    battery::DualSenseBattery
end

# ── Output Effect Structs ──

struct TriggerEffect
    mode::TriggerMode
    forces::NTuple{7,UInt8}
end
TriggerEffect() = TriggerEffect(TriggerOff, ntuple(_ -> UInt8(0), 7))

struct LightConfig
    r::UInt8
    g::UInt8
    b::UInt8
    player_id::PlayerID
    brightness::Brightness
    led_option::LedOption
    pulse_option::PulseOption
end
LightConfig(; r=0x00, g=0x00, b=0x00, player_id=PLAYER_1, brightness=High,
              led_option=PlayerLedBrightness, pulse_option=PulseOff) =
    LightConfig(r, g, b, player_id, brightness, led_option, pulse_option)

struct DualSenseEffects
    right_motor::UInt8
    left_motor::UInt8
    right_trigger::TriggerEffect
    left_trigger::TriggerEffect
    light::LightConfig
    mic_led::Bool
    mic_mute::Bool
end
DualSenseEffects(; right_motor=0x00, left_motor=0x00, right_trigger=TriggerEffect(),
                   left_trigger=TriggerEffect(), light=LightConfig(),
                   mic_led=false, mic_mute=false) =
    DualSenseEffects(right_motor, left_motor, right_trigger, left_trigger, light, mic_led, mic_mute)
