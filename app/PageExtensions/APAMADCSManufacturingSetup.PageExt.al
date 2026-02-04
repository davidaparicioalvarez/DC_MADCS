namespace MADCS.MADCS;

using Microsoft.Manufacturing.Setup;

pageextension 55000 "APA MADCS Manufacturing Setup" extends "Manufacturing Setup"
{
    layout
    {
        addlast(content)
        {
            group("MADCS Manufacturing Setup")
            {
                Caption = 'MADCS Manufacturing Setup', Comment = 'ESP="Configuración de fabricación MADCS"';

                field("APA MADCS Consump. Jnl. Templ."; Rec."APA MADCS Consump. Jnl. Templ.")
                {
                    ApplicationArea = All;
                }
                field("APA MADCS Consump. Jnl. Batch"; Rec."APA MADCS Consump. Jnl. Batch")
                {
                    ApplicationArea = All;
                }
                field("APA MADCS Output. Jnl. Templ."; Rec."APA MADCS Output Jnl. Templ.")
                {
                    ApplicationArea = All;
                }
                field("APA MADCS Output. Jnl. Batch"; Rec."APA MADCS Output Jnl. Batch")
                {
                    ApplicationArea = All;
                }
                field("APA MADCS Pro. Ord. Close Impl"; Rec."APA MADCS Pro. Ord. Close Impl")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
