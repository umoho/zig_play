const std = @import("std");

const c = @cImport({
    // TODO: let Zig find the path QuickJS is.
    @cInclude("/opt/homebrew/include/quickjs/quickjs.h");
});

/// QuickJS Runtime.
pub const Runtime = struct {
    rt: ?*c.JSRuntime,

    const Self = @This();

    /// Create a new QuickJS runtime. Call `free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.CreateRuntimeError` if the runtime cannot be created.
    ///
    /// # Returns
    ///
    /// A new QuickJS runtime.
    pub fn new() !Self {
        const rt = c.JS_NewRuntime();
        if (rt == null) {
            return error.CreateRuntimeError;
        }
        return Self{ .rt = rt };
    }

    /// Free the QuickJS runtime.
    ///
    /// # Errors
    ///
    /// - `error.BadRuntime` if the runtime is null.
    pub fn free(self: *Runtime) !void {
        if (self.rt != null) {
            c.JS_FreeRuntime(self.rt);
            self.rt = null;
        }
    }
};

/// Flags for `Context.eval`.
pub const EvalFlag = enum(c_int) {
    async_ = c.JS_EVAL_FLAG_ASYNC,
    backtrace_barrier = c.JS_EVAL_FLAG_BACKTRACE_BARRIER,
    strict = c.JS_EVAL_FLAG_STRICT,
    strip = c.JS_EVAL_FLAG_STRIP,
};

/// QuickJS context.
pub const Context = struct {
    ctx: ?*c.JSContext,

    const Self = @This();

    /// Create a new QuickJS context. Call `free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.CreateContextError` if the context cannot be created.
    ///
    /// # Returns
    ///
    /// A new QuickJS context.
    pub fn new(rt: Runtime) !Self {
        const ctx = c.JS_NewContext(rt.rt);
        if (ctx == null) {
            return error.CreateContextError;
        }
        return Self{ .ctx = ctx };
    }

    /// Free the QuickJS context.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    pub fn free(self: Self) !void {
        if (self.ctx == null) {
            return error.BadContext;
        }
        c.JS_FreeContext(self.ctx);
        return;
    }

    /// Evaluate JavaScript code. Call `Value.free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
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

    /// Get the global object. Call `Value.free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
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

    /// Get a property from the global object. Call `Value.free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
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

    /// Set a property on the global object.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    pub fn setPropertyStr(self: Self, global: Value, name: [*c]const u8, value: Value) !void {
        if (self.ctx == null) {
            return error.BadContext;
        }
        // TODO: check the return value.
        _ = c.JS_SetPropertyStr(self.ctx, global.val, name, value.val);
    }

    /// Convert a value to an i32.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    /// - `error.ConvertError` if the value cannot be converted.
    pub fn toInt32(self: Self, prop: Value) !i32 {
        if (self.ctx == null) {
            return error.BadContext;
        }
        var ans: i32 = 0;
        if (c.JS_ToInt32(self.ctx, &ans, prop.val) != 0) {
            return error.ConvertError;
        }
        return ans;
    }

    /// Convert a value to a C string. Call `CString.free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    /// - `error.ConvertError` if the value cannot be converted.
    pub fn toCString(self: Self, val: Value) !CString {
        if (self.ctx == null) {
            return error.BadContext;
        }
        const cstr = c.JS_ToCString(self.ctx, val.val);
        if (cstr == null) {
            return error.ConvertError;
        }
        return CString{ .ctx = self, .ptr = cstr };
    }

    /// Create a new i32 value. Call `Value.free` to release resources.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    ///
    /// # Returns
    ///
    /// A new i32 value.
    pub fn newInt32(self: Self, val: i32) !Value {
        if (self.ctx == null) {
            return error.BadContext;
        }
        const value = c.JS_NewInt32(self.ctx, val);
        return Value{
            .ctx = self,
            .val = value,
        };
    }
};

/// QuickJS value.
pub const Value = struct {
    ctx: Context,
    val: c.JSValue,

    const Self = @This();

    /// Free the QuickJS value.
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    pub fn free(self: Self) !void {
        if (self.ctx.ctx != null) {
            c.JS_FreeValue(self.ctx.ctx, self.val);
            return;
        }
        return error.BadContext;
    }

    /// Check if the value is an exception.
    ///
    /// # Returns
    ///
    /// `true` if the value is an exception, `false` otherwise.
    pub fn isException(self: Self) bool {
        return c.JS_IsException(self.val) != 0;
    }
};

/// C string wrapper.
pub const CString = struct {
    ctx: Context,
    ptr: [*c]const u8,

    const Self = @This();

    /// Free the C string.
    pub fn free(self: Self) void {
        c.JS_FreeCString(self.ctx.ctx, self.ptr);
    }
};

fn dumpError(ctx: Context, val: Value) !void {
    const str = try ctx.toCString(val);
    defer str.free();
    std.debug.print("Error: {}\n", .{str.ptr.*});
}

pub fn tryEval(ctx: Context, code: []const u8) !void {
    const res = try ctx.eval(code, "<input>", .async_);
    if (res.isException()) {
        try dumpError(ctx, res);
        return error.EvalError;
    }
    defer res.free() catch |err| std.debug.print("defer failed: {}\n", .{err});
}
