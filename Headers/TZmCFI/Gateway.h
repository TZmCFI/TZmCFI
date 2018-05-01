#pragma once
/*
 * This header file defines an interface from the software running in the
 * Non-Secure mode to the monitor progran running in the Secure mode.
 *
 * The linker conforming "Armv8-M Security Extensions: Requrements on
 * Development Tools" generates a Secure gateway veneer function for the
 * definition of each function. Veneer functions are located in the Non-Secure
 * callable (NSC) memory region so they can be called by the software running in
 * the Non-Secure mode. Resolving the location of veneer functions is
 * accomplished via a special object file (called Secure gateway import library)
 * generated while linking the Secure code.
 */
#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/**
 * The return codes indicating the result of an operation.
 */
typedef enum TCResult {
    TC_RESULT_SUCCESS = 0,
    TC_RESULT_ERROR_OUT_OF_MEMORY = 1,
    TC_RESULT_ERROR_UNPRIVILEGED = 2,
    /**
     * At least one of the parameters contains an invalid value. For example,
     * this code is returned if some parameter contains an invalid pointer.
     */
    TC_RESULT_ERROR_INVALID_ARGUMENT = 3,
    /**
     * The current state is invalid for the function call.
     */
    TC_RESULT_ERROR_INVALID_OPERATION = 4,
} TCResult;

/**
 * Reset the system configuration.
 */
TCResult TCReset(void);

/**
 * An identifier of a thread as recognized by the TZmCFI secure monitor.
 */
typedef uint8_t TCThread;

typedef enum TCThreadCreateFlags {} TCThreadCreateFlags;

typedef struct TCThreadCreateInfo {
    /**
     * Reserved. Specify zero.
     */
    TCThreadCreateFlags flags;

    /**
     * The size of the shadow stack associated with the thread, specified in
     * the depth of the call stack.
     */
    uint16_t stackSize;
} TCThreadCreateInfo;

/**
 * Creates a new thread.
 *
 * Creation may fail with the return code `TC_RESULT_ERROR_OUT_OF_MEMORY` due to
 * the following reasons:
 *
 *  - Lack of the shadow stack space. This happens if the sum of `stackSize` of
 *    all created threads reaches a certain threshold.
 *
 *  - Lack of free thread slots. This happens if too many threads were created
 *    before.
 */
TCResult TCCreateThread(TCThreadCreateInfo const *pCreateInfo, TCThread *thread);

/**
 * Transition the system into the lockdown state, preventing the further
 * creation and modification of threads. Further calls to most functions
 * modifying the system configuration (and therefore potentially jeopadizing the
 * control flow integrity) will return `TC_RESULT_ERROR_UNPRIVILEGED`.
 */
TCResult TCLockdown(void);

/**
 * Changes the current thread.
 */
TCResult TCActivateThread(TCThread thread);

#ifdef __cplusplus
};
#endif
