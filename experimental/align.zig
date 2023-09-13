const std = @import("std");

const MyStruct = struct { field1: i64, field2: bool };

pub fn main() void {
    const sizeOfMyStruct: usize = @sizeOf(MyStruct);
    std.debug.print("Size of MyStruct: {}-0x{}\n", .{ sizeOfMyStruct, @returnAddress() });

    const alignmentOfMyStruct: usize = @alignOf(MyStruct);
    std.debug.print("Alignment of MyStruct: {}\n", .{alignmentOfMyStruct});

    const alignmentOfInt: usize = @alignOf(i32);
    std.debug.print("Alignment of i32: {}\n", .{alignmentOfInt});

    const alignmentOfArray: usize = @alignOf([3]i8);
    std.debug.print("Alignment of [3]i8: {}\n", .{alignmentOfArray});
}
