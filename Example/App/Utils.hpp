#pragma once

#include <algorithm>
#include <cstdint>
#include <utility>

namespace TCExample {

template <class T> inline void WriteVolatile(std::intptr_t address, T value) {
    *reinterpret_cast<T volatile *>(address) = value;
}

template <class T> inline T ReadVolatile(std::intptr_t address) {
    return *reinterpret_cast<T volatile *>(address);
}

template <class T> void Print(T &target, uint32_t i) {
    std::array<char, 10> buffer;
    std::size_t len = 0;
    while (i != 0) {
        buffer[len++] = '0' + (i % 10);
        i /= 10;
    }
    std::reverse(buffer.begin(), buffer.begin() + len);

    target.WriteAll({buffer.data(), len});
}

}; // namespace TCExample
