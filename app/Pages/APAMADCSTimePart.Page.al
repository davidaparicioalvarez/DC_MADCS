namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;
using System.Utilities;

/// <summary>
/// APA MADCS Time Part
/// Part page for managing time tracking in production orders.
/// This page will be used within the main MADCS card to display and manage time data.
/// </summary>
page 55003 "APA MADCS Time Part"
{
    Caption = 'Time', Comment = 'ESP="Tiempo"';
    Extensible = true;
    PageType = List;
    SourceTable = "APA MADCS Pro. Order Line Time";
    SourceTableView = where(Posted = const(false));
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Editable = true;
    Permissions =
        tabledata "Prod. Order Line" = r;

    layout
    {
        area(Content)
        {
            grid(Columns1)
            {
                ShowCaption = false;
                GridLayout = Columns;

                group(leftGrpColumns1)
                {
                    ShowCaption = false;

                    usercontrol(ALInfButtonGroupColumns1; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            PreparationLbl: Label 'Preparation', Comment = 'ESP="Preparación"';
                            PreparationTextLbl: Label 'Init preparation phase', Comment = 'ESP="Iniciar fase de preparación"';
                            CleanLbl: Label 'Cleaning', Comment = 'ESP="Limpieza"';
                            CleanTextLbl: Label 'Init cleaning phase', Comment = 'ESP="Iniciar fase de limpieza"';
                        begin
                            CurrPage.ALInfButtonGroupColumns1.AddButton(PreparationLbl, PreparationTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonPreparationTok), this.NormalButtonTok);
                            CurrPage.ALInfButtonGroupColumns1.AddButton(CleanLbl, CleanTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonCleaningTok), this.NormalButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            this.APAMADCSManagement.ProcessPreparationCleaningTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            Message(this.NewActivityCreatedMsg);
                            CurrPage.Update(false);
                        end;
                    }

                    usercontrol(ALInfButtonGroupColumns2; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            ExecutionLbl: Label 'EXECUTION without fault', Comment = 'ESP="EJECUCIÓN sin avería"';
                            ExecutionTextLbl: Label 'Init execution phase', Comment = 'ESP="Iniciar fase de ejecución"';
                            EndLbl: Label 'STOP ALL WORK', Comment = 'ESP="PARAR TRABAJOS"';
                            EndTextLbl: Label 'Finalize the active phase', Comment = 'ESP="Finalizar la fase activa"';

                        begin
                            CurrPage.ALInfButtonGroupColumns2.AddButton(ExecutionLbl, ExecutionTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonExecutionTok), this.InfoButtonTok);
                            CurrPage.ALInfButtonGroupColumns2.AddButton(EndLbl, EndTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonEndTok), this.PrimaryButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            this.APAMADCSManagement.ProcessExecutionAndStopAllTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            case id of
                                Format(Enum::"APA MADCS Buttons"::ALButtonEndTok):
                                    Message(this.ClosedAllActivitiesMsg);
                                else
                                    Message(this.NewActivityCreatedMsg);
                            end;
                            CurrPage.Update(false);
                        end;
                    }

                    usercontrol(ALInfButtonGroupColumns3; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            FinalizeTimeOrderLbl: Label 'End (Times)', Comment = 'ESP="Fin (Tiempos)"';
                            FinalizeTimeOrderTxtLbl: Label 'Finalize times in order and mark it. No more times can be registered.', Comment = 'ESP="Finalizar tiempo en orden y marcarla. Ya no se podrán registrar más tiempos."';

                        begin
                            CurrPage.ALInfButtonGroupColumns3.AddButton(FinalizeTimeOrderLbl, FinalizeTimeOrderTxtLbl, Format(Enum::"APA MADCS Buttons"::ALButtonFinalizeTimeTok), this.DangerButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        var
                            ProdOrderLine: Record "Prod. Order Line";
                        begin
                            this.APAMADCSManagement.ProcessExecutionAndStopAllTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            Clear(ProdOrderLine);
                            if not ProdOrderLine.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.") then
                                this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("Prod. Order Line No."), this.ProdOrderLineNotFoundErrLbl, this.ProdOrderLineNotFoundMsgLbl));
                            if this.MarkProductionOrderAsFinished(ProdOrderLine) then begin
                                Message(this.ClosedAllActivitiesAndOrderMsg);
                                CurrPage.Close();
                            end;
                        end;
                    }
                }

                group(rightGrpColumns1)
                {
                    ShowCaption = false;

                    field(StopCode; this.BreakDownCode)
                    {
                        StyleExpr = this.styleColor;
                        Caption = 'Stop Code', Comment = 'ESP="Código de Paro"';
                        ToolTip = 'Specifies the stop code for the breakdown.', Comment = 'ESP="Especifica el código de paro para la avería."';
                        Editable = true;
                        TableRelation = "DC Detalles de paro".Code;
                    }

                    usercontrol(ALRightButtonGroupColumns2; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            BreakDownLbl: Label 'Execution WITH FAULT', Comment = 'ESP="Ejecución CON AVERÍA"';
                            BreakDownTextLbl: Label 'Register no blocked breakdown', Comment = 'ESP="Permite el uso de la máquina, pero no en condiciones óptimas"';
                            BlockedBreakDownLbl: Label 'Blocked Breakdown', Comment = 'ESP="Avería bloqueante"';
                            BlockedBreakDownTextLbl: Label 'Register blocked breakdown', Comment = 'ESP="No permite el uso de la máquina"';
                        begin
                            CurrPage.ALRightButtonGroupColumns2.AddButton(BreakDownLbl, BreakDownTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonBreakdownTok), this.WarningButtonTok);
                            CurrPage.ALRightButtonGroupColumns2.AddButton(BlockedBreakDownLbl, BlockedBreakDownTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonBlockedBreakdownTok), this.DangerButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        var
                            BreakdownTitleErrLbl: Label 'Breakdown Code Required', Comment = 'ESP="Código de Avería Requerido"';
                            BreakdownMsgErrLbl: Label 'Please enter a Breakdown Code before registering a breakdown.', Comment = 'ESP="Por favor, introduzca un Código de Avería antes de registrar una avería."';
                        begin
                            if this.BreakDownCode = '' then
                                this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("BreakDown Code"), BreakdownTitleErrLbl, BreakdownMsgErrLbl));
                            this.APAMADCSManagement.ProcessBreakdownAndBlockedBreakdownTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            Message(this.NewActivityCreatedMsg);
                            CurrPage.Update(false);
                        end;
                    }
                }
            }

            group(RepeaterGrp)
            {
                ShowCaption = false;
                Editable = false;

                repeater(Control1)
                {
                    ShowCaption = false;
                    Editable = false;

                    field(Status; Rec.Status)
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                    field("Prod. Order No."; Rec."Prod. Order No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                    field("Prod. Order Line No."; Rec."Prod. Order Line No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                    field("Line No."; Rec."Line No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                    field("Operation No."; Rec."Operation No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                    field("Operator Code"; Rec."Operator Code")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 10;
                        Editable = false;
                    }
                    field("Start Date Time"; Rec."Start Date Time")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 10;
                        Editable = false;
                    }
                    field("End Date Time"; Rec."End Date Time")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                    field("Action"; Rec."Action")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 10;
                        Editable = false;
                    }
                    field("BreakDown Code"; Rec."BreakDown Code")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 10;
                        Editable = false;
                    }
                    field(Posted; Rec.Posted)
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                        Editable = false;
                    }
                }
            }

        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        this.SetStyleColor();
    end;

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
    end;

    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        MyStatus: Enum "Production Order Status";
        styleColor: Text;
        MyProdOrdeNo: Code[20];
        BreakDownCode: Code[20];
        MyProdOrdeLineNo: Integer;
        NormalButtonTok: Label 'normal', Locked = true;
        PrimaryButtonTok: Label 'primary', Locked = true;
        InfoButtonTok: Label 'info', Locked = true;
        WarningButtonTok: Label 'warning', Locked = true;
        DangerButtonTok: Label 'danger', Locked = true;
        NewActivityCreatedMsg: Label 'New activity created successfully.', Comment = 'ESP="Nueva actividad creada con éxito."';
        ClosedAllActivitiesMsg: Label 'All active activities have been closed successfully.', Comment = 'ESP="Todas las actividades activas se han cerrado con éxito."';
        ClosedAllActivitiesAndOrderMsg: Label 'All active activities have been closed and the production order will not accept more times.', Comment = 'ESP="Todas las actividades activas se han cerrado y la orden de producción no admitirá más tiempos."';
        ProdOrderLineNotFoundErrLbl: Label 'Production Order Line Not Found', Comment = 'ESP="Línea de Orden de Producción No Encontrada"';
        ProdOrderLineNotFoundMsgLbl: Label 'The Production Order Line associated with this time entry could not be found.', Comment = 'ESP="No se pudo encontrar la Línea de Orden de Producción asociada con esta entrada de tiempo."';


    /// <summary>
    /// procedure InitializeData
    /// Initializes the page with the provided production order status, number, and line number.
    /// </summary>
    /// <param name="pStatus"></param>
    /// <param name="pProdOrderNo"></param>
    /// <param name="pProdOrderLineNo"></param>
    procedure InitializeData(pStatus: Enum "Production Order Status"; pProdOrderNo: Code[20]; pProdOrderLineNo: Integer)
    begin
        this.MyStatus := pStatus;
        this.MyProdOrdeNo := pProdOrderNo;
        this.MyProdOrdeLineNo := pProdOrderLineNo;
        Rec.SetFilter(Status, Format(this.MyStatus));
        Rec.SetFilter("Prod. Order No.", this.MyProdOrdeNo);
        Rec.SetFilter("Prod. Order Line No.", Format(this.MyProdOrdeLineNo));
    end;

    local procedure SetStyleColor()
    var
        newPageStyle: PageStyle;
    begin
        // Set style color based on task status:
        case Rec.Action of
            Rec.Action::Preparation,
            Rec.Action::Cleaning:
                newPageStyle := PageStyle::None;
            Rec.Action::Execution:
                newPageStyle := PageStyle::StrongAccent;
            Rec.Action::"Execution with Fault":
                newPageStyle := PageStyle::Ambiguous;
            Rec.Action::Fault:
                newPageStyle := PageStyle::Unfavorable;
            else
                newPageStyle := PageStyle::None;
        end;

        this.styleColor := Format(newPageStyle);
    end;

    local procedure MarkProductionOrderAsFinished(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ConfirmMgmt: Codeunit "Confirm Management";
        ConfirmFinishOrderQst: Label 'Are you sure you want to mark this production order as finished?', Comment = 'ESP="¿Está seguro de que desea marcar esta orden de producción como finalizada?"';
    begin
        // Get user confirmation first
        if not ConfirmMgmt.GetResponseOrDefault(ConfirmFinishOrderQst) then
            exit(false);
        exit(this.APAMADCSManagement.MarkProductionOrderAsTimeFinished(ProdOrderLine));
    end;
}