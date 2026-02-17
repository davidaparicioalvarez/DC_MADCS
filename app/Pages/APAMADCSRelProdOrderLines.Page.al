namespace MADCS.MADCS;

using Microsoft.Manufacturing.Document;

/// <summary>
/// APA MADCS Released Production Order Lines
/// List page for ADCS users to select a released production order.
/// </summary>
page 55000 "APA MADCS Rel Prod Order Lines"
{
    Caption = 'MADCS Released Production Order Lines', Comment = 'ESP="MADCS Líneas de órdenes de producción lanzadas"';
    Extensible = true;
    PageType = List;
    SourceTable = "Prod. Order Line";
    SourceTableView = sorting("Agrupacion Centros", "Orden Preparacion")
                      where(Status = const(Released),
                            "Orden Preparacion" = filter(<> 0),
                            "APA MADCS Picking Status" = const("Totaly Picked"),
                            "APA MADCS Time finished" = const(false));
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    RefreshOnActivate = true;
    Permissions =
        tabledata "Prod. Order Line" = r,
        tabledata "Prod. Order Component" = r;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Agrupacion Centros"; Rec."Agrupacion Centros")
                {
                    StyleExpr = this.styleColor;
                }
                field("Orden Preparacion"; Rec."Orden Preparacion")
                {
                    StyleExpr = this.styleColor;
                }
                field("Prod. Order No."; Rec."Prod. Order No.")
                {
                    ToolTip = 'Specifies the production order number.', Comment = 'ESP="Especifica el número de orden de producción."';
                    StyleExpr = this.styleColor;
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item number of the item to manufacture.', Comment = 'ESP="Especifica el número de artículo del producto a fabricar."';
                    StyleExpr = this.styleColor;
                    Width = 14;
                }
                field("Description"; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the item to manufacture.', Comment = 'ESP="Especifica la descripción del producto a fabricar."';
                    StyleExpr = this.styleColor;
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity to produce.', Comment = 'ESP="Especifica la cantidad a producir."';
                    StyleExpr = this.styleColor;
                }
                field("Finished Quantity"; Rec."Finished Quantity")
                {
                    Visible = false;
                    ToolTip = 'Specifies the finished quantity of the item.', Comment = 'ESP="Especifica la cantidad terminada del producto."';
                    StyleExpr = this.styleColor;
                }
                field("Starting Date-Time"; Rec."Starting Date-Time")
                {
                    Visible = false;
                    ToolTip = 'Specifies the starting date and time for the production order.', Comment = 'ESP="Especifica la fecha y hora de inicio de la orden de producción."';
                    StyleExpr = this.styleColor;
                }
                field("Ending Date-Time"; Rec."Ending Date-Time")
                {
                    Visible = false;
                    ToolTip = 'Specifies the ending date and time for the production order.', Comment = 'ESP="Especifica la fecha y hora de finalización de la orden de producción."';
                    StyleExpr = this.styleColor;
                }
                field("APA MADCS User Working"; Rec."APA MADCS User Working")
                {
                    Visible = false;
                    ToolTip = 'Specifies the user currently working with this production order.', Comment = 'ESP="Especifica el usuario que está trabajando con esta orden de producción."';
                    StyleExpr = this.styleColor;
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
                    Visible = not this.IsVerified;

                    trigger OnAction()
                    var
                        TempProdOrderComponent: Record "Prod. Order Component" temporary;
                        APAMADCSVerificationPart: Page "APA MADCS Verification";
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

                // action(QualityMeasuresAct)
                // { // TODO: Toda la funcionalidad de calidad.
                //     Caption = 'Quality', Comment = 'ESP="Calidad"';
                //     ToolTip = 'Manage quality measures for the production order.', Comment = 'ESP="Gestiona las medidas de calidad para la orden de producción."';
                //     Image = Questionaire;
                //     Promoted = true;
                //     PromotedOnly = true;
                //     PromotedCategory = Process;
                //     PromotedIsBig = true;
                //     Visible = this.IsVerified; 
                //     ApplicationArea = All;

                //     trigger OnAction()
                //     var
                //         ProdOrderRoutingLine: Record "Prod. Order Routing Line";
                //         APAMADCSQualityMeasuresPart: Page "APA MADCS Quality Measures";
                //     begin
                //         Error('Proceso no finalizado: falta definir la condición de visibilidad y los datos de calidad.');
                //         Clear(ProdOrderRoutingLine);
                //         ProdOrderRoutingLine.SetRange(Status, Rec.Status);
                //         ProdOrderRoutingLine.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                //         ProdOrderRoutingLine.SetRange("Routing Reference No.", Rec."Line No.");
                //         Clear(APAMADCSQualityMeasuresPart);
                //         APAMADCSQualityMeasuresPart.SetTableView(ProdOrderRoutingLine);
                //         APAMADCSQualityMeasuresPart.RunModal();
                //         CurrPage.Update(false);
                //     end;
                // }

                action(TimeAct)
                {
                    Caption = 'Time', Comment = 'ESP="Tiempos"';
                    ToolTip = 'Manage the time tracking for the production order.', Comment = 'ESP="Gestiona el seguimiento del tiempo para la orden de producción."';
                    Image = Timeline;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = this.IsVerified;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        APAMADCSTimePartPage: Page "APA MADCS Time Part";
                    begin
                        Clear(APAMADCSTimePartPage);
                        APAMADCSTimePartPage.InitializeData(Rec.Status, Rec."Prod. Order No.", Rec."Line No.");
                        APAMADCSTimePartPage.RunModal();
                        CurrPage.Update(false);
                    end;
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
                    Visible = this.IsVerified and not this.IsOutputsFinished;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        ProdOrderLine: Record "Prod. Order Line";
                        OutputsMsg: Label 'Outputs', Comment = 'ESP="Salidas"';
                        OutputCannotStartErr: Label 'Cannot manage outputs because there is not an execution task for the operator. Please create an execution task before managing outputs.', Comment = 'ESP="No se pueden gestionar las salidas porque no hay una tarea de ejecución para el operador. Por favor, cree una tarea de ejecución antes de gestionar las salidas."';
                    begin
                        Clear(ProdOrderLine);
                        ProdOrderLine.SetRange(Status, Rec.Status);
                        ProdOrderLine.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                        ProdOrderLine.SetRange("Line No.", Rec."Line No.");
                        if not (this.APAMADCSManagement.CurrentTask(this.APAMADCSManagement.GetOperatorCode()) in [Enum::"APA MADCS Journal Type"::Execution, Enum::"APA MADCS Journal Type"::"Execution with Fault"]) then
                            this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(OutputsMsg, OutputCannotStartErr));
                        RunModal(Page::"APA MADCS Outputs", ProdOrderLine);
                        CurrPage.Update(false);
                    end;
                }

                action(ConsumptionAct)
                {
                    Caption = 'Consumption', Comment = 'ESP="Consumos"';
                    ToolTip = 'Manage the consumption of components for the production order.', Comment = 'ESP="Gestiona el consumo de componentes para la orden de producción."';
                    Image = ConsumptionJournal;
                    Promoted = true;
                    PromotedOnly = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = this.IsVerified and not this.IsConsumptionFinished;
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        ProdOrderComponent: Record "Prod. Order Component";
                        ConsumeTitleErr: Label 'Consumption.', Comment = 'ESP="Consumos."';
                        CannotConsumeErr: Label 'Cannot consume components because the outputs are not finished.', Comment = 'ESP="No se pueden consumir los componentes porque no se han finalizado las salidas."';
                    begin
                        Clear(ProdOrderComponent);
                        ProdOrderComponent.SetRange(Status, Rec.Status);
                        ProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
                        ProdOrderComponent.SetRange("Prod. Order Line No.", Rec."Line No.");
                        if ProdOrderComponent.FindFirst() then
                            if not this.APAMADCSManagement.IsMarkedForConsume(ProdOrderComponent, this.APAMADCSManagement.GetOperatorCode()) then
                                this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(ConsumeTitleErr, CannotConsumeErr));
                        RunModal(Page::"APA MADCS Consumption", ProdOrderComponent);
                        CurrPage.Update(false);
                    end;
                }

            }
        }
    }

    trigger OnInit()
    begin
        // Ensure all data for filtering is up to date
        this.APAMADCSManagement.UpdatePickingStatusForReleasedProdOrders();
        Commit(); // Commit to ensure data consistency before user interaction
    end;

    trigger OnOpenPage()
    var
        LoginFailedErrMsg: Label 'Login failed', Comment = 'ESP="Error de inicio de sesión"';
        LoginFailedErrMsgLbl: Label 'Operator login failed. Please check your credentials and try again.', Comment = 'ESP="Error de inicio de sesión del operador. Por favor, verifique sus credenciales e intente de nuevo."';
    begin
        if not this.APAMADCSManagement.LogInOperator() then
            this.APAMADCSManagement.Raise(this.APAMADCSManagement.BuildApplicationError(LoginFailedErrMsg, LoginFailedErrMsgLbl));
    end;

    trigger OnClosePage()
    begin
        this.APAMADCSManagement.LogOutOperator();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        this.SetStyleColor();
        this.SetAllVars();
    end;

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
        this.SetAllVars();
    end;

    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        IsVerified: Boolean;
        IsOutputsFinished: Boolean;
        IsConsumptionFinished: Boolean;
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

    local procedure SetAllVars()
    begin
        Rec.CalcFields("APA MADCS Verified", "APA MADCS Time finished", "APA MADCS Output finished", "APA MADCS Consumption finished");
        this.IsVerified := Rec."APA MADCS Verified";
        this.IsOutputsFinished := Rec."APA MADCS Output finished";
        this.IsConsumptionFinished := Rec."APA MADCS Consumption finished";
    end;
}