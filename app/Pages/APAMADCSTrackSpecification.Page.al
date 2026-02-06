namespace MADCS.MADCS;

using Microsoft.Inventory.Tracking;

page 55007 "APA MADCS Track. Specification"
{
    ApplicationArea = All;
    Caption = 'Tracking Specification', Comment = 'ESP="Especificación de seguimiento"';
    Editable = false;
    PageType = List;
    SourceTable = "Tracking Specification";
    SourceTableTemporary = true;
    UsageCategory = None;
    
    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the tracking lot number.', Comment = 'ESP="Especifica el número de lote de trazabilidad."';
                }
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ToolTip = 'Specifies the expiration date for the tracking lot.', Comment = 'ESP="Especifica la fecha de vencimiento del lote de trazabilidad."';
                }
            }
        }
    }

    /// <summary>
    /// Initializes the page's temporary tracking specification data from an external temporary variable.
    /// </summary>
    /// <param name="SourceTrackingSpecification">Temporary tracking specification record to load from.</param>
    procedure InitializeTrackingData(var SourceTrackingSpecification: Record "Tracking Specification" temporary)
    begin
        Rec.DeleteAll(false);
        
        if SourceTrackingSpecification.FindSet() then
            repeat
                Rec.Init();
                Rec := SourceTrackingSpecification;
                Rec.Insert(false);
            until SourceTrackingSpecification.Next() = 0;
    end;

    /// <summary>
    /// Gets the selected tracking specification record from the page.
    /// </summary>
    /// <param name="TrackingSpecification">Output parameter to receive the selected record.</param>
    procedure GetSelectedTrackingSpec(var TrackingSpecification: Record "Tracking Specification" temporary)
    begin
        TrackingSpecification := Rec;
    end;
}
