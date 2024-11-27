const std = @import("std");
const mem = std.mem;
const File = std.fs.File;
const fatal = std.zig.fatal;
const TransferList = @import("root.zig");

const usage =
    \\Usage: sdat2img [options]
    \\Options:
    \\  --input-image   [path]  Path for input image(eg, system.new.dat)
    \\  --output-image  [file]  Path for output raw image
    \\  --transfer-list [file]  Path for system.transfer.list 
    \\  -h, --help              Print this help menu to stdout
    \\
;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);

    var opt_input_image: ?[]const u8 = null;
    var opt_output_image: ?[]const u8 = null;
    var opt_transfer_list: ?[]const u8 = null;

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.eql(u8, arg, "--input-image")) {
                if (i + 1 >= args.len) fatal("expected parameter after {s}", .{arg});
                i += 1;
                opt_input_image = args[i];
            } else if (mem.eql(u8, arg, "--transfer-list")) {
                if (i + 1 >= args.len) fatal("expected parameter after {s}", .{arg});
                i += 1;
                opt_transfer_list = args[i];
            } else if (mem.eql(u8, arg, "--output-image")) {
                if (i + 1 >= args.len) fatal("expected parameter after {s}", .{arg});
                i += 1;
                opt_output_image = args[i];
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try std.io.getStdOut().writeAll(usage);
                std.process.exit(0);
            } else {
                fatal("unrecognized argument: '{s}'", .{arg});
            }
        }
    }

    if (opt_input_image == null or opt_output_image == null or opt_transfer_list == null) {
        try std.io.getStdOut().writeAll(usage);
        std.process.exit(0);
    }

    var file = try std.fs.cwd().openFile(opt_transfer_list.?, .{});
    defer file.close();
    var list = try TransferList.parseFromStream(arena, file.reader());
    defer list.deinit();

    var input_image = try std.fs.cwd().openFile(opt_input_image.?, .{});
    defer input_image.close();
    var output_image = try std.fs.cwd().createFile(opt_output_image.?, .{ .truncate = true });
    defer output_image.close();

    try list.writeImage(&input_image, &output_image);
}
