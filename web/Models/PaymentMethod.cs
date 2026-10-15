namespace CuttingEdge.ManagerPortal.Models;

public class PaymentMethod
{
    public Guid PaymentMethodId { get; set; }
    public string MethodName { get; set; } = string.Empty;
}
