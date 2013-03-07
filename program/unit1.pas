unit Unit1; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, EditBtn,
  StdCtrls, Grids, Buttons, XMLPropStorage, ComCtrls, XmlParser, CsvParser,
  SymfoniaParser, ColorProgress, ExtMessage;

type

  { TForm1 }

  TForm1 = class(TForm)
    BitBtn1: TBitBtn;
    csv: TCsvParser;
    Edit1: TEdit;
    message: TExtMessage;
    not_filter: TCheckBox;
    FileNameEdit1: TFileNameEdit;
    Label1: TLabel;
    Label2: TLabel;
    cc: TProgressBar;
    sg: TStringGrid;
    sparser: TSymfoniaParser;
    xml: TXmlParser;
    XMLPropStorage1: TXMLPropStorage;
    procedure BitBtn1Click(Sender: TObject);
    procedure csvRead(Sender: TObject; NumberRec,PosRec: integer; sName,
      sValue: string; var Stopped: boolean);
    procedure FileNameEdit1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure sparserRead(Sender: TObject; poziom: integer; adres, klucz,
      zmienna, wartosc: string; var Stopped: boolean);
    procedure xmlProgress(Sender: TObject; vMax, vPos: integer);
    procedure xmlRead(Sender: TObject; poziom: integer; adres, klucz, zmienna,
      wartosc: string; var Stopped: boolean);
  private
    MSSQL1,MSSQL2: integer;
    CZYTAJ: boolean;
    { private declarations }
  public
    { public declarations }
  end; 

var
  Form1: TForm1; 

implementation

uses
  ExtC;

{$R *.lfm}

{ TForm1 }

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
  Close;
end;

procedure TForm1.csvRead(Sender: TObject; NumberRec,PosRec: integer; sName,
  sValue: string; var Stopped: boolean);
var
  s: string;
begin
  s:=sName;
  if s='' then s:=' ';
  //wczytuję rekord
  sg.InsertColRow(False,sg.RowCount);
  sg.Rows[sg.RowCount-1].Text:=IntToStr(NumberRec)+#13#10+IntToStr(PosRec)+#13#10+' '+#13#10+s+#13#10+sValue;
end;

procedure TForm1.FileNameEdit1Change(Sender: TObject);
var
  plik,ext: string;
begin
  Application.ProcessMessages;
  MSSQL1:=0;
  MSSQL2:=0;
  plik:=UTF8ToAnsi(FileNameEdit1.FileName);
  if FileExists(plik) then
  begin
    ext:=ExtractFileExt(plik);
    sg.Clean([gzNormal]);
    sg.RowCount:=1;
    if UpCase(ext)='.XML' then
    begin
      xml.Filename:=plik;
      xml.Execute;
      if MSSQL1=10 then
      begin
        sg.Clean([gzNormal]);
        sg.RowCount:=1;
        xml.Execute;
      end;
      not_filter.Enabled:=MSSQL1=10;
    end;
    if UpCase(ext)='.CSV' then
    begin
      csv.Filename:=plik;
      csv.Execute;
    end;
    if UpCase(ext)='.TXT' then
    begin
      sparser.Filename:=plik;
      sparser.Execute;
      cc.Position:=0;
    end;
    cc.Position:=0;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  s: string;
begin
  if FileExists(MyDir('local_xml_viewer.xml')) then Form1.Position:=poDesigned;
  s:=ParamStr(1);
  //message.ShowMessage(s);
  FileNameEdit1.InitialDir:=s;
end;

procedure TForm1.sparserRead(Sender: TObject; poziom: integer; adres, klucz,
  zmienna, wartosc: string; var Stopped: boolean);
var
  s: string;
begin
  s:=zmienna;
  if s='' then s:=' ';
  //wczytuję rekord
  CZYTAJ:=false;
  sg.InsertColRow(False,sg.RowCount);
  sg.Rows[sg.RowCount-1].Text:=IntToStr(poziom)+#13#10+adres+#13#10+klucz+#13#10+s+#13#10+wartosc;
end;

procedure TForm1.xmlProgress(Sender: TObject; vMax, vPos: integer);
begin
  cc.Max:=vMax;
  cc.Position:=vPos;
end;

procedure TForm1.xmlRead(Sender: TObject; poziom: integer; adres, klucz,
  zmienna, wartosc: string; var Stopped: boolean);
var
  s: string;
begin
  s:=zmienna;
  if s='' then s:=' ';
  //test MSSQL
  if (MSSQL1<3) then
  begin
    inc(MSSQL1);
    if (adres='/TraceData') and (zmienna='xmlns') and (wartosc='http://tempuri.org/TracePersistence.xsd') then inc(MSSQL2);
    if (adres='/TraceData/Header/TraceProvider') and (zmienna='name') and (wartosc='Microsoft SQL Server') then inc(MSSQL2);
    if MSSQL2>1 then
    begin
      MSSQL1:=10;
      Stopped:=true;
      CZYTAJ:=false;
    end;
  end;
  if (MSSQL1<>10) or ((MSSQL1=10) and CZYTAJ) or ((MSSQL1=10) and (not_filter.Checked)) then
  begin
    //wczytuję rekord
    CZYTAJ:=false;
    sg.InsertColRow(False,sg.RowCount);
    sg.Rows[sg.RowCount-1].Text:=IntToStr(poziom)+#13#10+adres+#13#10+klucz+#13#10+s+#13#10+wartosc;
  end;
  if (MSSQL1=10) and (not CZYTAJ) and (not not_filter.Checked) then
  begin
    //filtruję MSSQL TraceData
    CZYTAJ:=
      (adres='/TraceData/Events/Event/Column') and (zmienna='name') and (wartosc='TextData');
  end;
end;

end.
