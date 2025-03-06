const std = @import("std");
const mem = std.mem;
const File = std.fs.File;
const testing = std.testing;
const TransferList = @This();

const block_size = 4096;

version: Version = .unsupported,
commands: Command.List,
new_blocks: usize = 0,
max_block_num: usize = 0,

pub const Version = enum(u8) {
    unsupported = 0,
    @"Lollipop 5.0",
    @"Lollipop 5.1",
    @"Marshmallow 6.x",
    @"Nougat 7.x / Oreo 8.x",
};

pub const Command = struct {
    tag: Tag,
    begin: usize = 0,
    end: usize = 0,

    pub const Tag = enum {
        erase,
        new,
        zero,
    };

    pub const List = std.ArrayList(Command);

    pub fn parse(list: *TransferList, buf: []const u8) !void {
        var it = mem.splitScalar(u8, buf, ' ');
        const tag = std.meta.stringToEnum(Tag, it.first()) orelse return;
        var it_range = mem.tokenizeScalar(u8, it.rest(), ',');
        const size = try std.fmt.parseInt(usize, it_range.next().?, 10);
        if (!mem.containsAtLeast(u8, buf, size, ",")) {
            return error.MissingCommand;
        }
        while (it_range.next()) |raw| {
            var command: Command = .{ .tag = tag };
            command.begin = try std.fmt.parseInt(usize, raw, 10);
            command.end = try std.fmt.parseInt(usize, it_range.next().?, 10);
            try list.commands.append(command);
            if (command.end > list.max_block_num) {
                list.max_block_num = command.end;
            }
        }
    }
};

pub fn writeImage(self: *TransferList, in: *File, out: *File) !void {
    try out.seekTo(self.max_block_num * block_size - 1);
    try out.writer().writeByte('\x00');
    for (self.commands.items) |command| {
        if (command.tag == .new) {
            const in_offset = try in.getPos();
            const block_count = command.end - command.begin;
            const out_offset = command.begin * block_size;
            const size = block_size * block_count;
            std.log.info("Copying {d} blocks into position {d}...", .{
                block_count,
                command.begin,
            });
            _ = try in.copyRangeAll(in_offset, out.*, out_offset, size);
            try in.seekBy(@intCast(size));
        } else {
            std.log.info("Skipping command {s}...", .{@tagName(command.tag)});
        }
    }
}

pub fn parseFromStream(allocator: mem.Allocator, stream: anytype) !TransferList {
    var line: usize = 0;
    var buf: [4096]u8 = undefined;
    var list: TransferList = .{
        .commands = Command.List.init(allocator),
    };
    while (true) : (line += 1) {
        var out = std.io.fixedBufferStream(&buf);
        stream.streamUntilDelimiter(out.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
        if (line == 0) {
            const version = try std.fmt.parseInt(u8, out.getWritten(), 10);
            list.version = @enumFromInt(version);
            std.log.info("Android {s} detected!", .{@tagName(list.version)});
        } else if (line == 1) {
            list.new_blocks = try std.fmt.parseInt(usize, out.getWritten(), 10);
        } else if ((line == 2 or line == 3) and @intFromEnum(list.version) >= 2) {
            continue;
        } else {
            try Command.parse(&list, out.getWritten());
        }
    }
    return list;
}

pub fn deinit(self: *TransferList) void {
    self.commands.deinit();
}

test "transfer list parsing" {
    const transfer_list =
        \\3
        \\55920
        \\0
        \\0
        \\erase 2,24176,32256
        \\new 2,0,1024
        \\new 2,1024,2048
        \\new 2,2048,3072
        \\new 2,3072,4096
        \\new 2,4096,5120
        \\new 2,5120,6144
        \\new 2,6144,7168
        \\new 2,7168,8192
        \\new 2,8192,9216
        \\new 2,9216,10240
        \\new 2,10240,11264
        \\new 2,11264,12288
        \\new 2,12288,13312
        \\new 2,13312,14336
        \\new 2,14336,15360
        \\new 2,15360,16384
        \\new 2,16384,17408
        \\new 2,17408,18432
        \\new 2,18432,19456
        \\new 2,19456,20480
        \\new 2,20480,21504
        \\new 2,21504,22528
        \\new 2,22528,23552
        \\new 8,23552,23664,32768,32770,32785,32787,33287,34195
        \\new 2,34195,35219
        \\new 2,35219,36243
        \\new 2,36243,37267
        \\new 2,37267,38291
        \\new 2,38291,39315
        \\new 2,39315,40339
        \\new 2,40339,41363
        \\new 2,41363,42387
        \\new 2,42387,43411
        \\new 2,43411,44435
        \\new 2,44435,45459
        \\new 2,45459,46483
        \\new 2,46483,47507
        \\new 2,47507,48531
        \\new 2,48531,49555
        \\new 2,49555,50579
        \\new 2,50579,51603
        \\new 2,51603,52627
        \\new 2,52627,53651
        \\new 2,53651,54675
        \\new 2,54675,55699
        \\new 2,55699,56723
        \\new 2,56723,57747
        \\new 2,57747,58771
        \\new 2,58771,59795
        \\new 2,59795,60819
        \\new 2,60819,61843
        \\new 2,61843,62867
        \\new 2,62867,63891
        \\new 2,63891,63999
        \\zero 4,23664,24176,32256,32768
        \\zero 6,32770,32785,32787,33287,63999,64000
    ;
    var stream = std.io.fixedBufferStream(transfer_list);
    var list = try TransferList.parseFromStream(testing.allocator, stream.reader());
    defer list.deinit();
}
