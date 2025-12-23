namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Released Production Order Lines
/// List page for ADCS users to select a released production order.
/// </summary>
page 55000 "APA MADCS Rel Prod Order Lines"
{
    Caption = 'MADCS Released Production Orders Lines', Comment = 'ESP="Líneas de órdenes de producción lanzadas MADCS"';
    PageType = List;
    SourceTable = "Prod. Order Line";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    SourceTableView = where(Status = const(Released),
                            "Orden Preparacion" = filter(<>0));

    // TODO: Add filtering to show only orders assigned to a user or to a work center

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Orden Preparacion"; Rec."Orden Preparacion")
                {
                    ToolTip = 'Specifies the preparation order associated with the production order.', Comment = 'ESP="Especifica el orden de preparación asociado con la orden de producción."';
                }
                field("Agrupacion Centros";Rec."Agrupacion Centros")
                {
                    ToolTip = 'Specifies the work center group associated with the production order.', Comment = 'ESP="Especifica el grupo de centros de trabajo asociado con la orden de producción."';
                }
                field("Prod. Order No."; Rec."Prod. Order No.")
                {
                    ToolTip = 'Specifies the production order number.', Comment = 'ESP="Especifica el número de orden de producción."';
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item number of the item to manufacture.', Comment = 'ESP="Especifica el número de artículo del producto a fabricar."';
                }
                field("Description"; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the item to manufacture.', Comment = 'ESP="Especifica la descripción del producto a fabricar."';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity to produce.', Comment = 'ESP="Especifica la cantidad a producir."';
                }
                field("Finished Quantity"; Rec."Finished Quantity")
                {
                    Visible = false;
                    ToolTip = 'Specifies the finished quantity of the item.', Comment = 'ESP="Especifica la cantidad terminada del producto."';
                }
                field("Starting Date-Time"; Rec."Starting Date-Time")
                {
                    Visible = false;
                    ToolTip = 'Specifies the starting date and time for the production order.', Comment = 'ESP="Especifica la fecha y hora de inicio de la orden de producción."';
                }
                field("Ending Date-Time"; Rec."Ending Date-Time")
                {
                    Visible = false;
                    ToolTip = 'Specifies the ending date and time for the production order.', Comment = 'ESP="Especifica la fecha y hora de finalización de la orden de producción."';
                }
                field("APA MADCS User Working"; Rec."APA MADCS User Working")
                {
                    Visible = false;
                    ToolTip = 'Specifies the user currently working with this production order.', Comment = 'ESP="Especifica el usuario que está trabajando con esta orden de producción."';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Options)
            {
                Caption = 'Process', Comment = 'ESP="Proceso"';

                action(VerificationAct)
                {
                    Caption = 'Verifications', Comment = 'ESP="Verificaciones"';
                    ToolTip = 'Manage verifications for the production order.', Comment = 'ESP="Gestiona las verificaciones para la orden de producción."';
                    Image = CheckList;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ApplicationArea = All;
                    Visible = true; 
                    RunObject = page "APA MADCS Verification Part";
                    RunPageLink = "Status" = field("Status"),
                                  "Prod. Order No." = field("Prod. Order No.");
                }

                action(TimeAct)
                {
                    Caption = 'Time', Comment = 'ESP="Tiempo"';
                    ToolTip = 'Manage the time tracking for the production order.', Comment = 'ESP="Gestiona el seguimiento del tiempo para la orden de producción."';
                    Image = Timeline;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ApplicationArea = All;
                    RunObject = page "APA MADCS Time Part";
                    RunPageLink = Status = field(Status),
                                  "Prod. Order No." = field("Prod. Order No."),
                                  "Prod. Order Line No." = field("Line No.");
                }

                action(StopsAct)
                {
                    Caption = 'Stops', Comment = 'ESP="Paradas"';
                    ToolTip = 'Manage stops for the production order.', Comment = 'ESP="Gestiona las paradas para la orden de producción."';
                    Image = Stop;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ApplicationArea = All;
                    Visible = false; // TODO: V2.Temporarily hide until implemented
                    RunObject = page "APA MADCS Stops Part";
                    RunPageLink = Status = field(Status),
                                  "Prod. Order No." = field("Prod. Order No."),
                                  "Routing Reference No." = field("Line No.");
                }

                action(QualityMeasuresAct)
                {
                    Caption = 'Quality Measures', Comment = 'ESP="Medidas de Calidad"';
                    ToolTip = 'Manage quality measures for the production order.', Comment = 'ESP="Gestiona las medidas de calidad para la orden de producción."';
                    Image = Questionaire;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ApplicationArea = All;
                    Visible = false; // TODO: V2. Temporarily hide until implemented
                    RunObject = page "APA MADCS Quality MeasuresPart";
                    RunPageLink = Status = field(Status), 
                                  "Prod. Order No." = field("Prod. Order No."),
                                  "Routing Reference No." = field("Line No.");
                }

                action(ConsumptionAct)
                {
                    Caption = 'Consumption', Comment = 'ESP="Consumo"';
                    ToolTip = 'Manage the consumption of components for the production order.', Comment = 'ESP="Gestiona el consumo de componentes para la orden de producción."';
                    Image = ConsumptionJournal;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ApplicationArea = All;
                    RunObject = page "APA MADCS Consumption Part";
                    RunPageLink = Status = field(Status),
                                  "Prod. Order No." = field("Prod. Order No."),
                                  "Prod. Order Line No." = field("Line No.");
                }

                action(OutputsAct)
                {
                    Caption = 'Outputs', Comment = 'ESP="Salidas"';
                    ToolTip = 'Manage the outputs for the production order.', Comment = 'ESP="Gestiona las salidas para la orden de producción."';
                    Image = OutputJournal;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ApplicationArea = All;
                    RunObject = page "APA MADCS Outputs Part";
                    RunPageLink = Status = field(Status),
                                  "Prod. Order No." = field("Prod. Order No."),
                                  "Routing Reference No." = field("Line No.");
                }
            }
        }
    }
}
