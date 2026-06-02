const std = @import("std");

const cribbage = @import("cribbage");

pub fn main(init: std.process.Init) !void {
    try cribbage.main(init);
}
