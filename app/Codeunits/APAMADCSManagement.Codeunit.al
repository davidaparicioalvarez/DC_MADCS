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
        tabledata "DC Tolerancias Admitidas" = r,
        tabledata "Capacity Unit of Measure" = r;

    var
        CurrentOperatorCode: Code[20];
        Logged: Boolean;
        ManufacturingSetupMissMsg: Label 'Manufacturing Setup Missing', Comment = 'ESP="Falta la configuración de fabricación"';
        ManufacturingSetupErr: Label 'The Manufacturing Setup record is missing. Please set it up before posting consumption.', Comment = 'ESP="Falta el registro de Configuración de Fabricación. Por favor, configúrelo antes de registrar el consumo."';
        TaskErr: Label 'Task error', Comment = 'ESP="Error en la tarea"';
        TaskTextErr: Label 'There is a later task already started for this production order. You cannot start preparation task.', Comment = 'ESP="Ya hay una tarea posterior iniciada para esta orden de producción. No puede iniciar la tarea."';
        UserNotFoundMsg: Label 'Operator %1 not found in ADCS users.', Comment = 'ESP="El operador %1 no se encuentra en los usuarios ADCS."';

    #region procedures

    /// <summary>
    /// Checks if the production order is marked for component consumption.
    /// Components can be consumed when output is finished.
    /// </summary>
    /// <param name="ProdOrderComponent">Production order component to evaluate.</param>
    /// <param name="OperatorCode">Operator code (currently unused in validation).</param>
    /// <returns name="IsMarked">Boolean indicating if the production order is ready for consumption (output finished).</returns>
    procedure IsMarkedForConsume(ProdOrderComponent: Record "Prod. Order Component"; OperatorCode: Code[20]): Boolean
    var
        ProdOrder: Record "Production Order";
    begin
        Clear(ProdOrder);
        if ProdOrder.Get(ProdOrderComponent.Status, ProdOrderComponent."Prod. Order No.") then
            exit(ProdOrder."APA MADCS Output finished");

        exit(false);
    end;

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
            Message(this.UserNotFoundMsg, OperatorCode);
            exit(false);
        end;

        // Validate password
        if ADCSUser."APA MADCS Password" <> Password then begin
            Message(this.UserNotFoundMsg, OperatorCode);
            exit(false);
        end;

        // Store operator code globally
        this.SetOperatorCode(OperatorCode);
        exit(true);
    end;

    /// <summary>
     /// Gets the current operator code for logging and tracking purposes.
    /// Triggers login if not already logged in.
    /// </summary>
    /// <returns name="OperatorCode">Current operator code, or empty string if login fails.</returns>
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
    procedure PostOutput(var ProdOrderLine: Record "Prod. Order Line"; OutputQuantity: Decimal; LotNo: Code[50])
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
        this.SetupOutputJournalLine(ItemJnlLine, ProdOrderLine, ItemJnlTemplate, ItemJnlBatch, OutputQuantity);

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
    /// Validates that the provided record is temporary and deletes all its records.
    /// Ensures data integrity by verifying temporary table status before deletion.
    /// </summary>
    /// <param name="Rec">Temporary production order component record to validate and clear.</param>
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
    /// Loads production order components into the temporary record for warehouse consumption.
    /// Filters components by item number and picking service type, then processes each for tracking.
    /// </summary>
    /// <param name="Rec">Temporary record to populate with filtered components.</param>
    /// <param name="ProdOrderComponent">Source production order component record with filters applied.</param>
    /// <param name="ItemNo">Item number to filter components.</param>
    /// <param name="QuienSirvePickingOP">Picking service type to filter components.</param>
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
    /// Loads production order components into the temporary record for validation purposes.
    /// Processes all components for the production order including item tracking splits.
    /// </summary>
    /// <param name="Rec">Temporary record to populate with production order components.</param>
    /// <param name="ProdOrderComponent">Source production order component record with production order filter applied.</param>
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
    /// Processes the preparation or cleaning task based on the provided button id.
    /// Creates and logs the corresponding activity for the production order line.
    /// </summary>
    /// <param name="id">Button identifier to determine which task to process.</param>
    /// <param name="pProdOrderStatus">Production order status.</param>
    /// <param name="pProdOrder">Production order number.</param>
    /// <param name="pProdOrderLine">Production order line number.</param>
    /// <param name="OperatorCode">Operator code performing the task.</param>
    procedure ProcessPreparationCleaningTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        case id of
            Format(Enum::"APA MADCS Buttons"::ALButtonPreparationTok):
                begin
                    if this.LaterTaskExists(pProdOrderStatus, pProdOrder, pProdOrderLine, Enum::"APA MADCS Journal Type"::Preparation) then begin
                        this.Raise(this.BuildApplicationError(this.TaskErr, this.TaskTextErr));
                        exit;
                    end;
                    this.FinalizeAllActivitiesExcept(pProdOrderStatus, pProdOrder, OperatorCode, Enum::"APA MADCS Journal Type"::Preparation); // finalize for all operators except preparation
                    Activities.NewPreparationActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, '');
                end;
            Format(Enum::"APA MADCS Buttons"::ALButtonCleaningTok):
                begin
                    this.FinalizeAllActivitiesExcept(pProdOrderStatus, pProdOrder, OperatorCode, Enum::"APA MADCS Journal Type"::Cleaning); // finalize for all operators except cleaning
                    Activities.NewCleaningActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, '');
                end;
        end;
        this.LogAction(Activities, Enum::"APA MADCS Log Type"::Cleaning);
    end;

    /// <summary>
    /// Validates if cleaning can start for the given production order.
    /// Cleaning can only start after both consumption and output activities are finished.
    /// </summary>
    /// <param name="pProdOrderStatus">Production order status to validate.</param>
    /// <param name="pProdOrderCode">Production order number to validate.</param>
    /// <returns name="CanStart">Boolean indicating if cleaning can start (true when consumption and output are finished).</returns>
    procedure CleanCanStart(pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]): Boolean
    var
        ProductionOrder: Record "Production Order";
        NoProdOrderTitleMsg: Label 'Production Order', Comment = 'ESP="Orden de Producción"';
        NoProdOrderErr: Label 'Error Looking for Production Order.', Comment = 'ESP="Error al buscar la Orden de Producción."';
    begin
        // Cannot clean before all consumption and output activities are finished
        if not ProductionOrder.Get(pProdOrderStatus, pProdOrderCode) then
            this.Raise(this.BuildApplicationError(NoProdOrderTitleMsg, NoProdOrderErr));
        exit(ProductionOrder."APA MADCS Consumption finished" and ProductionOrder."APA MADCS Output finished");
    end;

    /// <summary>
    /// Validates if execution can start for the given production order.
    /// Execution cannot start after both consumption and output activities are finished.
    /// </summary>
    /// <param name="pProdOrderStatus">Production order status to validate.</param>
    /// <param name="pProdOrderCode">Production order number to validate.</param>
    /// <returns name="CanStart">Boolean indicating if execution can start (true when consumption and output are not finished).</returns>
    procedure ExecutionCanStart(pProdOrderStatus: Enum "Production Order Status"; pProdOrderCode: Code[20]): Boolean
    var
        ProductionOrder: Record "Production Order";
        NoProdOrderTitleMsg: Label 'Production Order', Comment = 'ESP="Orden de Producción"';
        NoProdOrderErr: Label 'Error Looking for Production Order.', Comment = 'ESP="Error al buscar la Orden de Producción."';
    begin
        // Cannot execution after all consumption and output activities are finished
        if not ProductionOrder.Get(pProdOrderStatus, pProdOrderCode) then
            this.Raise(this.BuildApplicationError(NoProdOrderTitleMsg, NoProdOrderErr));
        exit(not ProductionOrder."APA MADCS Consumption finished" and not ProductionOrder."APA MADCS Output finished");
    end;

    /// <summary>
    /// Processes the execution task and stops all other tasks for the production order.
    /// Ensures only one execution task is active at a time.
    /// </summary>
    /// <param name="id">Button identifier to determine which execution task to process.</param>
    /// <param name="pProdOrderStatus">Production order status.</param>
    /// <param name="pProdOrder">Production order number.</param>
    /// <param name="pProdOrderLine">Production order line number.</param>
    /// <param name="OperatorCode">Operator code performing the task.</param>
    /// <param name="BreakDownCode">Breakdown code if execution involves a fault.</param>
    procedure ProcessExecutionAndStopAllTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        case id of
            Format(Enum::"APA MADCS Buttons"::ALButtonExecutionTok):
                begin
                    if this.LaterTaskExists(pProdOrderStatus, pProdOrder, pProdOrderLine, Enum::"APA MADCS Journal Type"::Execution) then begin
                        this.Raise(this.BuildApplicationError(this.TaskErr, this.TaskTextErr));
                        exit;
                    end;
                    this.FinalizeAllActivitiesExcept(pProdOrderStatus, pProdOrder, OperatorCode, Enum::"APA MADCS Journal Type"::Execution); // finalize for all operators except execution
                    this.FinalizeLastActivity(OperatorCode); // only for execution tasks
                    Activities.NewExecutionActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);
                    this.LogAction(Activities, Enum::"APA MADCS Log Type"::Execution)
                end;
            Format(Enum::"APA MADCS Buttons"::ALButtonEndTok):
                begin
                    this.FinalizeAllActivities(pProdOrderStatus, pProdOrder);
                    this.LogAction(Activities, Enum::"APA MADCS Log Type"::StopTime);
                end;
            else
                this.LogAction(Activities, Enum::"APA MADCS Log Type"::StopTime);
        end;
    end;

    /// <summary>
    /// Stops the current task for the operator.
    /// Finalizes the active task and posts time consumption.
    /// </summary>
    /// <param name="id">Button identifier to determine which task to stop.</param>
    /// <param name="pProdOrderStatus">Production order status.</param>
    /// <param name="pProdOrder">Production order number.</param>
    /// <param name="pProdOrderLine">Production order line number.</param>
    /// <param name="OperatorCode">Operator code whose task should be stopped.</param>
    /// <param name="BreakDownCode">Breakdown code if task involves a fault.</param>
    procedure StopMyTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        case id of
            Format(Enum::"APA MADCS Buttons"::ALButtonFinalizeMyTaskTok):
                begin
                    this.FinalizeLastActivity(OperatorCode); // only for execution tasks
                    this.LogAction(Activities, Enum::"APA MADCS Log Type"::Execution)
                end;
        end;
    end;

    /// <summary>
    /// Processes the breakdown and blocked breakdown tasks.
    /// Validates that breakdown code matches any existing active fault and ensures correct button usage for blocking vs non-blocking codes.
    /// </summary>
    /// <param name="id">Button identifier to determine which breakdown task to process.</param>
    /// <param name="pProdOrderStatus">Production order status.</param>
    /// <param name="pProdOrder">Production order number.</param>
    /// <param name="pProdOrderLine">Production order line number.</param>
    /// <param name="OperatorCode">Operator code performing the breakdown task.</param>
    /// <param name="BreakDownCode">Breakdown code identifying the specific fault.</param>
    procedure ProcessBreakdownAndBlockedBreakdownTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20]; BreakDownCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
        ActualBreakDownCode: Code[20];
        BlockedBreakDownLbl: Label 'Stop code is blocking, for this stop code you should use the Blocked Breakdown button', Comment = 'ESP="El código de avería es bloqueante, para este código de paro debe usar el botón de Avería Bloqueante"';
        NoBlockedBreakDownLbl: Label 'Stop code is not blocking, for this stop code you should use the Execution with fault button', Comment = 'ESP="El código de avería no es bloqueante, para este código de paro debe usar el botón de Ejecución con avería"';
        BreakdownDifferentLbl: Label 'A different breakdown code is already registered for this production order. Please finalize it before registering a new one.', Comment = 'ESP="Ya hay un código de avería diferente registrado para esta orden de producción. Por favor, finalícelo antes de registrar uno nuevo."';
        BreakDownLbl: Label 'Breakdown', Comment = 'ESP="Avería"';
    begin
        ActualBreakDownCode := this.CurrenFaultTaskBreakdownCode(pProdOrderStatus, pProdOrder, pProdOrderLine);
        if (ActualBreakDownCode <> '') and (ActualBreakDownCode <> BreakDownCode) then
            this.Raise(this.BuildApplicationError(BreakDownLbl, BreakdownDifferentLbl));
        case id of
            Format(Enum::"APA MADCS Buttons"::ALButtonBreakdownTok): // NON BLOCKING FAULT
                if not Activities.BreakDownCodeIsBlocking(BreakDownCode) then begin
                    this.FinalizeAllActivitiesExcept(pProdOrderStatus, pProdOrder, OperatorCode, Enum::"APA MADCS Journal Type"::"Execution with Fault"); // for all operators
                    Activities.NewFaultActivity(id, pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);
                    this.LogAction(Activities, Enum::"APA MADCS Log Type"::BreakDown);
                end else
                    this.Raise(this.BuildApplicationError(BreakDownLbl, BlockedBreakDownLbl));
            Format(Enum::"APA MADCS Buttons"::ALButtonBlockedBreakdownTok): // BLOCKING FAULT
                if Activities.BreakDownCodeIsBlocking(BreakDownCode) then begin
                    this.FinalizeAllActivities(pProdOrderStatus, pProdOrder); // for all operators
                    Activities.NewFaultActivity(id, pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode, BreakDownCode);
                    this.LogAction(Activities, Enum::"APA MADCS Log Type"::Fault);
                end else
                    this.Raise(this.BuildApplicationError(BreakDownLbl, NoBlockedBreakDownLbl));
        end;
    end;

    /// <summary>
    /// Finds lot numbers assigned to the production order line and lets the user pick one.
    /// </summary>
    /// <param name="ProdOrderLine">Production order line to filter reservation entries.</param>
    /// <param name="LotNo">Selected lot number.</param>
    /// <param name="ShowPage">Boolean indicating whether to show the selection page.</param>
    /// <returns name="Found">True when a lot was selected.</returns>
    internal procedure FindLotNoForOutput(ProdOrderLine: Record "Prod. Order Line"; var LotNo: Code[50]; ShowPage: Boolean): Boolean
    var
        ReservationEntries: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        ProdOrderLineReserve: Codeunit "Prod. Order Line-Reserve";
        ItemTrackingLines: Page "Item Tracking Lines";
        APAMADCSTrackingSpecification: Page "APA MADCS Track. Specification";

    begin
        // DAA - Mostrar la lista de lotes de la línea de la orden y seleccionar uno
        LotNo := '';
        Clear(TrackingSpecification);
        Clear(TempTrackingSpecification);
        TempTrackingSpecification.DeleteAll(false);

        ProdOrderLineReserve.InitFromProdOrderLine(TrackingSpecification, ProdOrderLine);
        ProdOrderLineReserve.FindReservEntry(ProdOrderLine, ReservationEntries);
        if not ShowPage then begin
            if ReservationEntries.FindFirst() then begin
                LotNo := ReservationEntries."Lot No.";
                exit(LotNo <> '');
            end;
        end else begin
            ItemTrackingLines.SetSourceSpec(TrackingSpecification, ProdOrderLine."Due Date");
            ItemTrackingLines.GetTrackingSpec(TempTrackingSpecification);

            Clear(APAMADCSTrackingSpecification);
            APAMADCSTrackingSpecification.InitializeTrackingData(TempTrackingSpecification);
            APAMADCSTrackingSpecification.LookupMode(true);
            if APAMADCSTrackingSpecification.RunModal() = Action::LookupOK then begin
                APAMADCSTrackingSpecification.GetSelectedTrackingSpec(TempTrackingSpecification);
                LotNo := TempTrackingSpecification."Lot No.";
                exit(LotNo <> '');
            end;
        end;
        exit(false);
    end;

    /// <summary>
    /// Marks the production order as output finished.
    /// Sets the APA MADCS Output finished flag to true.
    /// </summary>
    /// <param name="ProdOrderLine">Production order line providing the production order reference.</param>
    /// <returns name="Success">Boolean indicating if the operation was successful.</returns>
    internal procedure MarkProductionOrderAsOutputFinished(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ProdOrder: Record "Production Order";
    begin
        if ProdOrder.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.") then begin
            ProdOrder."APA MADCS Output finished" := true;
            ProdOrder.Modify(true);
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Marks the production order as time finished and triggers production order closure.
    /// Validates that both consumption and output are finished before marking time as finished.
    /// </summary>
    /// <param name="ProdOrderLine">Production order line providing the production order reference.</param>
    /// <returns name="Success">Boolean indicating if the operation was successful.</returns>
    internal procedure MarkProductionOrderAsTimeFinished(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ProdOrder: Record "Production Order";
        ManufacturingSetup: Record "Manufacturing Setup";
        APAMADCSProOrdCloseErr: Interface "IAPA MADCS Pro. Ord. Close Err";
    begin
        Clear(ManufacturingSetup);
        if not ManufacturingSetup.Get() then
            this.Raise(this.BuildApplicationError(this.ManufacturingSetupMissMsg, this.ManufacturingSetupErr));
        if ProdOrder.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.") then begin
            ProdOrder.TestField("APA MADCS Consumption finished");
            ProdOrder.TestField("APA MADCS Output finished");
            ProdOrder."APA MADCS Time finished" := true;
            ProdOrder.Modify(true);
            APAMADCSProOrdCloseErr := ManufacturingSetup."APA MADCS Pro. Ord. Close Impl";
            APAMADCSProOrdCloseErr.APAMADCSCloseProductionOrder(ProdOrder, true);
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Marks the production order as consumption finished and automatically initiates cleaning task.
    /// Sets the APA MADCS Consumption finished flag and processes cleaning preparation.
    /// </summary>
    /// <param name="ProdOrderComponent">Production order component providing the production order reference.</param>
    /// <returns>Boolean indicating if the operation was successful.</returns>
    internal procedure MarkProductionOrderAsConsumptionFinished(ProdOrderComponent: Record "Prod. Order Component"): Boolean
    var
        ProdOrder: Record "Production Order";
    begin
        if ProdOrder.Get(ProdOrderComponent.Status, ProdOrderComponent."Prod. Order No.") then begin
            ProdOrder."APA MADCS Consumption finished" := true;
            ProdOrder.Modify(true);
            this.ProcessPreparationCleaningTask(Format(Enum::"APA MADCS Buttons"::ALButtonCleaningTok), ProdOrderComponent.Status, ProdOrderComponent."Prod. Order No.", ProdOrderComponent."Prod. Order Line No.", this.GetOperatorCode());
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// procedure UpdatePickingStatusForReleasedProdOrders
    /// Review all released production orders and update their picking status if needed
    /// </summary>
    internal procedure UpdatePickingStatusForReleasedProdOrders()
    var
        ProductionOrder: Record "Production Order";
    begin
        // Loop through all released production orders
        Clear(ProductionOrder);
        ProductionOrder.SetCurrentKey(Status, "No.");
        ProductionOrder.SetRange(Status, ProductionOrder.Status::Released);
        if ProductionOrder.FindSet(true) then
            repeat
                // Update the picking status as needed
                ProductionOrder.UpdatePickingStatusField(true);
            until ProductionOrder.Next() = 0;
    end;

    /// <summary>
    /// Retrieves the current active task for the given operator code.
    /// If no active task is found, returns the default enum value.
    /// </summary>
    /// <param name="OperatorCode">Operator code to filter active tasks.</param>
    /// <returns name="TaskType">Current active task type, or default value if no active task exists.</returns>
    internal procedure CurrentTask(OperatorCode: Code[20]): Enum "APA MADCS Journal Type"
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        // Find my current activity and stop it
        // Consume time used in recent stopped activity
        Clear(Activities);
        Activities.SetCurrentKey("Operator Code");
        Activities.SetRange(Posted, false);
        Activities.SetRange("Operator Code", OperatorCode);
        if Activities.FindFirst() then
            exit(Activities.Action);
    end;

    /// <summary>
    /// Retrieves the timer interval for refreshing the picking status of production orders.
    /// Converts the configured interval from seconds to milliseconds.
    /// </summary>
    /// <returns name="IntervalMs">Timer interval in milliseconds for production order status refresh.</returns>
    internal procedure GetTimerInterval(): Integer
    var
        ManufacturingSetup: Record "Manufacturing Setup";
    begin
        Clear(ManufacturingSetup);
        if not ManufacturingSetup.Get() then
            this.Raise(this.BuildApplicationError(this.ManufacturingSetupMissMsg, this.ManufacturingSetupErr));
        ManufacturingSetup.TestField("APA MADCS Timer Interval");
        exit(ManufacturingSetup."APA MADCS Timer Interval" * 1000); // Convert seconds to milliseconds
    end;

    /// <summary>
    /// Retrieves the center group (Agrupacion Centros) for a production order.
    /// </summary>
    /// <param name="MyStatus">Production order status to filter.</param>
    /// <param name="MyProdOrdeNo">Production order number to retrieve.</param>
    /// <returns name="CenterGroup">Center group text with asterisks removed, or empty string if not found.</returns>
    internal procedure GetProdOrderCenterGroup(MyStatus: Enum "Production Order Status"; MyProdOrdeNo: Code[20]): Text
    var
        ProductionOrder: Record "Production Order";
    begin
        Clear(ProductionOrder);
        if ProductionOrder.Get(MyStatus, MyProdOrdeNo) then
            exit(DelChr(ProductionOrder."Agrupacion Centros", '=', '*'));
        exit('');
    end;

    /// <summary>
    /// Updates the "APA MADCS Picking Status" field based on the picking status of production order components.
    /// Evaluates component picking completion and sets status to Totaly Picked, Partialy Picked, or Pending.
    /// </summary>
    /// <param name="ProductionOrder">Production order record to evaluate and update.</param>
    /// <param name="save">Boolean indicating whether to save the changes to the database.</param>
    procedure UpdatePickingStatusField(var ProductionOrder: Record "Production Order"; save: Boolean)
    var
        lrProdOrderComponent: Record "Prod. Order Component";
        lineasTotales: Integer;
    begin
        Clear(ProductionOrder."APA MADCS Picking Status");
        Clear(lrProdOrderComponent);
        lrProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderComponent.SetRange(Status, ProductionOrder.Status);
        lrProdOrderComponent.SetRange("Prod. Order No.", ProductionOrder."No.");
        lineasTotales := lrProdOrderComponent.Count();
        lrProdOrderComponent.SetRange("Completely Picked", false);
        if lrProdOrderComponent.IsEmpty() then begin
            ProductionOrder."APA MADCS Picking Status" := ProductionOrder."APA MADCS Picking Status"::"Totaly Picked";
            if save then
                ProductionOrder.Modify(true);
        end else
            if (lrProdOrderComponent.Count() <> lineasTotales) then begin
                ProductionOrder."APA MADCS Picking Status" := ProductionOrder."APA MADCS Picking Status"::"Partialy Picked";
                if save then
                    ProductionOrder.Modify(true);
            end else begin
                ProductionOrder.CalcFields("RPO No. Picking");
                if (ProductionOrder."RPO No. Picking" <> '') then begin
                    ProductionOrder."APA MADCS Picking Status" := ProductionOrder."APA MADCS Picking Status"::Pending;
                    if save then
                        ProductionOrder.Modify(true);
                end
            end;
    end;

    /// <summary>
    /// Retrieves the task number configured for a specific manufacturing journal type.
    /// Maps journal types (Preparation, Cleaning, Execution) to their corresponding task codes in manufacturing setup.
    /// </summary>
    /// <param name="APAMADCSJournalType">Journal type to retrieve task data for (Preparation, Cleaning, or Execution).</param>
    /// <returns name="TaskNo">Task number configured in Manufacturing Setup for the specified journal type.</returns>
    procedure GetManufacturingSetupTaskData(APAMADCSJournalType: Enum "APA MADCS Journal Type") TaskNo: Code[10]
    var
        ManufacturingSetup: Record "Manufacturing Setup";
    begin
        Clear(ManufacturingSetup);
        if not ManufacturingSetup.Get() then
            this.Raise(this.BuildApplicationError(this.ManufacturingSetupMissMsg, this.ManufacturingSetupErr));

        ManufacturingSetup.TestField("APA MADCS Preparation Task");
        ManufacturingSetup.TestField("APA MADCS Cleaning Task");
        ManufacturingSetup.TestField("APA MADCS Execution Task");

        case APAMADCSJournalType of
            "APA MADCS Journal Type"::Preparation:
                TaskNo := ManufacturingSetup."APA MADCS Preparation Task";
            "APA MADCS Journal Type"::Cleaning:
                TaskNo := ManufacturingSetup."APA MADCS Cleaning Task";
            "APA MADCS Journal Type"::Execution,
            "APA MADCS Journal Type"::"Execution with Fault":
                TaskNo := ManufacturingSetup."APA MADCS Execution Task";
        end;

        exit(TaskNo);
    end;

    /// <summary>
    /// Retrieves the current active activity for the given operator code.
    /// If no active task is found, raises an error.
    /// </summary>
    /// <param name="OperatorCode">Operator code to filter active tasks.</param>
    /// <param name="Activity">Output parameter containing the active activity record for the operator.</param>
    procedure GetMyActualActivity(OperatorCode: Code[20]; var Activity: Record "APA MADCS Pro. Order Line Time")
    var
        NoActiveTaskTitleMsg: Label 'No active task', Comment = 'ESP="No hay tarea activa"';
        NoActiveTaskErr: Label 'No active task found for the operator.', Comment = 'ESP="No se encontró una tarea activa para el operario."';
    begin
        Clear(Activity);
        Activity.SetCurrentKey("Operator Code");
        Activity.SetRange(Posted, false);
        Activity.SetRange("Operator Code", OperatorCode);
        if Activity.FindFirst() then
            exit
        else
            this.Raise(this.BuildApplicationError(NoActiveTaskTitleMsg, NoActiveTaskErr));
    end;
    #endregion procedures

    #region local procedures
    /// <summary>
    /// Calculates the time duration between start and end date times based on the specified unit of measure.
    /// Converts milliseconds to the target unit (Minutes, Hours, Days, Seconds, or 100/Hour).
    /// </summary>
    /// <param name="Activity">Activity record containing start and end date time.</param>
    /// <param name="UnitOfMeasure">Unit of measure code to determine conversion (Minutes, Hours, Days, Seconds, 100/Hour).</param>
    /// <returns name="Time">Calculated time duration in the specified unit of measure.</returns>
    internal procedure TimeUsed(Activity: Record "APA MADCS Pro. Order Line Time"; UnitOfMeasure: Code[10]) Time: Decimal
    var
        CapUnitOfMeasure: Record "Capacity Unit of Measure";
        Duration: Decimal;
    begin
        if not CapUnitOfMeasure.Get(UnitOfMeasure) then
            this.Raise(this.BuildApplicationError('Invalid Unit of Measure', 'The provided unit of measure is not valid.'));

        if Activity."End Date Time" = 0DT then
            Duration := 0
        else
            Duration := (Activity."End Date Time" - Activity."Start Date Time") / 1000;

        case CapUnitOfMeasure.Type of
            CapUnitOfMeasure.Type::" ":
                Time := Duration / 60; // Default to minutes when no type is specified
            CapUnitOfMeasure.Type::"100/Hour":
                Time := Duration / 60 / 60 * 100;
            CapUnitOfMeasure.Type::Days:
                Time := Duration / 60 / 60 / 24;
            CapUnitOfMeasure.Type::Hours:
                Time := Duration / 60 / 60;
            CapUnitOfMeasure.Type::Minutes:
                Time := Duration / 60;
            CapUnitOfMeasure.Type::Seconds:
                Time := Duration;
        end;

        exit(Time);
    end;

    /// <summary>
    /// Retrieves the machine center code configured for the current ADCS user.
    /// </summary>
    /// <param name="MachineCenterCode">Output parameter containing the machine center code from ADCS User setup.</param>
    /// <returns name="Success">Boolean indicating if the machine center was successfully retrieved.</returns>
    local procedure GetMachineCenterCode(var MachineCenterCode: Code[20]): Boolean
    var
        ADCSUser: Record "ADCS User";
        BadConfigurationMsg: Label 'Bad Configuration', Comment = 'ESP="Configuración incorrecta"';
        OperatorCode: Code[20];
    begin
        // Validate operator code exists in ADCS User table
        OperatorCode := this.GetOperatorCode();
        Clear(ADCSUser);
        if not ADCSUser.Get(OperatorCode) then begin
            this.Raise(this.BuildApplicationError(BadConfigurationMsg, StrSubstNo(this.UserNotFoundMsg, OperatorCode)));
            exit(false);
        end;

        ADCSUser.TestField("APA MADCS Machine Center");
        MachineCenterCode := ADCSUser."APA MADCS Machine Center";

        exit(true);
    end;

    /// <summary>
    /// Retrieves the breakdown code from the current fault or execution with fault task for a production order line.
    /// </summary>
    /// <param name="pProdOrderStatus">Production order status to filter.</param>
    /// <param name="pProdOrder">Production order number to filter.</param>
    /// <param name="pProdOrderLine">Production order line number to filter.</param>
    /// <returns name="BreakdownCode">The breakdown code from the active fault task, or empty string if none found.</returns>
    local procedure CurrenFaultTaskBreakdownCode(pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer): Code[20]
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        Clear(Activities);
        Activities.SetCurrentKey(Status, "Prod. Order No.", "Prod. Order Line No.");
        Activities.SetRange(Status, pProdOrderStatus);
        Activities.SetRange("Prod. Order No.", pProdOrder);
        Activities.SetRange("Prod. Order Line No.", pProdOrderLine);
        Activities.SetRange(Posted, false);
        Activities.SetFilter(Action, '%1|%2', Enum::"APA MADCS Journal Type"::Fault, Enum::"APA MADCS Journal Type"::"Execution with Fault");
        if Activities.FindFirst() then
            exit(Activities."BreakDown Code");
        exit('');
    end;

    /// <summary>
    /// Checks if there are later tasks (activities with higher priority) already registered for a production order line.
    /// This prevents starting earlier tasks when subsequent tasks have already been initiated.
    /// </summary>
    /// <param name="pProdOrderStatus">Production order status to filter.</param>
    /// <param name="pProdOrder">Production order number to filter.</param>
    /// <param name="pProdOrderLine">Production order line number to filter.</param>
    /// <param name="APAMADCSJournalType">Journal type to evaluate for later tasks.</param>
    /// <returns name="Exists">True if later tasks exist, preventing the current task from starting.</returns>
    local procedure LaterTaskExists(pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; APAMADCSJournalType: Enum "APA MADCS Journal Type"): Boolean
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        Clear(Activities);
        Activities.SetCurrentKey(Status, "Prod. Order No.", "Prod. Order Line No.");
        Activities.SetRange(Status, pProdOrderStatus);
        Activities.SetRange("Prod. Order No.", pProdOrder);
        Activities.SetRange("Prod. Order Line No.", pProdOrderLine);
        Activities.SetRange(Posted, false);
        case APAMADCSJournalType of
            Enum::"APA MADCS Journal Type"::Preparation:
                Activities.SetFilter(Action, '>%1', Enum::"APA MADCS Journal Type"::Preparation);
            Enum::"APA MADCS Journal Type"::Execution,
            Enum::"APA MADCS Journal Type"::"Execution with Fault":
                Activities.SetFilter(Action, '>%1', Enum::"APA MADCS Journal Type"::"Execution with Fault");
            Enum::"APA MADCS Journal Type"::Cleaning:
                Activities.SetFilter(Action, '>%1', Enum::"APA MADCS Journal Type"::Cleaning);
            Enum::"APA MADCS Journal Type"::Fault:
                exit(false);
        end;
        exit(not Activities.IsEmpty());
    end;

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
        Activities.SetRange(Posted, false);
        Activities.SetRange("Operator Code", OperatorCode);
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
    /// Finalizes all active tasks for a production order status and number.
    /// </summary>
    /// <param name="pProdOrderStatus">Production order status to filter.</param>
    /// <param name="pProdOrder">Production order number to filter.</param>
    /// <param name="OperatorCode">Operator identifier to filter activities.</param>
    /// <param name="ActivityToExclude">Activity type to exclude from finalization.</param>
    local procedure FinalizeAllActivitiesExcept(pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; OperatorCode: Code[20]; ActivityToExclude: Enum "APA MADCS Journal Type")
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        // Find my current activity and stop it
        // Consume time used in recent stopped activity
        Clear(Activities);
        Activities.SetCurrentKey(Status, "Prod. Order No.");
        Activities.SetRange(Status, pProdOrderStatus);
        Activities.SetRange("Prod. Order No.", pProdOrder);
        Activities.SetFilter("Action", '<>%1', ActivityToExclude);
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
        this.FinalizeLastActivity(OperatorCode); // finalize for the operator that is starting a new task
    end;

    /// <summary>
    /// Posts a capacity journal line based on the provided activity.
    /// </summary>
    /// <param name="Activities">Activity record containing time and order context.</param>
    local procedure PostCapacityJournalLine(Activities: Record "APA MADCS Pro. Order Line Time")
    var
        ItemJournalLine: Record "Item Journal Line";
        PostItemJnlLine: Codeunit "Item Jnl.-Post Line";
    //MachineCenter: Code[20];
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
        ItemJournalLine.Validate("Posting Date", Activities."End Date Time".Date());
        //this.GetMachineCenterCode(MachineCenter);
        //ItemJournalLine.Validate(Type, ItemJournalLine.Type::"Machine Center");
        //ItemJournalLine.Validate("No.", MachineCenter);
        // Only one operation per production order line in MADCS
        case Activities.Action of
            "APA MADCS Journal Type"::Preparation,
            "APA MADCS Journal Type"::Cleaning:
                ItemJournalLine.Validate("Setup Time", this.TimeUsed(Activities, ItemJournalLine."Cap. Unit of Measure Code"));
            "APA MADCS Journal Type"::Execution:
                ItemJournalLine.Validate("Run Time", this.TimeUsed(Activities, ItemJournalLine."Cap. Unit of Measure Code"));
            "APA MADCS Journal Type"::"Execution with Fault":
                begin
                    ItemJournalLine.Validate("Run Time", this.TimeUsed(Activities, ItemJournalLine."Cap. Unit of Measure Code"));
                    ItemJournalLine.Validate("Stop Code", Activities.GetStopCode(Activities."BreakDown Code"));
                    ItemJournalLine.Validate("Stop Detail Code", Activities."BreakDown Code");
                end;
            "APA MADCS Journal Type"::Fault:
                ItemJournalLine.Validate("Stop Time", this.TimeUsed(Activities, ItemJournalLine."Cap. Unit of Measure Code"));
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
        Clear(ReservationEntry);
        ReservationEntry.SetPointer(ItemJnlLine.RowID1());
        ReservationEntry.SetPointerFilter();
        ReservationEntry.DeleteAll(false);
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
    local procedure SetupOutputJournalLine(var ItemJnlLine: Record "Item Journal Line"; ProdOrderLine: Record "Prod. Order Line"; ItemJnlTemplate: Record "Item Journal Template"; ItemJnlBatch: Record "Item Journal Batch"; OutputQuantity: Decimal)
    begin
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
        ItemJnlLine.Validate("Operation No.", GetLastOperationNo(ProdOrderLine));
        ItemJnlLine.Level := 0;
        ItemJnlLine."Flushing Method" := Enum::"Flushing Method"::Manual;
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
        ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
        ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
        ItemJnlLine.Validate("Output Quantity", OutputQuantity);
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
        BadOutputMsg: Label 'Bad Output', Comment = 'ESP="Salida incorrecta"';
        BadOutputErr: Label 'The output quantity exceeds the available tracked quantity for lot %1.', Comment = 'ESP="La cantidad de salida excede la cantidad rastreada disponible para el lote %1."';
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
    /// Gets the last operation number for a given production order line.
    /// </summary>
    /// <param name="ProdOrderLine"></param>
    /// <returns></returns>
    local procedure GetLastOperationNo(ProdOrderLine: Record "Prod. Order Line"): Code[10]
    var
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
    begin
        // DAA - Return the last operation number for the given production order line
        Clear(ProdOrderRoutingLine);
        ProdOrderRoutingLine.SetCurrentKey(Status, "Prod. Order No.", "Routing Reference No.", "Operation No.");
        ProdOrderRoutingLine.SetRange(Status, ProdOrderLine.Status);
        ProdOrderRoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ProdOrderRoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Line No.");
        if ProdOrderRoutingLine.FindLast() then
            exit(ProdOrderRoutingLine."Operation No.")
        else
            exit('');
    end;
    #endregion local procedures
}
