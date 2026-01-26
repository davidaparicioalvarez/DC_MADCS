namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Outputs Part
/// Part page for managing outputs in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55004 "APA MADCS Outputs Part"
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
    Permissions =
        tabledata "Prod. Order Line" = rm,
        tabledata "Prod. Order Routing Line" = rm;

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

                    field("Item No."; Rec."Item No.")
                    {
                        Width = 11;
                    }
                    field(Description; Rec.Description)
                    {
                        Width = 11;
                    }
                    field(Quantity; Rec.Quantity)
                    {
                        Caption = 'QR', Comment = 'ESP="QR"';
                        Width = 5;
                    }
                    field("Finished Quantity"; Rec."Finished Quantity")
                    {
                        Caption = 'QT', Comment = 'ESP="QT"';
                        Width = 5;
                    }
                    field("Remaining Quantity"; Rec."Remaining Quantity")
                    {
                        Caption = 'RT', Comment = 'ESP="QP"';
                        Width = 5;
                    }
                }
            }
            group(DataGrp)
            {
                ShowCaption = false;

                grid(Columns)
                {
                    group(Left)
                    {
                        ShowCaption = false;

                        field(OutputQuantity; this.OutputQuantity)
                        {
                            Caption = 'Quan.', Comment = 'ESP="Cant."';
                            ToolTip = 'Specifies the quantity of output produced.', Comment = 'ESP="Indica la cantidad de salida producida."';
                            QuickEntry = true;
                        }

                        field(Bin; Rec."Bin Code")
                        {
                            Caption = 'Bin', Comment = 'ESP="Ubicación"';
                            ToolTip = 'Specifies the bin code where the output is stored.', Comment = 'ESP="Indica el código de ubicación donde se almacena la salida."';
                            Editable = false;
                        }
                    }
                    group(Center)
                    {
                        ShowCaption = false;

                        field(LotNo; this.LotNo)
                        {
                            Caption = 'Lot No.', Comment = 'ESP="Lote"';
                            ToolTip = 'Specifies the lot number associated with the output, if applicable.', Comment = 'ESP="Indica el número de lote asociado con la salida, si corresponde."';
                            Width = 50;
                            QuickEntry = true;

                            trigger OnLookup(var Text: Text): Boolean
                            begin
                                exit(FindLotNoForOutput(Text));
                            end;
                        }

                        usercontrol(ALInfButtonPost; "APA MADCS ButtonGroup")
                        {
                            Visible = true;

                            trigger OnLoad()
                            var
                            begin
                                CurrPage.ALInfButtonPost.AddButton(this.PostLbl, this.PostOutputLbl, this.ALButtonPostTok, this.PrimaryButtonTok);
                            end;

                            trigger OnClick(id: Text)
                            begin
                                // TODO: Implement button actions
                                Message('%1 button was clicked.', id);
                            end;
                        }
                    }
                    group(Right)
                    {
                        ShowCaption = false;

                        field(Scrap; this.ScrapQuantity)
                        {
                            Caption = 'Scrap', Comment = 'ESP="C.Rechazo"';
                            ToolTip = 'Specifies the quantity of scrap produced.', Comment = 'ESP="Indica la cantidad de desecho producida."';
                        }

                        usercontrol(ALInfButtonFinish; "APA MADCS ButtonGroup")
                        {
                            Visible = true;

                            trigger OnLoad()
                            begin
                                CurrPage.ALInfButtonFinish.AddButton(this.FinishLbl, this.FinishOrderLbl, this.ALButtonFinishTok, this.DangerButtonTok);
                            end;

                            trigger OnClick(id: Text)
                            begin
                                // TODO: Implement button actions
                                Message('%1 button was clicked.', id);
                            end;
                        }
                    }
                }

            }
        }
    }

    var
        OutputQuantity: Decimal;
        ScrapQuantity: Decimal;
        LotNo: Code[50];
        PostLbl: Label 'Post', Comment = 'ESP="Registrar"';
        PostOutputLbl: Label 'Post Output', Comment = 'ESP="Registrar salida"';
        ALButtonPostTok: Label 'ALButtonPost', Locked = true;
        PrimaryButtonTok: Label 'primary', Locked = true;
        FinishLbl: Label 'Finish', Comment = 'ESP="Finalizar"';
        FinishOrderLbl: Label 'Finish Order', Comment = 'ESP="Finalizar Orden"';
        ALButtonFinishTok: Label 'ALButtonFinish', Locked = true;
        DangerButtonTok: Label 'danger', Locked = true;

    trigger OnAfterGetCurrRecord()
    begin
        this.OutputQuantity := Rec."Remaining Quantity";
    end;

    local procedure FindLotNoForOutput(var Text: Text): Boolean
    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
    begin
        exit(APAMADCSManagement.FindLotNoForOutput(Rec, Text));
    end;
}