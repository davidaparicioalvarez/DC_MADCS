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

        field(55004; "APA MADCS Pro. Ord. Close Impl"; Enum "IAPA MADCS Pro. Ord. Close Err")
        {
            Caption = 'MADCS Prod. Order Close Error Implementation', Comment = 'ESP="Implementación de error de cierre de orden de producción MADCS"';
            ToolTip = 'Specifies the implementation method for handling production order close errors in MADCS.', Comment = 'ESP="Especifica el método de implementación para manejar los errores de cierre de órdenes de producción en MADCS."';
            DataClassification = SystemMetadata;
        }

        field(55005; "APA MADCS Preparation Task"; Code[10])
        {
            Caption = 'MADCS Preparation Task', Comment = 'ESP="Tarea de preparación MADCS"';
            ToolTip = 'Specifies the operation number for the preparation task in MADCS.', Comment = 'ESP="Especifica el número de operación para la tarea de preparación en MADCS."';
            DataClassification = SystemMetadata;
        }

        field(55006; "APA MADCS Execution Task"; Code[10])
        {
            Caption = 'MADCS Execution Task', Comment = 'ESP="Tarea de ejecución MADCS"';
            ToolTip = 'Specifies the operation number for the execution task in MADCS.', Comment = 'ESP="Especifica el número de operación para la tarea de ejecución en MADCS."';
            DataClassification = SystemMetadata;
        }

        field(55007; "APA MADCS Cleaning Task"; Code[10])
        {
            Caption = 'MADCS Cleaning Task', Comment = 'ESP="Tarea de limpieza MADCS"';
            ToolTip = 'Specifies the operation number for the cleaning task in MADCS.', Comment = 'ESP="Especifica el número de operación para la tarea de limpieza en MADCS."';
            DataClassification = SystemMetadata;
        }
    }
}
