const std = @import("std");
const wl = @import("wayland").client.wl;
const mem = std.mem;

pub fn main() !void {
    const display = try wl.Display.connect(null);
    const registry = try display.getRegistry();
    defer registry.destroy();

    // set listener for global events
    var zlip = Zlip.init();
    registry.setListener(*Zlip, registryListener, &zlip);
    if (display.roundtrip() != .SUCCESS) return error.RoundTripFailed;

    zlip.dd = try zlip.ddm.?.getDataDevice(zlip.seat.?);

    if (zlip.ddm == null or zlip.seat == null) {
        std.debug.print("Failed to bind required interfaces\n", .{});
        return;
    }
    if (zlip.dd) |dd| {
        dd.setListener(*Zlip, handle_dd, &zlip);
        std.debug.print("Data device listener set\n", .{});
    } else {
        std.debug.print("Failed to set data device listener: data device is null\n", .{});
        return error.DataDeviceNotInitialized;
    }
    // var counter: usize = 0;
    while (true) {
        std.debug.print("Dispatching events...\n", .{});
        if (display.dispatch() != .SUCCESS) return error.DispatchFailed;
        std.debug.print("Events dispatched\n", .{});
    }
}
fn handle_dd(_: *wl.DataDevice, event: wl.DataDevice.Event, zlip: *Zlip) void {
    std.debug.print("handle dd called", .{});
    switch (event) {
        .data_offer => |offer| {
            zlip.df = offer.id;
            std.debug.print("df set from data_offer", .{});
        },
        .selection => |selection| {
            std.debug.print("selection recieved {}", .{selection});
        },
        else => {
            std.debug.print("other events recieved", .{});
        },
    }
}
fn triggerClipboardEvent(zlip: *Zlip) void {
    std.debug.print("Attempting to trigger clipboard event...\n", .{});
    if (zlip.ddm) |ddm| {
        const data_source = ddm.createDataSource() catch |err| {
            std.debug.print("Failed to create data source: {}\n", .{err});
            return;
        };
        std.debug.print("Data source created\n", .{});

        data_source.offer("text/plain");
        std.debug.print("Offered text/plain MIME type\n", .{});

        if (zlip.dd) |dd| {
            dd.setSelection(data_source, 0);
            std.debug.print("Set selection on data device\n", .{});
        } else {
            std.debug.print("Data device is null\n", .{});
        }
    } else {
        std.debug.print("Data device manager is null\n", .{});
    }
}

const Zlip = struct {
    registry: ?*wl.Registry,
    ddm: ?*wl.DataDeviceManager,
    ds: ?*wl.DataSource,
    seat: ?*wl.Seat,
    dd: ?*wl.DataDevice,
    df: ?*wl.DataOffer,
    fn init() Zlip {
        return Zlip{ .registry = null, .ddm = null, .seat = null, .ds = null, .dd = null, .df = null };
    }
};

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, data: *Zlip) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.DataDeviceManager.getInterface().name) == .eq) {
                data.ddm = registry.bind(global.name, wl.DataDeviceManager, 3) catch return;
            }
            if (mem.orderZ(u8, global.interface, wl.Seat.getInterface().name) == .eq) {
                data.seat = registry.bind(global.name, wl.Seat, 1) catch return;
            }
            // if (mem.orderZ(u8, global.interface, wl.DataSource.getInterface().name) == .eq) {
            //     data.ds = registry.bind(global.name, wl.DataSource, 1) catch return;
            // }
            if (mem.orderZ(u8, global.interface, wl.DataDevice.getInterface().name) == .eq) {
                data.dd = registry.bind(global.name, wl.DataDevice, 1) catch return;
            }
            if (mem.orderZ(u8, global.interface, wl.DataOffer.getInterface().name) == .eq) {
                data.df = registry.bind(global.name, wl.DataOffer, 1) catch return;
            }
        },
        .global_remove => {},
    }
}

fn copyToClipboard(zlip: *Zlip, _: ?[]const u8) !void {
    //create a datasource
    const data_source = try zlip.ddm.?.createDataSource();
    errdefer data_source.destroy();
    const textToCopy: [*]const u8 = "Zig sayss hiii";
    data_source.offer("text/plain;charset=utf-8");
    data_source.setListener([*]const u8, copyToClipboardListener, textToCopy);
    if (zlip.dd) |dev| {
        dev.setSelection(data_source, 0);
    }
    // data_source.
}
fn get_copy_event_from_client(zlip: *Zlip) !void {
    const dd = try zlip.ddm.?.getDataDevice(zlip.seat.?);
    // const textToBeCopied: [*]const u8 = "Say hiii to zigggg";
    std.debug.print("here", .{});
    dd.setListener(*Zlip, copy_listener, zlip);
    std.debug.print("after setting listener", .{});
}
fn copy_listener(_: *wl.DataDevice, event: wl.DataDevice.Event, zlip: *Zlip) void {
    switch (event) {
        .data_offer => |offer| {
            zlip.df = offer.id;
            std.debug.print("offer for text recieved", .{});
            offer.id.setListener(*Zlip, dataOfferListener, zlip);
        },
        .selection => |selection| {
            if (selection.id) |offer| {
                std.debug.print("selection event recieved", .{});
                offer.accept(0, "text/plain;charset=utf-8");
            }
        },
        else => {
            std.debug.print("Nothing matches", .{});
        },
    }
}
fn dataOfferListener(_: *wl.DataOffer, event: wl.DataOffer.Event, _: *Zlip) void {
    switch (event) {
        .offer => |mime_type| {
            const mime_type_slice = mem.span(mime_type.mime_type);
            if (mem.eql(u8, mime_type_slice, "text/plain;charset=utf-8")) {
                std.debug.print("Text data available\n", .{});
            }
        },
        else => {},
    }
}

fn copyToClipboardListener(ds: *wl.DataSource, event: wl.DataSource.Event, _: [*]const u8) void {
    switch (event) {
        .send => |send| {
            std.debug.print("sending event", .{});
            const file = std.fs.File{ .handle = send.fd };
            file.writeAll("Zig says hello") catch {
                std.debug.print("failed to write to fd", .{});
                return;
            };
            file.close();
        },
        .cancelled => {
            ds.destroy();
        },
        else => {},
    }
}
fn setToClipboard() void {}
