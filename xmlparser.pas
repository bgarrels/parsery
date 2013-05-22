unit XmlParser;

{
  Komponent przelatuje caly plik XML i wyrzuca dane w odpowiedniej formie
  do przeczytania ze zdarzenia. Ewentualne bledy sa� wyrzucane w drugim zdarzeniu.

  Autor: Jacek Leszczynski
  E-Mail: tao@bialan.pl

  Wszelkie prawa zastrzezone (C) Bialystok 2011, Polska.


  Instrukcja obslugi:
  1. Ustawiamy wlasciwosci FILENAME, ma wskazywac na plik XML do wczytania.
  2. Wypelniamy zdarzenie ONREAD odpowiednia wartoscia.
  3. Wypelniamy zdarzenie ONERROR odpowiednia wartoscia� (zalecane).
  4. Uruchamiamy funckje EXECUTE, ktora zwroci TRUE jesli sie wykona, gdy wyjda
     jakies bledy, zostanie zwrocona wartosc FALSE!
}

{$IFDEF MSWINDOWS}
  {$DEFINE WINDOWS}
{$ENDIF}

{$IFNDEF FPC AND $IFDEF MSWINDOWS}
  {$DEFINE DELPHI}
{$ENDIF}

{$IFDEF FPC}
  {$DEFINE LAZARUS}
{$ENDIF}

