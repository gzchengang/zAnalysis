{ ****************************************************************************** }
{ * sound engine with BASS Support                                             * }
{ * written by QQ 600585@qq.com                                                * }
{ * https://github.com/PassByYou888/CoreCipher                                 * }
{ * https://github.com/PassByYou888/ZServer4D                                  * }
{ * https://github.com/PassByYou888/zExpression                                * }
{ * https://github.com/PassByYou888/zTranslate                                 * }
{ * https://github.com/PassByYou888/zSound                                     * }
{ * https://github.com/PassByYou888/zAnalysis                                  * }
{ * https://github.com/PassByYou888/zGameWare                                  * }
{ * https://github.com/PassByYou888/zRasterization                             * }
{ ****************************************************************************** }
unit zSound_Bass;

{$INCLUDE ..\zDefine.inc}

interface

uses CoreClasses, zSound, UnicodeMixedLib, MediaCenter,
  ObjectDataManager, ItemStream, LibraryManager, ListEngine, PascalStrings, MemoryStream64,
  SysUtils,
  Bass;

type
  TSoundEngine_Bass = class;

  TSoundStyle = (ssMusic, ssAmbient, ssSound, ssUnknow);

  TSound = class
  public
    Owner  : TSoundEngine_Bass;
    Name   : SystemString;
    Handle : Cardinal;
    Style  : TSoundStyle;
    channel: Cardinal;

    constructor Create;
    destructor Destroy; override;
  end;

  TSoundEngine_Bass = class(TzSound)
  protected
    SoundList: THashObjectList;

    procedure DoPrepareMusic(fileName: SystemString); override;
    procedure DoPlayMusic(fileName: SystemString); override;
    procedure DoStopMusic; override;

    procedure DoPrepareAmbient(fileName: SystemString); override;
    procedure DoPlayAmbient(fileName: SystemString); override;
    procedure DoStopAmbient; override;

    procedure DoPrepareSound(fileName: SystemString); override;
    procedure DoPlaySound(fileName: SystemString); override;
    procedure DoStopSound(fileName: SystemString); override;

    procedure DoStopAll; override;

    function DoIsPlaying(fileName: SystemString): Boolean; override;

    function SaveSoundAsLocalFile(fileName: SystemString): SystemString; override;
    function SoundReadyOk(fileName: SystemString): Boolean; override;
  public
    constructor Create(ATempPath: SystemString); override;
    destructor Destroy; override;

    procedure Progress(deltaTime: Double); override;
  end;

var
  SoundEngine_Bass: TSoundEngine_Bass = nil;

implementation

constructor TSound.Create;
begin
  Owner := nil;
  Name := '';
  Handle := 0;
  Style := ssUnknow;
  channel := 0;
  inherited Create;
end;

destructor TSound.Destroy;
begin
  case Style of
    ssMusic: BASS_MusicFree(Handle);
    ssAmbient: BASS_MusicFree(Handle);
    ssSound: BASS_SampleFree(Handle);
  end;
  inherited Destroy;
end;

procedure TSoundEngine_Bass.DoPrepareMusic(fileName: SystemString);
var
  s     : TSound;
  stream: TCoreClassStream;
  ms    : TMemoryStream64;
begin
  if SoundList.Exists(fileName) then
      Exit;

  stream := FileIOOpen(fileName);
  if stream = nil then
      Exit;

  ms := TMemoryStream64.Create;
  ms.CopyFrom(stream, stream.Size);
  ms.Position := 0;

  s := TSound.Create;
  s.Owner := Self;
  s.Name := fileName;
  s.Handle := BASS_SampleLoad(True, ms.Memory, 0, ms.Size, 3, BASS_SAMPLE_LOOP or BASS_SAMPLE_OVER_POS {$IFDEF UNICODE} or BASS_UNICODE{$ENDIF});
  s.Style := ssMusic;
  s.channel := 0;

  DisposeObject([ms, stream]);

  if s.Handle <> 0 then
    begin
      SoundList[fileName] := s;
      Exit;
    end;
  DisposeObject(s);
end;

procedure TSoundEngine_Bass.DoPlayMusic(fileName: SystemString);
var
  s: TSound;
begin
  DoStopMusic;

  s := SoundList[fileName] as TSound;
  if s = nil then
    begin
      DoPrepareMusic(fileName);
      s := SoundList[fileName] as TSound;
    end;

  if s = nil then
      Exit;

  s.channel := BASS_SampleGetChannel(s.Handle, False);
  if s.channel <> 0 then
      BASS_ChannelPlay(s.channel, False);
end;

procedure TSoundEngine_Bass.DoStopMusic;
var
  lst: TCoreClassListForObj;
  i  : Integer;
  s  : TSound;
begin
  lst := TCoreClassListForObj.Create;
  SoundList.GetAsList(lst);
  for i := 0 to lst.Count - 1 do
    begin
      s := lst[i] as TSound;

      if s.Style = ssMusic then
        if s.channel <> 0 then
            BASS_ChannelStop(s.channel);
    end;
  DisposeObject(lst);
end;

procedure TSoundEngine_Bass.DoPrepareAmbient(fileName: SystemString);
var
  s     : TSound;
  stream: TCoreClassStream;
  ms    : TMemoryStream64;
begin
  if SoundList.Exists(fileName) then
      Exit;

  stream := FileIOOpen(fileName);
  if stream = nil then
      Exit;

  ms := TMemoryStream64.Create;
  ms.CopyFrom(stream, stream.Size);
  ms.Position := 0;

  s := TSound.Create;
  s.Owner := Self;
  s.Name := fileName;
  s.Handle := BASS_SampleLoad(True, ms.Memory, 0, ms.Size, 5, BASS_SAMPLE_LOOP or BASS_SAMPLE_OVER_POS {$IFDEF UNICODE} or BASS_UNICODE{$ENDIF});
  s.Style := ssAmbient;
  s.channel := 0;

  DisposeObject([ms, stream]);

  if s.Handle <> 0 then
    begin
      SoundList[fileName] := s;
      Exit;
    end;
  DisposeObject(s);
end;

procedure TSoundEngine_Bass.DoPlayAmbient(fileName: SystemString);
var
  s: TSound;
begin
  if DoIsPlaying(fileName) then
      Exit;

  s := SoundList[fileName] as TSound;
  if s = nil then
    begin
      DoPrepareAmbient(fileName);
      s := SoundList[fileName] as TSound;
    end;

  if s = nil then
      Exit;

  s.channel := BASS_SampleGetChannel(s.Handle, False);
  if s.channel <> 0 then
      BASS_ChannelPlay(s.channel, False);
end;

procedure TSoundEngine_Bass.DoStopAmbient;
var
  lst: TCoreClassListForObj;
  i  : Integer;
  s  : TSound;
begin
  lst := TCoreClassListForObj.Create;
  SoundList.GetAsList(lst);
  for i := 0 to lst.Count - 1 do
    begin
      s := lst[i] as TSound;

      if s.Style = ssAmbient then
        if s.channel <> 0 then
            BASS_ChannelStop(s.channel);
    end;
  DisposeObject(lst);
end;

procedure TSoundEngine_Bass.DoPrepareSound(fileName: SystemString);
var
  s     : TSound;
  stream: TCoreClassStream;
  ms    : TMemoryStream64;
begin
  if SoundList.Exists(fileName) then
      Exit;

  stream := FileIOOpen(fileName);
  if stream = nil then
      Exit;

  ms := TMemoryStream64.Create;
  ms.CopyFrom(stream, stream.Size);
  ms.Position := 0;

  s := TSound.Create;
  s.Owner := Self;
  s.Name := fileName;
  s.Handle := BASS_SampleLoad(True, ms.Memory, 0, ms.Size, 3, BASS_SAMPLE_OVER_POS {$IFDEF UNICODE} or BASS_UNICODE{$ENDIF});
  s.Style := ssSound;
  s.channel := 0;

  DisposeObject([ms, stream]);

  if s.Handle <> 0 then
    begin
      SoundList[fileName] := s;
      Exit;
    end
  else
      RaiseInfo('bass error:%d', [BASS_ErrorGetCode]);
  DisposeObject(s);
end;

procedure TSoundEngine_Bass.DoPlaySound(fileName: SystemString);
var
  s: TSound;
begin
  s := SoundList[fileName] as TSound;
  if s = nil then
    begin
      DoPrepareSound(fileName);
      s := SoundList[fileName] as TSound;
    end;

  if s = nil then
      Exit;

  if (s.channel <> 0) and (BASS_ChannelIsActive(s.channel) = BASS_ACTIVE_PLAYING) then
    begin
      BASS_ChannelPlay(s.channel, True);
    end
  else
    begin
      s.channel := BASS_SampleGetChannel(s.Handle, False);
      if s.channel <> 0 then
          BASS_ChannelPlay(s.channel, False);
    end;
end;

procedure TSoundEngine_Bass.DoStopSound(fileName: SystemString);
var
  s: TSound;
begin
  s := SoundList[fileName] as TSound;
  if s = nil then
    begin
      DoPrepareSound(fileName);
      s := SoundList[fileName] as TSound;
    end;

  if s = nil then
      Exit;

  if s.channel <> 0 then
      BASS_ChannelStop(s.channel);
end;

procedure TSoundEngine_Bass.DoStopAll;
var
  lst: TCoreClassListForObj;
  i  : Integer;
  s  : TSound;
begin
  lst := TCoreClassListForObj.Create;
  SoundList.GetAsList(lst);
  for i := 0 to lst.Count - 1 do
    begin
      s := lst[i] as TSound;
      if s.channel <> 0 then
          BASS_ChannelStop(s.channel);
    end;
  DisposeObject(lst);
end;

function TSoundEngine_Bass.DoIsPlaying(fileName: SystemString): Boolean;
var
  s: TSound;
begin
  Result := False;

  s := SoundList[fileName] as TSound;
  if s = nil then
    begin
      DoPrepareAmbient(fileName);
      s := SoundList[fileName] as TSound;
    end;

  if s = nil then
      Exit;

  Result := (s.channel <> 0) and (BASS_ChannelIsActive(s.channel) = BASS_ACTIVE_PLAYING);
end;

function TSoundEngine_Bass.SaveSoundAsLocalFile(fileName: SystemString): SystemString;
begin
  Result := fileName;
end;

function TSoundEngine_Bass.SoundReadyOk(fileName: SystemString): Boolean;
begin
  Result := True;
end;

constructor TSoundEngine_Bass.Create(ATempPath: SystemString);
begin
  inherited Create(ATempPath);
  SoundList := THashObjectList.Create(True, 2048);
  SoundEngine_Bass := Self;
end;

destructor TSoundEngine_Bass.Destroy;
begin
  StopAll;
  SoundEngine_Bass := nil;
  DisposeObject(SoundList);
  inherited Destroy;
end;

procedure TSoundEngine_Bass.Progress(deltaTime: Double);
begin
  inherited Progress(deltaTime);
end;

initialization

if not Bass_Available then
    Exit;
try
  {$IFDEF MSWINDOWS}
  if not BASS_Init(-1, 44100, 0, 0, nil) then
      RaiseInfo('bass init failed (%d)', [BASS_ErrorGetCode]);
  {$ELSE}
  if not BASS_Init(-1, 44100, 0, nil, nil) then
      RaiseInfo('bass init failed (%d)', [BASS_ErrorGetCode]);
  {$ENDIF}
  BASS_SetConfig(BASS_CONFIG_NET_PLAYLIST, 1); // enable playlist processing
  BASS_SetConfig(BASS_CONFIG_NET_READTIMEOUT, 2000);
  BASS_SetConfig(BASS_CONFIG_IOS_SPEAKER, 1);
  BASS_SetConfig(BASS_CONFIG_NET_PREBUF, 0);

  DefaultSoundEngineClass := TSoundEngine_Bass;
except
end;

finalization

end. 
 
