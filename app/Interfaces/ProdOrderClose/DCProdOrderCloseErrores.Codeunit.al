namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Capacity;

codeunit 55001 "DC Prod. Order. Close Errores" implements "IAPA MADCS Pro. Ord. Close Err"
{
    Permissions =
        tabledata "DC Errores Cierre Orden" = rimd,
        tabledata "Prod. Order Component" = r,
        tabledata "Manufacturing Setup" = r,
        tabledata "Prod. Order Line" = r,
        tabledata "Production Order" = rm,
        tabledata Item = r,
        tabledata "DC Tolerancias Admitidas" = r,
        tabledata "Capacity Ledger Entry" = r;

    /// <summary>
    /// procedure CloseProductionOrder.
    /// Cierra una órden de producción siempre que se cumplan las condiciones necesarias:
    /// </summary>
    /// <param name="ProductionOrder">VAR Record "Production Order".</param>
    /// <param name="pbMostrarError">Boolean.</param>
    procedure APAMADCSCloseProductionOrder(var ProductionOrder: Record "Production Order"; pbMostrarError: Boolean)
    var
        lcuProdOrderStatusManagement: Codeunit "Prod. Order Status Management";
        lenumCierre: Enum "DC Cierre Orden";
        ltxtCierre: array[100] of Text;
        i: Integer;
        ErrorsLbl: Label 'Errors', Comment = 'ESP="Errores"';
    begin
        if not this.CanVerifyCloseOrder(ProductionOrder) then
            exit;

        this.CanCloseOrder(ltxtCierre, i, ProductionOrder);
        if i > 100 then
            i := 100;
        this.LogProductionOrderClose(ProductionOrder, ltxtCierre, i);
        if this.ShouldAbortClose(i, ltxtCierre, lenumCierre) then
            exit;
        if this.ShouldShowCloseErrors(pbMostrarError, i, ltxtCierre, lenumCierre) then
            Message(ErrorsLbl);

        if this.ShouldFinishOrder(ltxtCierre, lenumCierre) then
            this.FinalizeProductionOrder(ProductionOrder, lcuProdOrderStatusManagement);

        Commit(); // Cierra la transacción antes de seguir haciendo más procesos.
        exit;
    end;

    /// <summary>
    /// procedure CanVerifyCloseOrder.
    /// Checks whether basic conditions are met to verify closing a production order.
    /// </summary>
    /// <param name="ProductionOrder">Production order to evaluate.</param>
    /// <returns name="CanVerify">True when the order can be evaluated for closing.</returns>
    local procedure CanVerifyCloseOrder(ProductionOrder: Record "Production Order"): Boolean
    var
        decConsums: Decimal;
        decQuantityExpectedToConsum: Decimal;
        decFinished: Decimal;
        decQuantityExpectedToFinish: Decimal;
        bReleased: Boolean;
        bAllFinished: Boolean;
        bQuantityComplete: Boolean;
    begin
        this.CalcQuantities(ProductionOrder, decConsums, decQuantityExpectedToConsum, decFinished, decQuantityExpectedToFinish);
        bReleased := (ProductionOrder.Status = ProductionOrder.Status::Released);
        bAllFinished := ProductionOrder."APA MADCS Output finished" and ProductionOrder."APA MADCS Time finished" and ProductionOrder."APA MADCS Consumption finished";
        bQuantityComplete := (decFinished = decQuantityExpectedToFinish) or (decConsums = decQuantityExpectedToConsum);
        exit(bReleased and bAllFinished and bQuantityComplete);
    end;

    /// <summary>
    /// Calculates consumed, expected to consume, finished, and expected to finish quantities for a production order.
    /// </summary>
    /// <param name="ProductionOrder"></param>
    /// <param name="QuantityConsumed"></param>
    /// <param name="QuantityExpectedToConsum"></param>
    /// <param name="QuantityFinished"></param>
    /// <param name="QuantityExpectedToFinish"></param>
    local procedure CalcQuantities(ProductionOrder: Record "Production Order"; var QuantityConsumed: Decimal; var QuantityExpectedToConsum: Decimal; var QuantityFinished: Decimal; var QuantityExpectedToFinish: Decimal)
    var
        lrProdOrderComponents: Record "Prod. Order Component";
        lrProdOrderLines: Record "Prod. Order Line";
    begin
        QuantityConsumed := 0;
        QuantityExpectedToConsum := 0;
        QuantityFinished := 0;
        QuantityExpectedToFinish := 0;

        Clear(lrProdOrderLines);
        lrProdOrderLines.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderLines.SetRange(Status, ProductionOrder.Status);
        lrProdOrderLines.SetRange("Prod. Order No.", ProductionOrder."No.");
        lrProdOrderLines.CalcSums("Finished Quantity", Quantity);
        QuantityFinished := lrProdOrderLines."Finished Quantity";
        QuantityExpectedToFinish := lrProdOrderLines.Quantity;

        Clear(lrProdOrderComponents);
        lrProdOrderComponents.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderComponents.SetRange(Status, ProductionOrder.Status);
        lrProdOrderComponents.SetRange("Prod. Order No.", ProductionOrder."No.");
        lrProdOrderComponents.SetAutoCalcFields("Act. Consumption (Qty)");
        if lrProdOrderComponents.FindSet(false) then
            repeat
                QuantityConsumed += lrProdOrderComponents."Act. Consumption (Qty)";
                QuantityExpectedToConsum += lrProdOrderComponents."Expected Quantity";
            until lrProdOrderComponents.Next() = 0;
    end;

    /// <summary>
    /// procedure CanCloseOrder.
    /// Check if it is possible to close the order by evaluating tolerances, consumptions, and activities.
    /// </summary>
    /// <param name="pTextoErrores">Array where error messages are returned.</param>
    /// <param name="i">Index of the last message stored.</param>
    /// <param name="ProductionOrder">Production order under evaluation.</param>
    [TryFunction]
    local procedure CanCloseOrder(var pTextoErrores: array[100] of Text; var i: Integer; ProductionOrder: Record "Production Order")
    var
        lrManufacturingSetup: Record "Manufacturing Setup";
        lrProdOrderLine: Record "Prod. Order Line";
        lrProdOrderComponent: Record "Prod. Order Component";
        APAMADCSManagement: Codeunit "APA MADCS Management";
        lenumCierre: Enum "DC Cierre Orden";
        lbHayLineas: Boolean;
        ManufacturingSetupMissMsg: Label 'Manufacturing Setup Missing', Comment = 'ESP="Falta la configuración de fabricación"';
        ManufacturingSetupErr: Label 'The Manufacturing Setup record is missing. Please set it up before posting consumption.', Comment = 'ESP="Falta el registro de Configuración de Fabricación. Por favor, configúrelo antes de registrar el consumo."';
    begin
        // DAA - Verificar que se cumplen las condiciones necesarias para cerrar la orden
        if not lrManufacturingSetup.Get() then
            APAMADCSManagement.Raise(APAMADCSManagement.BuildApplicationError(ManufacturingSetupMissMsg, ManufacturingSetupErr));

        Clear(pTextoErrores);
        i := 1;

        if this.CheckPendingPicks(ProductionOrder, lrProdOrderComponent) then begin
            pTextoErrores[i] := Format(lenumCierre::"No cerrar");
            exit;
        end;

        lbHayLineas := false;
        Clear(lrProdOrderLine);
        lrProdOrderLine.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderLine.SetRange(Status, ProductionOrder.Status);
        lrProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if lrProdOrderLine.FindSet(false) then begin
            lbHayLineas := true;
            repeat
                this.ValidateProductionOrderLine(lrProdOrderLine, lrProdOrderComponent, ProductionOrder, pTextoErrores, i);
            until lrProdOrderLine.Next() = 0;
        end;

        if not lbHayLineas then begin
            pTextoErrores[i] := Format(lenumCierre::"Faltan lineas");
            i += 1;
        end;

        if i = 1 then
            pTextoErrores[i] := Format(lenumCierre::Correcto);
        exit;
    end;

    /// <summary>
    /// Checks if there are pending picks that block closing.
    /// </summary>
    /// <param name="ProductionOrder">Production order to check.</param>
    /// <param name="ProdOrderComponent">Component recordset for filtering.</param>
    /// <returns name="HasPending">True if pending picks exist.</returns>
    local procedure CheckPendingPicks(ProductionOrder: Record "Production Order"; var ProdOrderComponent: Record "Prod. Order Component") isNotEmpty: Boolean
    begin
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.");
        ProdOrderComponent.SetRange(Status, ProductionOrder.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderComponent.SetFilter("Pick Qty.", '<>%1', 0);
        isNotEmpty := not ProdOrderComponent.IsEmpty();
        ProdOrderComponent.SetRange("Pick Qty.");
        exit(isNotEmpty);
    end;

    /// <summary>
    /// Validates all aspects of a production order line.
    /// </summary>
    /// <param name="ProdOrderLine">Line to validate.</param>
    /// <param name="ProdOrderComponent">Component recordset.</param>
    /// <param name="ProductionOrder">Parent production order.</param>
    /// <param name="ErrorMessages">Error array.</param>
    /// <param name="MessageIndex">Current message index.</param>
    local procedure ValidateProductionOrderLine(ProdOrderLine: Record "Prod. Order Line"; var ProdOrderComponent: Record "Prod. Order Component"; ProductionOrder: Record "Production Order"; var ErrorMessages: array[100] of Text; var MessageIndex: Integer)
    var
        ToleranciaPrep: Decimal;
        ToleranciaEjec: Decimal;
    begin
        this.GetTimeTolerances(ProdOrderLine."Item No.", ToleranciaPrep, ToleranciaEjec);
        this.ValidateComponentsForLine(ProdOrderLine, ProdOrderComponent, ErrorMessages, MessageIndex);
        this.ValidateOutputQuantitiesForLine(ProdOrderLine, ErrorMessages, MessageIndex);
        this.ValidateCapacityTimesForLine(ProdOrderLine, ProductionOrder, ToleranciaPrep, ToleranciaEjec, ErrorMessages, MessageIndex);
    end;

    /// <summary>
    /// Logs close attempt results for a production order, recording all validation messages.
    /// </summary>
    /// <param name="ProductionOrder">Production order being evaluated.</param>
    /// <param name="pTextoErrores">Array of validation messages.</param>
    /// <param name="i">Number of messages recorded.</param>
    local procedure LogProductionOrderClose(ProductionOrder: Record "Production Order"; pTextoErrores: array[10] of Text; i: Integer)
    var
        lrDCErroresCierreOrden: Record "DC Errores Cierre Orden";
        lenumCierre: Enum "DC Cierre Orden";
        j: Integer;
        ltxtMsgOkLbl: Label 'Attempt to close production order %1', Comment = 'ESP="%1 Intento de cierre de orden de producción"';
        ltxtMsgErrorErr: Label '%1 I cannot close the order due to %2', Comment = 'ESP="%1 No puedo cerrar la orden por %2"';
    begin
        Clear(lrDCErroresCierreOrden);
        lrDCErroresCierreOrden.SetCurrentKey(Status, "Production Order No.", "Line No.");
        lrDCErroresCierreOrden.SetRange(Status, ProductionOrder.Status);
        lrDCErroresCierreOrden.SetRange("Production Order No.", ProductionOrder."No.");
        lrDCErroresCierreOrden.DeleteAll(true);
        Commit();  // Cierra la transacción, ya no necesito los mensajes anteriores
        for j := 1 to i - 1 do begin
            Clear(lrDCErroresCierreOrden);
            lrDCErroresCierreOrden.Status := ProductionOrder.Status;
            lrDCErroresCierreOrden."Production Order No." := ProductionOrder."No.";
            lrDCErroresCierreOrden.Validate("Error Date", CurrentDateTime());
            lrDCErroresCierreOrden.Validate("User Id", UserId());
            if (pTextoErrores[j] in [Format(lenumCierre::Correcto)]) then
                lrDCErroresCierreOrden.Validate(Message, StrSubstNo(ltxtMsgOkLbl, Format(CurrentDateTime())))
            else
                lrDCErroresCierreOrden.Validate(Message, StrSubstNo(ltxtMsgErrorErr, Format(CurrentDateTime()), Format(pTextoErrores[j])));
            lrDCErroresCierreOrden.Insert(true);
        end;
    end;

    /// <summary>
    /// Determine if the close operation must be aborted based on the first result entry.
    /// </summary>
    /// <param name="i">Number of messages returned by EsPosibleCerrarOrden.</param>
    /// <param name="ltxtCierre">Result messages.</param>
    /// <param name="lenumCierre">Enum defining close outcomes.</param>
    /// <returns name="ShouldAbort">Boolean.</returns>
    local procedure ShouldAbortClose(i: Integer; ltxtCierre: array[100] of Text; lenumCierre: Enum "DC Cierre Orden"): Boolean
    begin
        exit((i = 1) and (ltxtCierre[1] = Format(lenumCierre::"No cerrar")));
    end;

    /// <summary>
    /// Determine if error messages should be displayed to the user.
    /// </summary>
    /// <param name="pbMostrarError">Flag indicating whether to display errors.</param>
    /// <param name="i">Number of messages returned by EsPosibleCerrarOrden.</param>
    /// <param name="ltxtCierre">Result messages.</param>
    /// <param name="lenumCierre">Enum defining close outcomes.</param>
    /// <returns name="ShouldShow">Boolean.</returns>
    local procedure ShouldShowCloseErrors(pbMostrarError: Boolean; i: Integer; ltxtCierre: array[100] of Text; lenumCierre: Enum "DC Cierre Orden"): Boolean
    begin
        exit(pbMostrarError and ((i <> 1) or (ltxtCierre[i] <> Format(lenumCierre::Correcto))));
    end;

    /// <summary>
    /// Determine if the production order can be finished.
    /// </summary>
    /// <param name="ltxtCierre">Result messages.</param>
    /// <param name="lenumCierre">Enum defining close outcomes.</param>
    /// <returns name="ShouldFinish">Boolean.</returns>
    local procedure ShouldFinishOrder(ltxtCierre: array[100] of Text; lenumCierre: Enum "DC Cierre Orden"): Boolean
    begin
        exit(ltxtCierre[1] = Format(lenumCierre::Correcto));
    end;

    /// <summary>
    /// Finalize the production order by changing its status to Finished.
    /// </summary>
    /// <param name="ProductionOrder">Record Production Order to finalize.</param>
    /// <param name="ProdOrderStatusManagement">Codeunit Prod. Order Status Management reference.</param>
    local procedure FinalizeProductionOrder(var ProductionOrder: Record "Production Order"; var ProdOrderStatusManagement: Codeunit "Prod. Order Status Management")
    begin
        Clear(ProdOrderStatusManagement);
        ProductionOrder.AutoRegistrando := true;
        ProductionOrder.Modify(false);
        ProdOrderStatusManagement.ChangeProdOrderStatus(ProductionOrder, Enum::"Production Order Status"::Finished, WorkDate(), true);
    end;

    /// <summary>
    /// Retrieves time tolerances for setup and execution based on item format and brand settings.
    /// </summary>
    /// <param name="ItemNo">Item number to lookup.</param>
    /// <param name="ToleranciaPreparacionIncial">Setup time tolerance returned.</param>
    /// <param name="ToleranciaEjecucion">Execution time tolerance returned.</param>
    local procedure GetTimeTolerances(ItemNo: Code[20]; var ToleranciaPreparacionIncial: Decimal; var ToleranciaEjecucion: Decimal)
    var
        lrItem: Record Item;
        lrDCToleranciasAdmitidas: Record "DC Tolerancias Admitidas";
    begin
        ToleranciaPreparacionIncial := 0;
        ToleranciaEjecucion := 0;
        if lrItem.Get(ItemNo) then
            if lrDCToleranciasAdmitidas.Get(lrItem.Formato, lrItem.Marca) then begin
                ToleranciaPreparacionIncial := lrDCToleranciasAdmitidas."Toler. Tiempo Limpieza Inicial";
                ToleranciaEjecucion := lrDCToleranciasAdmitidas."Tolerancia Tiempo Fabricacion";
            end;
    end;

    /// <summary>
    /// Retrieves consumption quantity tolerance based on item format and brand settings.
    /// </summary>
    /// <param name="ItemNo">Item number to lookup.</param>
    /// <param name="ToleranciaConsumos">Consumption quantity tolerance returned.</param>
    local procedure GetQuantityTolerances(ItemNo: Code[20]; var ToleranciaConsumos: Decimal)
    var
        lrItem: Record Item;
        lrDCToleranciasAdmitidas: Record "DC Tolerancias Admitidas";
    begin
        ToleranciaConsumos := 0;
        if lrItem.Get(ItemNo) then
            if lrDCToleranciasAdmitidas.Get(lrItem.Formato, lrItem.Marca) then
                ToleranciaConsumos := lrDCToleranciasAdmitidas."Tolerancia Consumo";
    end;

    /// <summary>
    /// Validates component consumption for a production order line.
    /// </summary>
    /// <param name="ProdOrderLine">Line context.</param>
    /// <param name="ProdOrderComponent">Component recordset.</param>
    /// <param name="ErrorMessages">Error array.</param>
    /// <param name="MessageIndex">Current message index.</param>
    local procedure ValidateComponentsForLine(ProdOrderLine: Record "Prod. Order Line"; var ProdOrderComponent: Record "Prod. Order Component"; var ErrorMessages: array[100] of Text; var MessageIndex: Integer)
    var
        CierreEnum: Enum "DC Cierre Orden";
        ToleranciaConsumos: Decimal;
        CantidadFabricada: Decimal;
        CantidadMinima: Decimal;
        CantidadMaxima: Decimal;
        LineaComponentesLbl: Label ' component item %1', Comment = 'ESP=" producto componente %1"';
    begin
        ProdOrderComponent.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
        ProdOrderComponent.SetAutoCalcFields("Act. Consumption (Qty)");
        if ProdOrderComponent.FindSet(false) then
            repeat
                this.GetQuantityTolerances(ProdOrderComponent."Item No.", ToleranciaConsumos);
                CantidadFabricada := ProdOrderComponent."Act. Consumption (Qty)";
                CantidadMinima := ProdOrderComponent."Expected Quantity" - ToleranciaConsumos;
                CantidadMaxima := ProdOrderComponent."Expected Quantity" + ToleranciaConsumos;
                if CantidadFabricada < CantidadMinima then begin
                    ErrorMessages[MessageIndex] := Format(CierreEnum::"Faltan consumos") + StrSubstNo(LineaComponentesLbl, ProdOrderComponent."Item No.");
                    MessageIndex += 1;
                end else
                    if CantidadFabricada > CantidadMaxima then begin
                        ErrorMessages[MessageIndex] := Format(CierreEnum::"Sobran consumos") + StrSubstNo(LineaComponentesLbl, ProdOrderComponent."Item No.");
                        MessageIndex += 1;
                    end;
            until ProdOrderComponent.Next() = 0
        else begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Faltan componentes");
            MessageIndex += 1;
        end;
    end;

    /// <summary>
    /// Validates output quantities for a line.
    /// </summary>
    /// <param name="ProdOrderLine">Line to validate.</param>
    /// <param name="ErrorMessages">Error array.</param>
    /// <param name="MessageIndex">Current message index.</param>
    local procedure ValidateOutputQuantitiesForLine(ProdOrderLine: Record "Prod. Order Line"; var ErrorMessages: array[100] of Text; var MessageIndex: Integer)
    var
        CierreEnum: Enum "DC Cierre Orden";
    begin
        if ProdOrderLine."Remaining Quantity" <> 0 then begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Faltan salidas");
            MessageIndex += 1;
        end;
        if ProdOrderLine."Finished Quantity" > ProdOrderLine.Quantity then begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Sobran salidas");
            MessageIndex += 1;
        end;
    end;

    /// <summary>
    /// Validates capacity times against tolerances.
    /// </summary>
    /// <param name="ProdOrderLine">Line context.</param>
    /// <param name="ProductionOrder">Parent order.</param>
    /// <param name="ToleranciaPrep">Setup tolerance.</param>
    /// <param name="ToleranciaEjec">Run tolerance.</param>
    /// <param name="ErrorMessages">Error array.</param>
    /// <param name="MessageIndex">Current message index.</param>
    local procedure ValidateCapacityTimesForLine(ProdOrderLine: Record "Prod. Order Line"; ProductionOrder: Record "Production Order"; ToleranciaPrep: Decimal; ToleranciaEjec: Decimal; var ErrorMessages: array[100] of Text; var MessageIndex: Integer)
    var
        CapacityLedgerEntry: Record "Capacity Ledger Entry";
        CierreEnum: Enum "DC Cierre Orden";
        TiempoLimpieza: Decimal;
        TiempoProduccion: Decimal;
    begin
        TiempoLimpieza := 0;
        TiempoProduccion := 0;
        Clear(CapacityLedgerEntry);
        CapacityLedgerEntry.SetCurrentKey("Order Type", "Order No.", "Item No.", "Starting Time");
        CapacityLedgerEntry.SetRange("Order Type", CapacityLedgerEntry."Order Type"::Production);
        CapacityLedgerEntry.SetRange("Order No.", ProductionOrder."No.");
        CapacityLedgerEntry.SetRange("Item No.", ProdOrderLine."Item No.");
        if CapacityLedgerEntry.FindSet(false) then
            repeat
                TiempoLimpieza += CapacityLedgerEntry."Setup Time";
                TiempoProduccion += CapacityLedgerEntry."Run Time";
            until CapacityLedgerEntry.Next() = 0
        else begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Falta limpieza");
            MessageIndex += 1;
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Falta fabricacion");
            MessageIndex += 1;
        end;

        if TiempoLimpieza = 0 then begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Falta limpieza");
            MessageIndex += 1;
        end;
        if TiempoProduccion = 0 then begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Falta fabricacion");
            MessageIndex += 1;
        end;

        if (TiempoLimpieza <> 0) and (TiempoProduccion <> 0) then
            this.CompareTimesWithTolerances(ProdOrderLine, ProductionOrder, TiempoLimpieza, TiempoProduccion, ToleranciaPrep, ToleranciaEjec, ErrorMessages, MessageIndex);
    end;

    /// <summary>
    /// Compares actual times with expected times and tolerances.
    /// </summary>
    /// <param name="ProdOrderLine">Line context.</param>
    /// <param name="ProductionOrder">Parent order.</param>
    /// <param name="ActualSetup">Actual setup time.</param>
    /// <param name="ActualRun">Actual run time.</param>
    /// <param name="ToleranciaPrep">Setup tolerance.</param>
    /// <param name="ToleranciaEjec">Run tolerance.</param>
    /// <param name="ErrorMessages">Error array.</param>
    /// <param name="MessageIndex">Current message index.</param>
    local procedure CompareTimesWithTolerances(ProdOrderLine: Record "Prod. Order Line"; ProductionOrder: Record "Production Order"; ActualSetup: Decimal; ActualRun: Decimal; ToleranciaPrep: Decimal; ToleranciaEjec: Decimal; var ErrorMessages: array[100] of Text; var MessageIndex: Integer)
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        CierreEnum: Enum "DC Cierre Orden";
    begin
        Clear(ProdOrderRoutingLine);
        ProdOrderRoutingLine.SetCurrentKey(Status, "Prod. Order No.", "Routing Reference No.");
        ProdOrderRoutingLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Line No.");
        ProdOrderRoutingLine.CalcSums("Setup Time");
        if ProdOrderRoutingLine."Setup Time" < (ActualSetup - ToleranciaPrep) then begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Sobra limpieza");
            MessageIndex += 1;
        end else
            if ProdOrderRoutingLine."Setup Time" > (ActualSetup + ToleranciaPrep) then begin
                ErrorMessages[MessageIndex] := Format(CierreEnum::"Falta limpieza");
                MessageIndex += 1;
            end;
        ProdOrderRoutingLine.CalcSums("Run Time");
        if (ProdOrderRoutingLine."Run Time" * ProdOrderLine.Quantity) < (ActualRun - ToleranciaEjec) then begin
            ErrorMessages[MessageIndex] := Format(CierreEnum::"Sobra fabricacion");
            MessageIndex += 1;
        end else
            if (ProdOrderRoutingLine."Run Time" * ProdOrderLine.Quantity) > (ActualRun + ToleranciaEjec) then begin
                ErrorMessages[MessageIndex] := Format(CierreEnum::"Falta fabricacion");
                MessageIndex += 1;
            end;
    end;
}
