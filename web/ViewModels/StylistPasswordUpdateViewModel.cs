// ============================================================
// PROJECT: Cutting Edge Salon
// STUDENT DETAILS:
// ------------------------------------------------------------
// Name                  | Student Number
// ------------------------------------------------------------
// Goitse Kgwele         | 221050663
// Thabang Zitha         | 223007074
// Yamkela Mazamani      | 224007421
// Nyakallo Pali         | 223060226
// Bennet Linda          | 224004294
// ============================================================

using System.ComponentModel.DataAnnotations;

namespace CuttingEdge.ManagerPortal.ViewModels;
// Form model for the "reset stylist password" dialog, with data-annotation
// validation for the new password and its confirmation.

public sealed class StylistPasswordUpdateViewModel
{

    // New password chosen by the manager. Range enforced by [StringLength].
    [Required(ErrorMessage = "Enter a new password.")]
    [StringLength(128, MinimumLength = 8, ErrorMessage = "Use a password between 8 and 128 characters.")]
    [DataType(DataType.Password)]
    public string NewPassword { get; set; } = string.Empty;


    // Confirmation field; must equal NewPassword (checked by [Compare]).
    [Required(ErrorMessage = "Confirm the new password.")]
    [Compare(nameof(NewPassword), ErrorMessage = "The two passwords do not match.")]
    [DataType(DataType.Password)]
    public string ConfirmPassword { get; set; } = string.Empty;
}
