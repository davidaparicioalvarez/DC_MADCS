namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Released Production Order Lines
/// List page for ADCS users to select a released production order.
/// </summary>
page 55000 "APA MADCS Rel Prod Order Lines"
{
    Caption = 'Released Production Orders Lines', Comment = 'ESP="Líneas de órdenes de producción lanzadas"';
    Extensible = true;
    PageType = List;
    SourceTable = "Prod. Order Line";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    SourceTableView = where(Status = const(Released),
                            "Orden Preparacion" = filter(<> 0));

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
                    StyleExpr = styleColor;
                }
                field("Agrupacion Centros"; Rec."Agrupacion Centros")
                {
                    ToolTip = 'Specifies the work center group associated with the production order.', Comment = 'ESP="Especifica el grupo de centros de trabajo asociado con la orden de producción."';
                    StyleExpr = styleColor;
                }
                field("Prod. Order No."; Rec."Prod. Order No.")
                {
                    ToolTip = 'Specifies the production order number.', Comment = 'ESP="Especifica el número de orden de producción."';
                    StyleExpr = styleColor;
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item number of the item to manufacture.', Comment = 'ESP="Especifica el número de artículo del producto a fabricar."';
                    StyleExpr = styleColor;
                }
                field("Description"; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the item to manufacture.', Comment = 'ESP="Especifica la descripción del producto a fabricar."';
                    StyleExpr = styleColor;
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity to produce.', Comment = 'ESP="Especifica la cantidad a producir."';
                    StyleExpr = styleColor;
                }
                field("Finished Quantity"; Rec."Finished Quantity")
                {
                    Visible = false;
                    ToolTip = 'Specifies the finished quantity of the item.', Comment = 'ESP="Especifica la cantidad terminada del producto."';
                    StyleExpr = styleColor;
                }
                field("Starting Date-Time"; Rec."Starting Date-Time")
                {
                    Visible = false;
                    ToolTip = 'Specifies the starting date and time for the production order.', Comment = 'ESP="Especifica la fecha y hora de inicio de la orden de producción."';
                    StyleExpr = styleColor;
                }
                field("Ending Date-Time"; Rec."Ending Date-Time")
                {
                    Visible = false;
                    ToolTip = 'Specifies the ending date and time for the production order.', Comment = 'ESP="Especifica la fecha y hora de finalización de la orden de producción."';
                    StyleExpr = styleColor;
                }
                field("APA MADCS User Working"; Rec."APA MADCS User Working")
                {
                    Visible = false;
                    ToolTip = 'Specifies the user currently working with this production order.', Comment = 'ESP="Especifica el usuario que está trabajando con esta orden de producción."';
                    StyleExpr = styleColor;
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

                    trigger OnAction()
                    var
                        TempProdOrderComponent: Record "Prod. Order Component" temporary;
                        APAMADCSVerificationPart: Page "APA MADCS Verification Part";
                    begin
                        Clear(TempProdOrderComponent);
                        TempProdOrderComponent.SetRange("Status", Rec.Status);
                        TempProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                        Clear(APAMADCSVerificationPart);
                        APAMADCSVerificationPart.SetTableView(TempProdOrderComponent);
                        APAMADCSVerificationPart.RunModal();
                        CurrPage.Update(false);
                    end;
                }

                action(QualityMeasuresAct)
                { // TODO: V2. 
                    Caption = 'Quality', Comment = 'ESP="Calidad"';
                    ToolTip = 'Manage quality measures for the production order.', Comment = 'ESP="Gestiona las medidas de calidad para la orden de producción."';
                    Image = Questionaire;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = IsVerified;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
                        APAMADCSQualityMeasuresPart: Page "APA MADCS Quality MeasuresPart";
                    begin
                        Clear(ProdOrderRoutingLine);
                        ProdOrderRoutingLine.SetRange(Status, Rec.Status);
                        ProdOrderRoutingLine.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                        ProdOrderRoutingLine.SetRange("Routing Reference No.", Rec."Line No.");
                        Clear(APAMADCSQualityMeasuresPart);
                        APAMADCSQualityMeasuresPart.SetTableView(ProdOrderRoutingLine);
                        APAMADCSQualityMeasuresPart.RunModal();
                        CurrPage.Update(false);
                    end;
                }

                // action(TimeAct)
                // {
                //     Caption = 'Time', Comment = 'ESP="Tiempo"';
                //     ToolTip = 'Manage the time tracking for the production order.', Comment = 'ESP="Gestiona el seguimiento del tiempo para la orden de producción."';
                //     Image = Timeline;
                //     Promoted = true;
                //     PromotedOnly = true;
                //     PromotedCategory = Process;
                //     PromotedIsBig = true;
                //     Visible = IsVerified;
                //     ApplicationArea = All;

                //     trigger OnAction()
                //     var
                //         APAMADCSProOrderLineTime: Record "APA MADCS Pro. Order Line Time";
                //     begin
                //         Clear(APAMADCSProOrderLineTime);
                //         APAMADCSProOrderLineTime.SetRange("Status", Rec.Status);
                //         APAMADCSProOrderLineTime.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                //         APAMADCSProOrderLineTime.SetRange("Prod. Order Line No.", Rec."Line No.");
                //         RunModal(Page::"APA MADCS Time Part", APAMADCSProOrderLineTime);
                //         CurrPage.Update(false);
                //     end;
                // }

                // action(StopsAct)
                // { // TODO: V2. 
                //     Caption = 'Stops', Comment = 'ESP="Paradas"';
                //     ToolTip = 'Manage stops for the production order.', Comment = 'ESP="Gestiona las paradas para la orden de producción."';
                //     Image = Stop;
                //     Promoted = true;
                //     PromotedOnly = true;
                //     PromotedCategory = Process;
                //     PromotedIsBig = true;
                //     Visible = IsVerified;
                //     ApplicationArea = All;

                //     trigger OnAction()
                //     var
                //         ProdOrderRoutingLine: Record "Prod. Order Routing Line";
                //     begin
                //         Clear(ProdOrderRoutingLine);
                //         ProdOrderRoutingLine.SetRange(Status, Rec.Status);
                //         ProdOrderRoutingLine.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                //         ProdOrderRoutingLine.SetRange("Routing Reference No.", Rec."Line No.");
                //         RunModal(Page::"APA MADCS Stops Part", ProdOrderRoutingLine);
                //         CurrPage.Update(false);
                //     end;
                // }

                // action(ConsumptionAct)
                // {
                //     Caption = 'Consumption', Comment = 'ESP="Consumo"';
                //     ToolTip = 'Manage the consumption of components for the production order.', Comment = 'ESP="Gestiona el consumo de componentes para la orden de producción."';
                //     Image = ConsumptionJournal;
                //     Promoted = true;
                //     PromotedOnly = true;
                //     PromotedCategory = Process;
                //     PromotedIsBig = true;
                //     Visible = IsVerified;
                //     ApplicationArea = All;

                //     trigger OnAction()
                //     var
                //         ProdOrderComponent: Record "Prod. Order Component";
                //     begin
                //         Clear(ProdOrderComponent);
                //         ProdOrderComponent.SetRange(Status, Rec.Status);
                //         ProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                //         ProdOrderComponent.SetRange("Prod. Order Line No.", Rec."Line No.");
                //         RunModal(Page::"APA MADCS Consumption Part", ProdOrderComponent);
                //         CurrPage.Update(false);
                //     end;
                // }

                // action(OutputsAct)
                // {
                //     Caption = 'Outputs', Comment = 'ESP="Salidas"';
                //     ToolTip = 'Manage the outputs for the production order.', Comment = 'ESP="Gestiona las salidas para la orden de producción."';
                //     Image = OutputJournal;
                //     Promoted = true;
                //     PromotedOnly = true;
                //     PromotedCategory = Process;
                //     PromotedIsBig = true;
                //     Visible = IsVerified;
                //     ApplicationArea = All;

                //     trigger OnAction()
                //     var
                //         ProdOrderRoutingLine: Record "Prod. Order Routing Line";
                //     begin
                //         Clear(ProdOrderRoutingLine);
                //         ProdOrderRoutingLine.SetRange(Status, Rec.Status);
                //         ProdOrderRoutingLine.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                //         ProdOrderRoutingLine.SetRange("Routing Reference No.", Rec."Line No.");
                //         RunModal(Page::"APA MADCS Outputs Part", ProdOrderRoutingLine);
                //         CurrPage.Update(false);
                //     end;
                // }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        this.SetStyleColor();
        this.SetIsVerified();
    end;

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
        this.SetIsVerified();
    end;

    var
        IsVerified: Boolean;
        styleColor: Text;

    local procedure SetStyleColor()
    var
        newPageStyle: PageStyle;
    begin
        // Set style color based on production order status:
        // Completed (Finished Quantity >= Quantity): green (Favorable)
        // In progress (User Working assigned): yellow (Attention)
        // Not started: black (None)
        newPageStyle := PageStyle::None;

        Rec.CalcFields("APA MADCS Verified");
        if Rec."APA MADCS Verified" then
            newPageStyle := PageStyle::Favorable
        else
            newPageStyle := PageStyle::Attention;

        this.styleColor := Format(newPageStyle);
    end;

    local procedure SetIsVerified()
    begin
        Rec.CalcFields("APA MADCS Verified");
        this.IsVerified := Rec."APA MADCS Verified";
    end;
}
