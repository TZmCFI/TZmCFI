// Types (imported from the C header files) and conversion functions for
// TZmCFI's external interface.
const c = @cImport({
    @cInclude("TZmCFI/Gateway.h");
    @cInclude("TZmCFI/PrivateGateway.h");
    @cInclude("TZmCFI/Secure.h");
});

pub const TCResult = c.TCResult;
pub const TCThread = c.TCThread;
pub const TCThreadCreateFlags = c.TCThreadCreateFlags;
pub const TCThreadCreateInfo = c.TCThreadCreateInfo;

pub const TC_RESULT = struct {
    pub const SUCCESS = c.TC_RESULT_SUCCESS;
    pub const ERROR_OUT_OF_MEMORY = c.TC_RESULT_ERROR_OUT_OF_MEMORY;
    pub const ERROR_UNPRIVILEGED = c.TC_RESULT_ERROR_UNPRIVILEGED;
    pub const ERROR_INVALID_ARGUMENT = c.TC_RESULT_ERROR_INVALID_ARGUMENT;
    pub const ERROR_INVALID_OPERATION = c.TC_RESULT_ERROR_INVALID_OPERATION;
};

pub const ThreadCreateFlags = struct {
    pub const None = c.TCThreadCreateFlagsNone;
};
