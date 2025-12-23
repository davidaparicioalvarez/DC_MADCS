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
    PageType = List;
    SourceTable = "Prod. Order Routing Line";
    Editable = true;
    InsertAllowed = false;
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
            grid(Columns)
            {
                group(RepeaterGrp)
                {
                    ShowCaption = false;
                    Editable = false;

                    repeater(Control1)
                    {
                        ShowCaption = false;

                        field("Routing Link Code"; Rec."Routing Link Code")
                        {
                            Caption = 'Routing Link Code', Comment = 'ESP="Con. Ruta"';
                            ToolTip = 'Specifies the routing link code associated with the operation.', Comment = 'ESP="Indica el código de enlace de ruta asociado con la operación."';
                            Width = 1;
                        }
                        field("Operation No."; Rec."Operation No.")
                        {
                            Caption = 'Operation No.', Comment = 'ESP="Nº Oper."';
                            ToolTip = 'Specifies the operation number.', Comment = 'ESP="Indica el número de operación."';
                            Width = 1;
                        }
                        field(Description; Rec.Description)
                        {
                            Caption = 'Description', Comment = 'ESP="Descripción"';
                            ToolTip = 'Specifies the description of the operation.', Comment = 'ESP="Indica la descripción de la operación."';
                            Width = 1;
                        }
                        field(Quantity; ProdOrderLine.Quantity)
                        {
                            Caption = 'QR', Comment = 'ESP="QR"';
                            ToolTip = 'Specifies the quantity of output produced in the operation.', Comment = 'ESP="Indica la cantidad de salida producida en la operación."';
                            Width = 1;
                        }
                        field("Finished Quantity"; ProdOrderLine."Finished Quantity")
                        {
                            Caption = 'QT', Comment = 'ESP="QT"';
                            ToolTip = 'Specifies the quantity of scrap produced in the operation.', Comment = 'ESP="Indica la cantidad de desecho producida en la operación."';
                            Width = 1;
                        }
                    }
                }
                group(DataGrp)
                {
                    ShowCaption = false;

                    field(ItemNo; ProdOrderLine."Item No.")
                    {
                        Caption = 'Item No.', Comment = 'ESP="Cód.Prod."';
                        ToolTip = 'Specifies the item number associated with the output.', Comment = 'ESP="Indica el número de artículo asociado con la salida."';
                        Editable = false;
                    }

                    grid(ColumnsRight)
                    {
                        group(Left)
                        {
                            ShowCaption = false;

                            field(OutputQuantity; OutputQuantity)
                            {
                                Caption = 'Quan.', Comment = 'ESP="Cant."';
                                ToolTip = 'Specifies the quantity of output produced.', Comment = 'ESP="Indica la cantidad de salida producida."';
                                QuickEntry = true;
                            }

                            field(Bin; ProdOrderLine."Bin Code")
                            {
                                Caption = 'Bin', Comment = 'ESP="Ubicación"';
                                ToolTip = 'Specifies the bin code where the output is stored.', Comment = 'ESP="Indica el código de ubicación donde se almacena la salida."';
                                Editable = false;
                            }
                        }
                        group(right)
                        {
                            ShowCaption = false;

                            field(LotNo; LotNo)
                            {
                                Caption = 'Lot No.', Comment = 'ESP="Lote"';
                                ToolTip = 'Specifies the lot number associated with the output, if applicable.', Comment = 'ESP="Indica el número de lote asociado con la salida, si corresponde."';
                                QuickEntry = true;
                            }

                            field(UM; ProdOrderLine."Unit of Measure Code")
                            {
                                Caption = 'UM', Comment = 'ESP="UM"';
                                ToolTip = 'Specifies the unit of measure for the output quantity.', Comment = 'ESP="Indica la unidad de medida para la cantidad de salida."';
                                Editable = false;
                            }
                        }
                    }

                    field(Separator; '')
                    {
                        Caption = '', Locked = true;
                        ToolTip = 'Specifies blank separator.', Comment = 'ESP="Indica el separador en blanco."';
                    }

                    field(Scrap; ScrapQuantity)
                    {
                        Caption = 'Scrap', Comment = 'ESP="C.Rechazo"';
                        ToolTip = 'Specifies the quantity of scrap produced.', Comment = 'ESP="Indica la cantidad de desecho producida."';
                    }

                    usercontrol(ALInfButtonGroup; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        begin
                            CurrPage.ALInfButtonGroup.AddButton('Registrar', 'Iniciar tiempo', 'ALButtonPost', 'primary');
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

    var
        ProdOrderLine: Record "Prod. Order Line";
        OutputQuantity: Decimal;
        ScrapQuantity: Decimal;
        LotNo: Code[50];


    trigger OnAfterGetCurrRecord()
    begin
        if not ProdOrderLine.Get(Rec.Status, Rec."Prod. Order No.", Rec."Routing Reference No.") then
            exit;
        OutputQuantity := 0;
    end;
}