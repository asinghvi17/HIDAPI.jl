# DualSense (PS5 Controller) Demo
# Usage: julia --project=. examples/dualsense_demo.jl

using HIDAPI
using HIDAPI.DualSense

println("Searching for DualSense controller...")
init()

devices = find_dualsense()
if isempty(devices)
    println("No DualSense found. Connect a PS5 controller via USB.")
    shutdown()
    exit(1)
end

d = devices[1]
println("Found: $(d.product) ($(d.manufacturer)) at $(d.path)")

dev = open_dualsense()
try
    # Set LED to blue
    effects = DualSenseEffects(light=LightConfig(r=0x00, g=0x00, b=0xFF))
    report = build_output_report(effects)
    HIDAPI.write(dev, report)
    println("LED set to blue")

    # Read input reports
    println("Reading 200 reports — press buttons on controller (Ctrl+C to stop)...")
    for i in 1:200
        data = HIDAPI.read(dev, 64; timeout_ms=50)
        isempty(data) && continue

        state = parse_input_report(data)
        ls = state.left_stick
        rs = state.right_stick

        parts = String[]
        push!(parts, "L:($(lpad(ls.x, 4)),$(lpad(ls.y, 4)))")
        push!(parts, "R:($(lpad(rs.x, 4)),$(lpad(rs.y, 4)))")
        push!(parts, "LT:$(lpad(state.l2_trigger, 3)) RT:$(lpad(state.r2_trigger, 3))")

        btns = String[]
        state.buttons.cross     && push!(btns, "X")
        state.buttons.circle    && push!(btns, "O")
        state.buttons.square    && push!(btns, "□")
        state.buttons.triangle  && push!(btns, "△")
        state.buttons.l1        && push!(btns, "L1")
        state.buttons.r1        && push!(btns, "R1")
        state.buttons.l2        && push!(btns, "L2")
        state.buttons.r2        && push!(btns, "R2")
        state.buttons.share     && push!(btns, "Share")
        state.buttons.options   && push!(btns, "Opt")
        state.buttons.ps        && push!(btns, "PS")
        state.buttons.dpad_up   && push!(btns, "↑")
        state.buttons.dpad_down && push!(btns, "↓")
        state.buttons.dpad_left && push!(btns, "←")
        state.buttons.dpad_right && push!(btns, "→")

        !isempty(btns) && push!(parts, "[" * join(btns, " ") * "]")

        bat = state.battery
        push!(parts, "Bat:$(bat.level)%")

        print("\r", join(parts, " "), "    ")
    end
    println("\nDone!")
finally
    HIDAPI.close(dev)
    shutdown()
end
