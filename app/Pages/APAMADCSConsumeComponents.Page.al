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
                    var
                        NoComponentToConsumeMsg: Label 'No components to consume based on the remaining quantity.', Comment = 'ESP="No hay componentes para consumir en función de la cantidad restante."';
                    begin
                        // Consume all items with "Consumo por resto" = false (quien sirve: Fábrica)
                        if Rec."APA MADCS Qty. After Consump." <> (Rec."APA MADCS Quantity" - Rec."APA MADCS Consumed Quantity") then
                            this.Consume()
                        else
                            Message(NoComponentToConsumeMsg);
                        CurrPage.Update(false);
                    end;
                }
            }

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

                    trigger OnValidate()
                    var
                        OutputQuantytTitleErr: Label 'Invalid Output Quantity', Comment = 'ESP="Cantidad de salida no válida"';
                        OutputQuantityErr: Label 'ERROR: The output quantity cannot exceed the remaining quantity of %1.', Comment = 'ESP="ERROR: La cantidad de salida no puede exceder la cantidad restante de %1."';
                        OutputNegativeQuantityErr: Label 'ERROR: The output quantity cannot be negative.', Comment = 'ESP="ERROR: La cantidad de salida no puede ser negativa."';

                    begin
                        if (Rec."APA MADCS Qty. After Consump." > (Rec."APA MADCS Quantity" - Rec."APA MADCS Consumed Quantity")) then
                            this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(OutputQuantytTitleErr, StrSubstNo(OutputQuantityErr, Rec."Remaining Quantity")));
                        if (Rec."APA MADCS Qty. After Consump." < 0) then
                            this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(OutputQuantytTitleErr, OutputNegativeQuantityErr));
                    end;
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
        DangerButtonTok: Label 'danger', Locked = true;
        ALButtonConsumeAllTok: Label 'ALButtonConsumeAll', Locked = true;

    procedure Initialize(ItemNo: Code[20]; QuienSirvePickingOP: Enum "DC Quien Sirve Picking OP")
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        this.APAMADCSManagement.ValidateAndDeleteTemporaryTables(Rec);
        this.APAMADCSManagement.LoadProdOrderComponentsForWarehouseConsumption(Rec, ProdOrderComponent, ItemNo, QuienSirvePickingOP);
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
        QuantityToConsume: Decimal;
        BadQuantityMsg: Label 'Consume by Rest', Comment = 'ESP="Consumo por restos."';
        BadQuantityErr: Label 'The amount indicated as remainder %1 is not consistent with the amount of component %2 nor with the amount already consumed %3.', Comment = 'ESP="La cantidad indicada como resto %1 no es consistente con la cantidad del componente %2 ni con la cantidad ya consumida %3."';
        ComponentConsuedSuccessMsg: Label 'Component consumed successfully.', Comment = 'ESP="Componente consumido con éxito."';
    begin
        Rec.CalcFields("APA MADCS Consumed Quantity");
        QuantityToConsume := Rec."APA MADCS Quantity" - Rec."APA MADCS Consumed Quantity" - Rec."APA MADCS Qty. After Consump.";
        if QuantityToConsume <= 0 then
            this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(BadQuantityMsg, StrSubstNo(BadQuantityErr, Rec."APA MADCS Qty. After Consump.", Rec."APA MADCS Quantity", Rec."APA MADCS Consumed Quantity")));
        Clear(ProdOrderComponent);
        if ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."APA MADCS Original Line No.") then
            this.APAMADCSManagement.PostQuantityLotComponentConsumption(ProdOrderComponent, QuantityToConsume, Rec."APA MADCS Lot No.");
        Message(ComponentConsuedSuccessMsg);
    end;
}
