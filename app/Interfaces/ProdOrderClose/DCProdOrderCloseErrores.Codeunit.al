namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

codeunit 55001 "DC Prod. Order. Close Errores" implements "IAPA MADCS Pro. Ord. Close Err"
{

    /// <summary>
    /// procedure APAMADCSCloseProductionOrder
    /// Cierra la orden de producción segun algoritmo de DC, si se produce un error se muestra un mensaje con el error.
    /// </summary>
    /// <param name="ProductionOrder"></param>
    /// <param name="pbMostrarError"></param>
    procedure APAMADCSCloseProductionOrder(var ProductionOrder: Record "Production Order"; pbMostrarError: Boolean)
    var
        lrDCSupportFunctions: Codeunit "DC Support Functions";
    begin
        lrDCSupportFunctions.CerrarOrdenProduccion(ProductionOrder, pbMostrarError)
    end;
}
