namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

tableextension 55005 "APA MADCS Production Order" extends "Production Order"
{
    fields
    {
        field(55000; "APA MADCS Can be finished"; Boolean)
        {
            Caption = 'Can be finished', Comment = 'ESP="Se puede finalizar"';
            ToolTip = 'Indicates whether the production order can be finished based on MADCS-specific criteria.', Comment = 'ESP="Indica si la orden de producción se puede finalizar según criterios específicos de MADCS."';
            DataClassification = SystemMetadata;
        }
    }
}
