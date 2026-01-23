namespace MADCS.MADCS;

using Microsoft.Warehouse.ADCS;
using System.Text;
using System.Security.Encryption;

tableextension 55004 "APA MADCS ADCS User" extends "ADCS User"
{
    fields
    {
        field(55000; "MADCS Password"; Text[250])
        {
            Caption = 'MADCS Password', Comment = 'ESP="Contraseña MADCS"';
            ToolTip = 'Specifies the MADCS password.', Comment = 'ESP="Especifica la contraseña MADCS."';
            DataClassification = SystemMetadata;

            trigger OnValidate()
            begin
                Rec.TestField("MADCS Password");
                Rec."MADCS Password" := CopyStr(CalculateMADCSPassword(CopyStr("MADCS Password", 1, 30)), 1, MaxStrLen("MADCS Password"));
            end;
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
