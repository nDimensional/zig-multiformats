const std = @import("std");

pub const Code = enum(u8) {
    base10 = '9',
    base36 = 'k',
    base36upper = 'K',
    base58btc = 'z',
    base58flickr = 'Z',
    base2 = '0',
    base8 = '7',
    base16 = 'f',
    base16upper = 'F',
    base32 = 'b',
    base32upper = 'B',
    base32pad = 'c',
    base32padupper = 'C',
    base32hex = 'v',
    base32hexupper = 'V',
    base32hexpad = 't',
    base32hexpadupper = 'T',
    base32z = 'h',
    base64 = 'm',
    base64pad = 'M',
    base64url = 'u',
    base64urlpad = 'U',
};

comptime {
    std.debug.assert(@sizeOf(Code) == 1);
}
