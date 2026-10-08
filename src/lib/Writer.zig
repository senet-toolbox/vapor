const std = @import("std");
const Vapor = @import("Vapor.zig");
const Writer = @This();

pub const Error = error{OutOfSpace};

buffer: []u8,
/// Usable capacity, which is one byte short of `buffer.len`. These buffers are
/// handed to JS as C strings, and every caller writes its own NUL at `pos`
/// after the last write, so that byte is reserved up front rather than
/// remembered at fifteen call sites.
size: usize,
pos: usize,
start: usize = 0,
/// Set the first time a write did not fit. Once true the contents are
/// truncated, never past the end of `buffer`.
overflowed: bool = false,

pub fn init(writer: *Writer, buffer: []u8) void {
    writer.* = .{
        .buffer = buffer,
        .size = if (buffer.len == 0) 0 else buffer.len - 1,
        .pos = 0,
        .start = 0,
        .overflowed = false,
    };
}

pub fn reset(self: *Writer) void {
    self.pos = 0;
    self.start = 0;
    self.overflowed = false;
}

/// Claims `n` bytes at the cursor and returns them, or fails having written
/// nothing. Every write goes through here — it is the only place `pos` moves
/// forward, so it is the only place that has to be right.
fn reserve(self: *Writer, n: usize) Error![]u8 {
    // Saturating add: `n` is a caller-supplied length and must not wrap.
    if (self.pos +| n > self.size) return self.overflow(n);
    const dest = self.buffer[self.pos .. self.pos + n];
    self.pos += n;
    return dest;
}

/// Reports the first overflow on this writer, then stays quiet so a single
/// oversized node cannot flood the console.
fn overflow(self: *Writer, needed: usize) Error {
    if (!self.overflowed) {
        self.overflowed = true;
        Vapor.printlnErr(
            "Writer out of space: needed {d} more bytes at {d}/{d}. Output is truncated.",
            .{ needed, self.pos, self.size },
        );
    }
    return error.OutOfSpace;
}

/// Mark the current position as the start of a new segment
pub fn mark(self: *Writer) void {
    self.start = self.pos;
}

/// Get the current segment (from start to pos)
pub fn getWritten(self: *Writer) []const u8 {
    return self.buffer[self.start..self.pos];
}

/// Get the full buffer contents (from 0 to pos)
pub fn getAll(self: *Writer) []const u8 {
    return self.buffer[0..self.pos];
}

/// Reset just the current segment (move pos back to start)
pub fn resetSegment(self: *Writer) void {
    self.pos = self.start;
}

pub fn writeByte(self: *Writer, byte: u8) Error!void {
    const dest = try self.reserve(1);
    dest[0] = byte;
}

pub fn writeU8Num(self: *Writer, byte: u8) Error!void {
    try self.write(fastLargeIntToString(byte));
}

pub fn write(self: *Writer, value: []const u8) Error!void {
    const dest = try self.reserve(value.len);
    @memcpy(dest, value);
}

pub fn writeF32(self: *Writer, value: f32) Error!void {
    const formatted = std.fmt.bufPrint(self.buffer[self.pos..self.size], "{d:.2}", .{value}) catch
        return self.overflow(0);
    self.pos += formatted.len;
}

pub fn writeF16(self: *Writer, value: f16) Error!void {
    try self.write(fastFloatToString(value));
}

var float_buffer: [32]u8 = undefined;
fn fastFloatToString(value: f32) []const u8 {
    // Handle special cases
    if (std.math.isNan(value)) return "NaN";
    if (std.math.isInf(value)) return if (value > 0) "Infinity" else "-Infinity";
    if (value == 0.0) return "0";

    var buf_idx: usize = 0;
    var n = value;

    // Handle negative numbers
    if (n < 0) {
        float_buffer[buf_idx] = '-';
        buf_idx += 1;
        n = -n;
    }

    // Split into integer and fractional parts
    const int_part = @as(u32, @intFromFloat(@floor(n)));
    const frac_part = n - @floor(n);

    // Convert integer part
    if (int_part == 0) {
        float_buffer[buf_idx] = '0';
        buf_idx += 1;
    } else {
        const start_idx = buf_idx;
        var temp = int_part;

        // Get digits in reverse order
        while (temp > 0) {
            float_buffer[buf_idx] = @as(u8, @intCast(temp % 10)) + '0';
            buf_idx += 1;
            temp /= 10;
        }

        // Reverse the integer part
        std.mem.reverse(u8, float_buffer[start_idx..buf_idx]);
    }

    // Add decimal point and fractional part if needed
    if (frac_part > 0.0) {
        float_buffer[buf_idx] = '.';
        buf_idx += 1;

        var frac = frac_part;
        var precision: u8 = 0;
        const max_precision: u8 = 6; // Limit decimal places

        while (frac > 0.0 and precision < max_precision) {
            frac *= 10.0;
            const digit = @as(u8, @intFromFloat(@floor(frac)));
            float_buffer[buf_idx] = digit + '0';
            buf_idx += 1;
            frac = frac - @floor(frac);
            precision += 1;
        }

        // Remove trailing zeros
        while (buf_idx > 0 and float_buffer[buf_idx - 1] == '0') {
            buf_idx -= 1;
        }

        // Remove trailing decimal point if no fractional part remains
        if (buf_idx > 0 and float_buffer[buf_idx - 1] == '.') {
            buf_idx -= 1;
        }
    }

    return float_buffer[0..buf_idx];
}

pub fn writeI32(self: *Writer, value: i32) Error!void {
    const formatted = std.fmt.bufPrint(self.buffer[self.pos..self.size], "{d}", .{value}) catch
        return self.overflow(0);
    self.pos += formatted.len;
}

pub fn writeI16(self: *Writer, value: i16) Error!void {
    const formatted = std.fmt.bufPrint(self.buffer[self.pos..self.size], "{d}", .{value}) catch
        return self.overflow(0);
    self.pos += formatted.len;
}

pub fn writeU16(self: *Writer, value: u16) Error!void {
    try self.write(fastLargeIntToString(value));
}

pub fn writeUsize(self: *Writer, value: usize) Error!void {
    try self.write(fastLargeIntToString(value));
}

var large_int_buffer: [32]u8 = undefined;
fn fastLargeIntToString(value: anytype) []const u8 {
    if (value == 0) return "0";

    var buf_idx: usize = large_int_buffer.len;
    var n = value;

    // Convert digits from right to left
    while (n > 0) {
        buf_idx -= 1;
        large_int_buffer[buf_idx] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
    }

    return large_int_buffer[buf_idx..];
}

pub fn writeU32(self: *Writer, value: u32) Error!void {
    try self.write(fastLargeIntToString(value));
}

pub fn print(self: *Writer) !void {
    const len: usize = self.pos;
    std.log.info("{s}", .{self.buffer[0..len]});
}

/// Print only the current segment (from start to pos)
pub fn printSegment(self: *Writer) !void {
    Vapor.println("{s}", .{self.buffer[self.start..self.pos]});
}
