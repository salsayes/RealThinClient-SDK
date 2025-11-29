{
  @html(<b>)
  Suporte a ActiveX
  @html(</b>)
  - Copyright 2004-2019 (c) Teppi Technology (https://rtc.teppi.net)
  @html(<br><br>)

  Inclua esta unidade em algum lugar do seu Projeto se estiver usando
  objetos ActiveX em Aplicações RTC multi-thread.

  Esta unidade cria e registra um Callback de Thread para chamar automaticamente
  "CoInitialize" ao iniciar Threads RTC e "CoUnInitialize" ao encerrá-las.
}
unit rtcActiveX;

{$INCLUDE rtcDefs.inc}

interface

uses
  Classes, ActiveX,
  rtcTypes, rtcLog, rtcThrPool;

type
  { Uma instância da classe "TRtcActiveX" será criada e registrada
    como Callback de Thread RTC se esta unidade (rtcActiveX) for usada em qualquer lugar do
    Projeto, para chamar automaticamente "CoInitialize" ao iniciar Threads RTC
    e "CoUnInitialize" ao encerrá-las. }
  TRtcActiveX=class(TRtcThreadCallback)
    procedure AfterThreadStart; override;
    { Chamado dentro de cada Thread, antes de ser parada/destruída }
    procedure BeforeThreadStop; override;
    { Chamado após todas as threads terem sido encerradas.
      Este é o método no qual você deve destruir o objeto chamando "Free" }
    procedure DestroyCallback; override;
    end;

implementation

{ TRtcActiveX }

procedure TRtcActiveX.AfterThreadStart;
  begin
  CoInitialize(nil);
  end;

procedure TRtcActiveX.BeforeThreadStop;
  begin
  CoUninitialize;
  end;

procedure TRtcActiveX.DestroyCallback;
  begin
  Free;
  end;

initialization
{$IFDEF RTC_DEBUG} StartLog; Log('rtcActiveX Initializing ...','DEBUG');{$ENDIF}

AddThreadCallback( TRtcActiveX.Create );

{$IFDEF RTC_DEBUG} Log('rtcActiveX Initialized.','DEBUG');{$ENDIF}
finalization
{$IFDEF RTC_DEBUG} Log('rtcActiveX Finalizing ...','DEBUG');{$ENDIF}
CloseThreadPool;
{$IFDEF RTC_DEBUG} Log('rtcActiveX Finalized.','DEBUG');{$ENDIF}
end.
