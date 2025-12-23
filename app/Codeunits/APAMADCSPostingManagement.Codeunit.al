namespace MADCS.MADCS;

using Microsoft.Warehouse.ADCS;
using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Posting Management
/// Codeunit to handle posting of consumptions and outputs, and log all user actions.
/// </summary>
codeunit 55000 "APA MADCS Posting Management"
{
    SingleInstance = true;
    Permissions = 
        tabledata "APA MADCS User Log" = i,
        tabledata "ADCS User" = r;

    var
        ErrNoPermissionPostConsumptionLbl: Label 'You do not have permission to post consumption.', Comment = 'ESP="No tiene permiso para registrar consumo."';
        ErrNoPermissionPostOutputLbl: Label 'You do not have permission to post output.', Comment = 'ESP="No tiene permiso para registrar salida."';

    /// <summary>
    /// Posts component consumption for a production order component line and logs the action.
    /// </summary>
    /// <param name="ProdOrderComponent">Record "Prod. Order Component"</param>
    procedure PostComponentConsumption(var ProdOrderComponent: Record "Prod. Order Component")
    begin
        // Validate user permissions and input
        if not HasADCSUserPermission() then
            Error(ErrNoPermissionPostConsumptionLbl); // ESP="No tiene permiso para registrar consumo."

        // TODO: Implement actual posting logic to the consumption journal
        // Example: Insert a line in the Item Journal Line and post it

        // For demonstration, we just simulate a change
        // ProdOrderComponent.Quantity := ProdOrderComponent.Quantity; // No change, replace with actual logic

        // Log the action
        LogAction(ProdOrderComponent);
    end;

    /// <summary>
    /// Posts output for a production order routing line and logs the action.
    /// </summary>
    /// <param name="ProdOrderRoutingLine">Record "Prod. Order Routing Line"</param>
    procedure PostOutput(var ProdOrderRoutingLine: Record "Prod. Order Routing Line")
    begin
        // Validate user permissions and input
        if not HasADCSUserPermission() then
            Error(ErrNoPermissionPostOutputLbl); // ESP="No tiene permiso para registrar salida."

        // Store old value
        //oldOutputQty := ProdOrderRoutingLine.Quantity;

        // TODO: Implement actual posting logic to the output journal
        // Example: Insert a line in the Output Journal and post it

        // For demonstration, we just simulate a change
        // ProdOrderRoutingLine.Quantity := ProdOrderRoutingLine.Quantity; // No change, replace with actual logic

        // Log the action
        LogAction(ProdOrderRoutingLine);
    end;

    procedure LogAction(var ProdOrderComponent: Record "Prod. Order Component")
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        UserLog."Log Action" := UserLog."Log Action"::PostComponent;

        UserLog.Insert(true);
    end;

    procedure LogAction(var ProdOrderRoutingLine: Record "Prod. Order Routing Line")
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        UserLog."Log Action" := UserLog."Log Action"::PostOutput;

        UserLog.Insert(true);
    end;

    procedure LogAction(var ProductionOrder: Record "Prod. Order Line"; Open: Boolean)
    var
        UserLog: Record "APA MADCS User Log";
    begin
        UserLog.Init();
        UserLog."User ID" := CopyStr(UserId(), 1, 50);
        UserLog."Action DateTime" := CurrentDateTime();
        if Open then
            UserLog."Log Action" := UserLog."Log Action"::OpenProductionOrder
        else
            UserLog."Log Action" := UserLog."Log Action"::CloseProductionOrder;
        UserLog."Production Order No." := ProductionOrder."Prod. Order No.";
        UserLog.Insert(true);
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
}
