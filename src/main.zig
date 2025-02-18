const std = @import("std");

const Runtime = @import("root.zig").Runtime;
const Context = @import("root.zig").Context;
const Value = @import("root.zig").Value;
const tryEval = @import("root.zig").tryEval;

pub fn main() !void {
    var rt = try Runtime.new();
    defer rt.free() catch |err| std.debug.print("defer failed: {}\n", .{err});

    var ctx = try Context.new(rt);
    defer ctx.free() catch |err| std.debug.print("defer failed: {}\n", .{err});

    var global = try ctx.getGlobalObject();
    defer global.free() catch |err| std.debug.print("defer failed: {}\n", .{err});

    const code: []const u8 =
        \\const mul = x => y => x * y;
        \\var answer;
        \\answer = mul(6)(7);
    ;
    try tryEval(ctx, code);

    const prop = try ctx.getPropertyStr(global, "answer");
    defer prop.free() catch |err| std.debug.print("defer failed: {}\n", .{err});

    const answer = try ctx.toInt32(prop);
    std.debug.print("Answer: {}\n", .{answer});
}
