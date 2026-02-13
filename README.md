# HIDAPI.jl

Julia bindings for [HIDAPI](https://github.com/libusb/hidapi), a cross-platform library for communicating with USB and Bluetooth HID devices.

## Prerequisites

Build HIDAPI from source (requires CMake):

```sh
git clone https://github.com/libusb/hidapi.git
cd hidapi
cmake -B build -S .
cmake --build build
```

The package expects the built `libhidapi.dylib` in `hidapi/build/` relative to the package root.

## Setup

```sh
cd HIDAPI.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Quick Start

```julia
using HIDAPI

init()

# List all connected HID devices
for d in HIDAPI.enumerate()
    println("$(d.manufacturer) $(d.product) [$(string(d.vendor_id, base=16)):$(string(d.product_id, base=16))]")
end

shutdown()
```

## API Reference

### Lifecycle

```julia
init()       # Initialize HIDAPI — call before anything else
shutdown()   # Finalize HIDAPI — call when done
version()    # Returns the HIDAPI runtime VersionNumber
```

### Enumeration

```julia
# List all HID devices
devices = HIDAPI.enumerate()

# Filter by vendor/product ID
devices = HIDAPI.enumerate(0x054C, 0x0CE6)
```

Returns a `Vector{HIDDeviceInfo}` with fields: `path`, `vendor_id`, `product_id`, `serial_number`, `release_number`, `manufacturer`, `product`, `usage_page`, `usage`, `interface_number`, `bus_type`.

### Opening and Closing Devices

```julia
# Open by vendor/product ID
dev = HIDAPI.open(0x054C, 0x0CE6)

# Open by vendor/product ID with serial number
dev = HIDAPI.open(0x054C, 0x0CE6; serial="123456")

# Open by platform-specific path
dev = HIDAPI.open("/dev/hidraw0")

# Close when done (also called automatically by finalizer)
HIDAPI.close(dev)

# Check if still open
isopen(dev)
```

### Reading and Writing

```julia
# Write an output report (first byte = report ID, 0x00 if unused)
bytes_written = HIDAPI.write(dev, UInt8[0x00, 0x01, 0x02])

# Read an input report (blocking)
data = HIDAPI.read(dev, 64)

# Read with timeout (milliseconds)
data = HIDAPI.read(dev, 64; timeout_ms=1000)

# Non-blocking read (returns empty vector if no data)
data = HIDAPI.read(dev, 64; timeout_ms=0)

# Set non-blocking mode for all subsequent reads
set_nonblocking(dev, true)
```

### Feature and Input Reports

```julia
# Send a feature report (first byte = report ID)
send_feature_report(dev, UInt8[0x01, 0x02, 0x03])

# Get a feature report
data = get_feature_report(dev, 0x01, 256)  # report_id, max_length

# Get an input report
data = get_input_report(dev, 0x01, 256)

# Get the raw HID report descriptor
descriptor = get_report_descriptor(dev)
```

### Device Strings

```julia
get_manufacturer(dev)              # "Sony Interactive Entertainment"
get_product(dev)                   # "Wireless Controller"
get_serial(dev)                    # "ab:cd:ef:12:34:56"
get_indexed_string(dev, 2)         # String at index 2
```

### Error Handling

All functions throw `HIDAPIError` on failure:

```julia
try
    dev = HIDAPI.open(0xFFFF, 0xFFFF)
catch e::HIDAPIError
    println(e.msg)  # "Failed to open HID device (NULL pointer)"
end
```

## DualSense (PS5 Controller) Submodule

`HIDAPI.DualSense` provides structured access to the PS5 DualSense controller protocol.

```julia
using HIDAPI
using HIDAPI.DualSense
```

### Find and Open

```julia
init()

# Find connected DualSense controllers
controllers = find_dualsense()
for c in controllers
    println("$(c.product) at $(c.path)")
end

# Open the first one
dev = open_dualsense()
```

### Read Controller State

```julia
data = HIDAPI.read(dev, 64; timeout_ms=100)
state = parse_input_report(data)

# Analog sticks (-128 to 127, centered at 0)
state.left_stick.x
state.left_stick.y
state.right_stick.x
state.right_stick.y

# Triggers (0–255)
state.l2_trigger
state.r2_trigger

# Buttons (all Bool)
state.buttons.cross
state.buttons.circle
state.buttons.square
state.buttons.triangle
state.buttons.l1, state.buttons.r1
state.buttons.l2, state.buttons.r2
state.buttons.l3, state.buttons.r3
state.buttons.share, state.buttons.options
state.buttons.ps, state.buttons.touchpad, state.buttons.mic
state.buttons.dpad_up, state.buttons.dpad_down
state.buttons.dpad_left, state.buttons.dpad_right

# Touchpad (two touch points, 12-bit coordinates)
tp = state.touchpad.point1
tp.active  # true if finger is touching
tp.x       # 0–1919
tp.y       # 0–1079

# IMU (Int16 values)
state.imu.accel_x, state.imu.accel_y, state.imu.accel_z
state.imu.gyro_pitch, state.imu.gyro_yaw, state.imu.gyro_roll

# Battery
state.battery.level  # 0–100
state.battery.state  # Discharging, Charging, BatteryFull, etc.
```

### Control Outputs

```julia
# Set LED color
effects = DualSenseEffects(light=LightConfig(r=0xFF, g=0x00, b=0x80))
HIDAPI.write(dev, build_output_report(effects))

# Rumble motors (0–255 intensity)
effects = DualSenseEffects(right_motor=0x80, left_motor=0xFF)
HIDAPI.write(dev, build_output_report(effects))

# Adaptive triggers
stiff = TriggerEffect(Rigid, (0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00))
effects = DualSenseEffects(right_trigger=stiff)
HIDAPI.write(dev, build_output_report(effects))

# Player LEDs and microphone
effects = DualSenseEffects(
    light=LightConfig(r=0x00, g=0xFF, b=0x00, player_id=PLAYER_2),
    mic_led=true,
    mic_mute=false,
)
HIDAPI.write(dev, build_output_report(effects))

# Bluetooth output (includes CRC32 checksum)
HIDAPI.write(dev, build_output_report(effects; connection=BT))
```

### Trigger Modes

| Mode | Description |
|------|-------------|
| `TriggerOff` | No resistance |
| `Rigid` | Continuous resistance |
| `Pulse` | Pulsing resistance |
| `Rigid_A`, `Rigid_B`, `Rigid_AB` | Rigid variants |
| `Pulse_A`, `Pulse_B`, `Pulse_AB` | Pulse variants |
| `Calibration` | Calibration mode |

### Cleanup

```julia
HIDAPI.close(dev)
shutdown()
```

## Running Tests

```sh
cd HIDAPI.jl
julia --project=. -e 'using Pkg; Pkg.test()'
```

The test suite (240 tests) covers the core HIDAPI wrapper and the DualSense protocol parser. DualSense tests use canned byte arrays and require no hardware.

## Project Structure

```
HIDAPI.jl/
  src/
    HIDAPI.jl                   # Module definition
    generated/libhidapi.jl      # Auto-generated Clang.jl bindings
    error.jl                    # HIDAPIError, wchar_t helpers
    devices.jl                  # High-level API
    dualsense/
      DualSense.jl              # DualSense submodule
      types.jl                  # Enums and structs
      input.jl                  # Input report parser
      output.jl                 # Output report builder
  test/
    runtests.jl
    test_dualsense.jl
  examples/
    dualsense_demo.jl           # Interactive controller demo
  gen/
    generator.jl                # Clang.jl binding generator
    generator.toml              # Generator config
```
