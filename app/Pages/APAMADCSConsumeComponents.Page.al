namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;
using Microsoft.Inventory.Tracking;

/// <summary>
/// APA MADCS Consume Components
/// Page for consuming components in the MADCS system.
/// </summary>
page 55001 "APA MADCS Consume Components"
{
    Caption = 'Consume Components', Comment = 'ESP="Consumir Componentes"';
    Extensible = true;
    PageType = List;
    SourceTable = "Prod. Order Component";
    SourceTableTemporary = true;
    UsageCategory = None;
    InsertAllowed = false;
    ModifyAllowed = true;
    DeleteAllowed = false;
    Editable = true;
    ApplicationArea = All;
    Permissions =
        tabledata "Tracking Specification" = r,
        tabledata "Reservation Entry" = r;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item number of the production order component.', Comment = 'ESP="Especifica el número de producto del componente de la orden de producción."';
                    Editable = false;
                    StyleExpr = this.styleColor;
                    Width = 13;
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the production order component item.', Comment = 'ESP="Especifica la descripción del componente de la orden de producción."';
                    Editable = false;
                    StyleExpr = this.styleColor;
                    Width = 10;
                }
                field("MADCS Lot No."; Rec."APA MADCS Lot No.")
                {
                    Editable = false;
                    StyleExpr = this.styleColor;
                }
                field("MADCS Quantity"; Rec."APA MADCS Quantity")
                {
                    Editable = false;
                    StyleExpr = this.styleColor;
                    Width = 5;
                }
                field("MADCS Consumed Quantity"; Rec."APA MADCS Consumed Quantity")
                {
                    Editable = false;
                    StyleExpr = this.styleColor;
                    Width = 5;
                }
                field("MADCS Qty. After Consumption"; Rec."APA MADCS Qty. After Consump.")
                {
                    Editable = true;
                    StyleExpr = this.styleColor;
                    Width = 5;
                }
            }
            group(buttonGrp)
            {
                ShowCaption = false;

                usercontrol(ALButtonGroupAll; "APA MADCS ButtonGroup")
                {
                    Visible = true;

                    trigger OnLoad()
                    var
                        ConsumeAllLbl: Label 'Consume Lot', Comment = 'ESP="Consumir Lote"';
                        ConsumeAllTextLbl: Label 'Consume by rest selected line with lot and rest to consume.', Comment = 'ESP="Consumir por resto la línea seleccionada con lote y resto a consumir."';

                    begin
                        CurrPage.ALButtonGroupAll.AddButton(ConsumeAllLbl, ConsumeAllTextLbl, this.ALButtonConsumeAllTok, this.DangerButtonTok);
                    end;

                    trigger OnClick(id: Text)
                    begin
                        // Consume all items with "Consumo por resto" = false (quien sirve: Fábrica)
                        this.Consume();
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        this.SetStyleColor();
    end;

    var
        styleColor: Text;
        DangerButtonTok: Label 'danger', Locked = true;
        ALButtonConsumeAllTok: Label 'ALButtonConsumeAll', Locked = true;

    procedure Initialize(ItemNo: Code[20]; QuienSirvePickingOP: Enum "DC Quien Sirve Picking OP")
    var
        ProdOrderComponent: Record "Prod. Order Component";
        APAMADCSManagement: Codeunit "APA MADCS Management";
    begin
        APAMADCSManagement.ValidateAndDeleteTemporaryTables(Rec);
        APAMADCSManagement.LoadProdOrderComponentsForWarehouseConsumption(Rec, ProdOrderComponent, ItemNo, QuienSirvePickingOP);
    end;

    local procedure SetStyleColor()
    var
        ProdOrderComponent: Record "Prod. Order Component";
        newPageStyle: PageStyle;
    begin
        // Set style color based only on remaining quantity
        // Consumed lines (remaining quantity = 0): black (None)
        // Non-consumed lines (remaining quantity > 0): red (Attention)
        newPageStyle := PageStyle::Attention;
        if not ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."APA MADCS Original Line No.") then
            exit;

        if ProdOrderComponent."APA MADCS Verified" then
            newPageStyle := PageStyle::Favorable;

        this.styleColor := Format(newPageStyle);
    end;

    local procedure Consume()
    var
        ProdOrderComponent: Record "Prod. Order Component";
        APAMADCSManagement: Codeunit "APA MADCS Management";
        err: ErrorInfo;
        QuantityToConsume: Decimal;
        BadQuantityMsg: Label 'Consume by Rest', Comment = 'ESP="Consumo por restos."';
        BadQuantityErr: Label 'The amount indicated as remainder %1 is not consistent with the amount of component %2 nor with the amount already consumed %3.', Comment = 'ESP="La cantidad indicada como resto %1 no es consistente con la cantidad del componente %2 ni con la cantidad ya consumida %3."';
    begin
        Rec.CalcFields("APA MADCS Consumed Quantity");
        QuantityToConsume := Rec."APA MADCS Quantity" - Rec."APA MADCS Consumed Quantity" - Rec."APA MADCS Qty. After Consump.";
        if QuantityToConsume <= 0 then begin
            err := APAMADCSManagement.BuildApplicationError(BadQuantityMsg, StrSubstNo(BadQuantityErr, Rec."APA MADCS Qty. After Consump.", Rec."APA MADCS Quantity", Rec."APA MADCS Consumed Quantity"));
            APAMADCSManagement.Raise(err);
        end;
        Clear(ProdOrderComponent);
        if ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."APA MADCS Original Line No.") then
            APAMADCSManagement.PostQuantityLotComponentConsumption(ProdOrderComponent, QuantityToConsume, Rec."APA MADCS Lot No.");
    end;
}
