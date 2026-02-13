using HIDAPI.DualSense

"""Helper: create a neutral 64-byte input report (sticks centered, dpad released, no buttons)."""
function make_neutral_report()
    data = zeros(UInt8, 64)
    data[1] = 0x01  # Report ID
    data[2] = 0x80  # Left stick X (centered)
    data[3] = 0x80  # Left stick Y (centered)
    data[4] = 0x80  # Right stick X (centered)
    data[5] = 0x80  # Right stick Y (centered)
    data[9] = 0x08  # D-pad released (lower nibble = 8)
    return data
end

@testset "DualSense" begin

    @testset "Constants" begin
        @test DUALSENSE_VENDOR_ID == 0x054C
        @test DUALSENSE_PRODUCT_ID == 0x0CE6
        @test DUALSENSE_EDGE_PRODUCT_ID == 0x0DF2
    end

    @testset "Default constructors" begin
        te = TriggerEffect()
        @test te.mode == TriggerOff
        @test all(f == 0 for f in te.forces)

        lc = LightConfig()
        @test lc.r == 0x00
        @test lc.g == 0x00
        @test lc.b == 0x00
        @test lc.player_id == PLAYER_1

        eff = DualSenseEffects()
        @test eff.right_motor == 0x00
        @test eff.left_motor == 0x00
        @test eff.mic_led == false
        @test eff.mic_mute == false
    end

    @testset "Keyword constructors" begin
        lc = LightConfig(r=0xFF, g=0x80, b=0x40)
        @test lc.r == 0xFF
        @test lc.g == 0x80
        @test lc.b == 0x40

        eff = DualSenseEffects(right_motor=0xAA, left_motor=0xBB, mic_led=true)
        @test eff.right_motor == 0xAA
        @test eff.left_motor == 0xBB
        @test eff.mic_led == true
    end

    @testset "parse_dpad" begin
        pd = HIDAPI.DualSense.parse_dpad
        # 0 = up
        @test pd(0x00) == (; up=true,  down=false, left=false, right=false)
        # 1 = up+right
        @test pd(0x01) == (; up=true,  down=false, left=false, right=true)
        # 2 = right
        @test pd(0x02) == (; up=false, down=false, left=false, right=true)
        # 3 = down+right
        @test pd(0x03) == (; up=false, down=true,  left=false, right=true)
        # 4 = down
        @test pd(0x04) == (; up=false, down=true,  left=false, right=false)
        # 5 = down+left
        @test pd(0x05) == (; up=false, down=true,  left=true,  right=false)
        # 6 = left
        @test pd(0x06) == (; up=false, down=false, left=true,  right=false)
        # 7 = up+left
        @test pd(0x07) == (; up=true,  down=false, left=true,  right=false)
        # 8 = released
        @test pd(0x08) == (; up=false, down=false, left=false, right=false)
    end

    @testset "Neutral state parsing" begin
        data = make_neutral_report()
        state = parse_input_report(data)

        @test state.left_stick.x == 0
        @test state.left_stick.y == 0
        @test state.right_stick.x == 0
        @test state.right_stick.y == 0
        @test state.l2_trigger == 0
        @test state.r2_trigger == 0

        b = state.buttons
        @test !b.cross && !b.circle && !b.square && !b.triangle
        @test !b.l1 && !b.r1 && !b.l2 && !b.r2
        @test !b.l3 && !b.r3
        @test !b.share && !b.options && !b.ps && !b.touchpad && !b.mic
        @test !b.dpad_up && !b.dpad_down && !b.dpad_left && !b.dpad_right
    end

    @testset "Stick parsing" begin
        data = make_neutral_report()

        # Far left: 0 → -128
        data[2] = 0x00
        state = parse_input_report(data)
        @test state.left_stick.x == -128

        # Far right: 255 → 127
        data[2] = 0xFF
        state = parse_input_report(data)
        @test state.left_stick.x == 127

        # Centered: 128 → 0
        data[2] = 0x80
        data[3] = 0x00  # top
        state = parse_input_report(data)
        @test state.left_stick.y == -128

        data[3] = 0xFF  # bottom
        state = parse_input_report(data)
        @test state.left_stick.y == 127

        # Right stick
        data[3] = 0x80
        data[4] = 0x00
        state = parse_input_report(data)
        @test state.right_stick.x == -128

        data[4] = 0x80
        data[5] = 0x40
        state = parse_input_report(data)
        @test state.right_stick.y == Int8(0x40 - 128)
    end

    @testset "Trigger parsing" begin
        data = make_neutral_report()

        data[6] = 0x00  # L2 released
        data[7] = 0xFF  # R2 fully pressed
        state = parse_input_report(data)
        @test state.l2_trigger == 0
        @test state.r2_trigger == 255

        data[6] = 0x80
        state = parse_input_report(data)
        @test state.l2_trigger == 0x80
    end

    @testset "Face button parsing" begin
        data = make_neutral_report()

        # Cross (bit 5 of data[9])
        data[9] = 0x28  # 0x20 | 0x08 (cross + dpad=8)
        state = parse_input_report(data)
        @test state.buttons.cross
        @test !state.buttons.circle
        @test !state.buttons.square
        @test !state.buttons.triangle

        # Circle (bit 6)
        data[9] = 0x48
        state = parse_input_report(data)
        @test state.buttons.circle
        @test !state.buttons.cross

        # Square (bit 4)
        data[9] = 0x18
        state = parse_input_report(data)
        @test state.buttons.square

        # Triangle (bit 7)
        data[9] = 0x88
        state = parse_input_report(data)
        @test state.buttons.triangle

        # All face buttons
        data[9] = 0xF8
        state = parse_input_report(data)
        @test state.buttons.cross && state.buttons.circle && state.buttons.square && state.buttons.triangle
    end

    @testset "Shoulder/misc button parsing" begin
        data = make_neutral_report()

        # L1 (bit 0 of data[10])
        data[10] = 0x01
        state = parse_input_report(data)
        @test state.buttons.l1
        @test !state.buttons.r1

        # R1 (bit 1)
        data[10] = 0x02
        state = parse_input_report(data)
        @test state.buttons.r1

        # L2 digital (bit 2)
        data[10] = 0x04
        state = parse_input_report(data)
        @test state.buttons.l2

        # R2 digital (bit 3)
        data[10] = 0x08
        state = parse_input_report(data)
        @test state.buttons.r2

        # Share (bit 4)
        data[10] = 0x10
        state = parse_input_report(data)
        @test state.buttons.share

        # Options (bit 5)
        data[10] = 0x20
        state = parse_input_report(data)
        @test state.buttons.options

        # L3 (bit 6)
        data[10] = 0x40
        state = parse_input_report(data)
        @test state.buttons.l3

        # R3 (bit 7)
        data[10] = 0x80
        state = parse_input_report(data)
        @test state.buttons.r3
    end

    @testset "Special button parsing" begin
        data = make_neutral_report()

        # PS (bit 0 of data[11])
        data[11] = 0x01
        state = parse_input_report(data)
        @test state.buttons.ps

        # Touchpad (bit 1)
        data[11] = 0x02
        state = parse_input_report(data)
        @test state.buttons.touchpad

        # Mic (bit 2)
        data[11] = 0x04
        state = parse_input_report(data)
        @test state.buttons.mic
    end

    @testset "D-pad via full parse" begin
        data = make_neutral_report()

        # Up (dpad nibble = 0)
        data[9] = 0x00
        state = parse_input_report(data)
        @test state.buttons.dpad_up
        @test !state.buttons.dpad_down

        # Down (dpad nibble = 4)
        data[9] = 0x04
        state = parse_input_report(data)
        @test state.buttons.dpad_down
        @test !state.buttons.dpad_up

        # Right (dpad nibble = 2)
        data[9] = 0x02
        state = parse_input_report(data)
        @test state.buttons.dpad_right
        @test !state.buttons.dpad_left
    end

    @testset "IMU parsing" begin
        data = make_neutral_report()

        # Accelerometer X = 1000 (0x03E8 LE → bytes 0xE8, 0x03)
        data[17] = 0xE8
        data[18] = 0x03
        # Accelerometer Y = -500 (0xFE0C LE → bytes 0x0C, 0xFE)
        data[19] = 0x0C
        data[20] = 0xFE
        # Accelerometer Z = 0
        data[21] = 0x00
        data[22] = 0x00
        # Gyro pitch = 100
        data[23] = 0x64
        data[24] = 0x00
        # Gyro yaw = -1 (0xFFFF LE)
        data[25] = 0xFF
        data[26] = 0xFF
        # Gyro roll = 32767 (max Int16)
        data[27] = 0xFF
        data[28] = 0x7F

        state = parse_input_report(data)
        @test state.imu.accel_x == 1000
        @test state.imu.accel_y == -500
        @test state.imu.accel_z == 0
        @test state.imu.gyro_pitch == 100
        @test state.imu.gyro_yaw == -1
        @test state.imu.gyro_roll == 32767
    end

    @testset "Touchpad parsing" begin
        data = make_neutral_report()

        # Touch 0: active (bit 7 = 0), id = 5, x = 960, y = 540
        # id byte: 0x05 (bit 7 clear → active)
        data[34] = 0x05
        # x = 960 = 0x3C0 → x_lo = 0xC0, x_hi (lower nibble of byte 2) = 0x03
        # y = 540 = 0x21C → y_lo (upper nibble of byte 2) = 0x01 << 4 = 0x10 ... wait
        # Encoding: x = data[35] | ((data[36] & 0x0F) << 8)
        #           y = ((data[36] & 0xF0) >> 4) | (data[37] << 4)
        # x = 960 = 0x3C0: data[35] = 0xC0, (data[36] & 0x0F) = 0x03
        # y = 540 = 0x21C: ((data[36] & 0xF0) >> 4) = 0xC, data[37] << 4 = 0x21 << 4 = 0x210
        #   so y = 0x210 | 0xC = 0x21C = 540 ✓
        #   data[36] & 0xF0 = 0xC0, data[37] = 0x21
        #   data[36] = 0x03 | 0xC0 = 0xC3
        data[35] = 0xC0
        data[36] = 0xC3
        data[37] = 0x21

        # Touch 1: inactive (bit 7 = 1), id = 0
        data[38] = 0x80

        state = parse_input_report(data)
        tp = state.touchpad

        @test tp.point1.active == true
        @test tp.point1.id == 5
        @test tp.point1.x == 960
        @test tp.point1.y == 540

        @test tp.point2.active == false
        @test tp.point2.id == 0
    end

    @testset "Battery parsing" begin
        data = make_neutral_report()

        # Charging (state=1), level nibble=5 → level = min(5*10+5, 100) = 55
        data[54] = 0x15
        state = parse_input_report(data)
        @test state.battery.state == Charging
        @test state.battery.level == 55

        # Discharging (state=0), level nibble=10 → level = min(10*10+5, 100) = 100
        data[54] = 0x0A
        state = parse_input_report(data)
        @test state.battery.state == Discharging
        @test state.battery.level == 100

        # Full (state=2), level nibble=0 → level = 5
        data[54] = 0x20
        state = parse_input_report(data)
        @test state.battery.state == BatteryFull
        @test state.battery.level == 5
    end

    @testset "Short input report" begin
        @test_throws ArgumentError parse_input_report(zeros(UInt8, 10))
        @test_throws ArgumentError parse_input_report(zeros(UInt8, 63))
    end

    @testset "USB output report basics" begin
        eff = DualSenseEffects()
        report = build_output_report(eff)

        @test length(report) == 64
        @test report[1] == 0x02  # Report ID
        @test report[2] == 0xFF  # Feature flags 1
        @test report[3] == 0x57  # Feature flags 2
    end

    @testset "USB output report motors" begin
        eff = DualSenseEffects(right_motor=0xAA, left_motor=0xBB)
        report = build_output_report(eff)

        @test report[4] == 0xAA
        @test report[5] == 0xBB
    end

    @testset "USB output report LEDs" begin
        eff = DualSenseEffects(light=LightConfig(r=0xFF, g=0x80, b=0x40))
        report = build_output_report(eff)

        @test report[46] == 0xFF  # Red
        @test report[47] == 0x80  # Green
        @test report[48] == 0x40  # Blue
    end

    @testset "USB output report microphone" begin
        eff = DualSenseEffects(mic_led=true, mic_mute=true)
        report = build_output_report(eff)

        @test report[10] == 0x01  # mic LED on
        @test report[11] == 0x10  # mic mute
    end

    @testset "USB output trigger effects" begin
        te = TriggerEffect(Rigid, (0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70))
        eff = DualSenseEffects(right_trigger=te)
        report = build_output_report(eff)

        # Right trigger at offset 12
        @test report[12] == UInt8(Rigid)  # mode
        @test report[13] == 0x10  # force 1
        @test report[14] == 0x20  # force 2
        @test report[15] == 0x30  # force 3
        @test report[16] == 0x40  # force 4
        @test report[17] == 0x50  # force 5
        @test report[18] == 0x60  # force 6
        @test report[21] == 0x70  # force 7 (gap at 19-20)
    end

    @testset "USB output left trigger effects" begin
        te = TriggerEffect(Pulse, (0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07))
        eff = DualSenseEffects(left_trigger=te)
        report = build_output_report(eff)

        # Left trigger at offset 23
        @test report[23] == UInt8(Pulse)
        @test report[24] == 0x01
        @test report[29] == 0x06
        @test report[32] == 0x07  # force 7 (gap at 30-31)
    end

    @testset "BT output report" begin
        eff = DualSenseEffects(right_motor=0x55, light=LightConfig(r=0xFF))
        report = build_output_report(eff; connection=BT)

        @test length(report) == 78
        @test report[1] == 0x31  # BT Report ID
        @test report[2] == 0x02  # BT sequence tag
        @test report[3] == 0xFF  # Feature flags 1
        @test report[4] == 0x57  # Feature flags 2
        @test report[5] == 0x55  # Right motor (+1 from USB)

        # CRC32 is present (last 4 bytes)
        crc_bytes = report[75:78]
        @test any(b != 0 for b in crc_bytes)  # non-trivial checksum
    end

    @testset "BT output CRC32 consistency" begin
        eff = DualSenseEffects()
        report = build_output_report(eff; connection=BT)

        # Verify CRC matches by recomputing
        crc = HIDAPI.DualSense.crc32_dualsense(@view report[1:74])
        @test report[75] == UInt8(crc & 0xFF)
        @test report[76] == UInt8((crc >> 8) & 0xFF)
        @test report[77] == UInt8((crc >> 16) & 0xFF)
        @test report[78] == UInt8((crc >> 24) & 0xFF)
    end

    @testset "Default output effects produce valid report" begin
        eff = DualSenseEffects()
        report = build_output_report(eff)
        @test length(report) == 64
        @test report[1] == 0x02
        # Motors should be 0
        @test report[4] == 0x00
        @test report[5] == 0x00
    end

end
