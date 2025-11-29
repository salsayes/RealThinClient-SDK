{ 
  @html(<b>)
  Criação de Arquivo de Log
  @html(</b>)
  - Copyright 2004-2019 (c) Teppi Technology (https://rtc.teppi.net)
  @html(<br><br>)

  Esta unidade fornece suporte para gravação de Log com segurança para threads.
}
unit rtcLog;

{$INCLUDE rtcDefs.inc}

interface

uses
{$IFDEF WINDOWS}
  Windows, // FileCreate + FileClose + GetCurrentThreadID
{$ENDIF}
{$IFDEF POSIX}
  Posix.Unistd, // FileClose
  Posix.PThread, // GetCurrentThreadID
{$ENDIF}

  SysUtils,

{$IFDEF IDE_1}
  FileCtrl,
{$ENDIF}

  rtcTypes,
  rtcSystem,
  rtcSrcList;

var
  { Registrar exceções no arquivo de Log?
    Padrão=True. Alterar para False remove as exceções
    dos componentes de conexão do arquivo de Log. }
  LOG_EXCEPTIONS:boolean=True;

  { Registrar todas as chamadas "Log" no CONSOLE (stdout)? }
  LOG_TO_CONSOLE:boolean=False;

  { Registrar todas as chamadas "xLog" no CONSOLE (stdout)? }
  XLOG_TO_CONSOLE:boolean=False;

  { O RTC SDK pode tratar silenciosamente a maioria das exceções
    que, de outra forma, fariam os componentes pararem de funcionar.
    Este é um mecanismo de segurança que garante que até bugs no
    RTC SDK não derrubem seus aplicativos, mas uma exceção chegando
    até aqui normalmente significa que há algo errado no RTC SDK.
    Ao depurar o RTC SDK, LOG_AV_ERRORS deve ser TRUE para que
    todas as exceções anormais sejam registradas. }
  LOG_AV_ERRORS:boolean={$IFDEF RTC_DEBUG}True{$ELSE}False{$ENDIF};

  { Se quiser que arquivos antigos de log sejam apagados após alguns dias,
    defina por quantos dias (em dias) os arquivos devem ser mantidos.
    Se esta variável for 0 (padrão), os arquivos de log NÃO serão apagados. }
  RTC_LOGS_LIVE_DAYS:integer=0;

  { Subpasta dentro do diretório de AppFileName onde todos os arquivos de LOG serão armazenados.
    Se quiser criar os arquivos de LOG na mesma pasta do AppFile (EXE/DLL),
    defina LOG_FOLDER como uma string vazia antes de chamar "StartLog".
    Para que este valor tenha efeito, ele precisa ser definido antes de "StartLog". }
  LOG_FOLDER:RtcWideString='LOG';

  { Caminho completo para a pasta de LOG. Se deixar esta variável vazia (padrão),
    ela será inicializada automaticamente usando AppFileName e LOG_FOLDER
    imediatamente antes de a primeira entrada de log ser gravada.
    Se quiser que os arquivos de LOG sejam gravados em uma pasta específica
    usando o caminho completo, defina esta variável antes da primeira entrada.
    RTC_LOG_FOLDER deve SEMPRE terminar com '\' no Windows e '/' em outras plataformas. }
  RTC_LOG_FOLDER:RtcWideString='';

  { String usada para formatar a data/hora no LOG do RTC. Para mais informações sobre
    formatos válidos de data/hora, consulte a ajuda do Delphi para a função "FormatDateTime". }
  RTC_LOG_DATETIMEFORMAT:String='yyyy-mm-dd hh:nn:ss.zzz; ';

  { Incluir CurrentThreadID em cada entrada de LOG? }
  RTC_LOG_THREADID:boolean=False;

{$IFDEF RTC_BYTESTRING}
{ Registrar exceção com uma breve descrição no arquivo de Log global do aplicativo.
  Este procedimento não terá efeito se o Log não tiver sido iniciado
  (chamando StartLog) ou se LOG_EXCEPTIONS for @false }
procedure Log(const s:RtcString; E:Exception; const name:String=''); overload;

{ Registrar mensagem no arquivo de Log global do aplicativo.
  Este procedimento não terá efeito se o Log não tiver sido iniciado. }
procedure Log(const s:RtcString; const name:String=''); overload;

{ Registrar mensagem no arquivo de Log para a data atual.
  Este procedimento não terá efeito se o Log não tiver sido iniciado. }
procedure XLog(const s:RtcString; const name:String=''); overload;
{$ENDIF}

{ Copiar o arquivo de LOG "fromName" para o arquivo de LOG "toName". }
procedure Copy_Log(const fromName,toName:String);

{ Excluir arquivo de LOG "name" }
procedure Delete_Log(const name:String);

{ Registrar exceção com uma breve descrição no arquivo de Log global do aplicativo.
  Este procedimento não terá efeito se o Log não tiver sido iniciado
  (chamando StartLog) ou se LOG_EXCEPTIONS for @false }
procedure Log(const s:RtcWideString; E:Exception; const name:String=''); overload;

{ Registrar mensagem no arquivo de Log global do aplicativo.
  Este procedimento não terá efeito se o Log não tiver sido iniciado. }
procedure Log(const s:RtcWideString; const name:String=''); overload;

{ Registrar mensagem no arquivo de Log para a data atual.
  Este procedimento não terá efeito se o Log não tiver sido iniciado. }
procedure XLog(const s:RtcWideString; const name:String=''); overload;

{ Para que os procedimentos Log() tenham efeito,
  é preciso chamar este procedimento para iniciar o escritor de Log.
  Sem isso, não há arquivo de Log. }
procedure StartLog;

{ Para parar a criação de arquivos de Log, chame este procedimento.
  Para continuar a gravação, chame StartLog. }
procedure StopLog;

{ Iniciar o uso de Buffers para Log, o que torna o registro muito mais rápido.
  "MaxSize" é o tamanho máximo (em bytes) que o LOG pode ocupar
  na memória antes de precisar ser gravado em arquivos. @html(<br><br>)

  IMPORTANTE!!! Ao usar buffers para log, o parâmetro "name" diferencia maiúsculas de minúsculas,
  o que significa que um buffer separado será criado para 'XName' e para 'xname', mas
  ambos serão gravados no mesmo arquivo no final. Por isso, tenha cuidado ao usar o
  parâmetro "name" para sempre fornecer exatamente o mesmo valor para todas as entradas
  de LOG que precisam ir para o mesmo arquivo, ou a ordem das entradas pode se misturar. }
procedure StartLogBuffers(MaxSize:longint);

{ Parar de usar buffers para Log. }
procedure StopLogBuffers;

{ Despejar os buffers de Log atuais em arquivos e liberar a memória de buffer. }
procedure DumpLogBuffers;

implementation

var
  ThrCS:TRtcCritSec=nil;
  doLog:boolean=False;
  doBuffers:boolean=False;
  LogMaxBuff:longint;
  LogCurBuff:longint;
  LogBuff:TStringObjList;
  AppOnlyFileName,
  AppOnlyFilePath:RtcWideString;

procedure StartLog;
  begin
  if not doLog then
    if assigned(ThrCS) then
      begin
      doLog:=True;
      {$IFDEF RTC_DEBUG}Log('rtcLog START ...','DEBUG');{$ENDIF}
      end;
  end;

procedure StopLog;
  begin
  if doLog then
    begin
    {$IFDEF RTC_DEBUG} Log('rtcLog STOP.','DEBUG');{$ENDIF}
    if doBuffers then
      DumpLogBuffers;
    doLog:=False;
    end;
  end;

procedure Delete_old_logs;
  var
    vdate      :TDatetime;
    sr         :TSearchRec;
    intFileAge :LongInt;
    myfileage  :TDatetime;
  begin
  try
    vdate:= Now - RTC_LOGS_LIVE_DAYS;
    if FindFirst(RTC_LOG_FOLDER + '*.log', faAnyFile - faDirectory, sr) = 0 then
      repeat
        intFileAge := FileAge(RTC_LOG_FOLDER + RtcWideString(sr.name));
        if intFileAge > -1 then
          begin
          myfileage:= FileDateToDateTime(intFileAge);
          if myfileage < vdate then
            Delete_File(RTC_LOG_FOLDER + RtcWideString(sr.name));
          end;
        until (FindNext(sr) <> 0);
  finally
    FindClose(sr);
    end;
  end;

procedure File_AppendEx(const fname:RtcWideString; const Data:RtcByteArray);
  var
    f:TRtcFileHdl;
  begin
  f:=FileOpen(fname,fmOpenReadWrite+fmShareDenyNone);
  if f=RTC_INVALID_FILE_HDL then
    begin
    try
      if RTC_LOGS_LIVE_DAYS > 0 then
        Delete_old_logs;
    except
      // ignorar problemas ao excluir arquivos
      end;
    f:=FileCreate(fname);
    end;
  if f<>RTC_INVALID_FILE_HDL then
    try
      if FileSeek(f,0,2)>=0 then
        FileWrite(f,data[0],length(data));
    finally
      FileClose(f);
      end;
  end;

procedure File_Append(const fname:RtcWideString; const Data:RtcString);
  var
    f:TRtcFileHdl;
  begin
  f:=FileOpen(fname,fmOpenReadWrite+fmShareDenyNone);
  if f=RTC_INVALID_FILE_HDL then
    begin
    try
      if RTC_LOGS_LIVE_DAYS > 0 then
        Delete_old_logs;
    except
      // ignorar problemas ao excluir arquivos
      end;
    f:=FileCreate(fname);
    end;
  if f<>RTC_INVALID_FILE_HDL then
    try
      if FileSeek(f,0,2)>=0 then
        {$IFDEF RTC_BYTESTRING}
        FileWrite(f,data[1],length(data));
        {$ELSE}
        FileWrite(f,RtcStringToBytes(data)[0],length(data));
        {$ENDIF}
    finally
      FileClose(f);
      end;
  end;

procedure PrepareLogFolder;
  begin
  if AppFileName='' then
    AppFileName:=ExpandUNCFileName(RtcWideString(ParamStr(0)));

  if AppOnlyFileName='' then
    begin
    AppOnlyFileName:=ExtractFileName(AppFileName);
    AppOnlyFilePath:=ExtractFilePath(AppFileName);
    if Copy(AppOnlyFilePath,length(AppOnlyFilePath),1)<>FOLDER_DELIMITER then
      AppOnlyFilePath:=AppOnlyFilePath+FOLDER_DELIMITER;
    end;

  if RTC_LOG_FOLDER='' then
    begin
    RTC_LOG_FOLDER:=AppOnlyFilePath;
    if LOG_FOLDER<>'' then
      begin
      RTC_LOG_FOLDER:=RTC_LOG_FOLDER+LOG_FOLDER;
      if Copy(RTC_LOG_FOLDER,length(RTC_LOG_FOLDER),1)<>FOLDER_DELIMITER then
        RTC_LOG_FOLDER:=RTC_LOG_FOLDER+FOLDER_DELIMITER;
      end;
    end;

  if not DirectoryExists(RTC_LOG_FOLDER) then
    if not CreateDir(RTC_LOG_FOLDER) then
      begin
      RTC_LOG_FOLDER:=GetTempDirectory;
      if Copy(RTC_LOG_FOLDER,length(RTC_LOG_FOLDER),1)<>FOLDER_DELIMITER then
        RTC_LOG_FOLDER:=RTC_LOG_FOLDER+FOLDER_DELIMITER;

      RTC_LOG_FOLDER:=RTC_LOG_FOLDER+LOG_FOLDER;
      if not DirectoryExists(RTC_LOG_FOLDER) then
        CreateDir(RTC_LOG_FOLDER);

      if Copy(RTC_LOG_FOLDER,length(RTC_LOG_FOLDER),1)<>FOLDER_DELIMITER then
        RTC_LOG_FOLDER:=RTC_LOG_FOLDER+FOLDER_DELIMITER;
      end;
  end;

procedure WriteToLogEx(const ext:RtcWideString; const text:RtcByteArray);
  begin
  PrepareLogFolder;
  File_AppendEx(RTC_LOG_FOLDER+AppOnlyFileName+'.'+ext, text);
  end;

procedure WriteToLog(const ext:RtcWideString; const text:RtcString);
  begin
  PrepareLogFolder;
  File_Append(RTC_LOG_FOLDER+AppOnlyFileName+'.'+ext, text);
  end;

procedure WriteToBuffEx(const ext:RtcWideString; const text:RtcByteArray);
  var
    obj:TObject;
    data:TRtcHugeByteArray;
  begin
  obj:=LogBuff.search(ext);
  if not assigned(obj) then
    begin
    data:=TRtcHugeByteArray.Create;
    LogBuff.insert(ext,data);
    end
  else
    data:=TRtcHugeByteArray(obj);
  data.AddEx(text);
  Inc(LogCurBuff,length(text));
  if LogCurBuff>LogMaxBuff then
    DumpLogBuffers;
  end;

procedure WriteToBuff(const ext:RtcWideString; const text:RtcString);
  var
    obj:TObject;
    data:TRtcHugeByteArray;
  begin
  obj:=LogBuff.search(ext);
  if not assigned(obj) then
    begin
    data:=TRtcHugeByteArray.Create;
    LogBuff.insert(ext,data);
    end
  else
    data:=TRtcHugeByteArray(obj);
  data.Add(text);
  Inc(LogCurBuff,length(text));
  if LogCurBuff>LogMaxBuff then
    DumpLogBuffers;
  end;

procedure StartLogBuffers(MaxSize:longint);
  begin
  ThrCS.Acquire;
  try
    doBuffers:=True;
    if assigned(LogBuff) then
      DumpLogBuffers
    else
      LogBuff:=tStringObjList.Create(128);
    LogMaxBuff:=MaxSize;
    LogCurBuff:=0;
  finally
    ThrCS.Release;
    end;
  end;

procedure DumpLogBuffers;
  var
    s:RtcWideString;
    obj:TObject;
    data:TRtcHugeByteArray;
  begin
  ThrCS.Acquire;
  try
    if assigned(LogBuff) then
      begin
      while not LogBuff.Empty do
        begin
        s:=LogBuff.search_min(obj);
        LogBuff.remove(s);
        if assigned(obj) then
          begin
          data:=TRtcHugeByteArray(obj);
          try
            WriteToLogEx(s,data.GetEx);
          except
            end;
          data.Free;
          end;
        end;
      LogCurBuff:=0;
      end;
  finally
    ThrCS.Release;
    end;
  end;

procedure StopLogBuffers;
  begin
  ThrCS.Acquire;
  try
    doBuffers:=False;
    DumpLogBuffers;
    RtcFreeAndNil(LogBuff);
  finally
    ThrCS.Release;
    end;
  end;

procedure XLog(const s:RtcWideString; const name:String='');
  var
    d:TDateTime;
    fname:RtcWideString;
    s2:RtcString;
  begin
  if not doLog then Exit; // Sair aqui!!!!

  d:=Now;
  if RTC_LOG_DATETIMEFORMAT<>'' then
    begin
    if RTC_LOG_THREADID then
      s2:= Utf8Encode(RtcWideString(IntToStr(Cardinal(GetCurrentThreadId))+'#'+FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)))
    else
      s2:= Utf8Encode(RtcWideString(FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)));
    end
  else if RTC_LOG_THREADID then
    s2:= Int2Str(Cardinal(GetCurrentThreadId))+'#'
  else
    s2:= '';

  if name<>'' then
    fname:=RtcWideString(FormatDateTime('yyyy_mm_dd',d)+'.'+name)+'.log'
  else
    fname:=RtcWideString(FormatDateTime('yyyy_mm_dd',d))+'.log';

  ThrCS.Acquire;
  try
    if XLOG_TO_CONSOLE then
      Writeln(name,':',s);
    if doBuffers then
      WriteToBuff(fname, s2+Utf8Encode(s)+#13#10 )
    else
      WriteToLog(fname, s2+Utf8Encode(s)+#13#10 );
  except
    end;
  ThrCS.Release;
  end;

procedure Log(const s:RtcWideString; const name:String='');
  var
    d:TDateTime;
    fname:RtcWideString;
    s2:RtcString;
  begin
  if not doLog then Exit; // Sair aqui!!!!

  d:=Now;
  if RTC_LOG_DATETIMEFORMAT<>'' then
    begin
    if RTC_LOG_THREADID then
      s2:=Utf8Encode(RtcWideString(IntToStr(Cardinal(GetCurrentThreadId))+'#'+FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)))
    else
      s2:=Utf8Encode(RtcWideString(FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)));
    end
  else if RTC_LOG_THREADID then
    s2:=Int2Str(Cardinal(GetCurrentThreadId))+'#'
  else
    s2:='';

  if name<>'' then
    fname:=RtcWideString(name)+'.log'
  else
    fname:='log';

  ThrCS.Acquire;
  try
    if LOG_TO_CONSOLE then
      Writeln(name,':',s);
    if doBuffers then
      WriteToBuff(fname, s2+Utf8Encode(s)+#13#10 )
    else
      WriteToLog(fname, s2+Utf8Encode(s)+#13#10 );
  except
    end;
  ThrCS.Release;
  end;

procedure Log(const s:RtcWideString; E:Exception; const name:String='');
  begin
  if LOG_EXCEPTIONS then
    Log(s+' Exception! '+RtcWideString(E.ClassName)+': '+RtcWideString(E.Message), name);
  end;

{$IFDEF RTC_BYTESTRING}

procedure XLog(const s:RtcString; const name:String='');
  var
    d:TDateTime;
    fname:RtcWideString;
    s2:RtcString;
  begin
  if not doLog then Exit; // Sair aqui!!!!

  d:=Now;
  if RTC_LOG_DATETIMEFORMAT<>'' then
    begin
    if RTC_LOG_THREADID then
      s2:= Utf8Encode(RtcWideString(IntToStr(Cardinal(GetCurrentThreadId))+'#'+FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)))
    else
      s2:= Utf8Encode(RtcWideString(FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)));
    end
  else if RTC_LOG_THREADID then
    s2:= Int2Str(Cardinal(GetCurrentThreadId))+'#'
  else
    s2:= '';

  if name<>'' then
    fname:=RtcWideString(FormatDateTime('yyyy_mm_dd',d)+'.'+name)+'.log'
  else
    fname:=RtcWideString(FormatDateTime('yyyy_mm_dd',d))+'.log';

  ThrCS.Acquire;
  try
    if XLOG_TO_CONSOLE then
      Writeln(name,':',s);
    if doBuffers then
      WriteToBuff(fname, s2+s+#13#10 )
    else
      WriteToLog(fname, s2+s+#13#10 );
  except
    end;
  ThrCS.Release;
  end;

procedure Log(const s:RtcString; const name:String='');
  var
    d:TDateTime;
    fname:RtcWideString;
    s2:RtcString;
  begin
  if not doLog then Exit; // Sair aqui!!!!

  d:=Now;
  if RTC_LOG_DATETIMEFORMAT<>'' then
    begin
    if RTC_LOG_THREADID then
      s2:=Utf8Encode(RtcWideString(IntToStr(Cardinal(GetCurrentThreadId))+'#'+FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)))
    else
      s2:=Utf8Encode(RtcWideString(FormatDateTime(RTC_LOG_DATETIMEFORMAT,d)));
    end
  else if RTC_LOG_THREADID then
    s2:=Int2Str(Cardinal(GetCurrentThreadId))+'#'
  else
    s2:='';

  if name<>'' then
    fname:=RtcWideString(name)+'.log'
  else
    fname:='log';

  ThrCS.Acquire;
  try
    if LOG_TO_CONSOLE then
      Writeln(name,':',s);
    if doBuffers then
      WriteToBuff(fname, s2+s+#13#10 )
    else
      WriteToLog(fname, s2+s+#13#10 );
  except
    end;
  ThrCS.Release;
  end;

procedure Log(const s:RtcString; E:Exception; const name:String='');
  begin
  if LOG_EXCEPTIONS then
    Log(s+' Exception! '+RtcString(E.ClassName)+': '+RtcString(E.Message), name);
  end;
{$ENDIF}

{ Copy LOG file "fromName" to LOG file "toName". }
procedure Copy_Log(const fromName,toName:String);
  var
    xname,fname,tname:RtcWideString;
    cnt:integer;
  begin
  if not doLog then Exit; // Exit here !!!!
  if fromName=toName then Exit; // e aqui!!!!

  PrepareLogFolder;
  if fromName='' then fname:='log' else fname:=RtcWideString(fromName)+'.log';
  if toName=''   then tname:='log' else tname:=RtcWideString(toName)+'.log';

  DumpLogBuffers;

  cnt:=1;
  xname:=RTC_LOG_FOLDER+AppOnlyFileName+'.';
  while not Copy_FileEx(xname+fname,xname+tname,0,0,-1,128000) do
    begin
    Sleep(100);
    Inc(cnt);
    if cnt>10 then Break;
    end;
  end;

{ Delete LOG file "name" }
procedure Delete_Log(const name:String);
  var
    xname,fname:RtcWideString;
    cnt:integer;
  begin
  if not doLog then Exit; // Exit here !!!!

  PrepareLogFolder;
  if name='' then fname:='log' else fname:=RtcWideString(name)+'.log';

  DumpLogBuffers;

  cnt:=1;
  xname:=RTC_LOG_FOLDER+AppOnlyFileName+'.';
  while not Delete_File(xname+fname) do
    begin
    Sleep(100);
    Inc(cnt);
    if cnt>10 then Break;
    end;
  end;

initialization
AppOnlyFileName:='';
AppOnlyFilePath:='';
ThrCS:=TRtcCritSec.Create;
finalization
{$IFDEF RTC_DEBUG} Log('rtcLog Finalizing ...','DEBUG');{$ENDIF}
StopLogBuffers;
StopLog;
AppOnlyFileName:='';
AppOnlyFilePath:='';
RtcFreeAndNil(ThrCS);
end.
