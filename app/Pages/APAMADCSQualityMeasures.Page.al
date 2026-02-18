namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Quality Measures
/// Part page for managing Quality Measures in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55008 "APA MADCS Quality Measures"
{
    // TODO:
    Caption = 'Quality Measures', Comment = 'ESP="Medidas de Calidad"';
    Extensible = true;
    PageType = List;
    SourceTable = "Prod. Order Routing Line";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            grid(Columns)
            {
                group(RepeaterGrp)
                {
                    ShowCaption = false;
                    Editable = false;

                    repeater(Control1)
                    {
                        ShowCaption = false;

                        field("Operation No."; Rec."Operation No.")
                        {
                            Caption = 'Op. No.', Comment = 'ESP="Nº. Op."';
                            Width = 2;
                        }
                        field("Type"; Rec."Type")
                        {
                            Caption = 'Type', Comment = 'ESP="Tipo"';
                            Width = 10;
                        }
                        field("No."; Rec."No.")
                        {
                            Caption = 'No.', Comment = 'ESP="Nº"';
                            Width = 5;
                        }
                        field(Description; Rec.Description)
                        {
                            Caption = 'Description', Comment = 'ESP="Descripción"';
                            Width = 25;
                        }
                        field("Starting Date-Time"; Rec."Starting Date-Time")
                        {
                            Caption = 'Start', Comment = 'ESP="Inicio"';
                            Width = 15;
                        }
                        field("Ending Date-Time"; Rec."Ending Date-Time")
                        {
                            Caption = 'End', Comment = 'ESP="Fin"';
                            Width = 15;
                        }
                        field("Setup Time"; Rec."Setup Time")
                        {
                            Caption = 'Time', Comment = 'ESP="Preparación"';
                            Width = 10;
                        }
                        field("Setup Time Unit of Meas. Code"; Rec."Setup Time Unit of Meas. Code")
                        {
                            ShowCaption = false;
                            Width = 5;
                        }
                        field("Run Time"; Rec."Run Time" * Rec."Input Quantity")
                        {
                            Caption = 'Time', Comment = 'ESP="Ejecución"';
                            Width = 10;
                        }
                        field("Run Time Unit of Meas. Code"; Rec."Run Time Unit of Meas. Code")
                        {
                            ShowCaption = false;
                            Width = 5;
                        }
                    }
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Parameters)
            {
                Caption = 'Parameters', Comment = 'ESP="Parámetros"';
                ToolTip = 'Opens the parameters page for configuring quality measure settings.', Comment = 'ESP="Abre la página de parámetros para configurar los ajustes de las medidas de calidad."';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Page.Run(Page::"APA MADCS QA. Measure Params.");
                end;
            }

            action(ExcelExport)
            {
                Caption = 'Excel', Comment = 'ESP="Excel"';
                ToolTip = 'Exports the quality measures data to an Excel file.', Comment = 'ESP="Exporta los datos de las medidas de calidad a un archivo de Excel."';
                Image = Excel;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    ; // TODO: Implement special Excel generation functionality
                end;
            }

            action(Picture)
            {
                Caption = 'Picture', Comment = 'ESP="Imagen"';
                ToolTip = 'Show a picture of the manufactured item.', Comment = 'ESP="Muestra una imagen del artículo fabricado."';
                Image = Picture;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    ; // TODO: Implement Picture view functionality
                end;
            }

            action(Sample)
            {
                Caption = 'Take Sample', Comment = 'ESP="Tomar Muestra"';
                ToolTip = 'Take a sample of the quality measures.', Comment = 'ESP="Toma una muestra de las medidas de calidad."';
                Image = GetOrder;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    ; // TODO: Implement Get Sample  functionality
                end;
            }
        }
    }
}