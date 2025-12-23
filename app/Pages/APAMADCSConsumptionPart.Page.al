namespace MADCS.MADCS;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Consumption Part
/// Part page for managing consumption of components in production orders.
/// This page will be used within the main MADCS card to display and manage consumption data.
/// </summary>
page 55002 "APA MADCS Consumption Part"
{
    Caption = 'Consumption', Comment = 'ESP="Consumo"';
    PageType = List;
    SourceTable = "Prod. Order Component";
    Editable = true;
    ModifyAllowed = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;
    Permissions =
        tabledata "Warehouse Entry" = r;

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
                        ToolTip = 'Specifies the item number associated with the component.', Comment = 'ESP="Indica el número de artículo asociado con el componente."';
                        Width = 3;
                        StyleExpr = styleColor;
                    }
                    field(Description; Rec.Description)
                    {
                        ToolTip = 'Specifies the description of the component.', Comment = 'ESP="Indica la descripción del componente."';
                        Width = 10;
                        StyleExpr = styleColor;
                    }
                    field("Consumo por resto"; Rec."Consumo por resto")
                    {
                        Caption = 'CR', Comment = 'ESP="CR"';
                        ToolTip = 'Specifies the consumption by remainder of this component.', Comment = 'ESP="Indica el consumo por resto de este componente."';
                        Width = 1;
                        StyleExpr = styleColor;
                    }
                    field(Quantity; Rec."Expected Quantity")
                    {
                        Caption = 'Pred. Q.', Comment = 'ESP="Q. Prev."';
                        ToolTip = 'Specifies the quantity of the component.', Comment = 'ESP="Indica la cantidad del componente."';
                        Width = 5;
                        StyleExpr = styleColor;
                    }
                    field("Qty. Picked"; Rec."Qty. Picked")
                    {
                        Caption = 'Pick Q.', Comment = 'ESP="Q. Prep."';
                        ToolTip = 'Specifies the quantity of the component to pick for consumption.', Comment = 'ESP="Indica la cantidad del componente a recoger para el consumo."';
                        Width = 5;
                        StyleExpr = styleColor;
                    }
                    // field("MADCS Quantity List"; Rec."MADCS Quantity")
                    // {
                    //     Caption = 'Rest. Q.', Comment = 'ESP="Q. Rest."';
                    //     ToolTip = 'Specifies the MADCS quantity of the component.', Comment = 'ESP="Indica la cantidad MADCS del componente."';
                    //     Width = 5;
                    //     StyleExpr = styleColor;
                    // }
                }
            }
            grid(Columns)
            {
                ShowCaption = false;
                GridLayout = Columns;

                group(leftGrp)
                {
                    ShowCaption = false;

                    field("Item No. Search"; Rec."Item No.")
                    {
                        Caption = 'Item No.', Comment = 'ESP="Nº Prod."';
                        ToolTip = 'Specifies the item number to filter the components.', Comment = 'ESP="Indica el número de artículo para filtrar los componentes."';
                        Editable = false;
                        Lookup = false;
                    }

                    /// <summary>
                    /// Field to select the lot number to consume, with lookup to available lots in the user's bin.
                    /// </summary>
                    field("Lot No. To Consume"; Rec."Lot No.")
                    {
                        Caption = 'Lot No.', Comment = 'ESP="Lote"';
                        ToolTip = 'Specifies the lot number to consume from available lots in your bin.', Comment = 'ESP="Indica el lote a consumir de los disponibles en su ubicación."';
                        Lookup = true;

                        trigger OnLookup(var Text: Text): Boolean
                        // Locate available lots in the component's bin
                        var
                            warehouseEntry: Record "Warehouse Entry";
                            tempLotNoInformation: Record "Lot No. Information" temporary;
                            APAMADCSLotNoInformation: Page "APA MADCS Lot No. Information";
                        begin
                            // Filter Item Ledger Entries for the current item, bin, and positive remaining quantity
                            Clear(APAMADCSLotNoInformation);
                            warehouseEntry.Reset();
                            warehouseEntry.SetCurrentKey("Item No.", "Variant Code", "Lot No.", "Location Code", "Bin Code");
                            warehouseEntry.SetRange("Item No.", Rec."Item No.");
                            warehouseEntry.SetRange("Variant Code", Rec."Variant Code");
                            warehouseEntry.SetFilter("Lot No.", '<>%1', ''); // Only entries with a lot number
                            warehouseEntry.SetRange("Location Code", Rec."Location Code");
                            warehouseEntry.SetRange("Bin Code", Rec."Bin Code");
                            if warehouseEntry.FindSet() then
                                // Show a lookup dialog for available lots
                                repeat
                                    // You could use a page for lookup, but for simplicity, just pick the first available lot
                                    APAMADCSLotNoInformation.AddRecord(warehouseEntry."Item No.", warehouseEntry."Variant Code", warehouseEntry."Lot No.", warehouseEntry."Expiration Date", warehouseEntry."Location Code", warehouseEntry."Bin Code");
                                until (warehouseEntry.Next() = 0);

                            APAMADCSLotNoInformation.LookupMode(true);
                            if APAMADCSLotNoInformation.RunModal() = Action::LookupOK then begin
                                APAMADCSLotNoInformation.GetRecord(tempLotNoInformation);
                                Text := tempLotNoInformation."Lot No.";
                                exit(true);
                            end else
                                exit(false);
                        end;
                    }
                    // field("MADCS Quantity"; Rec."MADCS Quantity")
                    // {
                    //     Caption = 'Qty. to Consume', Comment = 'ESP="Cant. a consumir"';
                    //     ToolTip = 'Specifies the quantity of the component to consume.', Comment = 'ESP="Indica la cantidad del componente a consumir."';
                    //     Editable = true;
                    // }
                }
                group(right)
                {
                    ShowCaption = false;

                    field("Unit of Measure Code"; Rec."Unit of Measure Code")
                    {
                        ToolTip = 'Specifies the unit of measure for the component.', Comment = 'ESP="Indica la unidad de medida del componente."';
                        Editable = true;
                    }
                    usercontrol(ALButtonGroup; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            ConsumeAllLbl: Label 'Consume All', Comment = 'ESP="Consumir Todo"';
                            ConsumeAllTextLbl: Label 'Consume all components except for warehouse serving', Comment = 'ESP="Consumir todos los componentes excepto quién sirve almacén"';
                            ConsumeItemLbl: Label 'Consume Item', Comment = 'ESP="Consumir Comp."';
                            ConsumeItemTextLbl: Label 'Consume the selected component', Comment = 'ESP="Consumir el componente seleccionado"';

                        begin
                            CurrPage.ALButtonGroup.AddButton(ConsumeAllLbl, ConsumeAllTextLbl, ALButtonConsumeAllTok, NormalButtonTok);
                            CurrPage.ALButtonGroup.AddButton(ConsumeItemLbl, ConsumeItemTextLbl, ALButtonConsumeItemTok, PrimaryButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            // TODO: Implement button actions
                            Message('%1 button was clicked.', id);
                            ShowConsumptionpage();
                        end;
                    }
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        SetStyleColor();
    end;

    var
        styleColor: Text;
        NormalButtonTok: Label 'normal', Locked = true;
        PrimaryButtonTok: Label 'primary', Locked = true;
        // DangerButtonTok: Label 'danger', Locked = true;
        ALButtonConsumeAllTok: Label 'ALButtonConsumeAll', Locked = true;
        ALButtonConsumeItemTok: Label 'ALButtonConsumeItem', Locked = true;

    local procedure SetStyleColor()
    var
        newPageStyle: PageStyle;
    begin
        // Set style color based only on remaining quantity
        // Consumed lines (remaining quantity = 0): black (None)
        // Non-consumed lines (remaining quantity > 0): red (Attention)
        if Rec."Remaining Quantity" = 0 then
            newPageStyle := PageStyle::None // Consumed lines: black (None)
        else
            newPageStyle := PageStyle::Attention; // Non-consumed lines: red (Attention)
        styleColor := Format(newPageStyle);
    end;

    local procedure ShowConsumptionpage()
    var
        APAMADCSConsumeComponents: Page "APA MADCS Consume Components";
    begin
        Clear(APAMADCSConsumeComponents);
        APAMADCSConsumeComponents.Initialize(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."Item No.", Rec."Quien sirve picking OP");
        APAMADCSConsumeComponents.SetTableView(Rec);
        APAMADCSConsumeComponents.RunModal();
    end;
}