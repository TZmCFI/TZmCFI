#include "Pl011Driver.hpp"
#include "Utils.hpp"

using std::uint32_t;

/*
 * Some parts of this source code were adapted from:
 * https://github.com/altera-opensource/linux-socfpga/blob/master/drivers/tty/serial/mps2-uart.c
 */

#define BIT(n) (1ul << (n))

#define UARTn_DATA 0x00

#define UARTn_STATE 0x04
#define UARTn_STATE_TX_FULL BIT(0)
#define UARTn_STATE_RX_FULL BIT(1)
#define UARTn_STATE_TX_OVERRUN BIT(2)
#define UARTn_STATE_RX_OVERRUN BIT(3)

#define UARTn_CTRL 0x08
#define UARTn_CTRL_TX_ENABLE BIT(0)
#define UARTn_CTRL_RX_ENABLE BIT(1)
#define UARTn_CTRL_TX_INT_ENABLE BIT(2)
#define UARTn_CTRL_RX_INT_ENABLE BIT(3)
#define UARTn_CTRL_TX_OVERRUN_INT_ENABLE BIT(4)
#define UARTn_CTRL_RX_OVERRUN_INT_ENABLE BIT(5)

#define UARTn_INT 0x0c
#define UARTn_INT_TX BIT(0)
#define UARTn_INT_RX BIT(1)
#define UARTn_INT_TX_OVERRUN BIT(2)
#define UARTn_INT_RX_OVERRUN BIT(3)

#define UARTn_BAUDDIV 0x10
#define UARTn_BAUDDIV_MASK GENMASK(20, 0)

#define FLAGS_TX_INT_EN BIT(0)
#define FLAGS_RX_INT_EN BIT(1)

namespace TCExample {

void Pl011Driver::Configure(uint32_t systemCoreClock, uint32_t baudRate) const {
    WriteVolatile<uint32_t>(baseAddress + UARTn_BAUDDIV, systemCoreClock / baudRate);
    WriteVolatile<uint8_t>(baseAddress + UARTn_CTRL, UARTn_CTRL_TX_ENABLE | UARTn_CTRL_RX_ENABLE);
}

bool Pl011Driver::Write(char data) const {
    if (ReadVolatile<uint8_t>(baseAddress + UARTn_STATE) & UARTn_STATE_TX_FULL) {
        return false;
    }

    WriteVolatile<uint8_t>(baseAddress + UARTn_DATA, data);
    return true;
}

void Pl011Driver::WriteAll(char data) const {
    while (!Write(data))
        ;
}

void Pl011Driver::WriteAll(std::string_view data) const {
    for (char c : data) {
        WriteAll(c);
    }
}

}; // namespace TCExample