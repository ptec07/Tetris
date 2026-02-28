const std = @import("std");

pub const PieceType = enum(u8) {
    I = 0,
    O,
    T,
    S,
    Z,
    J,
    L,
};

pub const RandomBag = struct {
    prng: std.Random.DefaultPrng,
    bag: [7]PieceType = undefined,
    index: usize = 7,

    pub fn init(seed: u64) RandomBag {
        var rb = RandomBag{
            .prng = std.Random.DefaultPrng.init(seed),
            .index = 7,
        };
        rb.fillBag();
        return rb;
    }

    fn fillBag(self: *RandomBag) void {
        self.bag = .{
            .I,
            .O,
            .T,
            .S,
            .Z,
            .J,
            .L,
        };
        const random = self.prng.random();
        var i: usize = 6;
        while (i > 0) : (i -= 1) {
            const j = random.uintLessThan(usize, i + 1);
            const temp = self.bag[i];
            self.bag[i] = self.bag[j];
            self.bag[j] = temp;
        }
        self.index = 0;
    }

    pub fn next(self: *RandomBag) PieceType {
        if (self.index >= self.bag.len) {
            self.fillBag();
        }
        const t = self.bag[self.index];
        self.index += 1;
        return t;
    }
};
