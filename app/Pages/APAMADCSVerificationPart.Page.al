namespace MADCS.MADCS;
using Microsoft.Manufacturing.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item;

/// <summary>
/// APA MADCS Verification Part
/// Part page for managing Verification in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55006 "APA MADCS Verification Part"
{
    Caption = 'Verification', Comment = 'ESP="Verificación"';
    PageType = List;
    SourceTable = "Prod. Order Component";
    SourceTableTemporary = true;
    Editable = true;
    Extensible = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;
    Permissions =
        tabledata "Prod. Order Component" = rimd,
        tabledata "Reservation Entry" = r,
        tabledata "Item" = r,
        tabledata "Item Tracking Code" = r;

    layout
    {
        area(Content)
        {
            grid(Columns)
            {
                group(RepeaterGrp)
                {
                    ShowCaption = false;
                    Editable = true;

                    repeater(Control1)
                    {
                        ShowCaption = false;

                        field("Item No."; Rec."Item No.")
                        {
                            ToolTip = 'Specifies the item number of the component item.', Comment = 'ESP="Especifica el número del producto componente."';
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field(Description; Rec."Description")
                        {
                            ToolTip = 'Specifies the description of the component item.', Comment = 'ESP="Especifica la descripción del producto componente."';
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field("MADCS Lot No."; Rec."APA MADCS Lot No.")
                        {
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field("MADCS Quantity"; Rec."APA MADCS Quantity")
                        {
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field("MADCS Verified"; Rec."APA MADCS Verified")
                        {
                            Editable = true;
                            StyleExpr = styleColor;

                            trigger OnValidate()
                            begin
                                this.MarkAsVerified(Rec."APA MADCS Verified");
                                // Update style color when verification status changes
                                this.SetStyleColor();
                                CurrPage.Update(false);
                            end;
                        }
                    }
                }
                group(DataGrp)
                {
                    ShowCaption = false;

                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.InitializeData();
        this.SetStyleColor();
    end;

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        this.SetStyleColor();
    end;

    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        styleColor: Text;

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

    local procedure InitializeData()
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        APAMADCSManagement.ValidateAndDeleteTemporaryTables(Rec);
        APAMADCSManagement.LoadProdOrderComponentsForValidation(Rec, ProdOrderComponent);
        APAMADCSManagement.LogInOperator();
    end;

    local procedure MarkAsVerified(Verified: Boolean)
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        // If all lots in prod ord comp are verified, set the main line as verified
        CurrPage.Update(true);

        ProdOrderComponent.Copy(Rec);
        Rec.SetRange("APA MADCS Original Line No.", Rec."APA MADCS Original Line No.");
        Rec.SetRange("APA MADCS Verified", not Verified);

        if (Verified and Rec.IsEmpty()) or not Verified then
            if ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."APA MADCS Original Line No.") then begin
                ProdOrderComponent."APA MADCS Verified" := Verified;
                ProdOrderComponent.Modify(false);
            end;

        Rec.SetRange("APA MADCS Original Line No.");
        Rec.SetRange("APA MADCS Verified");
    end;
}