{$IFDEF LAZARUS}
{$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils,
  {$IFDEF LAZARUS}
  LResources,
  {$ENDIF}
  Forms, Controls, Graphics, Dialogs,
  {$IFDEF LAZARUS}
  DOM, XMLRead,
  {$ELSE}
  XmlDOM, XmlIntf, XmlDoc,
  {$ENDIF}
  DCPdes, DCPsha1;

type
  { zdarzenia }
  TBeforeAfterReadEvent = procedure(Sender: TObject) of object;
  TReadEvent = procedure(Sender: TObject; poziom: integer; adres,klucz,zmienna,wartosc: string; var Stopped:boolean) of object;
  TErrorEvent = procedure(Sender: TObject; ERR: integer; ERROR: string) of object;
  TOnProgress = procedure(Sender: TObject; vMax, vPos: integer) of object;

  { typy wyliczeniowe }
  TEncodingFormat = (eAuto,eUTF8,eWindows1250,eISO_8859_2,eDES);

  { TXmlParser }

  TXmlParser = class(TComponent)
  private
    FOnProgress: TOnProgress;
    { Private declarations }
    strumien,strumien2,strumien3: TMemoryStream;
    doc: TXMLDocument;
    temp: {$IFDEF LAZARUS} TDOMNode {$ELSE} IDOMNode {$ENDIF} ;
    __ERROR: integer;
    zm_filename: string;
    FES: TEncodingFormat;
    FNULL: boolean;
    FToken: String;
    FTest: boolean;
    FOnBeforeRead: TBeforeAfterReadEvent;
    FOnRead: TReadEvent;
    FOnAfterRead: TBeforeAfterReadEvent;
    FOnError: TErrorEvent;
    Des: TDCP_des;
    function OkreslStroneKodowa(filename:string):integer;
    function EncryptStream(s_in,s_out:TStream;size:longword):longword;
    function DecryptStream(s_in,s_out:TStream;size:longword):longword;
  protected
    { Protected declarations }
    procedure ParseXML(level: integer; node: {$IFDEF LAZARUS} TDOMNode {$ELSE} IDOMNode {$ENDIF});
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: boolean;
    function LockString(s:string;spaces:boolean=false):string;
    function UnlockString(s:string;spaces:boolean=false):string;
    function EncodeXML(XMLFile:string;EncodeFile:string=''):boolean; {$IFDEF DELPHI}overload;{$ENDIF}
    function EncodeXML:boolean; {$IFDEF DELPHI}overload;{$ENDIF}
    function DecodeXML(DecodeFile:string;XMLFile:string=''):boolean; {$IFDEF DELPHI}overload;{$ENDIF}
    function DecodeXML:boolean; {$IFDEF DELPHI}overload;{$ENDIF}
  published
    { Published declarations }
    property Encoding: TEncodingFormat read FES write FES default eAuto;
    property Filename: string read zm_filename write zm_filename;
    property LastNullRead: boolean read FNULL write FNULL default false;
    property Token: String read FToken write FToken;
    property HeaderTest: boolean read FTest write FTest default true;
    property OnBeforeRead: TBeforeAfterReadEvent read FOnBeforeRead write FOnBeforeRead;
    property OnRead: TReadEvent read FOnRead write FOnRead;
    property OnAfterRead: TBeforeAfterReadEvent read FOnAfterRead write FOnAfterRead;
    property OnError: TErrorEvent read FOnError write FOnError;
    property OnProgress: TOnProgress read FOnProgress write FOnProgress;
  end;

procedure Register;

implementation

uses
  {$IFDEF LAZARUS}
  lconvencoding;
  {$ELSE}
  windows;
  {$ENDIF}

type
  _import = record
              level: integer;
              klucz: string;
              adres: string;
            end;

var
  import: _import;
  zm_stop: boolean;
  istrumien: integer;

procedure Register;
begin
  {$IFDEF LAZARUS}
  {$I xmlparser_icon.lrs}
  {$ENDIF}
  RegisterComponents('Misc',[TXmlParser]);
end;

{ TXmlParser }

//Funkcja zwraca n-ty (l) ciag stringu (s), o wskazanym separatorze.
function GetLineToStr(s:string;l:integer;separator:char):string;
var
  i,ll,dl: integer;
begin
  dl:=length(s);
  ll:=1;
  s:=s+separator;
  for i:=1 to length(s) do
  begin
    if s[i]=separator then inc(ll);
    if ll=l then break;
  end;
  if ll=1 then dec(i);
  delete(s,1,i);
  for i:=1 to length(s) do if s[i]=separator then break;
  delete(s,i,dl);
  result:=s;
end;

function ConvOdczyt(s: string): string;
var
  pom: string;
begin
  {$IFDEF LAZARUS}
  pom:=ConvertEncoding(s,'cp1250','utf8');
  {$ELSE}
  pom:=UTF8Encode(s);
  {$ENDIF}
  result:=pom;
end;

function ConvZapis(s: string): string;
var
  pom: string;
begin
  {$IFDEF LAZARUS}
  pom:=ConvertEncoding(s,'utf8','cp1250');
  {$ELSE}
  pom:=UTF8Decode(s);
  {$ENDIF}
  result:=pom;
end;

procedure AktualizujAdres(klucz: string; level: integer);
var
  i,b: integer;
  s: string;
begin
  if klucz='#text' then exit;

  //gdy poczatek
  if level=-1 then
  begin
    import.adres:='/'+klucz;
    import.level:=level;
    import.klucz:=klucz;
    exit;
  end;

  //czy mamy cos do dodania?
  if import.level<level then import.adres:=import.adres+'/'+klucz;

  //czy mamy cos do usuniecia?
  if (import.level>level) or ((import.level=level) and (GetLineToStr(import.adres,level,'/')<>klucz)) then
  begin
    if klucz='' then b:=2 else b:=1;
    for i:=1 to level+b do if i=1 then s:=GetLineToStr(import.adres,i,'/') else s:=s+'/'+GetLineToStr(import.adres,i,'/');
    if b=1 then s:=s+'/'+klucz;
    import.adres:=s;
  end;

  if import.adres[length(import.adres)]='/' then delete(import.adres,length(import.adres),1);
  import.level:=level;
  import.klucz:=klucz;
end;

function CzyToJestXML(s:shortstring):boolean;
begin
  //sprawdzam ciag i porownuje go do: "<?xml"
  result:=(s[1]='<') and (s[2]='?') and
          ((s[3]='X') or (s[3]='x')) and
          ((s[4]='M') or (s[4]='m')) and
          ((s[5]='L') or (s[5]='l'));
end;

function TXmlParser.OkreslStroneKodowa(filename: string): integer;
var
  e: file of char;
  f: textfile;
  c: char;
  s: string;
  a: integer;
  b: boolean;
begin
  (* Najpierw sprawdze, czy plik nie jest zakodowany *)
  assignfile(e,filename);
  {$IFDEF LAZARUS}
  reset(e,1);
  {$ELSE}
  reset(e);
  {$ENDIF}
  //czytam pierwsze 5 znakow
  s:='';
  for a:=1 to 5 do
  begin
    read(e,c);
    s:=s+c;
  end;
  closefile(e);
  //sprawdze jeszcze tylko, czy to jest XML
  b:=CzyToJestXML(s);
  //jesli to jest plik zakodowany to wychodze
  if not b then
  begin
    result:=10;
    exit;
  end;
  (* Chyba mamy do czynienia z plikiem XML, sprawdzam kodowanie *)
  //przeczytanie pierwszego wiersza
  assignfile(f,filename);
  reset(f);
  readln(f,s);
  closefile(f);
  //sprawdzam kodowanie
  a:=pos('encoding=',lowercase(s));
  delete(s,1,a);
  s:=GetLineToStr(s,2,'"');
  if (s='utf8') or (s='utf-8') then a:=1 else
  if pos('1250',s)>0 then a:=2 else
  if pos('8859-2',s)>0 then a:=3 else
  a:=0;
  result:=a;
end;

function TXmlParser.EncryptStream(s_in, s_out: TStream; size: longword
  ): longword;
begin
  Des.InitStr(FToken,TDCP_sha1);
  result:=Des.EncryptStream(s_in,s_out,size);
  Des.Burn;
end;

function TXmlParser.DecryptStream(s_in, s_out: TStream; size: longword
  ): longword;
begin
  Des.InitStr(FToken,TDCP_sha1);
  result:=Des.DecryptStream(s_in,s_out,size);
  Des.Burn;
end;


procedure TXmlParser.ParseXML(level: integer; node: {$IFDEF LAZARUS} TDOMNode {$ELSE} IDOMNode {$ENDIF} );
var
  cNode: {$IFDEF LAZARUS} TDOMNode {$ELSE} IDOMNode {$ENDIF};
  i: integer;
begin
  if zm_stop or (Node=nil) then Exit;
  AktualizujAdres(Node.NodeName,level);

  if Assigned(FOnRead) then
  begin
    //ATRYBUTY
    try
    if {$IFDEF LAZARUS} Node.HasAttributes and {$ENDIF} (Node.Attributes.Length>0) then
    begin
      for i:=0 to Node.Attributes.Length-1 do
        {$IFDEF LAZARUS}
        FOnRead(self,level,import.adres,Node.NodeName,Node.Attributes[i].NodeName,UTF8Encode(Node.Attributes[i].NodeValue),zm_stop);
        {$ELSE}
        FOnRead(self,level,import.adres,Node.NodeName,Node.Attributes[i].NodeName,Node.Attributes[i].NodeValue,zm_stop);
        {$ENDIF}
    end;
    except end;
    //WARTOSCI KLUCZY
    if Node.NodeValue<>'' then
      {$IFDEF LAZARUS}
      FOnRead(self,import.level,import.adres,import.klucz,'',UTF8Encode(Node.NodeValue),zm_stop);
      {$ELSE}
      FOnRead(self,import.level,import.adres,import.klucz,'',Node.NodeValue,zm_stop);
      {$ENDIF}
  end;

  if Assigned(FOnProgress) then case istrumien of
    0: FOnProgress(self,strumien.Size,strumien.Position);
    2: FOnProgress(self,strumien.Size,strumien2.Position);
  end;

  cNode:=Node.FirstChild;
  while cNode<>nil do
  begin
    inc(level);
    ParseXML(level,cNode);
    cNode:=cNode.NextSibling;
    dec(level);
  end;
end;

constructor TXmlParser.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FES:=eAuto;
  FNULL:=false;
  FTest:=true;
  strumien:=TMemoryStream.Create;
  strumien2:=TMemoryStream.Create;
  strumien3:=TMemoryStream.Create;
  Des:=TDCP_des.Create(Self);
end;

destructor TXmlParser.Destroy;
begin
  strumien.Free;
  strumien2.Free;
  strumien3.Free;
  DES.Free;
  inherited Destroy;
end;

function TXmlParser.Execute: boolean;
var
  plik: string;
  bufor: shortstring;
  kodowanie,a,b,buf: integer;
  b_przekodowanie,zm_result: boolean;
begin
  if Assigned(FOnBeforeRead) then FOnBeforeRead(Self);
  plik:=ConvZapis(zm_filename);
  b_przekodowanie:=false;
  if (plik='') or (not FileExists(plik)) then
  begin
    __ERROR:=2;
    if Assigned(FOnError) then FOnError(Self, 2, 'Brak pliku *.XML! Parsowanie przerwane.');
    result:=false;
    exit;
  end;
  zm_stop:=false;
  if FES=eAuto then kodowanie:=OkreslStroneKodowa(plik) else kodowanie:=0;
  try
    __ERROR:=0;
    import.adres:='';
    import.level:=-1;
    strumien.Clear;
    strumien.LoadFromFile(plik);
    //przekodowanie - jesli trzeba
    if (FES=eWindows1250) or (FES=eISO_8859_2) or ((FES=eAuto) and (kodowanie>1)) then
    begin
      strumien2.Clear;
      a:=0;
      while true do
      begin
        buf:=strumien.Read(bufor[1],200);
        SetLength(bufor,buf);
        {$IFDEF LAZARUS}
        if (FES=eWindows1250) or (kodowanie=2) then
          bufor:=ConvertEncoding(bufor,'cp1250','utf8') else
        if (FES=eISO_8859_2) or (kodowanie=3) then
          bufor:=ConvertEncoding(bufor,'iso_8859_2','utf8');
        {$ELSE}
        bufor:=UTF8Encode(bufor);
        {$ENDIF}
        buf:=length(bufor);
        if (a=0) and (pos('<?',bufor)>0) or (a=1) then
        begin
          if a=0 then strumien2.Write('<?xml version="1.0" encoding="utf-8"?>',38);
          b:=pos('?>',bufor);
          if b>0 then
          begin
            delete(bufor,1,b+1);
            dec(buf,b+1);
            a:=2;
          end else begin
            a:=1;
            continue;
          end;
        end;
        if buf=0 then break;
        strumien2.Write(bufor[1],buf);
      end;
      strumien2.Position:=0;
      //strumien2.SaveToFile('/home/tao/AAA.XML');
      b_przekodowanie:=true;
    end;
    //DESToXML - jesli trzeba
    if (FES=eDES) or ((FES=eAuto) and (kodowanie=10)) then
    begin
      strumien2.Clear;
      DecryptStream(strumien,strumien2,strumien.Size);
      strumien2.Position:=0;
      b_przekodowanie:=true;
    end;
    //ewentualny test poprawnosci pliku XML
    if FTest then
    begin
      if b_przekodowanie then
      begin
        buf:=strumien2.Read(bufor[1],5);
        SetLength(bufor,buf);
        strumien2.Position:=0;
      end else begin
        buf:=strumien.Read(bufor[1],5);
        SetLength(bufor,buf);
        strumien.Position:=0;
      end;
      if not CzyToJestXML(bufor) then
      begin
        (* rejestruje blad i przerywam zadanie *)
        __ERROR:=4;
        if Assigned(FOnError) then FOnError(Self, 4, 'To nie jest plik XML! Parsowanie przerwane.');
        result:=false;
        exit;
      end;
    end;
    //parser
    {$IFDEF LAZARUS}
    doc:=TXMLDocument.Create;
    {$ELSE}
    doc:=TXMLDocument.Create(nil);
    {$ENDIF}
    if b_przekodowanie then
    begin
      istrumien:=2;
      if Assigned(FOnProgress) then FOnProgress(Self,strumien2.Size,0);
      {$IFDEF LAZARUS}
      ReadXMLFile(doc,strumien2); (* strumien przekodowany, lub zdeszyfrowany *)
      {$ELSE}
      doc.LoadFromStream(strumien2,xetUTF_8); (* strumien przekodowany, lub zdeszyfrowany *)
      {$ENDIF}
    end else begin
      istrumien:=0;
      if Assigned(FOnProgress) then FOnProgress(Self,strumien.Size,0);
      {$IFDEF LAZARUS}
      ReadXMLFile(doc,strumien); (* strumien domyslny *)
      {$ELSE}
      doc.LoadFromStream(strumien,xetUTF_8); (* strumien domyslny *)
      {$ENDIF}
    end;
    {$IFDEF LAZARUS}
    temp:=doc.DocumentElement;
    {$ELSE}
    temp:=doc.DOMDocument;
    {$ENDIF}
    ParseXML(0,temp);
    if (not zm_stop) and FNULL and Assigned(FOnRead) then FOnRead(self,-1,'','','','',zm_stop);
  finally
    doc.Free;
    strumien.Clear;
    if FES<>eUTF8 then strumien2.Clear;
  end;
  if __ERROR=0 then zm_result:=true else
  begin
    if Assigned(FOnError) then
      {$IFDEF LAZARUS}
      FOnError(Self, 2, 'Wysti nieprzewidziany przez autora bd!'+#13+'Parsowane pliku moe by niepene.');
      {$ELSE}
      FOnError(Self, 2, 'Wyst�pi�� nieprzewidziany przez autora b��d!'+#13+'Parsowane pliku mo�e by� niepe�ne.');
      {$ENDIF}
    zm_result:=false;
  end;
  if Assigned(FOnAfterRead) then FOnAfterRead(Self);
  result:=zm_result;
end;

function TXmlParser.LockString(s: string; spaces: boolean): string;
var
  pom: string;
begin
  pom:=s;
  pom:=StringReplace(pom,'<','◄',[rfReplaceAll]);
  pom:=StringReplace(pom,'>','►',[rfReplaceAll]);
  if spaces then pom:=StringReplace(pom,' ','♪',[rfReplaceAll]);
  result:=pom;
end;

function TXmlParser.UnlockString(s: string; spaces: boolean): string;
var
  pom: string;
begin
  pom:=s;
  pom:=StringReplace(pom,'◄','<',[rfReplaceAll]);
  pom:=StringReplace(pom,'►','>',[rfReplaceAll]);
  if spaces then pom:=StringReplace(pom,'♪',' ',[rfReplaceAll]);
  result:=pom;
end;

function TXmlParser.EncodeXML(XMLFile: string; EncodeFile: string): boolean;
var
  plik: string;
  bufor: shortstring;
  kodowanie,a,b,buf: integer;
  zm_result: boolean;
begin
  plik:=XMLFile;
  if (plik='') or (not FileExists(plik)) then
  begin
    __ERROR:=3;
    if Assigned(FOnError) then FOnError(Self, 2, 'Brak pliku *.XML! Kodowanie przerwane.');
    result:=false;
    exit;
  end;
  if (FES=eAuto) or (FES=eDES) then kodowanie:=OkreslStroneKodowa(plik) else kodowanie:=0;
  try
    __ERROR:=0;
    strumien.Clear;
    strumien.LoadFromFile(plik);
    //przekodowanie jesli trzeba
    if (FES=eWindows1250) or (((FES=eAuto) or (FES=eDES)) and (kodowanie=2)) then
    begin
      strumien2.Clear;
      a:=0;
      while true do
      begin
        buf:=strumien.Read(bufor[1],200);
        SetLength(bufor,buf);
        {$IFDEF LAZARUS}
        bufor:=ConvertEncoding(bufor,'cp1250','utf8');
        {$ELSE}
        bufor:=UTF8Encode(bufor);
        {$ENDIF}
        buf:=length(bufor);
        if (a=0) and (pos('<?',bufor)>0) or (a=1) then
        begin
          if a=0 then strumien2.Write('<?xml version="1.0" encoding="utf-8"?>',38);
          b:=pos('?>',bufor);
          if b>0 then
          begin
            delete(bufor,1,b+1);
            dec(buf,b+1);
            a:=2;
          end else begin
            a:=1;
            continue;
          end;
        end;
        if buf=0 then break;
        strumien2.Write(bufor[1],buf);
      end;
      strumien2.Position:=0;
    end;
    //XMLToDES
    strumien3.Clear;
    if (FES=eWindows1250) or (((FES=eAuto) or (FES=eDES)) and (kodowanie=2)) then
      EncryptStream(strumien2,strumien3,strumien2.Size)
    else
      EncryptStream(strumien,strumien3,strumien.Size);
    if EncodeFile<>'' then plik:=EncodeFile;
    strumien3.SaveToFile(plik);
  finally
    strumien.Clear;
    if FES<>eUTF8 then strumien2.Clear;
    strumien3.Clear;
  end;
  if __ERROR=0 then zm_result:=true else
  begin
    {$IFDEF LAZARUS}
    if Assigned(FOnError) then FOnError(Self, 2, 'Wystpi nieprzewidziany przez autora bd!'+#13+'Przekodowany plik moe by nieczytelny.');
    {$ELSE}
    if Assigned(FOnError) then FOnError(Self, 2, 'Wyst�pi�� nieprzewidziany przez autora b��d!'+#13+'Przekodowany plik mo�e by� nieczytelny.');
    {$ENDIF}
    zm_result:=false;
  end;
  result:=zm_result;
end;

function TXmlParser.EncodeXML: boolean;
begin
  result:=EncodeXML(ConvZapis(zm_filename));
end;

function TXmlParser.DecodeXML(DecodeFile: string; XMLFile: string): boolean;
var
  plik: string;
  bufor: shortstring;
  kodowanie,a,b,buf: integer;
  zm_result: boolean;
begin
  plik:=DecodeFile;
  if (plik='') or (not FileExists(plik)) then
  begin
    __ERROR:=3;
    if Assigned(FOnError) then FOnError(Self, 2, 'Brak zaszyfrowanego pliku XML! Dekodowanie przerwane.');
    result:=false;
    exit;
  end;
  kodowanie:=3;
  try
    __ERROR:=0;
    strumien.Clear;
    strumien.LoadFromFile(plik);
    //DESToXML
    strumien2.Clear;
    DecryptStream(strumien,strumien2,strumien.Size);
    if XMLFile<>'' then plik:=XMLFile;
    strumien2.SaveToFile(plik);
  finally
    strumien.Clear;
    strumien2.Clear;
  end;
  if __ERROR=0 then zm_result:=true else
  begin
    {$IFDEF LAZARUS}
    if Assigned(FOnError) then FOnError(Self, 2, 'Wystpi nieprzewidziany przez autora bd!'+#13+'Przekodowany plik moe by nieczytelny.');
    {$ELSE}
    if Assigned(FOnError) then FOnError(Self, 2, 'Wyst�pi�� nieprzewidziany przez autora b��d!'+#13+'Przekodowany plik mo�e by� nieczytelny.');
    {$ENDIF}
    zm_result:=false;
  end;
  result:=zm_result;
end;

function TXmlParser.DecodeXML: boolean;
begin
  result:=DecodeXML(ConvZapis(zm_filename));
end;

end.