{
  @html(<b>)
  Unidade de Verificação de Memória
  @html(</b>)
  - Copyright 2004-2019 (c) Teppi Technology (https://rtc.teppi.net)
  @html(<br><br>)

  @exclude
}
unit rtcMemory;

{$INCLUDE rtcDefs.inc}

interface

{ Obter o Status Completo do Heap }
function Get_HeapStatus:THeapStatus;

{ Verificar a quantidade de memória em uso (bytes) }
function Get_MemoryInUse:int64;

{ Verificar quanto Espaço de Endereço é usado pela Aplicação (KB) }
function Get_AddressSpaceUsed:int64;

implementation

{$IFNDEF FPC}
  {$O-}
{$ENDIF}

{$IFDEF WINDOWS}
uses 
  Windows;

function Get_AddressSpaceUsed: int64;
  var
    LMemoryStatus: TMemoryStatus;
  begin
  {Define o tamanho da estrutura}
  LMemoryStatus.dwLength := SizeOf(LMemoryStatus);
  {Obtém o status da memória}
  GlobalMemoryStatus(LMemoryStatus);
  {O resultado é o espaço total de endereços menos o espaço livre}
  Result := (LMemoryStatus.dwTotalVirtual - LMemoryStatus.dwAvailVirtual) shr 10;
  end;
  
{$ELSE}

function Get_AddressSpaceUsed: int64;
  var
    hs :THeapStatus;
  begin
  // nenhuma função disponível?
  hs := GetHeapStatus;
  Result := hs.TotalCommitted
  end;
  
{$ENDIF}

function Get_HeapStatus:THeapStatus;
  begin
  Result:=GetHeapStatus;
  end;

function Get_MemoryInUse:int64;
  begin
  Result:=GetHeapStatus.TotalAllocated;
  end;

end.
