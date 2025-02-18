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
        if (self.rt == null) {
            return error.BadRuntime;
        }
        c.JS_FreeRuntime(self.rt);
        self.rt = null;
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
        // TODO: fix 'error: cannot assign to constant'.
        // self.ctx = null;
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
    pub fn newInt32(self: Self, val: i32) Value {
        const value = c.JS_NewInt32(self.ctx, val);
        return Value{
            .ctx = self,
            .val = value,
        };
    }

    pub fn newInt64(self: Self, val: i64) Value {
        const value = c.JS_NewInt64(self.ctx, val);
        return .{
            .ctx = self,
            .val = value,
        };
    }

    pub fn newUInt32(self: Self, val: u32) Value {
        const value = c.JS_NewUint32(self.ctx, val);
        return .{
            .ctx = self,
            .val = value,
        };
    }

    pub fn newBigInt64(self: Self, val: i64) Value {
        const value = c.JS_NewBigInt64(self.ctx, val);
        return .{
            .ctx = self,
            .val = value,
        };
    }

    pub fn newBigUInt64(self: Self, val: i64) Value {
        const value = c.JS_NewBigUint64(self.ctx, val);
        return .{
            .ctx = self,
            .val = value,
        };
    }

    pub fn newFloat64(self: Self, val: f64) Value {
        const value = c.JS_NewFloat64(self.ctx, val);
        return .{
            .ctx = self,
            .val = value,
        };
    }

    pub fn newNumber(self: Self, comptime T: type, val: T) Value {
        return switch (T) {
            i32 => self.newInt32(val),
            i64 => self.newInt64(val),
            u32 => self.newUInt32(val),
            f64 => self.newFloat64(val),
            struct { .big_i64_val } => self.newBigInt64(val.big_i64_val),
            struct { .big_u64_val } => self.newBigUInt64(val.big_u64_val),
            else => @compileError("type" ++ @typeName(T) ++ " is not a kind of number"),
        };
    }

    pub fn newFunction(self: Self, function: Function, name: [*c]const u8, arg_length: usize) Value {
        const res = c.JS_NewCFunction(self.ctx, toCFunction(function), name, @intCast(arg_length));
        return Value{
            .ctx = self,
            .val = res,
        };
    }

    pub fn throw(self: Self, val: Value) Value {
        const res = c.JS_Throw(self.ctx, val.val);
        return Value{
            .ctx = self,
            .val = res,
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
        if (self.ctx.ctx == null) {
            return error.BadContext;
        }
        c.JS_FreeValue(self.ctx.ctx, self.val);
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
    ///
    /// # Errors
    ///
    /// - `error.BadContext` if the context is null.
    /// - `error.DoubleFreeCString` if the pointer is null.
    pub fn free(self: Self) !void {
        if (self.ctx.ctx == null) {
            return error.BadContext;
        }
        if (self.ptr == null) {
            return error.DoubleFreeCString;
        }
        c.JS_FreeCString(self.ctx.ctx, self.ptr);
        // TODO: fix 'error: cannot assign to constant'.
        // self.ptr = null;
    }
};

fn dumpError(ctx: Context, val: Value) !void {
    const str = try ctx.toCString(val);
    defer str.free() catch |err| std.debug.print("defer failed: {}\n", .{err});
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

pub const FunctionArgs = struct {
    argc: usize,
    argv: [*]Value,
};
pub const Function = fn (ctx: Context, this: Value, args: FunctionArgs) Value;

/// Convert a function to a C function pointer.
fn toCFunction(function: Function) ?*c.JSCFunction {
    const Wrapper = struct {
        fn handler(
            ctx: ?*c.JSContext,
            this_val: c.JSValueConst,
            argc: c_int,
            argv: [*c]c.JSValueConst,
        ) callconv(.C) c.JSValue {
            const ctxt = .{ .ctx = ctx };
            const this = .{ .ctx = ctxt, .val = this_val };
            const args = FunctionArgs{ .argc = @intCast(argc), .argv = @ptrCast(argv) };
            const value = function(ctxt, this, args);
            return value.val;
        }
    };
    return @constCast(&Wrapper.handler);
}
