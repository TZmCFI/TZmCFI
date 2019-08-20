// Types (imported from the C header files) and conversion functions for
// TZmCFI's external interface.
const c = @cImport({
    @cInclude("../../include/TZmCFI/Gateway.h");
    @cInclude("../../include/TZmCFI/PrivateGateway.h");
    @cInclude("../../include/TZmCFI/SecureGateway.h");
});

pub const TCResult = c.TCResult;
pub const TCThread = c.TCThread;
pub const TCThreadCreateFlags = c.TCThreadCreateFlags;
pub const TCThreadCreateInfo = c.TCThreadCreateInfo;
