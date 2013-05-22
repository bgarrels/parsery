{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit Parsery_components;

interface

uses
  XmlParser, CsvParser, SymfoniaParser, komunikaty_lazarus, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('XmlParser', @XmlParser.Register);
  RegisterUnit('CsvParser', @CsvParser.Register);
  RegisterUnit('SymfoniaParser', @SymfoniaParser.Register);
end;

initialization
  RegisterPackage('Parsery_components', @Register);
end.
