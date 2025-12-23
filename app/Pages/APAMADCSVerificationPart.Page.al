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
    begin
        this.ValidateAndDeleteTemporaryTables();
        this.LoadProdOrderComponents(ProdOrderComponent);
    end;

    local procedure ValidateAndDeleteTemporaryTables()
    var
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        TemporaryTableErr: Label 'Page table is not temporary.', Comment = 'ESP="La tabla de la página no es temporal."';
    begin
        if not Rec.IsTemporary() or not TempTrackingSpecification.IsTemporary() then begin
            err := this.errMgmt.BuildApplicationError(ProgramErr, TemporaryTableErr);
            this.errMgmt.Raise(err);
        end;
        Rec.DeleteAll(false);
    end;

    local procedure LoadProdOrderComponents(var ProdOrderComponent: Record "Prod. Order Component")
    begin
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey("Prod. Order No.");
        ProdOrderComponent.SetFilter("Prod. Order No.", Rec.GetFilter("Prod. Order No."));
        if ProdOrderComponent.FindSet(false) then
            repeat
                this.ProcessProdOrderComponent(ProdOrderComponent);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure ProcessProdOrderComponent(ProdOrderComponent: Record "Prod. Order Component")
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        Rec := ProdOrderComponent;
        this.ValidateAndGetItem(Item, ProdOrderComponent."Item No.");
        if this.ShouldProcessItemTracking(Item, ItemTrackingCode) then
            this.ProcessItemWithTracking(ProdOrderComponent)
        else
            this.InsertComponentRecord(ProdOrderComponent, '', Rec.Quantity, 0);
    end;

    local procedure ValidateAndGetItem(var Item: Record Item; ItemNo: Code[20])
    var
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        ItemErr: Label 'Item not found: %1', Comment = 'ESP="Artículo no encontrado: %1"';
    begin
        Clear(Item);
        if not Item.Get(ItemNo) then begin
            err := this.errMgmt.BuildApplicationError(ProgramErr, StrSubstNo(ItemErr, ItemNo));
            this.errMgmt.Raise(err);
        end;
    end;

    local procedure ShouldProcessItemTracking(Item: Record Item; var ItemTrackingCode: Record "Item Tracking Code"): Boolean
    var
        err: ErrorInfo;
        ProgramErr: Label 'Error initializing verification data.', Comment = 'ESP="Error al inicializar los datos de verificación."';
        ItemTrackingCodeErr: Label 'Item Tracking Code not found: %1', Comment = 'ESP="Código de seguimiento del artículo no encontrado: %1"';
    begin
        if Item."Item Tracking Code" = '' then
            exit(false);

        Clear(ItemTrackingCode);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            err := this.errMgmt.BuildApplicationError(ProgramErr, StrSubstNo(ItemTrackingCodeErr, Item."Item Tracking Code"));
            this.errMgmt.Raise(err);
        end;

        exit(ItemTrackingCode."Lot Manuf. Inbound Tracking");
    end;

    local procedure ProcessItemWithTracking(ProdOrderComponent: Record "Prod. Order Component")
    var
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        ProdOrderCompReserve: Codeunit "Prod. Order Comp.-Reserve";
        ItemTrackingLines: Page "Item Tracking Lines";
        i: Integer;
    begin
        Clear(TrackingSpecification);
        Clear(ItemTrackingLines);
        TempTrackingSpecification.DeleteAll(false);

        ProdOrderCompReserve.InitFromProdOrderComp(TrackingSpecification, ProdOrderComponent);
        ItemTrackingLines.SetSourceSpec(TrackingSpecification, ProdOrderComponent."Due Date");
        ItemTrackingLines.SetInbound(ProdOrderComponent.IsInbound());
        ItemTrackingLines.GetTrackingSpec(TempTrackingSpecification);

        i := 0;
        if TempTrackingSpecification.FindSet(false) then
            repeat
                i += 1;
                this.InsertComponentRecord(ProdOrderComponent, TempTrackingSpecification."Lot No.", TempTrackingSpecification."Quantity (Base)", i);
            until TempTrackingSpecification.Next() = 0;
    end;

    /// <summary>
    /// InsertComponentRecord
    /// Inserts a component record with or without item tracking information.
    /// </summary>
    /// <param name="ProdOrderComponent">Record "Prod. Order Component"</param>
    /// <param name="LotNo">Text[50]</param>
    /// <param name="Quantity">Decimal</param>
    /// <param name="LineIncrement">Integer</param>
    local procedure InsertComponentRecord(ProdOrderComponent: Record "Prod. Order Component"; LotNo: Text[50]; Quantity: Decimal; LineIncrement: Integer)
    begin
        Rec."Original Line No." := ProdOrderComponent."Line No.";
        Rec."Line No." := ProdOrderComponent."Line No." + LineIncrement;
        Rec."MADCS Lot No." := LotNo;
        Rec."MADCS Quantity" := Quantity;
        Rec.Insert(false);
    end;

    local procedure MarkAsVerified(Verified: Boolean)
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        // If all lots in prod ord comp are verified, set the main line as verified
        CurrPage.Update(true);

        ProdOrderComponent.Copy(Rec);
        Rec.SetRange("Original Line No.", Rec."Original Line No.");
        Rec.SetRange("MADCS Verified", not Verified);

        if (Verified and Rec.IsEmpty()) or not Verified then
            if ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."Original Line No.") then begin
                ProdOrderComponent."MADCS Verified" := Verified;
                ProdOrderComponent.Modify(false);
            end;

        Rec.SetRange("Original Line No.");
        Rec.SetRange("MADCS Verified");
    end;
}