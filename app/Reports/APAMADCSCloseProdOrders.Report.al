/// <summary>
/// Report Cerrar Ordenes Produccion (ID 55000).
/// </summary>
report 55000 "APA MADCS Close Prod. Orders"
{
    Caption = 'MADCS Close Prod. Orders', Comment = 'ESP="Cerrar órdenes de producción MADCS"';
    ProcessingOnly = true;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Permissions = tabledata "Production Order" = r;

    dataset
    {
        dataitem(Integer; Integer)
        {
            MaxIteration = 1;

            trigger OnAfterGetRecord()
            var
                lrProductionOrder: Record "Production Order";
                lrProductionOrderToClose: Record "Production Order";
                IAPAMADCSProOrdCloseErr: Interface "IAPA MADCS Pro. Ord. Close Err";
                ldlgDialogo: Dialog;
                ltxtTextoErrores: array[1] of Text;
                SpecialErrorErr: Label 'ATTENTION: %1 There is some unusual error in the order, check the directories, components and paths',
                        Comment = 'ESP="ATENCIÓN: %1 Hay algún error inusual en la orden, revise los directorios, los componentes y las rutas"';
                ProcessingMsg: Label 'Processing: #1##################', Comment = 'ESP="Procesando: #1##################"';
            begin
                if GuiAllowed() then
                    ldlgDialogo.Open(ProcessingMsg);
                Clear(lrProductionOrder);
                lrProductionOrder.SetCurrentKey(Status, "No.");
                lrProductionOrder.SetRange(Status, lrProductionOrder.Status::Released);
                if lrProductionOrder.FindSet(false) then
                    repeat
                        if GuiAllowed() then
                            ldlgDialogo.Update(1, lrProductionOrder."No.");
                        ltxtTextoErrores[1] := SpecialErrorErr;
                        lrProductionOrderToClose := lrProductionOrder;
                        IAPAMADCSProOrdCloseErr.APAMADCSCloseProductionOrder(lrProductionOrderToClose, false);
                    until lrProductionOrder.Next() = 0;
                if GuiAllowed() then
                    ldlgDialogo.Close();
            end;
        }
    }
}