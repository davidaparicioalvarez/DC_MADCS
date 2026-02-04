namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// interface APA MADCS Pro. Ord. Close Err.
/// Interface for store errors when closing orders in APA MADCS
/// </summary>
interface "IAPA MADCS Pro. Ord. Close Err"
{
    /// <summary>
    /// procedure CloseProductionOrder.
    /// Cierra una órden de producción siempre que se cumplan las condiciones necesarias:
    /// </summary>
    /// <param name="ProductionOrder">VAR Record "Production Order".</param>
    /// <param name="pbMostrarError">Boolean.</param>
    procedure APAMADCSCloseProductionOrder(var ProductionOrder: Record "Production Order"; pbMostrarError: Boolean)
}
