namespace MADCS.MADCS;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Journal;

/// <summary>
/// APA MADCS Consumption Part
/// Part page for managing consumption of components in production orders.
/// This page will be used within the main MADCS card to display and manage consumption data.
/// </summary>
page 55002 "APA MADCS Consumption Part"
{
    Caption = 'Consumption', Comment = 'ESP="Consumo"';
    Extensible = true;
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
                        Width = 13;
                        StyleExpr = this.styleColor;
                    }
                    field(Description; Rec.Description)
                    {
                        ToolTip = 'Specifies the description of the component.', Comment = 'ESP="Indica la descripción del componente."';
                        Width = 10;
                        StyleExpr = this.styleColor;
                    }
                    field("Consumo por resto"; Rec."Consumo por resto")
                    {
                        Caption = 'CR', Comment = 'ESP="CR"';
                        Width = 1;
                        StyleExpr = this.styleColor;
                    }
                    field(Quantity; Rec."Expected Quantity")
                    {
                        Caption = 'Original Q', Comment = 'ESP="Q Original"';
                        ToolTip = 'Specifies the original quantity of the component.', Comment = 'ESP="Indica la cantidad original del componente."';
                        Width = 5;
                        StyleExpr = this.styleColor;
                    }
                    field("Qty. Picked"; Rec."Qty. Picked")
                    {
                        Caption = 'Pick Q', Comment = 'ESP="Q Servida"';
                        ToolTip = 'Specifies the quantity of the component to pick for consumption.', Comment = 'ESP="Indica la cantidad del componente a recoger para el consumo."';
                        Width = 5;
                        StyleExpr = this.styleColor;
                    }
                    field("Remaining Quantity"; Rec."Remaining Quantity")
                    {
                        Caption = 'Remaining Q', Comment = 'ESP="Q Pendiente"';
                        ToolTip = 'Specifies the remaining quantity of the component to be consumed.', Comment = 'ESP="Indica la cantidad restante del componente por consumir."';
                        Width = 5;
                        StyleExpr = this.styleColor;
                    }
                }
            }
            grid(Columns)
            {
                ShowCaption = false;
                GridLayout = Columns;

                group(leftGrp)
                {
                    ShowCaption = false;

                    usercontrol(ALButtonGroupAll; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            ConsumeAllLbl: Label 'Consume All', Comment = 'ESP="Consumir Todo"';
                            ConsumeAllTextLbl: Label 'Consume all components except for warehouse serving', Comment = 'ESP="Consumir todos los componentes excepto quién sirve almacén"';

                        begin
                            CurrPage.ALButtonGroupAll.AddButton(ConsumeAllLbl, ConsumeAllTextLbl, ALButtonConsumeAllTok, DangerButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            // Consume all items with "Consumo por resto" = false (quien sirve: Fábrica)
                            this.ConsumeAllItemsFromFactory();
                            CurrPage.Update(false);
                        end;
                    }
                }
                group(right)
                {
                    ShowCaption = false;

                    usercontrol(ALButtonGroupItem; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            ConsumeItemLbl: Label 'Consume Item', Comment = 'ESP="Consumir Comp."';
                            ConsumeItemTextLbl: Label 'Consume the selected component', Comment = 'ESP="Consumir el componente seleccionado"';

                        begin
                            CurrPage.ALButtonGroupItem.AddButton(ConsumeItemLbl, ConsumeItemTextLbl, ALButtonConsumeItemTok, PrimaryButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            Rec.CalcFields("Consumo por resto");
                            if not Rec."Consumo por resto" then
                                exit;
                            // Show consumption page for the selected item if the item has "Consumo por resto" = true (quien sirve: Almacén)
                            this.ShowConsumptionPageFromWarehouse();
                        end;
                    }
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
    end;

    var
        styleColor: Text;
        PrimaryButtonTok: Label 'primary', Locked = true;
        DangerButtonTok: Label 'danger', Locked = true;
        ALButtonConsumeAllTok: Label 'ALButtonConsumeAll', Locked = true;
        ALButtonConsumeItemTok: Label 'ALButtonConsumeItem', Locked = true;

    local procedure SetStyleColor()
    var
        newPageStyle: PageStyle;
    begin
        // Set style color based only on remaining quantity and consumption from rest
        Rec.CalcFields("Consumo por resto");
        if Rec."Consumo por resto" then
            newPageStyle := PageStyle::Favorable // Warehouse serving lines: green (Favorable)
        else
            if Rec."Remaining Quantity" = 0 then
                newPageStyle := PageStyle::None // Consumed lines: black (None)
            else
                newPageStyle := PageStyle::Attention; // Non-consumed lines: red (Attention)
        this.styleColor := Format(newPageStyle);
    end;

    local procedure ConsumeAllItemsFromFactory()
    var
        ProdOrderComponent: Record "Prod. Order Component";
        APAMADCSManagement: Codeunit "APA MADCS Management";
        NoProdComponentsMsg: Label 'No production order components found for consumption from factory.', Comment = 'ESP="No se encontraron componentes de orden de producción para consumir desde fábrica."';
    begin
        // Create a Consumption Journal entry for each applicable item
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.", "Prod. Order Line No.");
        ProdOrderComponent.SetRange(Status, Rec.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", Rec."Prod. Order Line No.");
        ProdOrderComponent.SetRange("Consumo por resto", false); // Quien sirve: Fábrica
        ProdOrderComponent.SetFilter("Remaining Quantity", '<>%1', 0); // Only non-consumed items
        if ProdOrderComponent.FindSet() then
            repeat
                APAMADCSManagement.PostCompleteComponentConsumption(ProdOrderComponent);
            until ProdOrderComponent.Next() = 0
        else
            Message(NoProdComponentsMsg);
    end;

    local procedure ShowConsumptionPageFromWarehouse()
    var
        APAMADCSConsumeComponents: Page "APA MADCS Consume Components";
    begin
        Clear(APAMADCSConsumeComponents);
        APAMADCSConsumeComponents.SetTableView(Rec);
        APAMADCSConsumeComponents.Initialize(Rec."Item No.", Rec."Quien sirve picking OP");
        APAMADCSConsumeComponents.RunModal();
    end;
}