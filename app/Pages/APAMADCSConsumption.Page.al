namespace MADCS.MADCS;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Journal;
using System.Utilities;

/// <summary>
/// APA MADCS Consumption
/// Part page for managing consumption of components in production orders.
/// This page will be used within the main MADCS card to display and manage consumption data.
/// </summary>
page 55002 "APA MADCS Consumption"
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
        tabledata "Warehouse Entry" = r,
        tabledata "Prod. Order Line" = r;

    layout
    {
        area(Content)
        {
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
                            ConsumeAllLbl: Label 'Cons. All WAR/DOC', Comment = 'ESP="Cons. Todo FAB/DOC"';
                            ConsumeAllTextLbl: Label 'Consume all components except for warehouse serving', Comment = 'ESP="Consumir todos los componentes excepto quién sirve almacén"';

                        begin
                            CurrPage.ALButtonGroupAll.AddButton(ConsumeAllLbl, ConsumeAllTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonConsumeAllTok), this.WarningButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            // Consume all items with "Consumo por resto" = false (quien sirve: Fábrica)
                            this.ConsumeAllItemsFromFactory();
                            CurrPage.Update(false);
                        end;
                    }
                }

                group(center)
                {
                    ShowCaption = false;

                    usercontrol(ALButtonGroupItem; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            ConsumeItemLbl: Label 'Cons. Component', Comment = 'ESP="Cons. Componente"';
                            ConsumeItemTextLbl: Label 'Consume the selected component', Comment = 'ESP="Consumir el componente seleccionado"';

                        begin
                            CurrPage.ALButtonGroupItem.AddButton(ConsumeItemLbl, ConsumeItemTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonConsumeItemTok), this.PrimaryButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        begin
                            // Show consumption page for the selected item if the item has "Consumo por resto" = true (quien sirve: Almacén)
                            this.ShowConsumptionPageFromWarehouse();
                            CurrPage.Update(false);
                        end;
                    }
                }
                group(right)
                {
                    ShowCaption = false;

                    usercontrol(ALInfButtonFinish; "APA MADCS ButtonGroup")
                    {
                        Visible = true;

                        trigger OnLoad()
                        var
                            FinishLbl: Label 'End (Consumptions)', Comment = 'ESP="Fin (Consumos)"';
                            FinishOrderLbl: Label 'End Consumptions in Order', Comment = 'ESP="Fin Consumos en Orden"';
                        begin
                            CurrPage.ALInfButtonFinish.AddButton(FinishLbl, FinishOrderLbl, Format(Enum::"APA MADCS Buttons"::ALButtonFinalizeConsumptionTok), this.DangerButtonTok);
                        end;

                        trigger OnClick(id: Text)
                        var
                            ConfirmFinishOrderMsg: Label 'Production order marked as finished in consumptions and created new cleaning activity successfully.', Comment = 'ESP="Orden de producción marcada como finalizada en consumos y creada nueva actividad de limpieza con éxito."';
                        begin
                            if this.MarkProductionOrderAsFinished(Rec) then begin
                                Message(ConfirmFinishOrderMsg);
                                CurrPage.Close();
                            end
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

                    field("Item No."; Rec."Item No.")
                    {
                        ToolTip = 'Specifies the item number associated with the component.', Comment = 'ESP="Indica el número de artículo asociado con el componente."';
                        Width = 14;
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
                        Visible = false;
                        Width = 1;
                        StyleExpr = this.styleColor;
                    }
                    field("Quien sirve picking OP"; Rec."Quien sirve picking OP")
                    {
                        Caption = 'Picking Servicer', Comment = 'ESP="Quien sirve picking"';
                        ToolTip = 'Specifies Warehouse implies remaining quantities.Factories/OrderDocument if the OPL isn`t interrupted don`t perform remaining quantities select "consume all" button; else perform remaining quantities.', Comment = 'ESP="Opción Almacen siempre impilca Realizar Restos.Fabrica/DocOrden: Si no se interrumpe la OPL no realizar resto marcar boton consumir todo, si se interrumpe la OPL realizar resto."';
                        Width = 10;
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
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
    end;

    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        styleColor: Text;
        PrimaryButtonTok: Label 'primary', Locked = true;
        DangerButtonTok: Label 'danger', Locked = true;
        WarningButtonTok: Label 'warning', Locked = true;

    local procedure SetStyleColor()
    var
        newPageStyle: PageStyle;
    begin
        // Set style color based only on remaining quantity and consumption from rest
        Rec.CalcFields("Consumo por resto");
        if Rec."Consumo por resto" then begin
            if Rec."Remaining Quantity" = 0 then
                newPageStyle := PageStyle::None // Consumed lines: black (None)
            else
                newPageStyle := PageStyle::Favorable // Warehouse serving lines: green (Favorable)
        end else
            if Rec."Remaining Quantity" = 0 then
                newPageStyle := PageStyle::None // Consumed lines: black (None)
            else
                newPageStyle := PageStyle::Attention; // Non-consumed lines: red (Attention)
        this.styleColor := Format(newPageStyle);
    end;

    local procedure ConsumeAllItemsFromFactory()
    var
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderComponent: Record "Prod. Order Component";
        NoProdComponentsMsg: Label 'No production order components found for consumption from factory.', Comment = 'ESP="No se encontraron componentes de orden de producción para consumir desde fábrica."';
        ConsumptionCompleteMsg: Label 'All applicable components from factory have been consumed successfully.', Comment = 'ESP="Todos los componentes aplicables desde fábrica han sido consumidos con éxito."';
        CannotConsumeTitleMsg: Label 'Cannot Consume All from Factory', Comment = 'ESP="No se puede consumir todo desde fábrica"';
        CannotConsumeErr: Label 'Cannot consume all components from factory because the produced quantity %1 does not match the expected quantity to produce %2.', Comment = 'ESP="No se pueden consumir todos los componentes desde fábrica porque la cantidad fabricada %1 no coincide con la cantidad esperada a fabricar %2."';
    begin
        // We can consume all only if expected quantity line is equal to produced quantity
        Clear(ProdOrderLine);
        if ProdOrderLine.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.") then
            if ProdOrderLine."Quantity" <> ProdOrderLine."Finished Quantity" then
                this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(CannotConsumeTitleMsg, StrSubstNo(CannotConsumeErr, ProdOrderLine."Finished Quantity", ProdOrderLine."Quantity")));

        // Create a Consumption Journal entry for each applicable item
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.", "Prod. Order Line No.");
        ProdOrderComponent.SetRange(Status, Rec.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", Rec."Prod. Order Line No.");
        ProdOrderComponent.SetRange("Consumo por resto", false); // Quien sirve: Fábrica
        ProdOrderComponent.SetFilter("Remaining Quantity", '<>%1', 0); // Only non-consumed items
        if ProdOrderComponent.FindSet() then begin
            repeat
                this.APAMADCSManagement.PostCompleteComponentConsumption(ProdOrderComponent);
            until ProdOrderComponent.Next() = 0;
            Message(ConsumptionCompleteMsg);
        end else
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

    internal procedure MarkProductionOrderAsFinished(ProdOrdComponent: Record "Prod. Order Component"): Boolean
    var
        ConfirmMgmt: Codeunit "Confirm Management";
        ConfirmFinishOrderQst: Label 'Are you sure you want to mark this production order as finished in consumptions and create new cleaning activity?', Comment = 'ESP="¿Está seguro de que desea marcar esta orden de producción como finalizada en consumos y crear una nueva actividad de limpieza?"';
    begin
        // Get user confirmation first
        if not ConfirmMgmt.GetResponseOrDefault(ConfirmFinishOrderQst) then
            exit(false);
        exit(this.APAMADCSManagement.MarkProductionOrderAsConsumptionFinished(ProdOrdComponent));
    end;
}