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
        tabledata "Manufacturing Setup" = r,
        tabledata "Item Journal Template" = r,
        tabledata "Item Journal Batch" = r,
        tabledata "Item Journal Line" = i,
        tabledata "Prod. Order Line" = r,
        tabledata "Prod. Order Routing Line" = r,
        tabledata "Reservation Entry" = rm,
        tabledata "APA MADCS Pro. Order Line Time" = rmid,
        tabledata "Item Tracking Code" = r;

    var
        CurrentOperatorCode: Code[20];
        Logged: Boolean;

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
        if ADCSUser."MADCS Password" <> Password then begin
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
        err: ErrorInfo;
        ErrNoPermissionPostConsumptionMsg: Label 'Permissions Error.', Comment = 'ESP="Error de permisos."';
        ErrNoPermissionPostConsumptionErr: Label 'You do not have permission to post consumptions.', Comment = 'ESP="No tiene permiso para registrar consumos."';
    begin
        // Validate user permissions
        if not this.HasADCSUserPermission() then begin
            err := this.BuildApplicationError(ErrNoPermissionPostConsumptionMsg, ErrNoPermissionPostConsumptionErr);
            this.Raise(err);
        end;

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
        err: ErrorInfo;
        NeededQty: Decimal;
        OriginalNeededQty: Decimal;
        ErrNoPermissionPostConsumptionMsg: Label 'Permissions Error.', Comment = 'ESP="Error de permisos."';
        ErrNoPermissionPostConsumptionErr: Label 'You do not have permission to post consumptions.', Comment = 'ESP="No tiene permiso para registrar consumos."';
    begin
        // Validate user permissions
        if not this.HasADCSUserPermission() then begin
            err := this.BuildApplicationError(ErrNoPermissionPostConsumptionMsg, ErrNoPermissionPostConsumptionErr);
            this.Raise(err);
        end;

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
    /// <param name="ProdOrderRoutingLine">Record "Prod. Order Routing Line"</param>
    /// <param name="OutputQuantity">Decimal quantity to post as output</param>
    procedure PostOutput(var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; OutputQuantity: Decimal)
    var
        Item: Record Item;
        ProdOrderLine: Record "Prod. Order Line";
        ItemJnlLine: Record "Item Journal Line";
        ManufacturingSetup: Record "Manufacturing Setup";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        PostItemJnlLine: Codeunit "Item Jnl.-Post Line";
        err: ErrorInfo;
        ErrNoPermissionPostOutputLbl: Label 'You do not have permission to post output.', Comment = 'ESP="No tiene permiso para registrar salida."';
        ErrNoPermissionPostOutputErr: Label 'You do not have permission to post output.', Comment = 'ESP="No tiene permiso para registrar salidas."';
    begin
        // Validate user permissions
        if not this.HasADCSUserPermission() then begin
            err := this.BuildApplicationError(ErrNoPermissionPostOutputLbl, ErrNoPermissionPostOutputErr);
            this.Raise(err);
        end;

        // Validate item and variant
        if not this.ValidateOutputItemAndVariantNotBlocked(ProdOrderRoutingLine, Item, ProdOrderLine) then
            exit;

        // Get manufacturing setup and journal configuration
        this.GetManufacturingSetupForConsumption(ManufacturingSetup, ItemJnlTemplate, ItemJnlBatch);

        // Setup journal line for complete consumption
        this.SetupOutputJournalLine(ItemJnlLine, ProdOrderRoutingLine, ItemJnlTemplate, ItemJnlBatch, OutputQuantity);

        // Apply item tracking if needed
        if Item."Item Tracking Code" <> '' then
            this.ApplyItemTrackingToOutput(ItemJnlLine, ProdOrderLine);

        // Post Journal
        Clear(PostItemJnlLine);
        PostItemJnlLine.Run(ItemJnlLine);

        // Log the action
        this.LogAction(ProdOrderRoutingLine, Enum::"APA MADCS Log Type"::Output);
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
    /// <param name="ProdOrderRoutingLine"></param>
    /// <param name="LogType"></param>
    procedure LogAction(ProdOrderRoutingLine: Record "Prod. Order Routing Line"; LogType: Enum "APA MADCS Log Type")
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
    procedure LogAction(ItemJournalLine: Record "Item Journal Line"; LogType: Enum "APA MADCS Log Type")
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        UserLog."Production Order No." := ItemJournalLine."Order No.";
        UserLog."Log Action" := UserLog."Log Action"::PostTime;
        UserLog."Log Action" := UserLog."Log Action"::"New Activity";

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
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        TemporaryTableErr: Label 'Page table is not temporary.', Comment = 'ESP="La tabla de la página no es temporal."';
    begin
        if not Rec.IsTemporary() or not TempTrackingSpecification.IsTemporary() then begin
            err := this.BuildApplicationError(ProgramErr, TemporaryTableErr);
            this.Raise(err);
        end;
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
    procedure ProcessPreparationCleaningTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        this.FinalizeLastActivity(OperatorCode);

        case id of
            Format(Enum::"APA MADCS Time Buttons"::ALButtonPreparationTok):
                Activities.NewPreparationActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode);
            Format(Enum::"APA MADCS Time Buttons"::ALButtonCleaningTok):
                Activities.NewCleaningActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode);
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
    procedure ProcessExecutionAndStopAllTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        this.FinalizeLastActivity(OperatorCode);

        Activities.NewExecutionActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode);
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
    procedure ProcessBreakdownAndBlockedBreakdownTask(id: Text; pProdOrderStatus: Enum "Production Order Status"; pProdOrder: Code[20]; pProdOrderLine: Integer; OperatorCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        this.FinalizeLastActivity(OperatorCode); // only for blocked tasks

        Activities.NewFaultActivity(pProdOrderStatus, pProdOrder, pProdOrderLine, OperatorCode);
        this.LogAction(Activities, Enum::"APA MADCS Log Type"::Fault);
    end;

    local procedure FinalizeLastActivity(OperatorCode: Code[20])
    var
        Activities: Record "APA MADCS Pro. Order Line Time";
    begin
        // Find my current activity and stop it
        // Consume time used in recent stopped activity
        Clear(Activities);
        Activities.SetCurrentKey("Operator Code");
        Activities.SetRange("Operator Code", OperatorCode);
        if Activities.FindSet(true) then
            repeat
                Activities."End Date Time" := CurrentDateTime();
                this.PostCapacityJournalLine(Activities);
                Activities.Validate(Posted, true);
                Activities.Modify(false);
                // Log the action
                this.LogAction(Activities, Enum::"APA MADCS Log Type"::FinalizeTask);
            until Activities.Next() = 0;

    end;

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
        ItemJournalLine.Validate(Description, Activities.Description());
        case Activities.Action of
            "APA MADCS Journal Type"::Preparation,
            "APA MADCS Journal Type"::Clean:
                ItemJournalLine.Validate("Setup Time", Activities.MinutesUsed());
            "APA MADCS Journal Type"::Execution:
                ItemJournalLine.Validate("Run Time", Activities.MinutesUsed());
            "APA MADCS Journal Type"::Fault:
                ItemJournalLine.Validate("Stop Time", Activities.MinutesUsed());
        end;
        ItemJournalLine.Validate(Quantity, 0);
        ItemJournalLine.Validate("Output Quantity", 0);

        // Post Journal
        Clear(PostItemJnlLine);
        PostItemJnlLine.Run(ItemJournalLine);
        this.LogAction(ItemJournalLine, Enum::"APA MADCS Log Type"::PostTime);
    end;

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

    local procedure ValidateAndGetItem(var Item: Record Item; ItemNo: Code[20])
    var
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        ItemErr: Label 'Item not found: %1', Comment = 'ESP="Artículo no encontrado: %1"';
    begin
        Clear(Item);
        if not Item.Get(ItemNo) then begin
            err := this.BuildApplicationError(ProgramErr, StrSubstNo(ItemErr, ItemNo));
            this.Raise(err);
        end;
    end;

    local procedure ShouldProcessItemTracking(Item: Record Item; var ItemTrackingCode: Record "Item Tracking Code"): Boolean
    var
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        ItemTrackingCodeErr: Label 'Item Tracking Code not found: %1', Comment = 'ESP="Código de seguimiento del artículo no encontrado: %1"';
    begin
        if Item."Item Tracking Code" = '' then
            exit(false);

        Clear(ItemTrackingCode);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            err := this.BuildApplicationError(ProgramErr, StrSubstNo(ItemTrackingCodeErr, Item."Item Tracking Code"));
            this.Raise(err);
        end;

        exit(ItemTrackingCode."Lot Manuf. Inbound Tracking");
    end;

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

    local procedure ValidateOutputItemAndVariantNotBlocked(ProdOrderRoutingLine: Record "Prod. Order Routing Line"; var Item: Record Item; ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ItemVariant: Record "Item Variant";
        ItemItemVariantTok: Label '%1 %2', Locked = true, Comment = '%1 - Item No., %2 - Variant Code';
        BlockedMsg: Label 'The item %1 (%2) is blocked and cannot be consumed.', Comment = 'ESP="El artículo %1 (%2) está bloqueado y no se puede consumir."';
    begin
        if not ProdOrderLine.Get(ProdOrderRoutingLine.Status, ProdOrderRoutingLine."Prod. Order No.", ProdOrderRoutingLine."Routing Reference No.") then
            exit(false);

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

    local procedure GetManufacturingSetupForConsumption(var ManufacturingSetup: Record "Manufacturing Setup"; var ItemJnlTemplate: Record "Item Journal Template"; var ItemJnlBatch: Record "Item Journal Batch")
    var
        err: ErrorInfo;
        ManufacturingSetupMissMsg: Label 'Manufacturing Setup Missing', Comment = 'ESP="Falta la configuración de fabricación"';
        ManufacturingSetupErr: Label 'The Manufacturing Setup record is missing. Please set it up before posting consumption.', Comment = 'ESP="Falta el registro de Configuración de Fabricación. Por favor, configúrelo antes de registrar el consumo."';
        ItemJournalMissingMsg: Label 'Item Journal Template Missing', Comment = 'ESP="Falta la plantilla de diario de artículos para el consumo MADCS."';
        ItemJournalMissingErr: Label 'The specified Item Journal Template for MADCS consumption is missing. Please check the Manufacturing Setup.', Comment = 'ESP="Falta la plantilla de diario de artículos especificada para el consumo MADCS. Por favor, verifique la Configuración de Fabricación."';
        ItemJournalBatchMissingMsg: Label 'Item Journal Batch Missing', Comment = 'ESP="Falta la sección del diario de artículos para el consumo MADCS."';
        ItemJournalBatchMissingErr: Label 'The specified Item Journal Batch for MADCS consumption is missing. Please check the Manufacturing Setup.', Comment = 'ESP="Falta el lote de diario de artículos especificado para el consumo MADCS. Por favor, verifique la Configuración de Fabricación."';
    begin
        if not ManufacturingSetup.Get() then begin
            err := this.BuildApplicationError(ManufacturingSetupMissMsg, ManufacturingSetupErr);
            this.Raise(err);
        end;

        if not ItemJnlTemplate.Get(ManufacturingSetup."APA MADCS Consump. Jnl. Templ.") then begin
            err := this.BuildApplicationError(ItemJournalMissingMsg, ItemJournalMissingErr);
            this.Raise(err);
        end;

        if not ItemJnlBatch.Get(ManufacturingSetup."APA MADCS Consump. Jnl. Templ.", ManufacturingSetup."APA MADCS Consump. Jnl. Batch") then begin
            err := this.BuildApplicationError(ItemJournalBatchMissingMsg, ItemJournalBatchMissingErr);
            this.Raise(err);
        end;
    end;

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
        ItemJnlLine."Line No." := 10000;
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
        ItemJnlLine.Validate("Prod. Order Comp. Line No.", ProdOrderComp."MADCS Original Line No.");

        ItemJnlLine.Level := 0;
        ItemJnlLine."Flushing Method" := ProdOrderComp."Flushing Method";
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
        ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
        ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
    end;

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

    local procedure SetupOutputJournalLine(var ItemJnlLine: Record "Item Journal Line"; ProdOrderRoutingLine: Record "Prod. Order Routing Line"; ItemJnlTemplate: Record "Item Journal Template"; ItemJnlBatch: Record "Item Journal Batch"; OutputQuantity: Decimal)
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        // TODO: Review
        // Get production order line
        Clear(ProdOrderLine);
        if not ProdOrderLine.Get(ProdOrderRoutingLine.Status, ProdOrderRoutingLine."Prod. Order No.", ProdOrderRoutingLine."Routing Reference No.") then
            exit;

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
        ItemJnlLine."Flushing Method" := ProdOrderRoutingLine."Flushing Method";
        ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
        ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
        ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
        ItemJnlLine.Validate("Output Quantity", OutputQuantity);
    end;

    local procedure ApplyItemTrackingToCompleteConsumption(var ItemJnlLine: Record "Item Journal Line"; ProdOrderComp: Record "Prod. Order Component")
    var
        ItemTrackingMgt: Codeunit "Item Tracking Management";
    begin
        ItemTrackingMgt.CopyItemTracking(ProdOrderComp.RowID1(), ItemJnlLine.RowID1(), false);
    end;

    local procedure ApplyItemTrackingToOutput(var ItemJnlLine: Record "Item Journal Line"; ProdOrderLine: Record "Prod. Order Line")
    var
        ItemTrackingMgt: Codeunit "Item Tracking Management";
    begin
        ItemTrackingMgt.CopyItemTracking(ProdOrderLine.RowID1(), ItemJnlLine.RowID1(), false);
    end;

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

    local procedure InsertComponentRecord(var Rec: Record "Prod. Order Component" temporary; ProdOrderComponent: Record "Prod. Order Component"; LotNo: Text[50]; RemQuantityLot: Decimal; LineIncrement: Integer)
    begin
        if RemQuantityLot = 0 then
            exit;
        Rec."MADCS Original Line No." := ProdOrderComponent."Line No.";
        Rec."Line No." := ProdOrderComponent."Line No." + LineIncrement;
        Rec."MADCS Lot No." := LotNo;
        Rec.CalcFields("MADCS Consumed Quantity");
        Rec."MADCS Quantity" := RemQuantityLot + Rec."MADCS Consumed Quantity";
        Rec."MADCS Qty. After Consumption" := Rec."MADCS Quantity" - Rec."MADCS Consumed Quantity";
        Rec.Insert(false);
    end;
}
