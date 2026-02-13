using HIDAPI
using Test

@testset "HIDAPI.jl" begin

    @testset "Library loading" begin
        @test isfile(HIDAPI.hidapi)
    end

    @testset "Error types" begin
        err = HIDAPIError("test error")
        @test err isa Exception
        @test err.msg == "test error"
        buf = IOBuffer()
        showerror(buf, err)
        @test String(take!(buf)) == "HIDAPIError: test error"
    end

    @testset "unsafe_wstring with C_NULL" begin
        @test HIDAPI.unsafe_wstring(Ptr{Cwchar_t}(C_NULL)) == ""
    end

    @testset "Version" begin
        v = version()
        @test v isa VersionNumber
        @test v >= v"0.10.0"
    end

    @testset "Init/Shutdown lifecycle" begin
        @test init() === nothing
        @test shutdown() === nothing
    end

    @testset "Enumerate" begin
        init()
        devices = HIDAPI.enumerate()
        @test devices isa Vector{HIDDeviceInfo}
        for d in devices
            @test d.path isa String
            @test d.vendor_id isa UInt16
            @test d.product_id isa UInt16
            @test d.manufacturer isa String
            @test d.product isa String
        end

        bogus = HIDAPI.enumerate(0xFFFF, 0xFFFF)
        @test isempty(bogus)

        shutdown()
    end

    @testset "HIDDevice null pointer" begin
        @test_throws HIDAPIError HIDDevice(Ptr{HIDAPI.hid_device}(C_NULL))
    end

    @testset "Open nonexistent device" begin
        init()
        @test_throws HIDAPIError HIDAPI.open(0xFFFF, 0xFFFF)
        shutdown()
    end

    @testset "Raw bindings accessible" begin
        @test HIDAPI.hid_init isa Function
        @test HIDAPI.hid_exit isa Function
        @test HIDAPI.hid_enumerate isa Function
        @test HIDAPI.hid_version isa Function
    end

    include("test_dualsense.jl")

end
