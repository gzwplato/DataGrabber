{
  Copyright (C) 2013-2015 Tim Sinaeve tim.sinaeve@gmail.com

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
}

unit DataGrabber.Utils;

interface

uses
  Winapi.Windows,
  System.Classes,
  Vcl.Controls,

  VirtualTrees;

function ContainsFocus(AControl: TWinControl): Boolean;

function GetTextWidth(const AText: string): Integer;

function GetMaxTextWidth(AStrings: TStrings): Integer;

function Explode(Separator, Text: string): TStringList;

function FindNode(
  AVT         : TVirtualStringTree;
  AIdx        : Integer;
  AParentNode : PVirtualNode
): PVirtualNode;

procedure SelectNode(
  AVT         : TVirtualStringTree;
  AIdx        : Integer;
  AParentNode : PVirtualNode = nil
); overload;

procedure SelectNode(
  AVT   : TVirtualStringTree;
  ANode : PVirtualNode
); overload;

implementation

uses
  System.Math, System.StrUtils, System.Character, System.SysUtils,
  Vcl.Forms,

  ts.Utils;

{$REGION 'interfaced routines'}
function GetTextWidth(const AText: string): Integer;
var
  SL      : TStringList;
  I, W, R : Integer;
begin
  SL := TStringList.Create;
  try
    SL.Text := AText;
    R := 0;
    for I := 0 to SL.Count - 1 do
    begin
      W := Length(SL[I]);
      if W > R then
        R := W;
    end;
    Result := R;
  finally
    SL.Free;
  end;
end;

function GetMaxTextWidth(AStrings: TStrings): Integer;
var
  I : Integer;
  N : Integer;
begin
  Result := 0;
  if Assigned(AStrings) then
  begin
    for I := 0 to AStrings.Count - 1 do
    begin
      N := GetTextWidth(AStrings[I]);
      if N > Result then
        Result := N;
    end;
  end;
end;

function RunFormatterProcess(const AExeName: string; const AParams: string;
  const AString: string; const ATempFile: string): string;
var
  SL : TStringList;
  S  : string;
  T  : string;
begin
  S := ExtractFilePath(Application.ExeName) + AExeName;
  T := ExtractFilePath(Application.ExeName) + ATempFile;
  if FileExists(S) then
  begin
    SL := TStringList.Create;
    try
      SL.Text := AString;
      SL.SaveToFile(T);
      RunApplication(Format(AParams, [T]), S);
      SL.LoadFromFile(T);
      Result := SL.Text;
    finally
      FreeAndNil(SL);
    end;
    if FileExists(T) then
      DeleteFile(T);
  end
  else
    raise Exception.CreateFmt('%s not found!', [S]);
end;

function FormatSQL(const AString: string): string;
begin
  Result := RunFormatterProcess(
    'SQLFormatter.exe',
    '%s /is:"  " /st:2 /mw:80 /tc /uk- /ae',
    AString,
    'Formatter.sql'
  );
end;

function Explode(Separator, Text: String): TStringList;
var
  i: Integer;
  Item: String;
begin
  // Explode a string by separator into a TStringList
  Result := TStringList.Create;
  while true do begin
    i := Pos(Separator, Text);
    if i = 0 then begin
      // Last or only segment: Add to list if it's the last. Add also if it's not empty and list is empty.
      // Do not add if list is empty and text is also empty.
      if (Result.Count > 0) or (Text <> '') then
        Result.Add(Text);
      break;
    end;
    Item := Trim(Copy(Text, 1, i-1));
    Result.Add(Item);
    Delete(Text, 1, i-1+Length(Separator));
  end;
end;

function FindNode(AVT: TVirtualStringTree; AIdx: Integer; AParentNode: PVirtualNode): PVirtualNode;
var
  Node: PVirtualNode;
begin
  // Helper to find a node by its index
  Result := nil;
  if Assigned(AParentNode) then
    Node := AVT.GetFirstChild(AParentNode)
  else
    Node := AVT.GetFirst;
  while Assigned(Node) do begin
    if Node.Index = AIdx then begin
      Result := Node;
      break;
    end;
    Node := AVT.GetNextSibling(Node);
  end;
end;

procedure SelectNode(AVT: TVirtualStringTree; AIdx: Integer; AParentNode: PVirtualNode);
var
  Node: PVirtualNode;
begin
  // Helper to focus and highlight a node by its index
  Node := FindNode(AVT, AIdx, AParentNode);
  if Assigned(Node) then
    SelectNode(AVT, Node);
end;

procedure SelectNode(AVT: TVirtualStringTree; ANode: PVirtualNode);
begin
  AVT.ClearSelection;
  AVT.FocusedNode := ANode;
  AVT.Selected[ANode] := True;
  AVT.ScrollIntoView(ANode, False);
end;
{$ENDREGION}

{
Useage:
  Fill(ListBox.Items, Beatles.GetEnumerator);
  Fill(ListBox.Items, Memo.Lines.GetEnumerator);

}

//procedure Fill(Strings: TStrings; Enumerator: TObject);
//var
//  Context: TRttiContext;
//  EnumType: TRttiType;
//  Current: TRttiProperty;
//  MoveNext: TRttiMethod;
//  Value: TValue;
//begin
//  Context := TRttiContext.Create;
//  try
//    EnumType := Context.GetType(Enumerator.ClassType);
//
//    // Find the Current property
//    Current := EnumType.GetProperty('Current');
//    if (Current = nil) or
//      not (Current.PropertyType.TypeKind in
//        [tkString, tkUString, tkClass]) then
//      raise Exception.Create('Invalid Current property');
//
//    // Find the MoveNext property
//    MoveNext := EnumType.GetMethod('MoveNext');
//    if (MoveNext = nil) or (Length(MoveNext.GetParameters) > 0) or
//      (MoveNext.MethodKind <> mkFunction) or
//      (MoveNext.ReturnType.Handle <> TypeInfo(Boolean)) then
//      raise Exception.Create('Invalid MoveNext method');
//
//    // while MoveNext do
//    while MoveNext.Invoke(Enumerator, []).AsBoolean do
//    begin
//      // Value := Current
//      Value := Current.GetValue(Enumerator);
//      case Value.Kind of
//        tkClass: Strings.Add(Value.AsObject.ToString);
//        tkUString, tkString: Strings.Add(Value.AsString);
//        tkClassRef: Strings.Add(Value.AsClass.ClassName);
//        // Any other types you want to support go here
//      end;
//    end;
//  finally
//    Context.Free;
//  end;
//end;

function ContainsFocus(AControl: TWinControl): Boolean;
var
  H : HWND;
  C : TWinControl;
begin
  H := Winapi.Windows.GetFocus;
  C := FindControl(H);
  if not Assigned(C) then
    Result := False
  else
  begin
    Result := AControl.ContainsControl(C);
  end;
end;

end.