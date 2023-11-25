const std = @import("std");

const rfc4648 = @import("rfc4648.zig");
const baseX = @import("baseX.zig");

// Base-X family

pub const base10 = baseX.Base("9", "0123456789");

pub const base36 = baseX.Base("k", "0123456789abcdefghijklmnopqrstuvwxyz");
pub const base36upper = baseX.Base("K", "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ");

pub const base58btc = baseX.Base("z", "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz");
pub const base58flickr = baseX.Base("Z", "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ");

// RFC 4648 family

pub const base2 = rfc4648.Base("0", "01", 1);

pub const base8 = rfc4648.Base("7", "01234567", 3);

pub const base16 = rfc4648.Base("f", "0123456789abcdef", 4);
pub const base16upper = rfc4648.Base("F", "0123456789ABCDEF", 4);

pub const base32 = rfc4648.Base("b", "abcdefghijklmnopqrstuvwxyz234567", 5);
pub const base32upper = rfc4648.Base("B", "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", 5);
pub const base32pad = rfc4648.Base("c", "abcdefghijklmnopqrstuvwxyz234567=", 5);
pub const base32padupper = rfc4648.Base("C", "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=", 5);

pub const base32hex = rfc4648.Base("v", "0123456789abcdefghijklmnopqrstuv", 5);
pub const base32hexupper = rfc4648.Base("V", "0123456789ABCDEFGHIJKLMNOPQRSTUV", 5);
pub const base32hexpad = rfc4648.Base("t", "0123456789abcdefghijklmnopqrstuv=", 5);
pub const base32hexpadupper = rfc4648.Base("T", "0123456789ABCDEFGHIJKLMNOPQRSTUV=", 5);

pub const base32z = rfc4648.Base("h", "ybndrfg8ejkmcpqxot1uwisza345h769", 5);

pub const base64 = rfc4648.Base("m", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", 6);
pub const base64pad = rfc4648.Base("M", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=", 6);
pub const base64url = rfc4648.Base("u", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", 6);
pub const base64urlpad = rfc4648.Base("U", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=", 6);
