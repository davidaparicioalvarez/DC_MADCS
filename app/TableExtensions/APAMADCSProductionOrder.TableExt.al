namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

tableextension 55005 "APA MADCS Production Order" extends "Production Order"
{
    fields
    {
        field(55000; "APA MADCS Output finished"; Boolean)
        {
            Caption = 'Output finished', Comment = 'ESP="Salida finalizada"';
            ToolTip = 'Specifies whether the production order output has been finished in MADCS.', Comment = 'ESP="Especifica si la salida de la orden de producción ha sido finalizada en MADCS."';
            DataClassification = SystemMetadata;
        }

        field(55001; "APA MADCS Consumption finished"; Boolean)
        {
            Caption = 'Consumption finished', Comment = 'ESP="Consumo finalizado"';
            ToolTip = 'Specifies whether the production order consumption has been finished in MADCS.', Comment = 'ESP="Especifica si el consumo de la orden de producción ha sido finalizado en MADCS."';
            DataClassification = SystemMetadata;
        }

        field(55002; "APA MADCS Time finished"; Boolean)
        {
            Caption = 'Time finished', Comment = 'ESP="Tiempo finalizado"';
            ToolTip = 'Specifies whether the production order time has been finished in MADCS.', Comment = 'ESP="Especifica si el tiempo de la orden de producción ha sido finalizado en MADCS."';
            DataClassification = SystemMetadata;
        }

        field(55003; "APA MADCS Picking Status"; Enum "APA MADCS Picking Status")
        { // Derived from DC extension
            Caption = 'Picking Status', Comment = 'ESP="APA MADCS Picking Status"';
            Editable = false;
            InitValue = "";
            DataClassification = SystemMetadata;
        }
    }

    /// <summary>
    /// procedure UpdatePickingStatusField
    /// Updates the "APA MADCS Picking Status" field based on the picking status of the production order components.
    /// </summary>
    /// <param name="save"></param>
    procedure UpdatePickingStatusField(save: Boolean)
    var
        lrProdOrderComponent: Record "Prod. Order Component";
        lineasTotales: Integer;
    begin
        Clear(Rec."APA MADCS Picking Status");
        Clear(lrProdOrderComponent);
        lrProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.");
        lrProdOrderComponent.SetRange(Status, Rec.Status);
        lrProdOrderComponent.SetRange("Prod. Order No.", Rec."No.");
        lineasTotales := lrProdOrderComponent.Count();
        lrProdOrderComponent.SetRange("Completely Picked", false);
        if lrProdOrderComponent.IsEmpty() then begin
            Rec."APA MADCS Picking Status" := Rec."APA MADCS Picking Status"::"Totaly Picked";
            if save then
                Rec.Modify(true);
        end else
            if (lrProdOrderComponent.Count() <> lineasTotales) then begin
                Rec."APA MADCS Picking Status" := Rec."APA MADCS Picking Status"::"Partialy Picked";
                if save then
                    Rec.Modify(true);
            end else begin
                Rec.CalcFields("RPO No. Picking");
                if (Rec."RPO No. Picking" <> '') then begin
                    Rec."APA MADCS Picking Status" := Rec."APA MADCS Picking Status"::Pending;
                    if save then
                        Rec.Modify(true);
                end 
            end;
    end;
}
