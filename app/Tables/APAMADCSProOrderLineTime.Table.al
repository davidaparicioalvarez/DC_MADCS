namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Pro. Order Line Time
/// Table to log time entries for production order lines in the MADCS system.
/// </summary>
table 55001 "APA MADCS Pro. Order Line Time"
{
    Caption = 'Production Order Line Time', Comment = 'ESP="Tiempo Línea Orden de Producción"';
    Extensible = true;
    LookupPageId = "APA MADCS Time Part";
    DrillDownPageId = "APA MADCS Time Part";
    DataClassification = SystemMetadata;
    Permissions =
        tabledata "Prod. Order Line" = r,
        tabledata "APA MADCS Pro. Order Line Time" = rmid,
        tabledata "Prod. Order Routing Line" = r,
        tabledata "DC Detalles de paro" = r,
        tabledata "Production Order" = r;

    fields
    {
        field(1; Status; Enum "Production Order Status")
        {
            Caption = 'Status', Comment = 'ESP="Estado"';
            ToolTip = 'Specifies the status of the production order line.', Comment = 'ESP="Especifica el estado de la línea de orden de producción."';
        }
        field(2; "Prod. Order No."; Code[20])
        {
            Caption = 'Prod. Order No.', Comment = 'ESP="Nº Orden de Producción"';
            ToolTip = 'Specifies the production order number.', Comment = 'ESP="Especifica el número de orden de producción."';
        }
        field(3; "Prod. Order Line No."; Integer)
        {
            Caption = 'Prod. Order Line No.', Comment = 'ESP="Nº Línea Orden de Producción"';
            ToolTip = 'Specifies the line number of the production order.', Comment = 'ESP="Especifica el número de línea de la orden de producción."';
        }
        field(4; "Line No."; Integer)
        {
            Caption = 'Line No.', Comment = 'ESP="Nº Línea"';
            ToolTip = 'Specifies the line number.', Comment = 'ESP="Especifica el número de línea."';
        }
        field(5; "Operation No."; Code[10])
        {
            Caption = 'Operation No.', Comment = 'ESP="Nº Operación"';
            ToolTip = 'Specifies the operation number of the production order line.', Comment = 'ESP="Especifica el número de operación de la línea de orden de producción."';
        }
        field(6; "Operator Code"; Code[20])
        {
            Caption = 'Operator Code', Comment = 'ESP="Código de Operario"';
            ToolTip = 'Specifies the operator code.', Comment = 'ESP="Especifica el código de operario."';
        }
        field(7; "Action"; Enum "APA MADCS Journal Type")
        {
            Caption = 'Action', Comment = 'ESP="Acción"';
            ToolTip = 'Specifies the action type.', Comment = 'ESP="Especifica el tipo de acción."';
        }
        field(8; "Start Date Time"; DateTime)
        {
            Caption = 'Start Date Time', Comment = 'ESP="Fecha y Hora de Inicio"';
            ToolTip = 'Specifies the start date and time of the time entry.', Comment = 'ESP="Especifica la fecha y hora de inicio de la entrada de tiempo."';
        }
        field(9; "End Date Time"; DateTime)
        {
            Caption = 'End Date Time', Comment = 'ESP="Fecha y Hora de Fin"';
            ToolTip = 'Specifies the end date and time of the time entry.', Comment = 'ESP="Especifica la fecha y hora de fin de la entrada de tiempo."';
        }
        field(10; "BreakDown Code"; Code[20])
        {
            Caption = 'BreakDown Code', Comment = 'ESP="Código de Paro"';
            ToolTip = 'Specifies the code of the breakdown.', Comment = 'ESP="Especifica el código de paro."';
            TableRelation = "DC Detalles de paro".Code;
        }
        field(11; Posted; Boolean)
        {
            Caption = 'Posted', Comment = 'ESP="Registrada"';
            ToolTip = 'Indicates whether the time entry has been posted.', Comment = 'ESP="Indica si la entrada de tiempo ha sido registrada."';
            AllowInCustomizations = Always;
        }
    }
    keys
    {
        key(PK; Status, "Prod. Order No.", "Prod. Order Line No.", "Line No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Prod. Order No.", "Prod. Order Line No.", "Line No.", "Operator Code", "Action", "Start Date Time", "BreakDown Code")
        {
        }
        fieldgroup(Brick; Status, "Prod. Order No.", "Prod. Order Line No.", "Line No.", "Operator Code", "Action", "Start Date Time", "BreakDown Code")
        {
        }
    }

    var
        PreparationDescriptionLbl: Label 'Preparation Phase', Comment = 'ESP="Fase de Preparación"';
        ExecutionDescriptionLbl: Label 'Execution Phase', Comment = 'ESP="Fase de Ejecución"';
        ExecutionWithFaultDescriptionLbl: Label 'Execution with Fault', Comment = 'ESP="Ejecución con Avería"';
        CleanDescriptionLbl: Label 'Cleaning Phase', Comment = 'ESP="Fase de Limpieza"';
        FaultDescriptionLbl: Label 'Fault Occurred', Comment = 'ESP="Se produjo una avería"';

    /// <summary>
    /// procedure ItemNo
    /// Gets the item number associated with the production order line.
    /// </summary>
    /// <returns></returns>
    procedure ItemNo(): Code[20]
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        if ProdOrderLine.Get(Status, "Prod. Order No.", "Prod. Order Line No.") then
            exit(ProdOrderLine."Item No.")
        else
            exit('');
    end;

    /// <summary>
    /// procedure Description
    /// Gets the description based on the action type.
    /// </summary>
    /// <returns></returns>
    procedure Description(): Text[100]
    begin
        case Rec.Action of
            "APA MADCS Journal Type"::Preparation:
                exit(CopyStr(PreparationDescriptionLbl, 1, 100));
            "APA MADCS Journal Type"::Cleaning:
                exit(CopyStr(CleanDescriptionLbl, 1, 100));
            "APA MADCS Journal Type"::Execution:
                exit(CopyStr(ExecutionDescriptionLbl, 1, 100));
            "APA MADCS Journal Type"::"Execution with Fault":
                exit(CopyStr(ExecutionWithFaultDescriptionLbl, 1, 100));
            "APA MADCS Journal Type"::Fault:
                exit(CopyStr(FaultDescriptionLbl, 1, 100));
        end;
    end;

    /// <summary>
    /// internal procedure NewPreparationActivity
    /// Creates a new preparation activity based on the button ID for preparation.
    /// </summary>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrderCode"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    internal procedure NewPreparationActivity(pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    begin
        this.CreateNewActivity(pProdOrderStatus, pProdOrderCode, pProdOrderLine, OperatorCode, Enum::"APA MADCS Journal Type"::Preparation, BreakDownCode);
    end;

    /// <summary>
    /// internal procedure NewCleaningActivity
    /// Creates a new cleaning activity based on the button ID for cleaning.
    /// </summary>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrderCode"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    internal procedure NewCleaningActivity(pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        CleanCannotStartTitleLbl: Label 'Cleaning Phase Cannot Start', Comment = 'ESP="La fase de limpieza no puede iniciarse"';
        CleanCannotStartErr: Label 'The cleaning phase cannot be started because the execution phase has not been completed yet.', Comment = 'ESP="La fase de limpieza no puede iniciarse porque la fase de ejecución no se ha completado aún."';
    begin
        if APAMADCSManagement.CleanCanStart(pProdOrderStatus, pProdOrderCode) then
            this.CreateNewActivity(pProdOrderStatus, pProdOrderCode, pProdOrderLine, OperatorCode, Enum::"APA MADCS Journal Type"::Cleaning, BreakDownCode)
        else
            APAMADCSManagement.Raise(APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("Action"), CleanCannotStartTitleLbl, CleanCannotStartErr));
    end;

    /// <summary>
    /// internal procedure NewExecutionActivity
    /// Creates a new fault activity based on the button ID for execution.
    /// </summary>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrderCode"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    internal procedure NewExecutionActivity(pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        ProductionOrder: Record "Production Order";
        APAMADCSManagement: Codeunit "APA MADCS Management";
        ExecutionCannotStartTitleLbl: Label 'Execution Phase Cannot Start', Comment = 'ESP="La fase de ejecución no puede iniciarse"';
        ExecutionCannotStartErr: Label 'The execution phase cannot be started because consumptions or outputs have been finished.', Comment = 'ESP="La fase de ejecución no puede iniciarse porque los consumos o las salidas se han finalizado."';
    begin
        if APAMADCSManagement.ExecutionCanStart(pProdOrderStatus, pProdOrderCode) then
            this.CreateNewActivity(pProdOrderStatus, pProdOrderCode, pProdOrderLine, OperatorCode, Enum::"APA MADCS Journal Type"::Execution, BreakDownCode)
        else begin
            if not ProductionOrder.Get(pProdOrderStatus, pProdOrderCode) then
                APAMADCSManagement.Raise(APAMADCSManagement.BuildApplicationError(ExecutionCannotStartTitleLbl, ExecutionCannotStartErr));
            APAMADCSManagement.Raise(APAMADCSManagement.BuildApplicationError(ExecutionCannotStartTitleLbl, ExecutionCannotStartErr));
        end;
    end;

    /// <summary>
    /// internal procedure NewFaultActivity
    /// Creates a new fault activity based on the button ID for breakdown or execution with fault.
    /// </summary>
    /// <param name="id"></param>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrderCode"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    internal procedure NewFaultActivity(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        AlertBlockedFaultMsg: Label 'The breakdown code %1 is blocking. A fault activity will be created instead of a execution with fault activity.', Comment = 'ESP="El código de paro %1 es bloqueante. Se creará una actividad de avería en lugar de una actividad de ejecución con avería."';
        AlertNotBlockedFaultMsg: Label 'The breakdown code %1 is not blocking. A fault activity will be created instead of a execution with fault activity.', Comment = 'ESP="El código de paro %1 es bloqueante. Se creará una actividad de ejecución con avería en lugar de una actividad de avería."';
    begin
        if (id = Format(Enum::"APA MADCS Buttons"::ALButtonBlockedBreakdownTok)) then begin
            if not this.BreakDownCodeIsBlocking(BreakDownCode) then
                Message(AlertNotBlockedFaultMsg, BreakDownCode);
            this.CreateNewActivity(pProdOrderStatus, pProdOrderCode, pProdOrderLine, OperatorCode, Enum::"APA MADCS Journal Type"::Fault, BreakDownCode)
        end else
            if this.BreakDownCodeIsBlocking(BreakDownCode) then begin
                Message(AlertBlockedFaultMsg, BreakDownCode);
                this.CreateNewActivity(pProdOrderStatus, pProdOrderCode, pProdOrderLine, OperatorCode, Enum::"APA MADCS Journal Type"::Fault, BreakDownCode);
            end else
                this.CreateNewActivity(pProdOrderStatus, pProdOrderCode, pProdOrderLine, OperatorCode, Enum::"APA MADCS Journal Type"::"Execution with Fault", BreakDownCode);
    end;

    /// <summary>
    /// internal procedure MinutesUsed
    /// Calculates the total minutes used between the start and end date times.
    /// </summary>
    /// <returns></returns>
    internal procedure MinutesUsed() Hours: Decimal
    var
        Duration: Decimal;
    begin
        if Rec."End Date Time" = 0DT then
            Duration := 0
        else
            Duration := Rec."End Date Time" - Rec."Start Date Time";

        Hours := Duration / 1000 / 60 / 60;
        exit(Hours);
    end;

    /// <summary>
    /// internal procedure GetLastLineNo
    /// Gets the last line number for a given production order status, code, and line.
    /// </summary>
    /// <param name="pStatus"></param>
    /// <param name="pProdOrderCode"></param>
    /// <param name="pProdOrderLine"></param>
    /// <returns></returns>
    internal procedure GetLastLineNo(pStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]; pProdOrderLine: Integer): Integer
    var
        MADCSProOrderLineTime: Record "APA MADCS Pro. Order Line Time";
    begin
        Clear(MADCSProOrderLineTime);
        MADCSProOrderLineTime.SetRange(Status, pStatus);
        MADCSProOrderLineTime.SetRange("Prod. Order No.", pProdOrderCode);
        MADCSProOrderLineTime.SetRange("Prod. Order Line No.", pProdOrderLine);
        if MADCSProOrderLineTime.FindLast() then
            exit(MADCSProOrderLineTime."Line No.")
        else
            exit(0);
    end;

    /// <summary>
    /// internal procedure FindOperationNo
    /// Gets the operation number for the production order routing line that matches the journal type.
    /// </summary>
    /// <param name="APAMADCSJournalType">Enum "APA MADCS Journal Type"</param>
    /// <returns>Code[10]</returns>
    internal procedure FindOperationNo(APAMADCSJournalType: Enum MADCS.MADCS."APA MADCS Journal Type"): Code[10]
    var
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
    begin
        this.GetProdOrderLine(ProdOrderLine);
        this.InitProdOrderRoutingLine(ProdOrderRoutingLine, ProdOrderLine);

        if this.IsCleanJournalType(APAMADCSJournalType) then
            this.EnsureCleanOperation(ProdOrderRoutingLine, APAMADCSJournalType)
        else
            if this.IsPreparationJournalType(APAMADCSJournalType) then
                this.EnsurePreparationOperation(ProdOrderRoutingLine, APAMADCSJournalType)
            else
                this.EnsureExecutionFailOperation(ProdOrderRoutingLine, APAMADCSJournalType);

        exit(ProdOrderRoutingLine."Operation No.");
    end;

    /// <summary>
    /// internal procedure GetStopCode
    /// Gets the stop code from the breakdown code.
    /// </summary>
    /// <param name="BreakDownCode"></param>
    /// <returns></returns>
    internal procedure GetStopCode(BreakDownCode: Code[20]): Code[10]
    var
        DCDetallesDeParo: Record "DC Detalles de paro";
    begin
        Clear(DCDetallesDeParo);
        DCDetallesDeParo.SetCurrentKey("Stop Code", Code);
        DCDetallesDeParo.SetRange(Code, BreakDownCode);
        if DCDetallesDeParo.FindFirst() then
            exit(CopyStr(DCDetallesDeParo."Stop Code", 1, 10))
        else
            exit('');
    end;

    /// <summary>
    /// internal procedure BreakDownCodeIsBlocking
    /// Checks if the breakdown code is blocking.
    /// </summary>
    /// <param name="BreakDownCode"></param>
    /// <returns></returns>
    internal procedure BreakDownCodeIsBlocking(BreakDownCode: Code[20]): Boolean
    var
        DCDetallesDeParo: Record "DC Detalles de paro";
    begin
        Clear(DCDetallesDeParo);
        DCDetallesDeParo.SetCurrentKey("Stop Code", Code);
        DCDetallesDeParo.SetRange(Code, BreakDownCode);
        if DCDetallesDeParo.FindFirst() then
            exit(DCDetallesDeParo.Disabling)
        else
            exit(false);
    end;

    local procedure GetProdOrderLine(var ProdOrderLine: Record "Prod. Order Line")
    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        TittleMsgLbl: Label 'Error Looking for Operation No.', Comment = 'ESP="Error al buscar el Nº de Operación."';
        MessageMsgLbl: Label 'The operation number could not be found for the production order line.', Comment = 'ESP="No se pudo encontrar el número de operación para la línea de orden de producción."';
    begin
        Clear(ProdOrderLine);
        if not ProdOrderLine.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.") then
            APAMADCSManagement.Raise(APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("Operation No."), TittleMsgLbl, MessageMsgLbl));
    end;

    local procedure InitProdOrderRoutingLine(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; ProdOrderLine: Record "Prod. Order Line")
    begin
        Clear(ProdOrderRoutingLine);
        ProdOrderRoutingLine.SetCurrentKey(Status, "Prod. Order No.", "Routing Reference No.", "Routing No.");
        ProdOrderRoutingLine.SetRange(Status, Rec.Status);
        ProdOrderRoutingLine.SetRange("Routing Reference No.", Rec."Prod. Order Line No.");
        ProdOrderRoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
    end;

    local procedure IsPreparationJournalType(APAMADCSJournalType: Enum MADCS.MADCS."APA MADCS Journal Type"): Boolean
    begin
        exit(APAMADCSJournalType in [Enum::"APA MADCS Journal Type"::Preparation]);
    end;

    local procedure IsCleanJournalType(APAMADCSJournalType: Enum MADCS.MADCS."APA MADCS Journal Type"): Boolean
    begin
        exit(APAMADCSJournalType in [Enum::"APA MADCS Journal Type"::Cleaning]);
    end;

    local procedure EnsureCleanOperation(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; APAMADCSJournalType: Enum "APA MADCS Journal Type")
    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        TittleMsgLbl: Label 'Error Looking for Operation No.', Comment = 'ESP="Error al buscar el Nº de Operación."';
        CleanNotFoundMsgLbl: Label 'No cleaning operation found for the production order line.', Comment = 'ESP="No se encontró ninguna operación de limpieza para la línea de orden de producción."';
    begin
        ProdOrderRoutingLine.SetFilter("Setup Time", '<>%1', 0);
        ProdOrderRoutingLine.SetFilter("Operation No.", '%1', APAMADCSManagement.GetManufacturingSetupTaskData(APAMADCSJournalType));

        if not ProdOrderRoutingLine.FindLast() then
            APAMADCSManagement.Raise(APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("Operation No."), TittleMsgLbl, CleanNotFoundMsgLbl));
    end;

    local procedure EnsurePreparationOperation(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; APAMADCSJournalType: Enum "APA MADCS Journal Type")
    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        TittleMsgLbl: Label 'Error Looking for Operation No.', Comment = 'ESP="Error al buscar el Nº de Operación."';
        MessageMsgLbl: Label 'The operation number could not be found for the production order line.', Comment = 'ESP="No se pudo encontrar el número de operación para la línea de orden de producción."';
    begin
        ProdOrderRoutingLine.SetFilter("Setup Time", '<>%1', 0);
        ProdOrderRoutingLine.SetFilter("Operation No.", '%1', APAMADCSManagement.GetManufacturingSetupTaskData(APAMADCSJournalType));

        if not ProdOrderRoutingLine.FindFirst() then
            APAMADCSManagement.Raise(APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("Operation No."), TittleMsgLbl, MessageMsgLbl));
    end;

    local procedure EnsureExecutionFailOperation(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; APAMADCSJournalType: Enum "APA MADCS Journal Type")
    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        TittleMsgLbl: Label 'Error Looking for Operation No.', Comment = 'ESP="Error al buscar el Nº de Operación."';
        MessageMsgLbl: Label 'The operation number could not be found for the production order line.', Comment = 'ESP="No se pudo encontrar el número de operación para la línea de orden de producción."';
    begin
        ProdOrderRoutingLine.SetFilter("Run Time", '<>%1', 0);
        ProdOrderRoutingLine.SetFilter("Operation No.", '%1', APAMADCSManagement.GetManufacturingSetupTaskData(APAMADCSJournalType));

        if not ProdOrderRoutingLine.FindFirst() then
            APAMADCSManagement.Raise(APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("Operation No."), TittleMsgLbl, MessageMsgLbl));
    end;

    local procedure CreateNewActivity(pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; ActionType: Enum "APA MADCS Journal Type"; BreakDownCode: Code[20])
    var
        NewActivity: Record "APA MADCS Pro. Order Line Time";
    begin
        Clear(NewActivity);
        NewActivity.Status := pProdOrderStatus;
        NewActivity."Prod. Order No." := pProdOrderCode;
        NewActivity."Prod. Order Line No." := pProdOrderLine;
        NewActivity."Line No." := Rec.GetLastLineNo(pProdOrderStatus, pProdOrderCode, pProdOrderLine) + 1;
        NewActivity."Operation No." := NewActivity.FindOperationNo(ActionType);
        NewActivity."Operator Code" := OperatorCode;
        NewActivity."Action" := ActionType;
        NewActivity."Start Date Time" := CurrentDateTime();
        NewActivity."BreakDown Code" := BreakDownCode;
        NewActivity.Insert(true);
    end;
}
