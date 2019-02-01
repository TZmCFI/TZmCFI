#pragma once

#include <array>
#include <cstdint>
#include <string_view>

namespace Base64 {

// Largely based on <https://github.com/ReneNyffenegger/cpp-base64/blob/master/base64.cpp>

template <class F> void EncodeAndOutputToFunctionByCharacter(std::string_view data, F sink) {
    constexpr const char *chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                  "abcdefghijklmnopqrstuvwxyz"
                                  "0123456789+/";

    const char *read = data.data();
    std::size_t len = data.size();

    std::array<std::uint8_t, 3> char_array_3;
    std::array<std::uint8_t, 4> char_array_4;
    int i = 0;

    while (len--) {
        char_array_3[i++] = *(read++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for (char c : char_array_4) {
                sink(chars[static_cast<std::size_t>(c)]);
            }
            i = 0;
        }
    }

    if (i) {
        for (int k = i; k < 3; ++k) {
            char_array_3[k] = 0;
        }

        char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);

        for (int k = 0; k < i + 1; ++k) {
            sink(chars[static_cast<std::size_t>(char_array_4[k])]);
        }
        while ((i++) < 3) {
            sink('=');
        }
    }
}

} // namespace Base64
