namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

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
    Editable = true;
    ModifyAllowed = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(RepeaterGrp)
            {
                ShowCaption = false;
                Editable = false;

                repeater(Control1)
                {
                    ShowCaption = false;

                    field(Status; Rec.Status)
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                    field("Prod. Order No."; Rec."Prod. Order No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                    field("Prod. Order Line No."; Rec."Prod. Order Line No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                    field("Line No."; Rec."Line No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                    field("Operation No."; Rec."Operation No.")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                    field("Operator Code"; Rec."Operator Code")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 1;
                    }
                    field("Start Date Time"; Rec."Start Date Time")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 1;
                    }
                    field("End Date Time"; Rec."End Date Time")
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                    field("Action"; Rec."Action")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 1;
                    }
                    field("BreakDown Code"; Rec."BreakDown Code")
                    {
                        StyleExpr = this.styleColor;
                        Visible = true;
                        Width = 1;
                    }
                    field(Posted; Rec.Posted)
                    {
                        StyleExpr = this.styleColor;
                        Visible = false;
                        Width = 1;
                    }
                }
            }

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
                            CurrPage.ALInfButtonGroupColumns1.AddButton(PreparationLbl, PreparationTextLbl, Format(Enum::"APA MADCS Time Buttons"::ALButtonPreparationTok), this.NormalButtonTok);
                            CurrPage.ALInfButtonGroupColumns1.AddButton(CleanLbl, CleanTextLbl, Format(Enum::"APA MADCS Time Buttons"::ALButtonCleaningTok), this.NormalButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            this.APAMADCSManagement.ProcessPreparationCleaningTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            CurrPage.Update(false);
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
                }
            }

            grid(Columns2)
            {
                ShowCaption = false;
                GridLayout = Columns;

                group(leftGrpColumns)
                {
                    ShowCaption = false;

                    usercontrol(ALInfButtonGroupColumns2; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            ExecutionLbl: Label 'Execution', Comment = 'ESP="Ejecución"';
                            ExecutionTextLbl: Label 'Init execution phase', Comment = 'ESP="Iniciar fase de ejecución"';
                            EndLbl: Label 'STOP ALL WORK', Comment = 'ESP="PARAR TRABAJOS"';
                            EndTextLbl: Label 'Finalize the active phase', Comment = 'ESP="Finalizar la fase activa"';
                        begin
                            CurrPage.ALInfButtonGroupColumns2.AddButton(ExecutionLbl, ExecutionTextLbl, Format(Enum::"APA MADCS Time Buttons"::ALButtonExecutionTok), this.InfoButtonTok);
                            CurrPage.ALInfButtonGroupColumns2.AddButton(EndLbl, EndTextLbl, Format(Enum::"APA MADCS Time Buttons"::ALButtonEndTok), this.PrimaryButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            this.APAMADCSManagement.ProcessExecutionAndStopAllTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            CurrPage.Update(false);
                        end;
                    }
                }

                group(rightGrpColumns2)
                {
                    ShowCaption = false;

                    usercontrol(ALRightButtonGroupColumns2; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            BreakDownLbl: Label 'Breakdown', Comment = 'ESP="Avería"';
                            BreakDownTextLbl: Label 'Register breakdown', Comment = 'ESP="Registrar avería"';
                            BlockedBreakDownLbl: Label 'Blocked Breakdown', Comment = 'ESP="Avería bloqueante"';
                            BlockedBreakDownTextLbl: Label 'Register blocked breakdown', Comment = 'ESP="Registrar avería bloqueante"';
                        begin
                            CurrPage.ALRightButtonGroupColumns2.AddButton(BreakDownLbl, BreakDownTextLbl, Format(Enum::"APA MADCS Time Buttons"::ALButtonBreakdownTok), this.WarningButtonTok);
                            CurrPage.ALRightButtonGroupColumns2.AddButton(BlockedBreakDownLbl, BlockedBreakDownTextLbl, Format(Enum::"APA MADCS Time Buttons"::ALButtonBlockedBreakdownTok), this.DangerButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        var
                            BreakdownTitleErrLbl: Label 'Breakdown Code Required', Comment = 'ESP="Código de Avería Requerido"';
                            BreakdownMsgErrLbl: Label 'Please enter a Breakdown Code before registering a breakdown.', Comment = 'ESP="Por favor, introduzca un Código de Avería antes de registrar una avería."';
                        begin
                            if this.BreakDownCode = '' then 
                                this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildValidationError(Rec.RecordId(), Rec.FieldNo("BreakDown Code"), BreakdownTitleErrLbl, BreakdownMsgErrLbl));
                            this.APAMADCSManagement.ProcessBreakdownAndBlockedBreakdownTask(id, this.MyStatus, this.MyProdOrdeNo, this.MyProdOrdeLineNo, this.APAMADCSManagement.GetOperatorCode(), this.BreakDownCode);
                            CurrPage.Update(false);
                        end;
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
            Rec.Action::Clean:
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
}