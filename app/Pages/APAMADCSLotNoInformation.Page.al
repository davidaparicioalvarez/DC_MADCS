namespace MADCS.MADCS;

using Microsoft.Inventory.Tracking;

/// <summary>
/// APA MADCS Lot No. Information
/// Page for displaying lot number information in the MADCS system.
/// </summary>
page 55005 "APA MADCS Lot No. Information"
{
    ApplicationArea = All;
    Caption = 'Lot No. Information', Comment = 'ESP="Información del números de lote"';
    Extensible = true;
    PageType = List;
    SourceTable = "Lot No. Information";
    SourceTableTemporary = true;
    UsageCategory = Lists;
    Editable = false;
    
    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item number for the lot information.', Comment = 'ESP="Especifica el número de producto para la información del lote."';
                }
                
                field("Variant Code"; Rec."Variant Code")
                {
                    ToolTip = 'Specifies the variant code for the item.', Comment = 'ESP="Especifica el código de variante del producto."';
                }
                
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the lot number for the item.', Comment = 'ESP="Especifica el número de lote del producto."';
                }
                
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ToolTip = 'Specifies the expiration date for the item.', Comment = 'ESP="Especifica la fecha de caducidad del producto."';
                }
                
                field("APA MADCS Warehouse Inventory"; Rec."APA MADCS Warehouse Inventory")
                {
                }
            }
        }
    }

    procedure AddRecord(ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]; ExpirationDate: Date; LocationCode: Code[10]; BinCode: Code[20])
    begin
        Clear(Rec);
        if not Rec.Get(ItemNo, VariantCode, LotNo) then begin
            Rec."Item No." := ItemNo;
            Rec."Variant Code" := VariantCode;
            Rec."Lot No." := LotNo;
            Rec."Expiration Date" := ExpirationDate;
            Rec.SetRange("Location Filter", LocationCode);
            Rec.SetRange("Bin Filter", BinCode);
            Rec.CalcFields(Inventory);
            if Rec.Inventory > 0 then
                Rec.Insert(false);
        end;
    end;
}