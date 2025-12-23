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
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the production order component item.', Comment = 'ESP="Especifica la descripción del componente de la orden de producción."';
                    Editable = false;
                }
                // field("MADCS Lot No."; Rec."MADCS Lot No.")
                // {
                //     Editable = false;
                // }
                field("Expected Quantity"; Rec."Expected Quantity")
                {
                    ToolTip = 'Specifies the expected quantity to be consumed for the production order component.', Comment = 'ESP="Especifica la cantidad esperada por consumir del componente de la orden de producción."';
                    Editable = false;
                }
                field("Remaining Quantity"; Rec."Remaining Quantity")
                {
                    ToolTip = 'Specifies the remaining quantity to be consumed for the production order component.', Comment = 'ESP="Especifica la cantidad restante por consumir del componente de la orden de producción."';
                    Editable = false;
                }
                // field("MADCS Quantity"; Rec."MADCS Quantity")
                // {
                // }
            }
        }
    }

    procedure Initialize(Status: Enum "Production Order Status"; ProdOrderNo: Code[20]; ProdOrderLineNo: Integer; ItemNo: Code[20]; QuienSirvePickingOP: Enum "DC Quien Sirve Picking OP")
    var
        ProdOrderComponent: Record "Prod. Order Component";
        LineNo: Integer;
    begin
        // Initialize the temporary record with data from "Prod. Order Component" for the specified production order, 
        // line, item and showing lots assigned to the component item.
        LineNo := 10000;
        Clear(Rec);
        Rec.DeleteAll(false);
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.", "Prod. Order Line No.", "Item No.", "Quien sirve picking OP");
        ProdOrderComponent.SetRange(Status, Status);
        ProdOrderComponent.SetRange("Prod. Order No.", ProdOrderNo);
        ProdOrderComponent.SetRange("Prod. Order Line No.", ProdOrderLineNo);
        ProdOrderComponent.SetRange("Item No.", ItemNo);
        ProdOrderComponent.SetRange("Quien sirve picking OP", QuienSirvePickingOP);
        if ProdOrderComponent.FindSet() then
            repeat
                Rec.Status := ProdOrderComponent.Status;
                Rec."Prod. Order No." := ProdOrderComponent."Prod. Order No.";
                Rec."Prod. Order Line No." := ProdOrderComponent."Prod. Order Line No.";
                Rec."Line No." := LineNo;
                Rec."Item No." := ProdOrderComponent."Item No.";
                Rec.Description := ProdOrderComponent.Description;
                Rec."Expected Quantity" := ProdOrderComponent."Expected Quantity";
                Rec."Remaining Quantity" := ProdOrderComponent."Remaining Quantity";
                FillItemTracking(ProdOrderComponent, LineNo);
            until ProdOrderComponent.Next() = 0;
    end;

    local procedure FillItemTracking(ProdOrderComponent: Record "Prod. Order Component"; var LineNo: Integer)
    var
        TrackingSpecification: Record "Tracking Specification";
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        ReservEntry: Record "Reservation Entry";
        ProdOrderCompReserve: Codeunit "Prod. Order Comp.-Reserve";
    begin
        ProdOrderCompReserve.InitFromProdOrderComp(TrackingSpecification, ProdOrderComponent);
        ReservEntry.SetSourceFilter(
          TrackingSpecification."Source Type", TrackingSpecification."Source Subtype",
          TrackingSpecification."Source ID", TrackingSpecification."Source Ref. No.", true);
        ReservEntry.SetSourceFilter(
          TrackingSpecification."Source Batch Name", TrackingSpecification."Source Prod. Order Line");
        ReservEntry.SetRange("Untracked Surplus", false);

        AddReservEntriesToTempRecSet(ReservEntry, TempTrackingSpecification);

        TrackingSpecification.SetSourceFilter(
          TrackingSpecification."Source Type", TrackingSpecification."Source Subtype",
          TrackingSpecification."Source ID", TrackingSpecification."Source Ref. No.", true);
        TrackingSpecification.SetSourceFilter(
          TrackingSpecification."Source Batch Name", TrackingSpecification."Source Prod. Order Line");

        if TrackingSpecification.FindSet() then
            repeat
                TempTrackingSpecification := TrackingSpecification;
                TempTrackingSpecification.Insert(false);
            until TrackingSpecification.Next() = 0;


        if TempTrackingSpecification.FindSet() then
            repeat
                Rec."Line No." := LineNo;
                // Rec."MADCS Lot No." := TempTrackingSpecification."Lot No.";
                // Rec."MADCS Quantity" := -TempTrackingSpecification."Qty. to Handle (Base)";
                Rec.Insert(false);
                LineNo += 10000;
            until TempTrackingSpecification.Next() = 0;
    end;

    local procedure AddReservEntriesToTempRecSet(var ReservEntry: Record "Reservation Entry"; var TempTrackingSpecification: Record "Tracking Specification" temporary)
    begin
        if ReservEntry.FindSet() then
            repeat
                if ReservEntry.TrackingExists() then begin
                    TempTrackingSpecification.TransferFields(ReservEntry);
                    // Ensure uniqueness of Entry No. by making it negative:
                    TempTrackingSpecification."Entry No." *= -1;
                    TempTrackingSpecification.Insert(false);
                end;
            until ReservEntry.Next() = 0;
    end;
}
