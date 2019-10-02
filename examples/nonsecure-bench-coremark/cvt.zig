// Translated from `cvt.c` using `zig translate-c` (with manual modification).
// The original copyright text is shown below:
//
//   Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)
//   
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//   
//       http://www.apache.org/licenses/LICENSE-2.0
//   
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//
const modf = @import("std").math.modf;

var CVTBUF: [80]u8 = undefined;
export fn cvt(_arg_arg: f64, _arg_ndigits: c_int, decpt: [*c]c_int, sign: [*c]c_int, buf: [*c]u8, eflag: c_int) [*c]u8 {
    var arg = _arg_arg;
    var ndigits = _arg_ndigits;
    var r2: c_int = undefined;
    var fi: f64 = undefined;
    var fj: f64 = undefined;
    var p: [*c]u8 = undefined;
    var p1: [*c]u8 = undefined;
    if (ndigits < 0) ndigits = 0;
    if (ndigits >= (80 - 1)) ndigits = (80 - 2);
    r2 = 0;
    sign.?.* = 0;
    p = (&buf[0]);
    if (arg < @intToFloat(f64, 0)) {
        sign.?.* = 1;
        arg = (-arg);
    }
    {
        const modf_result = modf(arg);
        arg = modf_result.fpart;
        fi = modf_result.ipart;
    }
    p1 = (&buf[80]);
    if (fi != @intToFloat(f64, 0)) {
        p1 = (&buf[80]);
        while (fi != @intToFloat(f64, 0)) {
            {
                const modf_result = modf(fi / 10.0);
                fj = modf_result.fpart;
                fi = modf_result.ipart;
            }
            p1 -= 1;
            p1.?.* = @floatToInt(u8, (fj + 0.03) * 10.0) + '0';
            r2 += 1;
        }
        while (p1 < (&buf[80])) {
            p.?.* = p1.?.*;
            p += 1;
            p1 += 1;
        }
    } else if (arg > 0.0) {
        while ((x: {
            const _tmp = arg * 10.0;
            fj = _tmp;
            break :x _tmp;
        }) < @intToFloat(f64, 1)) {
            arg = fj;
            r2 -= 1;
        }
    }
    p1 = (&buf[@intCast(usize, ndigits)]);
    if (eflag == 0) p1 += @intCast(usize, r2);
    decpt.?.* = r2;
    if (p1 < (&buf[0])) {
        buf[0] = u8('\x00');
        return buf;
    }
    while ((p <= p1) and (p < (&buf[80]))) {
        arg *= 10.0;
        {
            const modf_result = modf(arg);
            arg = modf_result.fpart;
            fj = modf_result.ipart;
        }
        p.?.* = @floatToInt(u8, fj) + '0';
        p += 1;
    }
    if (p1 >= (&buf[80])) {
        buf[80 - 1] = u8('\x00');
        return buf;
    }
    p = p1;
    p1.?.* +%= 5;
    while (c_int(p1.?.*) > '9') {
        p1.?.* = u8('0');
        if (p1 > buf) {
            p1 -= 1;
            p1.?.* += 1;
        } else {
            p1.?.* = u8('1');
            decpt.?.* += 1;
            if (eflag == 0) {
                if (p > buf) p.?.* = u8('0');
                p += 1;
            }
        }
    }
    p.?.* = 0;
    return buf;
}
export fn ecvt(arg: f64, ndigits: c_int, decpt: [*c]c_int, sign: [*c]c_int) [*c]u8 {
    return cvt(arg, ndigits, decpt, sign, &CVTBUF, 1);
}
export fn ecvtbuf(arg: f64, ndigits: c_int, decpt: [*c]c_int, sign: [*c]c_int, buf: [*c]u8) [*c]u8 {
    return cvt(arg, ndigits, decpt, sign, buf, 1);
}
export fn fcvt(arg: f64, ndigits: c_int, decpt: [*c]c_int, sign: [*c]c_int) [*c]u8 {
    return cvt(arg, ndigits, decpt, sign, &CVTBUF, 0);
}
export fn fcvtbuf(arg: f64, ndigits: c_int, decpt: [*c]c_int, sign: [*c]c_int, buf: [*c]u8) [*c]u8 {
    return cvt(arg, ndigits, decpt, sign, buf, 0);
}
