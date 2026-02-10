namespace MADCS.MADCS;
using Microsoft.Manufacturing.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item;

/// <summary>
/// APA MADCS Verification
/// Part page for managing Verification in production orders.
/// This page will be used within the main MADCS card to display and manage output data.
/// </summary>
page 55006 "APA MADCS Verification"
{
    Caption = 'Verification', Comment = 'ESP="Verificación"';
    PageType = List;
    SourceTable = "Prod. Order Component";
    SourceTableTemporary = true;
    Editable = true;
    Extensible = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;
    UsageCategory = None;
    RefreshOnActivate = true;
    Permissions =
        tabledata "Prod. Order Component" = rimd,
        tabledata "Reservation Entry" = r,
        tabledata "Item" = r,
        tabledata "Item Tracking Code" = r;

    layout
    {
        area(Content)
        {
            group(ButtonsGrp)
            {
                ShowCaption = false;

                usercontrol(ALInfButtonGroupColumns2; "APA MADCS ButtonGroup")
                {
                    Visible = true;

                    trigger OnLoad()
                    var
                        PreparationLbl: Label 'End (Verification)', Comment = 'ESP="Fin (Verificación)"';
                        PreparationTextLbl: Label 'Init verification phase', Comment = 'ESP="Iniciar fase de verificación"';
                    begin
                        CurrPage.ALInfButtonGroupColumns2.AddButton(PreparationLbl, PreparationTextLbl, Format(Enum::"APA MADCS Buttons"::ALButtonPreparationTok), this.DangerButtonTok);
                    end;

                    trigger OnClick(id: Text)
                    var
                        NotAllComponentsVerifiedMsg: Label 'Not all components have been verified. Please verify all components before starting the preparation phase.', Comment = 'ESP="No todos los componentes han sido verificados. Por favor, verifique todos los componentes antes de iniciar la fase de preparación."';
                        AllVerifiedMsg: Label 'All components have already been verified. No further action is possible. Please, launch preparation phase from Time page.', Comment = 'ESP="Todos los componentes ya han sido verificados. No es posible realizar más acciones. Por favor, inicie la fase de preparación desde la página Tiempos."';
                    begin
                        // Verify if all components are verified before starting preparation

                        if not this.AreAllVerified() then begin
                            Message(NotAllComponentsVerifiedMsg);
                            exit;
                        end;
                        if Rec."Prod. Order Line No." <> 0 then begin
                            this.APAMADCSManagement.ProcessPreparationCleaningTask(id, Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", this.APAMADCSManagement.GetOperatorCode(), '');
                            Message(this.NewActivityCreatedMsg);
                        end else
                            Message(AllVerifiedMsg);
                        CurrPage.Update(false);
                    end;
                }
            }

            group(RepeaterGrp)
            {
                ShowCaption = false;
                Editable = true;

                repeater(Control1)
                {
                    ShowCaption = false;

                    field("Item No."; Rec."Item No.")
                    {
                        ToolTip = 'Specifies the item number of the component item.', Comment = 'ESP="Especifica el número del producto componente."';
                        Editable = false;
                        StyleExpr = this.styleColor;
                        Width = 14;
                    }
                    field(Description; Rec."Description")
                    {
                        ToolTip = 'Specifies the description of the component item.', Comment = 'ESP="Especifica la descripción del producto componente."';
                        Editable = false;
                        StyleExpr = this.styleColor;
                        Width = 11;
                    }
                    field("MADCS Lot No."; Rec."APA MADCS Lot No.")
                    {
                        Editable = false;
                        StyleExpr = this.styleColor;
                        Width = 10;
                    }
                    field("MADCS Quantity"; Rec."APA MADCS Quantity")
                    {
                        Editable = false;
                        StyleExpr = this.styleColor;
                        Width = 10;
                    }
                    field("MADCS Verified"; Rec."APA MADCS Verified")
                    {
                        Editable = true;
                        StyleExpr = this.styleColor;
                        Width = 5;

                        trigger OnValidate()
                        begin
                            this.MarkAsVerified(Rec."APA MADCS Verified");
                            // Update style color when verification status changes
                            this.SetStyleColor();
                            CurrPage.Update(false);
                        end;
                    }
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.InitializeData();
        this.SetStyleColor();
    end;

    trigger OnAfterGetRecord()
    begin
        this.SetStyleColor();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        this.SetStyleColor();
    end;

    var
        APAMADCSManagement: Codeunit "APA MADCS Management";
        styleColor: Text;
        NewActivityCreatedMsg: Label 'New preparation activity has been created.', Comment = 'ESP="Se ha creado una nueva actividad de preparación."';
        DangerButtonTok: Label 'danger', Locked = true;

    local procedure SetStyleColor()
    var
        ProdOrderComponent: Record "Prod. Order Component";
        newPageStyle: PageStyle;
    begin
        // Set style color based only on remaining quantity
        // Consumed lines (remaining quantity = 0): black (None)
        // Non-consumed lines (remaining quantity > 0): red (Attention)
        newPageStyle := PageStyle::Attention;
        if not ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."APA MADCS Original Line No.") then
            exit;

        if ProdOrderComponent."APA MADCS Verified" then
            newPageStyle := PageStyle::Favorable;

        this.styleColor := Format(newPageStyle);
    end;

    local procedure InitializeData()
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        APAMADCSManagement.ValidateAndDeleteTemporaryTables(Rec);
        APAMADCSManagement.LoadProdOrderComponentsForValidation(Rec, ProdOrderComponent);
        APAMADCSManagement.LogInOperator();
    end;

    local procedure MarkAsVerified(Verified: Boolean)
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        // If all lots in prod ord comp are verified, set the main line as verified
        CurrPage.Update(true);

        ProdOrderComponent.Copy(Rec);
        Rec.SetRange("APA MADCS Original Line No.", Rec."APA MADCS Original Line No.");
        Rec.SetRange("APA MADCS Verified", not Verified);

        if (Verified and Rec.IsEmpty()) or not Verified then
            if ProdOrderComponent.Get(Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", Rec."APA MADCS Original Line No.") then begin
                ProdOrderComponent."APA MADCS Verified" := Verified;
                ProdOrderComponent.Modify(false);
            end;

        Rec.SetRange("APA MADCS Original Line No.");
        Rec.SetRange("APA MADCS Verified");
    end;

    local procedure AreAllVerified(): Boolean
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        if Rec."Prod. Order Line No." = 0 then
            exit(true);
        Clear(ProdOrderComponent);
        ProdOrderComponent.SetCurrentKey(Status, "Prod. Order No.", "Prod. Order Line No.");
        ProdOrderComponent.SetRange(Status, Rec.Status);
        ProdOrderComponent.SetRange("Prod. Order No.", Rec."Prod. Order No.");
        ProdOrderComponent.SetRange("Prod. Order Line No.", Rec."Prod. Order Line No.");
        ProdOrderComponent.SetRange("APA MADCS Verified", false);
        exit(ProdOrderComponent.IsEmpty());
    end;
}