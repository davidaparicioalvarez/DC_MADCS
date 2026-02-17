namespace MADCS.MADCS;

using Microsoft.Warehouse.ADCS;
using System.Text;
using System.Security.Encryption;
using Microsoft.Manufacturing.MachineCenter;

tableextension 55004 "APA MADCS ADCS User" extends "ADCS User"
{
    fields
    {
        field(55000; "APA MADCS Password"; Text[250])
        {
            Caption = 'MADCS Password', Comment = 'ESP="Contraseña MADCS"';
            ToolTip = 'Specifies the MADCS password.', Comment = 'ESP="Especifica la contraseña MADCS."';
            DataClassification = SystemMetadata;

            trigger OnValidate()
            begin
                Rec.TestField("APA MADCS Password");
                Rec."APA MADCS Password" := CopyStr(CalculateMADCSPassword(CopyStr("APA MADCS Password", 1, 30)), 1, MaxStrLen("APA MADCS Password"));
            end;
        }
        field(55001; "APA MADCS Machine Center"; Code[20])
        {
            TableRelation = "Machine Center"."No.";
            Caption = 'Associated Machine Center', Comment = 'ESP="Centro de Maquina asociado"';
            ToolTip = 'Specifies the MADCS machine center code.', Comment = 'ESP="Especifica el código del centro de máquina para MADCS."';
            DataClassification = SystemMetadata;
        }
    }

    /// <summary>
    /// procedure CalculateMADCSPassword
    /// Calculates the hashed password for MADCS authentication.
    /// </summary>
    /// <param name="Input"></param>
    /// <returns></returns>
    procedure CalculateMADCSPassword(Input: Text[30]) HashedValue: Text
    var
        Crypto: Codeunit "Cryptography Management";
        HashAlgorithmType: Enum "APA MADCS Hash Algorithm Type"; // Option MD5,SHA1,SHA256,SHA384,SHA512;
    begin
        Clear(Crypto);
        exit(Crypto.GenerateHashAsBase64String(Input, HashAlgorithmType::SHA512.AsInteger()));
    end;
}
