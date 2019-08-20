#pragma once
/*
 * This header file defines the private part of an interface from the software
 * running in the Non-Secure mode to the monitor progran running in the Secure
 * mode. It's not intended to be called from an application or operating system
 * but rather to be called by CFI infrastructure code.
 */
#ifdef __cplusplus
extern "C" {
#endif

/**
 * Enters the Secure part of the interrupt trampoline.
 */
void __TCPrivateEnterInterrupt(void (*isrBody)());

/**
 * Enters the Secure part of the interrupt return trampoline.
 */
void __TCPrivateLeaveInterrupt(void);

#ifdef __cplusplus
};
#endif