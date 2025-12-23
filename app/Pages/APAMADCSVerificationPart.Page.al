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
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field(Description; Rec."Description")
                        {
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field("MADCS Lot No."; Rec."MADCS Lot No.")
                        {
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field("MADCS Quantity"; Rec."MADCS Quantity")
                        {
                            Editable = false;
                            StyleExpr = styleColor;
                        }
                        field("MADCS Verified"; Rec."MADCS Verified")
                        {
                            Editable = true;
                            StyleExpr = styleColor;

                            trigger OnValidate()
                            begin
                                this.MarkAsVerified(Rec."MADCS Verified");
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
        errMgmt: Codeunit "APA MADCS Posting Management";
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
        if not ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."Original Line No.") then
            exit;

        if ProdOrderComponent."MADCS Verified" then
            newPageStyle := PageStyle::Favorable;

        this.styleColor := Format(newPageStyle);
    end;

    local procedure InitializeData()
    var
        ProdOrderComponent: Record "Prod. Order Component";
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ProdOrderCompReserve: Codeunit "Prod. Order Comp.-Reserve";
        ItemTrackingLines: Page "Item Tracking Lines";
        i: Integer;
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        TemporaryTableErr: Label 'Page table is not temporary.', Comment = 'ESP="La tabla de la página no es temporal."';
        ItemErr: Label 'Item not found: %1', Comment = 'ESP="Artículo no encontrado: %1"';
        ItemTrackingCodeErr: Label 'Item Tracking Code not found: %1', Comment = 'ESP="Código de seguimiento del artículo no encontrado: %1"';
    begin
        if not Rec.IsTemporary() or not TempTrackingSpecification.IsTemporary() then begin
            err := this.errMgmt.BuildApplicationError(ProgramErr, TemporaryTableErr);
            this.errMgmt.Raise(err);
        end;
        Rec.DeleteAll(false);
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey("Prod. Order No.");
        ProdOrderComponent.SetFilter("Prod. Order No.", Rec.GetFilter("Prod. Order No."));
        if ProdOrderComponent.FindSet(false) then
            repeat
                i := 0;
                Clear(Item);
                Clear(ItemTrackingCode);
                Clear(ItemTrackingLines);
                Clear(TrackingSpecification);
                TempTrackingSpecification.DeleteAll(false);
                Rec := ProdOrderComponent;
                Rec."Original Line No." := ProdOrderComponent."Line No.";
                if not Item.Get(ProdOrderComponent."Item No.") then begin
                    err := this.errMgmt.BuildApplicationError(ProgramErr, StrSubstNo(ItemErr, Rec."Item No."));
                    this.errMgmt.Raise(err);
                end;
                if Item."Item Tracking Code" <> '' then begin
                    if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
                        err := this.errMgmt.BuildApplicationError(ProgramErr, StrSubstNo(ItemTrackingCodeErr, Item."Item Tracking Code"));
                        this.errMgmt.Raise(err);
                    end;
                    if ItemTrackingCode."Lot Manuf. Inbound Tracking" then begin
                        ProdOrderCompReserve.InitFromProdOrderComp(TrackingSpecification, ProdOrderComponent);
                        ItemTrackingLines.SetSourceSpec(TrackingSpecification, ProdOrderComponent."Due Date");
                        ItemTrackingLines.SetInbound(ProdOrderComponent.IsInbound());
                        ItemTrackingLines.GetTrackingSpec(TempTrackingSpecification);
                        if TempTrackingSpecification.FindSet(false) then
                            repeat
                                i += 1;
                                Rec."Original Line No." := ProdOrderComponent."Line No.";
                                Rec."Line No." := ProdOrderComponent."Line No." + i;
                                Rec."MADCS Lot No." := TempTrackingSpecification."Lot No.";
                                Rec."MADCS Quantity" := TempTrackingSpecification."Quantity (Base)";
                                Rec.Insert(false);
                            until TempTrackingSpecification.Next() = 0;
                    end;
                end else begin
                    Rec."MADCS Lot No." := '';
                    Rec."MADCS Quantity" := Rec.Quantity;
                    Rec.Insert(false);
                end;
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure MarkAsVerified(Verified: Boolean)
    var
        ProdOrderComponent: Record "Prod. Order Component";
        allVerified: Boolean;
    begin
        // If all lots in prod ord comp are verified, set the main line as verified
        CurrPage.Update(true);

        allVerified := true;
        ProdOrderComponent.Copy(Rec);
        Rec.SetRange("Original Line No.", Rec."Original Line No.");
        Rec.SetRange("MADCS Verified", not Verified);

        allVerified := Rec.IsEmpty();
        if ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."Original Line No.") then begin
            ProdOrderComponent."MADCS Verified" := allVerified;
            ProdOrderComponent.Modify(false);
        end;

        Rec.SetRange("Original Line No.");
        Rec.SetRange("MADCS Verified");
    end;
}