/// <summary>
/// Page for APA MADCS Operator Login
/// This page allows operators to enter their credentials to access the APA MADCS system.
/// </summary>
page 55010 "APA MADCS Operator Login"
{
    Caption = 'Operator Login', Comment = 'ESP="Inicio de sesión del operador"';
    PageType = StandardDialog;
    UsageCategory = None;
    Extensible = false;
    InherentPermissions = X;
    InherentEntitlements = X;

    layout
    {
        area(Content)
        {
            group(LoginGroup)
            {
                Caption = 'Operator Credentials', Comment = 'ESP="Credenciales del operador"';
                field(OperatorCodeField; this.OperatorCode)
                {
                    ApplicationArea = All;
                    Caption = 'Operator Code', Comment = 'ESP="Código del operador"';
                    ToolTip = 'Specifies the operator code.', Comment = 'ESP="Especifica el código del operador."';
                    ShowMandatory = true;
                }
                field(PasswordField; this.Password)
                {
                    ApplicationArea = All;
                    Caption = 'Password', Comment = 'ESP="Contraseña"';
                    ToolTip = 'Specifies the operator password.', Comment = 'ESP="Especifica la contraseña del operador."';
                    ExtendedDatatype = Masked;
                    ShowMandatory = true;
                }
            }
        }
    }

    var
        OperatorCode: Code[20];
        Password: Text[50];

    /// <summary>
    /// Gets the operator code entered by the user.
    /// </summary>
    /// <returns>The operator code as Code[20]</returns>
    procedure GetOperatorCode(): Code[20]
    begin
        exit(this.OperatorCode);
    end;

    /// <summary>
    /// Gets the password entered by the user.
    /// </summary>
    /// <returns>The password as Text</returns>
    procedure GetPassword(): Text
    var
        ADCSUser: Record "ADCS User";
    begin
        exit(ADCSUser.CalculateMADCSPassword(CopyStr(this.Password, 1, 30)));
    end;
}
