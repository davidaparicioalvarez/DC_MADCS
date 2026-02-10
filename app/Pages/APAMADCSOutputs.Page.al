namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;
using System.Utilities;

/// <summary>
/// APA MADCS Outputs
/// Part page for managing outputs in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55004 "APA MADCS Outputs"
{
    Caption = 'Outputs', Comment = 'ESP="Salidas"';
    Extensible = true;
    PageType = List;
    SourceTable = "Prod. Order Line";
    Editable = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;
    RefreshOnActivate = true;
    Permissions =
        tabledata "Prod. Order Line" = rm,
        tabledata "Prod. Order Routing Line" = rm;

    layout
    {
        area(Content)
        {
            group(Columns)
            {
                ShowCaption = false;

                grid(ColumnsGrid)
                {
                    group(Left)
                    {
                        ShowCaption = false;

                        field(LotNo; this.LotNo)
                        {
                            Caption = 'Lot No.', Comment = 'ESP="Lote"';
                            ToolTip = 'Specifies the lot number associated with the output, if applicable.', Comment = 'ESP="Indica el número de lote asociado con la salida, si corresponde."';
                            Width = 50;
                            Editable = false;

                            trigger OnDrillDown()
                            begin
                                this.FindLotNoForOutput(this.LotNo);
                            end;
                        }
                    }
                    group(Center)
                    {
                        ShowCaption = false;

                        field(OutputQuantity; this.OutputQuantity)
                        {
                            Caption = 'Quan.', Comment = 'ESP="Cant."';
                            ToolTip = 'Specifies the quantity of output produced.', Comment = 'ESP="Indica la cantidad de salida producida."';
                            QuickEntry = true;

                            trigger OnValidate()
                            var
                                OutputQuantytTitleErr: Label 'Invalid Output Quantity', Comment = 'ESP="Cantidad de salida no válida"';
                                OutputQuantityErr: Label 'ERROR: The output quantity cannot exceed the remaining quantity of %1.', Comment = 'ESP="ERROR: La cantidad de salida no puede exceder la cantidad restante de %1."';

                            begin
                                if this.OutputQuantity > Rec."Remaining Quantity" then
                                    this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(OutputQuantytTitleErr, StrSubstNo(OutputQuantityErr, Rec."Remaining Quantity")));
                            end;
                        }
                    }
                    group(Right)
                    {
                        ShowCaption = false;

                        usercontrol(ALInfButtonPost; "APA MADCS ButtonGroup")
                        {
                            Visible = true;

                            trigger OnLoad()
                            var
                                PostLbl: Label 'Post', Comment = 'ESP="Registrar"';
                                PostOutputLbl: Label 'Post Output', Comment = 'ESP="Registrar salida"';
                            begin
                                CurrPage.ALInfButtonPost.AddButton(PostLbl, PostOutputLbl, Format(Enum::"APA MADCS Buttons"::ALButtonPostTok), this.PrimaryButtonTok);
                            end;

                            trigger OnClick(id: Text)
                            var
                                OuputCorrectMsg: Label 'Output of %1 units posted successfully.', Comment = 'ESP="Salida de %1 unidades registrada con éxito."';
                            begin
                                this.APAMADCSManagement.PostOutput(Rec, this.OutputQuantity, this.LotNo);
                                this.LotNo := '';
                                CurrPage.Update(false);
                                Message(OuputCorrectMsg, this.OutputQuantity);
                            end;
                        }
                    }
                }
            }

            usercontrol(ALInfButtonFinish; "APA MADCS ButtonGroup")
            {
                Visible = true;

                trigger OnLoad()
                var
                    FinishLbl: Label 'End (Outputs)', Comment = 'ESP="Fin (Salidas)"';
                    FinishOrderLbl: Label 'End Outputs in Order', Comment = 'ESP="Fin salidas en orden"';
                begin
                    CurrPage.ALInfButtonFinish.AddButton(FinishLbl, FinishOrderLbl, Format(Enum::"APA MADCS Buttons"::ALButtonFinalizeOutputTok), this.DangerButtonTok);
                end;

                trigger OnClick(id: Text)
                var
                    ConfirmFinishOrderMsg: Label 'Production order marked as finished in outputs successfully.', Comment = 'ESP="Orden de producción marcada como finalizada en salidas con éxito."';
                begin
                    if this.MarkProductionOrderAsFinished(Rec) then begin
                        Message(ConfirmFinishOrderMsg);
                        CurrPage.Close();
                    end
                end;
            }

            group(RepeaterGrp)
            {
                ShowCaption = false;
                Editable = false;

                repeater(Control1)
                {
                    ShowCaption = false;

                    field("Item No."; Rec."Item No.")
                    {
                        ToolTip = 'Specifies the item to be propduced in the production order.', Comment = 'ESP="Especifica el artículo que se va a producir en la orden de producción."';
                        Width = 14;
                    }
                    field(Description; Rec.Description)
                    {
                        ToolTip = 'Specifies the description of the item to be produced in the production order.', Comment = 'ESP="Especifica la descripción del artículo que se va a producir en la orden de producción."';
                        Width = 11;
                    }
                    field(Quantity; Rec.Quantity)
                    {
                        ToolTip = 'Specifies the total expected quantity to be produced in the production order.', Comment = 'ESP="Especifica la cantidad total que se espera producir en la orden de producción."';
                        Caption = 'QR', Comment = 'ESP="QR"';
                        Width = 5;
                    }
                    field("Finished Quantity"; Rec."Finished Quantity")
                    {
                        ToolTip = 'Specifies the quantity that has been finished in the production order.', Comment = 'ESP="Especifica la cantidad que se ha terminado en la orden de producción."';
                        Caption = 'QT', Comment = 'ESP="QT"';
                        Width = 5;
                    }
                    field("Remaining Quantity"; Rec."Remaining Quantity")
                    {
                        ToolTip = 'Specifies the quantity that remains to be produced in the production order.', Comment = 'ESP="Especifica la cantidad que queda por producir en la orden de producción."';
                        Caption = 'RT', Comment = 'ESP="QP"';
                        Width = 5;
                    }
                }
            }

        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        this.OutputQuantity := Rec."Remaining Quantity";
    end;

    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        OutputQuantity: Decimal;
        LotNo: Code[50];
        PrimaryButtonTok: Label 'primary', Locked = true;
        DangerButtonTok: Label 'danger', Locked = true;

    local procedure FindLotNoForOutput(var myLotNo: Code[50]): Boolean
    begin
        exit(this.APAMADCSManagement.FindLotNoForOutput(Rec, myLotNo));
    end;

    local procedure MarkProductionOrderAsFinished(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ConfirmMgmt: Codeunit "Confirm Management";
        ConfirmFinishOrderQst: Label 'Are you sure you want to mark this production order as finished in outputs?', Comment = 'ESP="¿Está seguro de que desea marcar esta orden de producción como finalizada en salidas?"';
    begin
        // Get user confirmation first
        if not ConfirmMgmt.GetResponseOrDefault(ConfirmFinishOrderQst) then
            exit(false);
        exit(this.APAMADCSManagement.MarkProductionOrderAsOutputFinished(ProdOrderLine));
    end;
}