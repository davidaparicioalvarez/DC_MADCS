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
                    begin
                        // Verify if all components are verified before starting preparation

                        this.FinalizeVerifications(id);

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
                        Editable = false;
                        StyleExpr = this.styleColor;
                        Width = 14;
                    }
                    field(Description; Rec."Description")
                    {
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

    trigger OnClosePage()
    begin
        this.FinalizeVerifications(Format(Enum::"APA MADCS Buttons"::ALButtonPreparationTok));
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

    /// <summary>
    /// Determines the appropriate page style based on component verification status.
    /// Sets favorable style (green) if component is verified, otherwise uses attention style (red).
    /// Provides visual feedback for verification completion status.
    /// </summary>
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

    /// <summary>
    /// Initializes the verification page with production order components.
    /// Clears existing temporary data, loads all components for the production order, and logs in the operator.
    /// </summary>
    local procedure InitializeData()
    var
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        this.APAMADCSManagement.ValidateAndDeleteTemporaryTables(Rec);
        this.APAMADCSManagement.LoadProdOrderComponentsForValidation(Rec, ProdOrderComponent);
        this.APAMADCSManagement.LogInOperator();
    end;

    /// <summary>
    /// Marks or unmarks a component as verified.
    /// Updates both the temporary record and the actual database record.
    /// When all lots for a component are verified, the main component line is also marked as verified.
    /// </summary>
    /// <param name="Verified">Boolean indicating if component should be marked as verified (true) or unverified (false).</param>
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

    /// <summary>
    /// Validates if all components in the production order have been verified.
    /// Checks the actual database records for unverified components.
    /// </summary>
    /// <returns name="AllVerified">Boolean indicating if all components are verified.</returns>
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

    /// <summary>
    /// Finalizes all verifications and creates preparation or cleaning task.
    /// Validates that all components are verified before proceeding.
    /// Creates appropriate activity based on button identifier (Preparation or Cleaning).
    /// </summary>
    /// <param name="id">Button identifier for determining which task to create (Preparation/Cleaning).</param>
    local procedure FinalizeVerifications(id: Text)
    var
        NotAllComponentsVerifiedMsg: Label 'Not all components have been verified. Please verify all components before starting the preparation phase.', Comment = 'ESP="No todos los componentes han sido verificados. Por favor, verifique todos los componentes antes de iniciar la fase de preparación."';
        AllVerifiedMsg: Label 'All components have already been verified. No further action is possible. Please, launch preparation phase from Time page.', Comment = 'ESP="Todos los componentes ya han sido verificados. No es posible realizar más acciones. Por favor, inicie la fase de preparación desde la página Tiempos."';
    begin
        if not this.AreAllVerified() then begin
            Message(NotAllComponentsVerifiedMsg);
            exit;
        end;
        if Rec."Prod. Order Line No." <> 0 then begin
            this.APAMADCSManagement.ProcessPreparationCleaningTask(id, Rec.Status, Rec."Prod. Order No.", Rec."Prod. Order Line No.", this.APAMADCSManagement.GetOperatorCode());
            Message(this.NewActivityCreatedMsg);
        end else
            Message(AllVerifiedMsg);
    end;
}