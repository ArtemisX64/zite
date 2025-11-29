//TODO: For compatibility. Remove

const Color = @import("types.zig").Color;

pub const RenColor = extern struct {
    b: u8,
    g: u8,
    r: u8,
    a: u8,

    pub fn toRenColor(col: Color) RenColor {
        return .{
            .r = col.r,
            .g = col.g,
            .b = col.b,
            .a = col.a,
        };
    }

    pub fn fromRenColor(self: *const RenColor) Color {
        return .{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = self.a,
        };
    }
};
