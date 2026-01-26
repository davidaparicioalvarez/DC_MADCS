namespace MADCS.MADCS;

using Microsoft.Manufacturing.Setup;
using Microsoft.Inventory.Journal;

tableextension 55003 "APA MADCS Manufacturing Setup" extends "Manufacturing Setup"
{
    fields
    {
        field(55000; "APA MADCS Consump. Jnl. Templ."; Code[10])
        {
            Caption = 'MADCS Consumption Journal Template', Comment = 'ESP="Plantilla de diario de consumo MADCS"';
            ToolTip = 'Specifies the item journal template to be used for MADCS consumption journals.', Comment = 'ESP="Especifica el nombre del diario que se utilizará para los diarios de consumo MADCS."';
            DataClassification = SystemMetadata;
            TableRelation = "Item Journal Template" where (Type = const(Consumption));
        }

        field(55001; "APA MADCS Consump. Jnl. Batch"; Code[10])
        {
            Caption = 'MADCS Consumption Journal Batch', Comment = 'ESP="Sección de diario de consumo MADCS"';
            ToolTip = 'Specifies the item journal batch to be used for MADCS consumption journals.', Comment = 'ESP="Especifica la sección del diario que se utilizará para los diarios de consumo MADCS."';
            DataClassification = SystemMetadata;
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("APA MADCS Consump. Jnl. Templ."));
        }
        field(55002; "APA MADCS Output Jnl. Templ."; Code[10])
        {
            Caption = 'MADCS Output Journal Template', Comment = 'ESP="Plantilla de diario de salida MADCS"';
            ToolTip = 'Specifies the item journal template to be used for MADCS output journals.', Comment = 'ESP="Especifica el nombre del diario que se utilizará para los diarios de salida MADCS."';
            DataClassification = SystemMetadata;
            TableRelation = "Item Journal Template" where (Type = const(Output));
        }

        field(55003; "APA MADCS Output Jnl. Batch"; Code[10])
        {
            Caption = 'MADCS Output Journal Batch', Comment = 'ESP="Sección de diario de salida MADCS"';
            ToolTip = 'Specifies the item journal batch to be used for MADCS output journals.', Comment = 'ESP="Especifica la sección del diario que se utilizará para los diarios de salida MADCS."';
            DataClassification = SystemMetadata;
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("APA MADCS Output Jnl. Templ."));
        }
    }
}
