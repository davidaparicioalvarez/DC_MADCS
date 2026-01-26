namespace MADCS.MADCS;

using Microsoft.Warehouse.ADCS;
using Microsoft.Inventory.Posting;
using Microsoft.Manufacturing.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Foundation.Navigate;

/// <summary>
/// APA MADCS Posting Management
/// Codeunit to handle posting of consumptions and outputs, and log all user actions.
/// </summary>
codeunit 55000 "APA MADCS Management"
{
    SingleInstance = true;
    Permissions =
        tabledata "APA MADCS User Log" = i,
        tabledata "ADCS User" = r,
        tabledata Item = r,
        tabledata Location = r,
        tabledata "Item Variant" = r,
        tabledata "Prod. Order Component" = r,
        tabledata "Production Order" = rm,
        tabledata "Manufacturing Setup" = r,
        tabledata "Item Journal Template" = r,
        tabledata "Item Journal Batch" = r,
        tabledata "Item Journal Line" = i,
        tabledata "Prod. Order Line" = r,
        tabledata "Prod. Order Routing Line" = r,
        tabledata "Reservation Entry" = rmd,
        tabledata "APA MADCS Pro. Order Line Time" = rmid,
        tabledata "Item Tracking Code" = r,
        tabledata "Capacity Ledger Entry" = r,
        tabledata "DC Errores Cierre Orden" = rmid,
        tabledata "DC Tolerancias Admitidas" = r;

    var
        CurrentOperatorCode: Code[20];
        Logged: Boolean;
        ManufacturingSetupMissMsg: Label 'Manufacturing Setup Missing', Comment = 'ESP="Falta la configuración de fabricación"';
        ManufacturingSetupErr: Label 'The Manufacturing Setup record is missing. Please set it up before posting consumption.', Comment = 'ESP="Falta el registro de Configuración de Fabricación. Por favor, configúrelo antes de registrar el consumo."';

    #region procedures
    /// <summary>
    /// procedure LogInOperator
    /// Logs in the operator for time tracking purposes.
    /// Displays the APA MADCS Operator Login page, validates credentials against ADCS users, and stores the operator code.
    /// </summary>
    /// <returns name="">Boolean indicating if login was successful.</returns>
    procedure LogInOperator(): Boolean
    var
        ADCSUser: Record "ADCS User";
        OperatorLoginPage: Page "APA MADCS Operator Login";
        OperatorCode: Code[20];
        Password: Text;
        UserNotFoundMsg: Label 'Operator %1 not found in ADCS users.', Comment = 'ESP="El operador %1 no se encuentra en los usuarios ADCS."';
    begin
        if this.Logged then
            exit(true);

        // Display the operator login page
        if OperatorLoginPage.RunModal() <> Action::OK then
            exit(false);

        // Get the entered credentials from the page
        OperatorCode := OperatorLoginPage.GetOperatorCode();
        Password := OperatorLoginPage.GetPassword();

        // Validate input is not empty
        if OperatorCode = '' then
            exit(false);

        if Password = '' then
            exit(false);

        // Validate operator code exists in ADCS User table
        Clear(ADCSUser);
        if not ADCSUser.Get(OperatorCode) then begin
            Message(UserNotFoundMsg, OperatorCode);
            exit(false);
        end;

        // Validate password
        if ADCSUser."APA MADCS Password" <> Password then begin
            Message(UserNotFoundMsg, OperatorCode);
            exit(false);
        end;

        // Store operator code globally
        this.SetOperatorCode(OperatorCode);
        exit(true);
    end;

    /// <summary>
    /// procedure GetOperatorCode
    /// Gets the current operator code for logging purposes.
    /// </summary>
    /// <returns></returns>
    procedure GetOperatorCode(): Code[20]
    begin
        if not this.Logged then
            if not this.LogInOperator() then
                exit('');
        exit(this.CurrentOperatorCode);
    end;

    /// <summary>
    /// Posts component consumption for a production order component line and logs the action.
    /// </summary>
    /// <param name="ProdOrderComp">Record "Prod. Order Component"</param>
    /// <param name="Quantity">Decimal quantity to consume</param>
    /// <param name="LotNo">Code[50] Lot number for tracked items</param>
    procedure PostQuantityLotComponentConsumption(var ProdOrderComp: Record "Prod. Order Component"; Quantity: Decimal; LotNo: Code[50])
    var
        Item: Record Item;
        ItemJnlLine: Record "Item Journal Line";
        ManufacturingSetup: Record "Manufacturing Setup";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        PostItemJnlLine: Codeunit "Item Jnl.-Post Line";
        ErrNoPermissionPostConsumptionMsg: Label 'Permissions Error.', Comment = 'ESP="Error de permisos."';
        ErrNoPermissionPostConsumptionErr: Label 'You do not have permission to post consumptions.', Comment = 'ESP="No tiene permiso para registrar consumos."';
    begin
        // Validate user permissions
        if not this.HasADCSUserPermission() then
            this.Raise(this.BuildApplicationError(ErrNoPermissionPostConsumptionMsg, ErrNoPermissionPostConsumptionErr));

        // Validate item and variant
        if not this.ValidateComponentItemAndVariantNotBlocked(ProdOrderComp, Item) then
            exit;

        // Get manufacturing setup and journal configuration
        this.GetManufacturingSetupForConsumption(ManufacturingSetup, ItemJnlTemplate, ItemJnlBatch);

        // Setup journal line
        this.SetupConsumptionJournalLine(ItemJnlLine, ProdOrderComp, ItemJnlTemplate, ItemJnlBatch, Item, Quantity);

        // Apply item tracking if needed
        if (Item."Item Tracking Code" <> '') and (LotNo <> '') then
            this.ApplyItemTrackingToJournalLine(ItemJnlLine, ProdOrderComp, LotNo, Quantity);

        // Post Journal
        Clear(PostItemJnlLine);
        PostItemJnlLine.Run(ItemJnlLine);

        // Log the action
        this.LogAction(ProdOrderComp, Enum::"APA MADCS Log Type"::Consum);
    end;

    /// <summary>
    /// Posts component consumption for a production order component line and logs the action.
    /// </summary>
    /// <param name="ProdOrderComp">Record "Prod. Order Component"</param>
    procedure PostCompleteComponentConsumption(var ProdOrderComp: Record "Prod. Order Component")
    var
        Item: Record Item;
        ItemJnlLine: Record "Item Journal Line";
        ManufacturingSetup: Record "Manufacturing Setup";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        PostItemJnlLine: Codeunit "Item Jnl.-Post Line";
        NeededQty: Decimal;
        OriginalNeededQty: Decimal;
        ErrNoPermissionPostConsumptionMsg: Label 'Permissions Error.', Comment = 'ESP="Error de permisos."';
        ErrNoPermissionPostConsumptionErr: Label 'You do not have permission to post consumptions.', Comment = 'ESP="No tiene permiso para registrar consumos."';
    begin
        // Validate user permissions
        if not this.HasADCSUserPermission() then
            this.Raise(this.BuildApplicationError(ErrNoPermissionPostConsumptionMsg, ErrNoPermissionPostConsumptionErr));

        // Validate item and variant
        if not this.ValidateComponentItemAndVariantNotBlocked(ProdOrderComp, Item) then
            exit;

        // Calculate consumption quantity
        this.CalculateConsumptionQuantity(ProdOrderComp, NeededQty, OriginalNeededQty);

        // Get manufacturing setup and journal configuration
        this.GetManufacturingSetupForConsumption(ManufacturingSetup, ItemJnlTemplate, ItemJnlBatch);

        // Setup journal line for complete consumption
        this.SetupCompleteConsumptionJournalLine(ItemJnlLine, ProdOrderComp, ItemJnlTemplate, ItemJnlBatch, Item, NeededQty, OriginalNeededQty);

        // Apply item tracking if needed
        if Item."Item Tracking Code" <> '' then
            this.ApplyItemTrackingToCompleteConsumption(ItemJnlLine, ProdOrderComp);

        // Post Journal
        Clear(PostItemJnlLine);
        PostItemJnlLine.Run(ItemJnlLine);

        // Log the action
        this.LogAction(ProdOrderComp, Enum::"APA MADCS Log Type"::Consum);
    end;

    /// <summary>
    /// Posts output for a production order routing line and logs the action.
    /// </summary>
    /// <param name="ProdOrderLine">Record "Prod. Order Line"</param>
    /// <param name="OutputQuantity">Decimal quantity to post as output</param>
    /// <param name="LotNo">Code[50] Lot number for tracked items</param>
    /// <param name="ScrapQuantity">Decimal quantity of scrap produced</param>
    procedure PostOutput(var ProdOrderLine: Record "Prod. Order Line"; OutputQuantity: Decimal; LotNo: Code[50]; ScrapQuantity: Decimal)
    var
        Item: Record Item;
        ItemJnlLine: Record "Item Journal Line";
        ManufacturingSetup: Record "Manufacturing Setup";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        PostItemJnlLine: Codeunit "Item Jnl.-Post Line";
        ErrNoPermissionPostOutputLbl: Label 'You do not have permission to post output.', Comment = 'ESP="No tiene permiso para registrar salida."';
        ErrNoPermissionPostOutputErr: Label 'You do not have permission to post output.', Comment = 'ESP="No tiene permiso para registrar salidas."';
    begin
        // Validate user permissions
        if not this.HasADCSUserPermission() then
            this.Raise(this.BuildApplicationError(ErrNoPermissionPostOutputLbl, ErrNoPermissionPostOutputErr));

        // Validate item and variant
        if not this.ValidateOutputItemAndVariantNotBlocked(Item, ProdOrderLine) then
            exit;

        // Get manufacturing setup and journal configuration
        this.GetManufacturingSetupForOutput(ManufacturingSetup, ItemJnlTemplate, ItemJnlBatch);

        // Setup journal line for complete consumption
        this.SetupOutputJournalLine(ItemJnlLine, ProdOrderLine, ItemJnlTemplate, ItemJnlBatch, OutputQuantity, LotNo, ScrapQuantity);

        // Apply item tracking if needed
        if Item."Item Tracking Code" <> '' then
            this.ApplyItemTrackingToOutput(ItemJnlLine, ProdOrderLine, LotNo, OutputQuantity);

        // Post Journal
        Clear(PostItemJnlLine);
        PostItemJnlLine.Run(ItemJnlLine);

        // Log the action
        this.LogAction(ProdOrderLine, Enum::"APA MADCS Log Type"::Output);
    end;

    /// <summary>
    /// procedure LogAction
    /// Logs the specified action performed by the current user.
    /// </summary>
    /// <param name="ProdOrderComponent"></param>
    /// <param name="LogType"></param>
    procedure LogAction(ProdOrderComponent: Record "Prod. Order Component"; LogType: Enum "APA MADCS Log Type")
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        UserLog."Log Action" := UserLog."Log Action"::PostComponent;
        UserLog."Log Type" := LogType;

        UserLog.Insert(true); // TODO: Verify log
    end;

    /// <summary>
    /// procedure LogAction
    /// Logs the specified action performed by the current user.
    /// </summary>
    /// <param name="Activities"></param>
    /// <param name="LogType"></param>
    procedure LogAction(Activities: Record "APA MADCS Pro. Order Line Time"; LogType: Enum "APA MADCS Log Type")
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := Activities."Start Date Time";
        UserLog."Log Action" := UserLog."Log Action"::"New Activity";

        UserLog.Insert(true); // TODO: Verify log
    end;

    /// <summary>
    /// procedure LogAction
    /// Logs the specified action performed by the current user.
    /// </summary>
    /// <param name="ProdOrderLine"></param>
    /// <param name="LogType"></param>
    procedure LogAction(ProdOrderLine: Record "Prod. Order Line"; LogType: Enum "APA MADCS Log Type")
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        UserLog."Log Action" := UserLog."Log Action"::PostOutput;
        UserLog."Log Action" := UserLog."Log Action"::"New Activity";

        UserLog.Insert(true); // TODO: Verify log
    end;

    /// <summary>
    /// procedure LogAction
    /// Logs the specified action performed by the current user.
    /// </summary>
    /// <param name="ItemJournalLine"></param>
    /// <param name="LogType"></param>
    /// <param name="BreakDownCode"></param>
    procedure LogAction(ItemJournalLine: Record "Item Journal Line"; LogType: Enum "APA MADCS Log Type"; BreakDownCode: Code[20])
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        UserLog."Production Order No." := ItemJournalLine."Order No.";
        UserLog."Log Action" := UserLog."Log Action"::PostTime;
        UserLog."Log Action" := UserLog."Log Action"::"New Activity";
        UserLog."BreakDown Code" := BreakDownCode;

        UserLog.Insert(true); // TODO: Verify log
    end;

    /// <summary>
    /// procedure LogOutOperator
    /// Clears the current operator code, effectively logging out the operator.
    /// </summary>
    procedure LogOutOperator()
    begin
        this.CurrentOperatorCode := '';
        this.Logged := false;
    end;

    /// <summary>
    /// procedure SetOperatorCode
    /// Sets the current operator code for logging purposes.
    /// </summary>
    /// <param name="OperatorCode"></param>
    local procedure SetOperatorCode(OperatorCode: Code[20])
    begin
        this.CurrentOperatorCode := OperatorCode;
        Logged := true;
    end;


    /// <summary>
    /// Checks if the current user has ADCS user permission.
    /// </summary>
    /// <returns name="HasPermission">Boolean</returns>
    local procedure HasADCSUserPermission(): Boolean
    var
        ADCSUser: Record "ADCS User";
    begin
        // Check if user is in the "ADCS User" permission set
        exit(ADCSUser.Get(UserId()));
    end;

    /// <summary>
    /// Build a validation ErrorInfo with record and field context information.
    /// Creates a structured error with title and message for field-level validation failures.
    /// </summary>
    /// <param name="myrecordId">RecordId of the record where the validation failed. Can be used by caller for UI context.</param>
    /// <param name="fieldNo">Field number where the validation failed. Can be used by caller for field highlighting.</param>
    /// <param name="titleText">Short title for the error (e.g., "Comment required", "Invalid value"). Displayed prominently.</param>
    /// <param name="messageText">Detailed error message explaining what went wrong and how to fix it. Displayed below the title.</param>
    /// <returns name="ErrorInfo">Configured ErrorInfo ready to be raised via Error() or collected via ErrorBehavior.Collect.</returns>
    procedure BuildValidationError(myrecordId: RecordId; fieldNo: Integer; titleText: Text; messageText: Text) err: ErrorInfo
    begin
        err := ErrorInfo.Create(messageText);
        err.RecordId := myrecordId;
        err.Title := titleText;
        err.AddNavigationAction();
        exit(err);
    end;

    /// <summary>
    /// Build an application error with title and message.
    /// </summary>
    /// <param name="titleText">Short title for the error.</param>
    /// <param name="messageText">Detailed error message for the user.</param>
    /// <returns name="ErrorInfo">ErrorInfo</returns>
    procedure BuildApplicationError(titleText: Text; messageText: Text) err: ErrorInfo
    begin
        err := ErrorInfo.Create(messageText);
        err.Title := titleText;
        exit(err);
    end;

    /// <summary>
    /// Raise a blocking error using ErrorInfo.
    /// </summary>
    /// <param name="err">ErrorInfo to raise.</param>
    procedure Raise(err: ErrorInfo)
    begin
        Error(err);
    end;

    /// <summary>
    /// Send a non-blocking notification to the user for warnings or info.
    /// </summary>
    /// <param name="titleText">Title of the notification.</param>
    /// <param name="messageText">Message body.</param>
    /// <param name="recordId">Optional record context.</param>
    procedure Notify(titleText: Text; messageText: Text; recordId: RecordId)
    var
        notif: Notification;
    begin
        notif.Message(messageText);
        notif.Scope(NotificationScope::LocalScope);
        if recordId.TableNo() <> 0 then
            notif.SetData('RecordId', Format(recordId));
        notif.Send();
    end;

    /// <summary>
    /// procedure ValidateAndDeleteTemporaryTables
    /// Validates that the provided record is temporary and deletes all its records.
    /// </summary>
    /// <param name="Rec"></param>
    procedure ValidateAndDeleteTemporaryTables(var Rec: Record "Prod. Order Component" temporary)
    var
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        TemporaryTableErr: Label 'Page table is not temporary.', Comment = 'ESP="La tabla de la página no es temporal."';
    begin
        if not Rec.IsTemporary() or not TempTrackingSpecification.IsTemporary() then
            this.Raise(this.BuildApplicationError(ProgramErr, TemporaryTableErr));
        Rec.DeleteAll(false);
    end;

    /// <summary>
    /// procedure LoadProdOrderComponentsForWarehouseConsumption
    /// Loads production order components into the temporary record for the given production order.
    /// </summary>
    /// <param name="Rec"></param>
    /// <param name="ProdOrderComponent"></param>
    /// <param name="ItemNo"></param>
    /// <param name="QuienSirvePickingOP"></param>
    procedure LoadProdOrderComponentsForWarehouseConsumption(var Rec: Record "Prod. Order Component" temporary; var ProdOrderComponent: Record "Prod. Order Component"; ItemNo: Code[20]; QuienSirvePickingOP: Enum "DC Quien Sirve Picking OP")
    begin
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.");
        ProdOrderComponent.SetFilter(Status, Rec.GetFilter(Status));
        ProdOrderComponent.SetFilter("Prod. Order No.", Rec.GetFilter("Prod. Order No."));
        ProdOrderComponent.SetRange("Item No.", ItemNo);
        ProdOrderComponent.SetRange("Quien sirve picking OP", QuienSirvePickingOP);
        if ProdOrderComponent.FindSet(false) then
            repeat
                this.ProcessProdOrderComponent(Rec, ProdOrderComponent);
            until ProdOrderComponent.Next() = 0;
    end;

    /// <summary>
    /// procedure LoadProdOrderComponentsForValidation
    /// Loads production order components into the temporary record for the given production order.
    /// </summary>
    /// <param name="Rec"></param>
    /// <param name="ProdOrderComponent"></param>
    procedure LoadProdOrderComponentsForValidation(var Rec: Record "Prod. Order Component" temporary; var ProdOrderComponent: Record "Prod. Order Component")
    begin
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey("Prod. Order No.");
        ProdOrderComponent.SetFilter("Prod. Order No.", Rec.GetFilter("Prod. Order No."));
        if ProdOrderComponent.FindSet(false) then
            repeat
                this.ProcessProdOrderComponent(Rec, ProdOrderComponent);
            until ProdOrderComponent.Next() = 0;
    end;

    /// <summary>
    /// procedure ProcessPreparationCleaningTask
    /// Processes the preparation or cleaning task based on the provided id.
    /// </summary>
    /// <param name="id"></param>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrder"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    procedure ProcessPreparationCleaningTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        this.FinalizeLastActivity(OperatorCode);

        case id of
            Format(Enum::"APA MADCS Time Buttons"::ALButtonPreparationTok):
                Activities.NewPreparationActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);
            Format(Enum::"APA MADCS Time Buttons"::ALButtonCleaningTok):
                Activities.NewCleaningActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);
        end;
        this.LogAction(Activities, Enum::"APA MADCS Log Type"::Cleaning);
    end;

    /// <summary>
    /// procedure ProcessExecutionAndStopAllTask
    /// Processes the execution task and stops all other tasks.
    /// </summary>
    /// <param name="id"></param>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrder"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    procedure ProcessExecutionAndStopAllTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        this.FinalizeLastActivity(OperatorCode);

        if id = Format(Enum::"APA MADCS Time Buttons"::ALButtonExecutionTok) then
            Activities.NewExecutionActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);

        this.LogAction(Activities, Enum::"APA MADCS Log Type"::Execution);
    end;

    /// <summary>
    /// procedure ProcessBreakdownAndBlockedBreakdownTask
    /// Processes the breakdown and blocked breakdown tasks.
    /// </summary>
    /// <param name="id"></param>
    /// <param name="pProdOrderStatus"></param>
    /// <param name="pProdOrder"></param>
    /// <param name="pProdOrderLine"></param>
    /// <param name="OperatorCode"></param>
    /// <param name="BreakDownCode"></param>
    procedure ProcessBreakdownAndBlockedBreakdownTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        if Activities.BreakDownCodeIsBlocking(BreakDownCode) then
            this.FinalizeAllActivities(pProdOrderStatus, pProdOrder) // for all operators
        else
            this.FinalizeLastActivity(BreakDownCode); // only for blocked tasks

        Activities.NewFaultActivity(id, pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);
        this.LogAction(Activities, Enum::"APA MADCS Log Type"::Fault);
    end;

    /// <summary>
    /// CerrarOrdenProduccion.
    /// Cierra una órden de producción siempre que se cumplan las condiciones necesarias:
    /// </summary>
    /// <param name="ProductionOrder">VAR Record "Production Order".</param>
    /// <param name="pbMostrarError">Boolean.</param>
    procedure CerrarOrdenProduccion(var ProductionOrder: Record "Production Order"; pbMostrarError: Boolean)
    var
        lcuProdOrderStatusManagement: Codeunit "Prod. Order Status Management";
        lcuDCRegistrarDiarioCapacidad: Codeunit "DC Registrar Diario Capacidad";
        lenumCierre: Enum "APA MADCS Cierre Orden";
        ltxtCierre: array[100] of Text;
        i: Integer;
        ErrorsLbl: Label 'Errors', Comment = 'ESP="Errores"';
    begin
        if not this.PuedoVerificarCierreOrden(ProductionOrder) then
            exit;

        Clear(lcuDCRegistrarDiarioCapacidad);
        lcuDCRegistrarDiarioCapacidad.PostProductionOrderJournalLines(ProductionOrder."No."); // Antes de nada registra los diarios de capacidad que haya pendientes
        this.EsPosibleCerrarOrden(ltxtCierre, i, ProductionOrder);
        if i > 100 then
            i := 100;
        this.AnotarCierreOrden(ProductionOrder, ltxtCierre, i);
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
    /// Finds lot numbers assigned to the production order line and lets the user pick one.
    /// </summary>
    /// <param name="ProdOrderLine">Production order line to filter reservation entries.</param>
    /// <param name="Text">Selected lot number.</param>
    /// <returns name="Found">True when a lot was selected.</returns>
    internal procedure FindLotNoForOutput(ProdOrderLine: Record "Prod. Order Line"; var Text: Text): Boolean
    var
        ReservationEntries: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        ProdOrderLineReserve: Codeunit "Prod. Order Line-Reserve";
        ItemTrackingLines: Page "Item Tracking Lines";
        APAMADCSTrackingSpecification: Page "APA MADCS Track. Specification";

    begin
        // DAA - Mostrar la lista de lotes de la línea de la orden y seleccionar uno
        Text := '';
        Clear(TrackingSpecification);
        Clear(TempTrackingSpecification);
        TempTrackingSpecification.DeleteAll(false);

        ProdOrderLineReserve.InitFromProdOrderLine(TrackingSpecification, ProdOrderLine);
        ProdOrderLineReserve.FindReservEntry(ProdOrderLine, ReservationEntries);
        ItemTrackingLines.SetSourceSpec(TrackingSpecification, ProdOrderLine."Due Date");
        ItemTrackingLines.GetTrackingSpec(TempTrackingSpecification);

        Clear(APAMADCSTrackingSpecification);
        APAMADCSTrackingSpecification.InitializeTrackingData(TempTrackingSpecification);
        APAMADCSTrackingSpecification.LookupMode(true);
        if APAMADCSTrackingSpecification.RunModal() = Action::LookupOK then begin
            APAMADCSTrackingSpecification.GetSelectedTrackingSpec(TempTrackingSpecification);
            Text := TempTrackingSpecification."Lot No.";
            exit(Text <> '');
        end;

        exit(false);
    end;
    #endregion procedures


    #region local procedures
    /// <summary>
    /// Finalizes the last active task for an operator, posting time and marking it posted.
    /// </summary>
    /// <param name="OperatorCode">Operator identifier to filter activities.</param>
    local procedure FinalizeLastActivity(OperatorCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        // Find my current activity and stop it
        // Consume time used in recent stopped activity
        Clear(Activities);
        Activities.SetCurrentKey("Operator Code");
        Activities.SetRange("Operator Code", OperatorCode);
        Activities.SetRange(Posted, false);
        if Activities.FindSet(true) then
            repeat
                Activities."End Date Time" := CurrentDateTime();
                if Activities."Action" <> Enum::"APA MADCS Journal Type"::Fault then
                    this.PostCapacityJournalLine(Activities);
                Activities.Validate(Posted, true);
                Activities.Modify(false);
                // Log the action
                this.LogAction(Activities, Enum::"APA MADCS Log Type"::FinalizeTask);
            until Activities.Next() = 0;
    end;

    /// <summary>
    /// Finalizes all active tasks for a production order status and number.
    /// </summary>
    /// <param name="pProdOrderStatus">Production order status to filter.</param>
    /// <param name="pProdOrder">Production order number to filter.</param>
    local procedure FinalizeAllActivities(pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        // Find my current activity and stop it
        // Consume time used in recent stopped activity
        Clear(Activities);
        Activities.SetCurrentKey(Status, "Prod. Order No.");
        Activities.SetRange(Status, pProdOrderStatus);
        Activities.SetRange("Prod. Order No.", pProdOrder);
        Activities.SetRange(Posted, false);
        if Activities.FindSet(true) then
            repeat
                Activities."End Date Time" := CurrentDateTime();
                if Activities."Action" <> Enum::"APA MADCS Journal Type"::Fault then
                    this.PostCapacityJournalLine(Activities);
                Activities.Validate(Posted, true);
                Activities.Modify(false);
                // Log the action
                this.LogAction(Activities, Enum::"APA MADCS Log Type"::FinalizeTask);
            until Activities.Next() = 0;
    end;

    /// <summary>
    /// Posts a capacity journal line based on the provided activity.
    /// </summary>
    /// <param name="Activities">Activity record containing time and order context.</param>
    local procedure PostCapacityJournalLine(Activities: Record "APA MADCS Pro. Order Line Time")
    var
        ItemJournalLine: Record "Item Journal Line";
        PostItemJnlLine: Codeunit "Item Jnl.-Post Line";
    begin
        Clear(ItemJournalLine);
        ItemJournalLine."Journal Template Name" := '';
        ItemJournalLine."Journal Batch Name" := '';
        ItemJournalLine.Validate("Order Type", ItemJournalLine."Order Type"::Production);
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Output);
        ItemJournalLine.Validate("Order No.", Activities."Prod. Order No.");
        ItemJournalLine.Validate("Order Line No.", Activities."Prod. Order Line No.");
        ItemJournalLine.Validate("Item No.", Activities.ItemNo());
        ItemJournalLine.Validate("Operation No.", Activities."Operation No.");
        ItemJournalLine.Validate("Document No.", Activities."Prod. Order No.");
        // Only one operation per production order line in MADCS
        ItemJournalLine.Validate("Posting Date", Activities."End Date Time".Date());
        case Activities.Action of
            "APA MADCS Journal Type"::Preparation,
            "APA MADCS Journal Type"::Clean:
                ItemJournalLine.Validate("Setup Time", Activities.MinutesUsed());
            "APA MADCS Journal Type"::Execution:
                ItemJournalLine.Validate("Run Time", Activities.MinutesUsed());
            "APA MADCS Journal Type"::"Execution with Fault":
                begin
                    ItemJournalLine.Validate("Run Time", Activities.MinutesUsed());
                    ItemJournalLine.Validate("Stop Code", Activities.GetStopCode(Activities."BreakDown Code"));
                    ItemJournalLine.Validate("Stop Detail Code", Activities."BreakDown Code");
                end;
            "APA MADCS Journal Type"::Fault:
                ItemJournalLine.Validate("Stop Time", Activities.MinutesUsed());
        end;
        ItemJournalLine.Validate(Quantity, 0);
        ItemJournalLine.Validate("Output Quantity", 0);
        ItemJournalLine.Validate(Description, Activities.Description());

        // Post Journal
        Clear(PostItemJnlLine);
        PostItemJnlLine.Run(ItemJournalLine);
        this.LogAction(ItemJournalLine, Enum::"APA MADCS Log Type"::PostTime, Activities."BreakDown Code");
    end;

    /// <summary>
    /// Copies a production order component into a temporary buffer and processes tracking when required.
    /// </summary>
    /// <param name="Rec">Temporary component buffer to populate.</param>
    /// <param name="ProdOrderComponent">Source production order component.</param>
    local procedure ProcessProdOrderComponent(var Rec: Record "Prod. Order Component" temporary; ProdOrderComponent: Record "Prod. Order Component")
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        Rec := ProdOrderComponent;
        this.ValidateAndGetItem(Item, ProdOrderComponent."Item No.");
        if this.ShouldProcessItemTracking(Item, ItemTrackingCode) then
            this.ProcessItemWithTracking(Rec, ProdOrderComponent)
        else
            this.InsertComponentRecord(Rec, ProdOrderComponent, '', Rec."Remaining Qty. (Base)", 0);
    end;

    /// <summary>
    /// Retrieves an item record or raises an application error if not found.
    /// </summary>
    /// <param name="Item">Item record to populate.</param>
    /// <param name="ItemNo">Item number to fetch.</param>
    local procedure ValidateAndGetItem(var Item: Record Item; ItemNo: Code[20])
    var
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        ItemErr: Label 'Item not found: %1', Comment = 'ESP="Artículo no encontrado: %1"';
    begin
        Clear(Item);
        if not Item.Get(ItemNo) then
            this.Raise(this.BuildApplicationError(ProgramErr, StrSubstNo(ItemErr, ItemNo)));
    end;

    /// <summary>
    /// Determines whether item tracking must be processed and loads the tracking code.
    /// </summary>
    /// <param name="Item">Item to evaluate.</param>
    /// <param name="ItemTrackingCode">Loaded tracking code when applicable.</param>
    /// <returns name="ShouldProcess">Boolean.</returns>
    local procedure ShouldProcessItemTracking(Item: Record Item; var ItemTrackingCode: Record "Item Tracking Code"): Boolean
    var
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        ItemTrackingCodeErr: Label 'Item Tracking Code not found: %1', Comment = 'ESP="Código de seguimiento del artículo no encontrado: %1"';
    begin
        if Item."Item Tracking Code" = '' then
            exit(false);

        Clear(ItemTrackingCode);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then
            this.Raise(this.BuildApplicationError(ProgramErr, StrSubstNo(ItemTrackingCodeErr, Item."Item Tracking Code")));

        exit(ItemTrackingCode."Lot Manuf. Inbound Tracking");
    end;

    /// <summary>
    /// Handles item tracking selection for a component and inserts resulting lines into the buffer.
    /// </summary>
    /// <param name="Rec">Temporary component buffer to insert tracking splits.</param>
    /// <param name="ProdOrderComponent">Source production order component.</param>
    local procedure ProcessItemWithTracking(var Rec: Record "Prod. Order Component" temporary; ProdOrderComponent: Record "Prod. Order Component")
    var
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        ProdOrderCompReserve: Codeunit "Prod. Order Comp.-Reserve";
        ItemTrackingLines: Page "Item Tracking Lines";
        i: Integer;
    begin
        Clear(TrackingSpecification);
        Clear(ItemTrackingLines);
        TempTrackingSpecification.DeleteAll(false);

        ProdOrderCompReserve.InitFromProdOrderComp(TrackingSpecification, ProdOrderComponent);
        ItemTrackingLines.SetSourceSpec(TrackingSpecification, ProdOrderComponent."Due Date");
        ItemTrackingLines.SetInbound(ProdOrderComponent.IsInbound());
        ItemTrackingLines.GetTrackingSpec(TempTrackingSpecification);

        i := 0;
        if TempTrackingSpecification.FindSet(false) then
            repeat
                i += 1;
                this.InsertComponentRecord(Rec, ProdOrderComponent, TempTrackingSpecification."Lot No.", TempTrackingSpecification."Quantity (Base)", i);
            until TempTrackingSpecification.Next() = 0;
    end;

    /// <summary>
    /// Validates that the component item and its variant are not blocked before consumption.
    /// </summary>
    /// <param name="ProdOrderComp">Component line to check.</param>
    /// <param name="Item">Resolved item record.</param>
    /// <returns name="IsAllowed">True when the component can be consumed.</returns>
    local procedure ValidateComponentItemAndVariantNotBlocked(ProdOrderComp: Record "Prod. Order Component"; var Item: Record Item): Boolean
    var
        ItemVariant: Record "Item Variant";
        ItemItemVariantTok: Label '%1 %2', Locked = true, Comment = '%1 - Item No., %2 - Variant Code';
        BlockedMsg: Label 'The item %1 (%2) is blocked and cannot be consumed.', Comment = 'ESP="El artículo %1 (%2) está bloqueado y no se puede consumir."';
    begin
        if not Item.Get(ProdOrderComp."Item No.") then
            exit(false);

        if Item.Blocked then begin
            Message(BlockedMsg, ProdOrderComp."Item No.", Item.TableCaption());
            exit(false);
        end;

        if ProdOrderComp."Variant Code" <> '' then begin
            ItemVariant.SetLoadFields(Blocked);
            if not ItemVariant.Get(ProdOrderComp."Item No.", ProdOrderComp."Variant Code") then
                exit(false);
            if ItemVariant.Blocked then begin
                Message(BlockedMsg, StrSubstNo(ItemItemVariantTok, ProdOrderComp."Item No.", ProdOrderComp."Variant Code"), ItemVariant.TableCaption());
                exit(false);
            end;
        end;

        exit(true);
    end;

    /// <summary>
    /// Validates that the output item and variant are available and not blocked for posting.
    /// </summary>
    /// <param name="Item">Resolved item record.</param>
    /// <param name="ProdOrderLine">Resolved production order line.</param>
    /// <returns name="IsAllowed">True when the output can be posted.</returns>
    local procedure ValidateOutputItemAndVariantNotBlocked(var Item: Record Item; ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ItemVariant: Record "Item Variant";
        ItemItemVariantTok: Label '%1 %2', Locked = true, Comment = '%1 - Item No., %2 - Variant Code';
        BlockedMsg: Label 'The item %1 (%2) is blocked and cannot be consumed.', Comment = 'ESP="El artículo %1 (%2) está bloqueado y no se puede consumir."';
    begin
        if not Item.Get(ProdOrderLine."Item No.") then
            exit(false);

        if Item.Blocked then begin
            Message(BlockedMsg, ProdOrderLine."Item No.", Item.TableCaption());
            exit(false);
        end;

        if ProdOrderLine."Variant Code" <> '' then begin
            ItemVariant.SetLoadFields(Blocked);
            if not ItemVariant.Get(ProdOrderLine."Item No.", ProdOrderLine."Variant Code") then
                exit(false);
            if ItemVariant.Blocked then begin
                Message(BlockedMsg, StrSubstNo(ItemItemVariantTok, ProdOrderLine."Item No.", ProdOrderLine."Variant Code"), ItemVariant.TableCaption());
                exit(false);
            end;
        end;

        exit(true);
    end;

    /// <summary>
    /// Retrieves MADCS consumption journal setup and raises an error if configuration is missing.
    /// </summary>
    /// <param name="ManufacturingSetup">Manufacturing setup record to load.</param>
    /// <param name="ItemJnlTemplate">Journal template resolved from setup.</param>
    /// <param name="ItemJnlBatch">Journal batch resolved from setup.</param>
    local procedure GetManufacturingSetupForConsumption(var ManufacturingSetup: Record "Manufacturing Setup"; var ItemJnlTemplate: Record "Item Journal Template"; var ItemJnlBatch: Record "Item Journal Batch")
    var
        ItemJournalMissingMsg: Label 'Item Journal Template Missing', Comment = 'ESP="Falta la plantilla de diario de artículos para el consumo MADCS."';
        ItemJournalMissingErr: Label 'The specified Item Journal Template for MADCS consumption is missing. Please check the Manufacturing Setup.', Comment = 'ESP="Falta la plantilla de diario de artículos especificada para el consumo MADCS. Por favor, verifique la Configuración de Fabricación."';
        ItemJournalBatchMissingMsg: Label 'Item Journal Batch Missing', Comment = 'ESP="Falta la sección del diario de artículos para el consumo MADCS."';
        ItemJournalBatchMissingErr: Label 'The specified Item Journal Batch for MADCS consumption is missing. Please check the Manufacturing Setup.', Comment = 'ESP="Falta el lote de diario de artículos especificado para el consumo MADCS. Por favor, verifique la Configuración de Fabricación."';
    begin
        if not ManufacturingSetup.Get() then
            this.Raise(this.BuildApplicationError(this.ManufacturingSetupMissMsg, this.ManufacturingSetupErr));

        if not ItemJnlTemplate.Get(ManufacturingSetup."APA MADCS Consump. Jnl. Templ.") then
            this.Raise(this.BuildApplicationError(ItemJournalMissingMsg, ItemJournalMissingErr));

        if not ItemJnlBatch.Get(ManufacturingSetup."APA MADCS Consump. Jnl. Templ.", ManufacturingSetup."APA MADCS Consump. Jnl. Batch") then
            this.Raise(this.BuildApplicationError(ItemJournalBatchMissingMsg, ItemJournalBatchMissingErr));
    end;

    /// <summary>
    /// Retrieves MADCS output journal setup and raises an error if configuration is missing.
    /// </summary>
    /// <param name="ManufacturingSetup">Manufacturing setup record to load.</param>
    /// <param name="ItemJnlTemplate">Journal template resolved from setup.</param>
    /// <param name="ItemJnlBatch">Journal batch resolved from setup.</param>
    local procedure GetManufacturingSetupForOutput(var ManufacturingSetup: Record "Manufacturing Setup"; var ItemJnlTemplate: Record "Item Journal Template"; var ItemJnlBatch: Record "Item Journal Batch")
    var
        ItemJournalMissingMsg: Label 'Item Journal Template Missing', Comment = 'ESP="Falta la plantilla de diario de artículos para la salida MADCS."';
        ItemJournalMissingErr: Label 'The specified Item Journal Template for MADCS output is missing. Please check the Manufacturing Setup.', Comment = 'ESP="Falta la plantilla de diario de artículos especificada para la salida MADCS. Por favor, verifique la Configuración de Fabricación."';
        ItemJournalBatchMissingMsg: Label 'Item Journal Batch Missing', Comment = 'ESP="Falta la sección del diario de artículos para la salida MADCS."';
        ItemJournalBatchMissingErr: Label 'The specified Item Journal Batch for MADCS output is missing. Please check the Manufacturing Setup.', Comment = 'ESP="Falta el lote de diario de artículos especificado para la salida MADCS. Por favor, verifique la Configuración de Fabricación."';
    begin
        if not ManufacturingSetup.Get() then
            this.Raise(this.BuildApplicationError(this.ManufacturingSetupMissMsg, this.ManufacturingSetupErr));

        if not ItemJnlTemplate.Get(ManufacturingSetup."APA MADCS Output Jnl. Templ.") then
            this.Raise(this.BuildApplicationError(ItemJournalMissingMsg, ItemJournalMissingErr));

        if not ItemJnlBatch.Get(ManufacturingSetup."APA MADCS Output Jnl. Templ.", ManufacturingSetup."APA MADCS Output Jnl. Batch") then
            this.Raise(this.BuildApplicationError(ItemJournalBatchMissingMsg, ItemJournalBatchMissingErr));
    end;

    /// <summary>
    /// Builds a consumption item journal line for a specific production order component.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line to populate.</param>
    /// <param name="ProdOrderComp">Component providing consumption context.</param>
    /// <param name="ItemJnlTemplate">Journal template from setup.</param>
    /// <param name="ItemJnlBatch">Journal batch from setup.</param>
    /// <param name="Item">Item record for validations.</param>
    /// <param name="Quantity">Quantity to consume in base units.</param>
    local procedure SetupConsumptionJournalLine(var ItemJnlLine: Record "Item Journal Line"; ProdOrderComp: Record "Prod. Order Component"; ItemJnlTemplate: Record "Item Journal Template"; ItemJnlBatch: Record "Item Journal Batch"; Item: Record Item; Quantity: Decimal)
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        // Get production order line
        Clear(ProdOrderLine);
        if not ProdOrderLine.Get(ProdOrderComp.Status, ProdOrderComp."Prod. Order No.", ProdOrderComp."Prod. Order Line No.") then
            exit;

        Clear(ItemJnlLine);
        ItemJnlLine."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := 0;
        ItemJnlLine.Validate("Posting Date", WorkDate());
        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Consumption);
        ItemJnlLine.Validate("Order Type", ItemJnlLine."Order Type"::Production);
        ItemJnlLine.Validate("Order No.", ProdOrderComp."Prod. Order No.");
        ItemJnlLine.Validate("Source No.", ProdOrderLine."Item No.");
        ItemJnlLine.Validate("Item No.", ProdOrderComp."Item No.");
        ItemJnlLine.Validate("Unit of Measure Code", ProdOrderComp."Unit of Measure Code");
        ItemJnlLine.Description := ProdOrderComp.Description;
        this.ConsumptionItemJnlLineValidateQuantity(ItemJnlLine, Quantity, Item, false);

        ItemJnlLine.Validate("Location Code", ProdOrderComp."Location Code");
        ItemJnlLine.Validate("Dimension Set ID", ProdOrderComp."Dimension Set ID");
        if ProdOrderComp."Bin Code" <> '' then
            ItemJnlLine."Bin Code" := ProdOrderComp."Bin Code";

        ItemJnlLine."Variant Code" := ProdOrderComp."Variant Code";
        ItemJnlLine.Validate("Order Line No.", ProdOrderComp."Prod. Order Line No.");
        ItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrderComp."APA MADCS Original Line No.");

        ItemJnlLine.Level := 0;
        ItemJnlLine."Flushing Method" := ProdOrderComp."Flushing Method";
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
        ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
        ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
    end;

    /// <summary>
    /// Applies lot tracking from a production component to the consumption journal line and sets handling quantities.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line that receives tracking.</param>
    /// <param name="ProdOrderComp">Component line providing original tracking.</param>
    /// <param name="LotNo">Selected lot number.</param>
    /// <param name="Quantity">Quantity to assign to the lot.</param>
    local procedure ApplyItemTrackingToJournalLine(var ItemJnlLine: Record "Item Journal Line"; ProdOrderComp: Record "Prod. Order Component"; LotNo: Code[50]; Quantity: Decimal)
    var
        ReservationEntry: Record "Reservation Entry";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
    begin
        ItemTrackingMgt.CopyItemTracking(ProdOrderComp.RowID1(), ItemJnlLine.RowID1(), false);

        Clear(ReservationEntry);
        ReservationEntry.SetPointer(ItemJnlLine.RowID1());
        ReservationEntry.SetPointerFilter();
        ReservationEntry.ModifyAll("Qty. to Handle (Base)", 0, false);
        ReservationEntry.ModifyAll("Qty. to Invoice (Base)", 0, false);
        ReservationEntry.SetRange("Lot No.", LotNo);
        if ReservationEntry.FindSet(true) then
            repeat
                ReservationEntry.Validate("Qty. to Handle (Base)", -Quantity);
                ReservationEntry.Validate("Qty. to Invoice (Base)", -Quantity);
                ReservationEntry.Modify(false);
            until ReservationEntry.Next() = 0;
    end;

    /// <summary>
    /// Calculates the required consumption quantity for a component considering flushing method and warehouse adjustments.
    /// </summary>
    /// <param name="ProdOrderComp">Component line to evaluate.</param>
    /// <param name="NeededQty">Calculated quantity required.</param>
    /// <param name="OriginalNeededQty">Unadjusted calculated quantity.</param>
    local procedure CalculateConsumptionQuantity(var ProdOrderComp: Record "Prod. Order Component"; var NeededQty: Decimal; var OriginalNeededQty: Decimal)
    var
        CalcBasedOn: Enum "APA MADCS Calc Based On";
    begin
        CalcBasedOn := CalcBasedOn::"Expected Output";
        if ProdOrderComp."Flushing Method" <> ProdOrderComp."Flushing Method"::Manual then
            NeededQty := 0
        else
            NeededQty := ProdOrderComp.GetNeededQty(CalcBasedOn.AsInteger(), true);

        OriginalNeededQty := NeededQty;

        if ProdOrderComp."Flushing Method" = ProdOrderComp."Flushing Method"::Manual then
            this.AdjustQuantityForWarehouse(ProdOrderComp, NeededQty);
    end;

    /// <summary>
    /// Adjusts consumption quantity based on warehouse pick handling setup.
    /// </summary>
    /// <param name="ProdOrderComp">Component line to inspect.</param>
    /// <param name="NeededQty">Quantity to adjust when warehouse picks are mandatory.</param>
    local procedure AdjustQuantityForWarehouse(var ProdOrderComp: Record "Prod. Order Component"; var NeededQty: Decimal)
    var
        Location: Record Location;
        ShouldAdjustQty: Boolean;
    begin
        if ProdOrderComp."Location Code" <> Location.Code then
            if not Location.GetLocationSetup(ProdOrderComp."Location Code", Location) then
                Clear(Location);

        ShouldAdjustQty := Location."Prod. Consump. Whse. Handling" = Location."Prod. Consump. Whse. Handling"::"Warehouse Pick (mandatory)";
        if ShouldAdjustQty then
            ProdOrderComp.AdjustQtyToQtyPicked(NeededQty);
    end;

    /// <summary>
    /// Builds a consumption journal line for complete component consumption including adjustment quantities.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line to populate.</param>
    /// <param name="ProdOrderComp">Component providing context.</param>
    /// <param name="ItemJnlTemplate">Configured journal template.</param>
    /// <param name="ItemJnlBatch">Configured journal batch.</param>
    /// <param name="Item">Item record for validations.</param>
    /// <param name="NeededQty">Adjusted quantity to consume.</param>
    /// <param name="OriginalNeededQty">Original quantity prior to adjustments.</param>
    local procedure SetupCompleteConsumptionJournalLine(var ItemJnlLine: Record "Item Journal Line"; ProdOrderComp: Record "Prod. Order Component"; ItemJnlTemplate: Record "Item Journal Template"; ItemJnlBatch: Record "Item Journal Batch"; Item: Record Item; NeededQty: Decimal; OriginalNeededQty: Decimal)
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        // Get production order line
        Clear(ProdOrderLine);
        if not ProdOrderLine.Get(ProdOrderComp.Status, ProdOrderComp."Prod. Order No.", ProdOrderComp."Prod. Order Line No.") then
            exit;

        Clear(ItemJnlLine);
        ItemJnlLine."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := 0;
        ItemJnlLine.Validate("Posting Date", WorkDate());
        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Consumption);
        ItemJnlLine.Validate("Order Type", ItemJnlLine."Order Type"::Production);
        ItemJnlLine.Validate("Order No.", ProdOrderComp."Prod. Order No.");
        ItemJnlLine.Validate("Source No.", ProdOrderLine."Item No.");
        ItemJnlLine.Validate("Item No.", ProdOrderComp."Item No.");
        ItemJnlLine.Validate("Unit of Measure Code", ProdOrderComp."Unit of Measure Code");
        ItemJnlLine.Description := ProdOrderComp.Description;
        this.ConsumptionItemJnlLineValidateQuantity(ItemJnlLine, NeededQty, Item, NeededQty < OriginalNeededQty);

        ItemJnlLine.Validate("Location Code", ProdOrderComp."Location Code");
        ItemJnlLine.Validate("Dimension Set ID", ProdOrderComp."Dimension Set ID");
        if ProdOrderComp."Bin Code" <> '' then
            ItemJnlLine."Bin Code" := ProdOrderComp."Bin Code";

        ItemJnlLine."Variant Code" := ProdOrderComp."Variant Code";
        ItemJnlLine.Validate("Order Line No.", ProdOrderComp."Prod. Order Line No.");
        ItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrderComp."Line No.");

        ItemJnlLine.Level := 0;
        ItemJnlLine."Flushing Method" := ProdOrderComp."Flushing Method";
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
        ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
        ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
    end;

    /// <summary>
    /// Builds an output journal line for a routing line with the specified output quantity.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line to populate.</param>
    /// <param name="ProdOrderLine">Production order line providing context.</param>
    /// <param name="ItemJnlTemplate">Configured journal template.</param>
    /// <param name="ItemJnlBatch">Configured journal batch.</param>
    /// <param name="OutputQuantity">Quantity to post as output.</param>
    /// <param name="LotNo">Lot number assigned.</param>
    /// <param name="ScrapQuantity">Quantity of scrap produced.</param>
    local procedure SetupOutputJournalLine(var ItemJnlLine: Record "Item Journal Line"; ProdOrderLine: Record "Prod. Order Line"; ItemJnlTemplate: Record "Item Journal Template"; ItemJnlBatch: Record "Item Journal Batch"; OutputQuantity: Decimal; LotNo: Code[50]; ScrapQuantity: Decimal)
    begin
        // TODO: Review
        Clear(ItemJnlLine);
        ItemJnlLine."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := 0;
        ItemJnlLine.Validate("Posting Date", WorkDate());
        ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Output);
        ItemJnlLine.Validate("Order Type", ItemJnlLine."Order Type"::Production);
        ItemJnlLine.Validate("Order No.", ProdOrderLine."Prod. Order No.");
        ItemJnlLine.Validate("Source No.", ProdOrderLine."Item No.");
        ItemJnlLine.Validate("Item No.", ProdOrderLine."Item No.");
        ItemJnlLine.Validate("Unit of Measure Code", ProdOrderLine."Unit of Measure Code");
        ItemJnlLine.Description := ProdOrderLine.Description;

        ItemJnlLine.Validate("Location Code", ProdOrderLine."Location Code");
        ItemJnlLine.Validate("Dimension Set ID", ProdOrderLine."Dimension Set ID");
        if ProdOrderLine."Bin Code" <> '' then
            ItemJnlLine."Bin Code" := ProdOrderLine."Bin Code";

        ItemJnlLine."Variant Code" := ProdOrderLine."Variant Code";
        ItemJnlLine.Validate("Order Line No.", ProdOrderLine."Line No.");
        ItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrderLine."Line No.");
        ItemJnlLine.Level := 0;
        ItemJnlLine."Flushing Method" := Enum::"Flushing Method"::Manual;
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
        ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
        ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
        ItemJnlLine.Validate("Output Quantity", OutputQuantity);
        ItemJnlLine.Validate("Scrap Quantity", ScrapQuantity);
    end;

    /// <summary>
    /// Copies tracking from the production component to the complete consumption journal line.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line that receives tracking.</param>
    /// <param name="ProdOrderLine">Component providing source tracking.</param>
    /// <param name="LotNo">Selected lot number.</param>
    /// <param name="OutputQuantity">Quantity to post as output.</param>
    local procedure ApplyItemTrackingToOutput(var ItemJnlLine: Record "Item Journal Line"; ProdOrderLine: Record "Prod. Order Line"; LotNo: Code[50]; OutputQuantity: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        RemainingQuantity: Decimal;
        BadOutputMsg: Label 'Bad Output', Comment='ESP="Salida incorrecta"';
        BadOutputErr: Label 'The output quantity exceeds the available tracked quantity for lot %1.', Comment='ESP="La cantidad de salida excede la cantidad rastreada disponible para el lote %1."';
    begin
        ItemTrackingMgt.CopyItemTracking(ProdOrderLine.RowID1(), ItemJnlLine.RowID1(), false);
        ReservEntry.SetPointer(ItemJnlLine.RowID1());
        ReservEntry.SetPointerFilter();
        ReservEntry.SetFilter("Lot No.", '<>%1', LotNo);
        ReservEntry.ModifyAll("Qty. to Handle (Base)", 0, false);
        ReservEntry.ModifyAll("Qty. to Invoice (Base)", 0, false);
        RemainingQuantity := OutputQuantity;
        ReservEntry.SetRange("Lot No.", LotNo);
        if ReservEntry.FindSet(true) then
            repeat
                if ReservEntry."Qty. to Handle (Base)" >= OutputQuantity then begin
                    RemainingQuantity := 0;
                    ReservEntry.Validate("Qty. to Handle (Base)", OutputQuantity);
                    ReservEntry.Validate("Qty. to Invoice (Base)", OutputQuantity);
                end else begin
                    RemainingQuantity -= ReservEntry."Qty. to Handle (Base)";
                    ReservEntry.Validate("Qty. to Handle (Base)", OutputQuantity);
                    ReservEntry.Validate("Qty. to Invoice (Base)", OutputQuantity);
                end;
                ReservEntry.Modify(false);
            until (ReservEntry.Next() = 0) or (RemainingQuantity = 0);
        if RemainingQuantity <> 0 then
            this.Raise(this.BuildValidationError(ProdOrderLine.RecordId(), ProdOrderLine.FieldNo("Item No."), BadOutputMsg, StrSubstNo(BadOutputErr, LotNo)));
    end;

    /// <summary>
    /// Copies tracking from the production component to the complete consumption journal line.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line that receives tracking.</param>
    /// <param name="ProdOrderComp">Component providing source tracking.</param>
    local procedure ApplyItemTrackingToCompleteConsumption(var ItemJnlLine: Record "Item Journal Line"; ProdOrderComp: Record "Prod. Order Component")
    var
        ItemTrackingMgt: Codeunit "Item Tracking Management";
    begin
        ItemTrackingMgt.CopyItemTracking(ProdOrderComp.RowID1(), ItemJnlLine.RowID1(), false);
    end;

    /// <summary>
    /// Validates consumption quantity respecting item rounding precision.
    /// </summary>
    /// <param name="ItemJnlLine">Journal line to validate.</param>
    /// <param name="NeededQty">Quantity to apply.</param>
    /// <param name="Item">Item record supplying rounding settings.</param>
    /// <param name="IgnoreRoundingPrecision">Whether to bypass rounding validation.</param>
    local procedure ConsumptionItemJnlLineValidateQuantity(var ItemJnlLine: Record "Item Journal Line"; NeededQty: Decimal; Item: Record Item; IgnoreRoundingPrecision: Boolean)
    var
        UOMMgt: Codeunit "Unit of Measure Management";
    begin
        if NeededQty <> 0 then
            if (Item."Rounding Precision" > 0) and not IgnoreRoundingPrecision then
                ItemJnlLine.Validate(Quantity, UOMMgt.RoundToItemRndPrecision(NeededQty, Item."Rounding Precision"))
            else
                ItemJnlLine.Validate(Quantity, Round(NeededQty, UOMMgt.QtyRndPrecision()));
    end;

    /// <summary>
    /// Inserts a temporary production component record with lot split and consumption tracking fields.
    /// </summary>
    /// <param name="Rec">Temporary buffer to insert into.</param>
    /// <param name="ProdOrderComponent">Source component line.</param>
    /// <param name="LotNo">Lot number assigned.</param>
    /// <param name="RemQuantityLot">Remaining quantity for this lot split.</param>
    /// <param name="LineIncrement">Increment to derive the new line number.</param>
    local procedure InsertComponentRecord(var Rec: Record "Prod. Order Component" temporary; ProdOrderComponent: Record "Prod. Order Component"; LotNo: Text[50]; RemQuantityLot: Decimal; LineIncrement: Integer)
    begin
        if RemQuantityLot = 0 then
            exit;
        Rec."APA MADCS Original Line No." := ProdOrderComponent."Line No.";
        Rec."Line No." := ProdOrderComponent."Line No." + LineIncrement;
        Rec."APA MADCS Lot No." := LotNo;
        Rec.CalcFields("APA MADCS Consumed Quantity");
        Rec."APA MADCS Quantity" := RemQuantityLot + Rec."APA MADCS Consumed Quantity";
        Rec."APA MADCS Qty. After Consump." := Rec."APA MADCS Quantity" - Rec."APA MADCS Consumed Quantity";
        Rec.Insert(false);
    end;

    /// <summary>
    /// Checks whether basic conditions are met to verify closing a production order.
    /// </summary>
    /// <param name="ProductionOrder">Production order to evaluate.</param>
    /// <returns name="CanVerify">True when the order can be evaluated for closing.</returns>
    local procedure PuedoVerificarCierreOrden(var ProductionOrder: Record "Production Order"): Boolean
    var
        lrProdOrderComponents: Record "Prod. Order Component";
        lrProdOrderLines: Record "Prod. Order Line";
        decConsums: Decimal;
        decQuantity: Decimal;
    begin
        // DAA - Desactivo por ahora el control de fechas
        //if ProductionOrder."Ending Date-Time" >= CurrentDateTime then // DAA - No cierro las órdenes antes de tiempo, siempre con un día de retraso
        //    exit(false);

        if ProductionOrder.Status <> ProductionOrder.Status::Released then
            exit(false);

        if not ProductionOrder."APA MADCS Can be finished" then
            exit(false);

        decConsums := 0;
        decQuantity := 0;
        Clear(lrProdOrderLines);
        lrProdOrderLines.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderLines.SetRange(Status, ProductionOrder.Status);
        lrProdOrderLines.SetRange("Prod. Order No.", ProductionOrder."No.");
        lrProdOrderLines.CalcSums("Finished Quantity", Quantity);

        Clear(lrProdOrderComponents);
        lrProdOrderComponents.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderComponents.SetRange(Status, ProductionOrder.Status);
        lrProdOrderComponents.SetRange("Prod. Order No.", ProductionOrder."No.");
        lrProdOrderComponents.SetAutoCalcFields("Act. Consumption (Qty)");
        if lrProdOrderComponents.FindSet(false) then
            repeat
                decConsums += lrProdOrderComponents."Act. Consumption (Qty)";
                decQuantity += lrProdOrderComponents."Expected Quantity";
            until lrProdOrderComponents.Next() = 0;

        exit((lrProdOrderLines."Finished Quantity" = lrProdOrderLines.Quantity) or (decConsums = decQuantity));
    end;

    /// <summary>
    /// Comprobar si es posible cerrar la orden evaluando tolerancias, consumos y actividades.
    /// </summary>
    /// <param name="pTextoErrores">Array where error messages are returned.</param>
    /// <param name="i">Index of the last message stored.</param>
    /// <param name="ProductionOrder">Production order under evaluation.</param>
    [TryFunction]
    local procedure EsPosibleCerrarOrden(var pTextoErrores: array[100] of Text; var i: Integer; ProductionOrder: Record "Production Order")
    var
        lrManufacturingSetup: Record "Manufacturing Setup";
        lrProdOrderLine: Record "Prod. Order Line";
        lrProdOrderComponent: Record "Prod. Order Component";
        lenumCierre: Enum "APA MADCS Cierre Orden";
        lbHayLineas: Boolean;
    begin
        // DAA - Verificar que se cumplen las condiciones necesarias para cerrar la orden
        if not lrManufacturingSetup.Get() then
            this.Raise(this.BuildApplicationError(this.ManufacturingSetupMissMsg, this.ManufacturingSetupErr));

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
    /// Validates component consumption for a production order line.
    /// </summary>
    /// <param name="ProdOrderLine">Line context.</param>
    /// <param name="ProdOrderComponent">Component recordset.</param>
    /// <param name="ErrorMessages">Error array.</param>
    /// <param name="MessageIndex">Current message index.</param>
    local procedure ValidateComponentsForLine(ProdOrderLine: Record "Prod. Order Line"; var ProdOrderComponent: Record "Prod. Order Component"; var ErrorMessages: array[100] of Text; var MessageIndex: Integer)
    var
        CierreEnum: Enum "APA MADCS Cierre Orden";
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
        CierreEnum: Enum "APA MADCS Cierre Orden";
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
        CierreEnum: Enum "APA MADCS Cierre Orden";
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
        CierreEnum: Enum "APA MADCS Cierre Orden";
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
    /// Logs close attempt results for a production order, recording all validation messages.
    /// </summary>
    /// <param name="ProductionOrder">Production order being evaluated.</param>
    /// <param name="pTextoErrores">Array of validation messages.</param>
    /// <param name="i">Number of messages recorded.</param>
    local procedure AnotarCierreOrden(ProductionOrder: Record "Production Order"; pTextoErrores: array[10] of Text; i: Integer)
    var
        lrDCErroresCierreOrden: Record "DC Errores Cierre Orden";
        lenumCierre: Enum "APA MADCS Cierre Orden";
        j: Integer;
        ltxtMsgOkLbl: Label 'Attempt to close production order %1', Comment = 'ESP="%1 Intento de cierre de orden de producción"';
        ltxtMsgErrorErr: Label '%1 I cannot close the order due to %2', Comment = 'ESP="%1 No puedo cerrar la orden por %2"';
    begin
        Clear(lrDCErroresCierreOrden);
        lrDCErroresCierreOrden.SetCurrentKey(Status, "Production Order No.", "Line No.");
        lrDCErroresCierreOrden.SetRange(Status, ProductionOrder.Status);
        lrDCErroresCierreOrden.SetRange("Production Order No.", ProductionOrder."No.");
        lrDCErroresCierreOrden.DeleteAll(true);
        Commit();  // Cierra la transacción, ya no necesito los menajes anteriores
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
    local procedure ShouldAbortClose(i: Integer; ltxtCierre: array[100] of Text; lenumCierre: Enum "APA MADCS Cierre Orden"): Boolean
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
    local procedure ShouldShowCloseErrors(pbMostrarError: Boolean; i: Integer; ltxtCierre: array[100] of Text; lenumCierre: Enum "APA MADCS Cierre Orden"): Boolean
    begin
        exit(pbMostrarError and ((i <> 1) or (ltxtCierre[i] <> Format(lenumCierre::Correcto))));
    end;

    /// <summary>
    /// Determine if the production order can be finished.
    /// </summary>
    /// <param name="ltxtCierre">Result messages.</param>
    /// <param name="lenumCierre">Enum defining close outcomes.</param>
    /// <returns name="ShouldFinish">Boolean.</returns>
    local procedure ShouldFinishOrder(ltxtCierre: array[100] of Text; lenumCierre: Enum "APA MADCS Cierre Orden"): Boolean
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

    #endregion local procedures
}
