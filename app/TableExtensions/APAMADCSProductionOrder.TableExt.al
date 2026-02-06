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

            trigger OnValidate()
            begin
                if (Rec."APA MADCS Output finished" <> xRec."APA MADCS Output finished") and not Rec."APA MADCS Output finished" and Rec."APA MADCS Time finished" then
                    Message(TimeIsFinishedMsg);
            end;
        }

        field(55001; "APA MADCS Consumption finished"; Boolean)
        {
            Caption = 'Consumption finished', Comment = 'ESP="Consumo finalizado"';
            ToolTip = 'Specifies whether the production order consumption has been finished in MADCS.', Comment = 'ESP="Especifica si el consumo de la orden de producción ha sido finalizado en MADCS."';
            DataClassification = SystemMetadata;

            trigger OnValidate()
            
            begin
                if (Rec."APA MADCS Consumption finished" <> xRec."APA MADCS Consumption finished") and not Rec."APA MADCS Consumption finished" and Rec."APA MADCS Time finished" then
                    Message(TimeIsFinishedMsg);
            end;
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
            AllowInCustomizations = Always;
            Editable = false;
            InitValue = "";
            DataClassification = SystemMetadata;
        }
    }

    var
        TimeIsFinishedMsg: Label 'Order cannot be used in MADCS because time is finished.', Comment = 'ESP="No se puede usar la orden en MADCS porque el tiempo está finalizado."';

    /// <summary>
    /// procedure UpdatePickingStatusField
    /// Updates the "APA MADCS Picking Status" field based on the picking status of the production order components.
    /// </summary>
    /// <param name="save"></param>
    procedure UpdatePickingStatusField(save: Boolean)
    var
        APAMADCSMangenet: Codeunit "APA MADCS Management";
    begin
        APAMADCSMangenet.UpdatePickingStatusField(Rec, save);
    end;
}
