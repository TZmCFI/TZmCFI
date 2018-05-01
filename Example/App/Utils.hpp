#pragma once

#include <cstdint>
#include <utility>

namespace TCExample {

template <class T> inline void WriteVolatile(std::intptr_t address, T value) {
    *reinterpret_cast<T volatile *>(address) = value;
}

template <class T> inline T ReadVolatile(std::intptr_t address) {
    return *reinterpret_cast<T volatile *>(address);
}

}; // namespace TCExample
