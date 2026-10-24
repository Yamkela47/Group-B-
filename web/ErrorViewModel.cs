
// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

namespace CuttingEdge.ManagerPortal.Models;
/// <summary>
/// Backing model for the shared error page. Exposes the request ID
/// so support can correlate the error with server logs.
/// </summary>
public class ErrorViewModel
{
    // ASP.NET Core trace/request ID for correlating with logs.
    public string? RequestId { get; set; }

    // Only show the request ID when one was actually captured.
    public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);
}