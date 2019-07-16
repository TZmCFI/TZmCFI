/*
 * Provides the implementation of FreeRTOS's hook functions.
 */
#include "FreeRTOS.h"
#include "task.h"

#include "Main.hpp"
#include <TZmCFI/Gateway.h>

uint32_t SystemCoreClock = 25'000'000;

// In this example application, secure contexts are associated with shadow
// exception stacks.
extern "C" void SecureContext_LoadContext(uint32_t contextId) {
    TCResult result = TCActivateThread((TCThread)contextId);
    if (result != TC_RESULT_SUCCESS) {
        using namespace std::literals;
        TCExample::Panic("TCActivateThread failed"sv);
    }
}
extern "C" void SecureContext_SaveContext() {}
extern "C" void SecureContext_Init() {}
extern "C" void SecureContext_FreeContext(uint32_t context) {
    // Can't delete a thread for now :(
}
extern "C" uint32_t SecureContext_AllocateContext(uint32_t contextId, uint32_t taskPrivileged,
                                                  uintptr_t pc, uintptr_t lr, uintptr_t exc_return,
                                                  uintptr_t frame) {
    (void)taskPrivileged;

    TCThreadCreateInfo createInfo;
    TCResult result;

    createInfo.flags = TCThreadCreateFlagsNone;
    createInfo.stackSize = 4; // unused for now
    createInfo.initialPC = pc;
    createInfo.initialLR = lr;
    createInfo.excReturn = exc_return;
    createInfo.exceptionFrame = frame;

    // Create a TZmCFI thread
    TCThread thread;
    result = TCCreateThread(&createInfo, &thread);

    if (result != TC_RESULT_SUCCESS) {
        using namespace std::literals;
        TCExample::Panic("TCCreateThread failed"sv);
    }

    return (uint32_t)thread;
}
extern "C" void SecureInit_DePrioritizeNSExceptions() {}

/*-----------------------------------------------------------*/

/* Stack overflow hook. */
extern "C" void vApplicationStackOverflowHook(TaskHandle_t xTask, signed char *pcTaskName) {
    /* Force an assert. */
    configASSERT(pcTaskName == 0);
}
/*-----------------------------------------------------------*/

/* configUSE_STATIC_ALLOCATION is set to 1, so the application must provide an
 * implementation of vApplicationGetIdleTaskMemory() to provide the memory that
 * is used by the Idle task. */
extern "C" void vApplicationGetIdleTaskMemory(StaticTask_t **ppxIdleTaskTCBBuffer,
                                              StackType_t **ppxIdleTaskStackBuffer,
                                              uint32_t *pulIdleTaskStackSize) {
    /* If the buffers to be provided to the Idle task are declared inside this
     * function then they must be declared static - otherwise they will be
     * allocated on the stack and so not exists after this function exits. */
    static StaticTask_t xIdleTaskTCB;
    static StackType_t uxIdleTaskStack[configMINIMAL_STACK_SIZE] __attribute__((aligned(32)));

    /* Pass out a pointer to the StaticTask_t structure in which the Idle
     * task's state will be stored. */
    *ppxIdleTaskTCBBuffer = &xIdleTaskTCB;

    /* Pass out the array that will be used as the Idle task's stack. */
    *ppxIdleTaskStackBuffer = uxIdleTaskStack;

    /* Pass out the size of the array pointed to by *ppxIdleTaskStackBuffer.
     * Note that, as the array is necessarily of type StackType_t,
     * configMINIMAL_STACK_SIZE is specified in words, not bytes. */
    *pulIdleTaskStackSize = configMINIMAL_STACK_SIZE;
}
/*-----------------------------------------------------------*/

/* configUSE_STATIC_ALLOCATION and configUSE_TIMERS are both set to 1, so the
 * application must provide an implementation of vApplicationGetTimerTaskMemory()
 * to provide the memory that is used by the Timer service task. */
extern "C" void vApplicationGetTimerTaskMemory(StaticTask_t **ppxTimerTaskTCBBuffer,
                                               StackType_t **ppxTimerTaskStackBuffer,
                                               uint32_t *pulTimerTaskStackSize) {
    /* If the buffers to be provided to the Timer task are declared inside this
     * function then they must be declared static - otherwise they will be
     * allocated on the stack and so not exists after this function exits. */
    static StaticTask_t xTimerTaskTCB;
    static StackType_t uxTimerTaskStack[configTIMER_TASK_STACK_DEPTH] __attribute__((aligned(32)));

    /* Pass out a pointer to the StaticTask_t structure in which the Timer
     * task's state will be stored. */
    *ppxTimerTaskTCBBuffer = &xTimerTaskTCB;

    /* Pass out the array that will be used as the Timer task's stack. */
    *ppxTimerTaskStackBuffer = uxTimerTaskStack;

    /* Pass out the size of the array pointed to by *ppxTimerTaskStackBuffer.
     * Note that, as the array is necessarily of type StackType_t,
     * configTIMER_TASK_STACK_DEPTH is specified in words, not bytes. */
    *pulTimerTaskStackSize = configTIMER_TASK_STACK_DEPTH;
}
/*-----------------------------------------------------------*/
