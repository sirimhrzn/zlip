const std = @import("std");
const Scanner = @import("zig-wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});
    const wayland = b.createModule(.{ .root_source_file = scanner.result });
    const wlroots = b.dependency("zig-wlroots", .{}).module("wlroots");
    wlroots.addImport("wayland", wayland);
    wlroots.resolved_target = target;
    wlroots.linkSystemLibrary("wlroots", .{});

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addSystemProtocol("staging/ext-session-lock/ext-session-lock-v1.xml");
    scanner.generate("wl_compositor", 4);
    scanner.generate("wl_data_device_manager", 3);
    //TODO use wlr-data-control-unstable-v1
    //scanner.addCustomProtocol("wlr.xml");
    scanner.generate("wl_seat", 4);
    scanner.generate("xdg_wm_base", 3);
    scanner.generate("ext_session_lock_manager_v1", 1);

    const zlip = b.addExecutable(.{
        .name = "zlip",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    zlip.root_module.addImport("wayland", wayland);
    zlip.root_module.addImport("wlroots", wlroots);
    zlip.linkLibC();
    zlip.linkSystemLibrary("wayland-client");
    scanner.addCSource(zlip);

    const run_cmd = b.addRunArtifact(zlip);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    b.installArtifact(zlip);
}
