const std = @import("std");

const c = @cImport({
    // TODO: let Zig find the path QuickJS is.
    @cInclude("/opt/homebrew/include/quickjs/quickjs.h");
});

const Runtime = struct {
    rt: ?*c.JSRuntime,

    const Self = @This();

    pub fn new() !Self {
        const rt = c.JS_NewRuntime();
        if (rt == null) {
            return error.CreateRuntimeError;
        }
        return Self{ .rt = rt };
    }

    pub fn free(self: *Runtime) !void {
        if (self.rt != null) {
            c.JS_FreeRuntime(self.rt);
            self.rt = null;
        }
    }
};

const EvalFlag = enum(c_int) {
    async_ = c.JS_EVAL_FLAG_ASYNC,
    blacktrace_barrier = c.JS_EVAL_FLAG_BACKTRACE_BARRIER,
    strict = c.JS_EVAL_FLAG_STRICT,
    strip = c.JS_EVAL_FLAG_STRIP,
};

const Context = struct {
    ctx: ?*c.JSContext,

    const Self = @This();

    pub fn new(rt: Runtime) !Self {
        const ctx = c.JS_NewContext(rt.rt);
        if (ctx == null) {
            return error.CreateContextError;
        }
        return Self{ .ctx = ctx };
    }

    pub fn free(self: Self) !void {
        if (self.ctx != null) {
            c.JS_FreeContext(self.ctx);
            return;
        }
        return error.Leak;
    }

    pub fn eval(self: Self, code: []const u8, filename: [*c]const u8, flag: EvalFlag) !Value {
        if (self.ctx == null) {
            return error.BadContext;
        }
        const res = c.JS_Eval(self.ctx, code.ptr, code.len, filename, @intCast(@intFromEnum(flag)));
        return Value{
            .ctx = self,
            .val = res,
        };
    }

    pub fn getGlobalObject(self: Self) !Value {
        if (self.ctx == null) {
            return error.BadContext;
        }
        const global = c.JS_GetGlobalObject(self.ctx);
        return Value{
            .ctx = self,
            .val = global,
        };
    }

    pub fn getPropertyStr(self: Self, global: Value, name: [*c]const u8) !Value {
        if (self.ctx == null) {
            return error.BadContext;
        }
        const prop_str = c.JS_GetPropertyStr(self.ctx, global.val, name);
        return Value{
            .ctx = self,
            .val = prop_str,
        };
    }

    pub fn toInt32(self: Self, prop: Value) !i32 {
        var ans: i32 = 0;
        if (c.JS_ToInt32(self.ctx, &ans, prop.val) != 0) {
            return error.ConvertError;
        }
        return ans;
    }

    pub fn toCString(self: Self, val: Value) !CString {
        const cstr = c.JS_ToCString(self.ctx, val.val);
        if (cstr == null) {
            return error.ConvertError;
        }
        return CString{ .ptr = cstr };
    }
};

const Value = struct {
    ctx: Context,
    val: c.JSValue,

    const Self = @This();

    pub fn free(self: Self) !void {
        if (self.ctx.ctx != null) {
            c.JS_FreeValue(self.ctx.ctx, self.val);
            return;
        }
        return error.BadContext;
    }

    pub fn isException(self: Self) bool {
        return c.JS_IsException(self.val) != 0;
    }
};

const CString = struct {
    ptr: [*c]const u8,

    const Self = @This();

    pub fn free(self: Self) void {
        c.JS_FreeCString(self.ptr);
    }
};

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

fn dumpError(ctx: Context, val: Value) !void {
    const str = try ctx.toCString(val);
    std.debug.print("Error: {}\n", .{str.ptr.*});
}

fn tryEval(ctx: Context, code: []const u8) !void {
    const res = try ctx.eval(code, "<input>", .async_);
    if (res.isException()) {
        try dumpError(ctx, res);
        return error.EvalError;
    }
    defer res.free() catch |err| std.debug.print("defer failed: {}\n", .{err});
}
