constructor TSequenceMemoryRaster.Create;
begin
  inherited Create;
  FTotal := 1;
  FColumn := 1;
end;

destructor TSequenceMemoryRaster.Destroy;
begin
  inherited Destroy;
end;

procedure TSequenceMemoryRaster.Clear(FillColor: TRasterColor);
begin
  inherited Clear(FillColor);
  FTotal := 1;
  FColumn := 1;
end;

procedure TSequenceMemoryRaster.SetSize(NewWidth, NewHeight: Integer; const ClearColor: TRasterColor);
begin
  inherited SetSize(NewWidth, NewHeight, ClearColor);
  FTotal := 1;
  FColumn := 1;
end;

procedure TSequenceMemoryRaster.Reset;
begin
  inherited Reset;
  FTotal := 1;
  FColumn := 1;
end;

procedure TSequenceMemoryRaster.Assign(sour: TMemoryRaster);
begin
  inherited Assign(sour);
  FTotal := 1;
  FColumn := 1;
  if sour is TSequenceMemoryRaster then
    begin
      FTotal := TSequenceMemoryRaster(sour).FTotal;
      FColumn := TSequenceMemoryRaster(sour).FColumn;
    end;
end;

class function TSequenceMemoryRaster.CanLoadStream(stream: TCoreClassStream): Boolean;
var
  FP: Int64;
  hflag: Word;
  ATotal, aColumn: Integer;
begin
  Result := False;
  FP := stream.Position;
  if stream.read(hflag, 2) <> 2 then
      Exit;
  try
    if hflag = $8888 then
      begin
        if stream.read(ATotal, 4) <> 4 then
            Exit;
        if stream.read(aColumn, 4) <> 4 then
            Exit;
        Result := inherited CanLoadStream(stream);
        stream.Position := FP;
      end
    else
      begin
        stream.Position := FP;
        Result := inherited CanLoadStream(stream);
      end;
  except
  end;
end;

procedure TSequenceMemoryRaster.LoadFromStream(stream: TCoreClassStream);
var
  FP: Int64;
  hflag: Word;
  ATotal, aColumn: Integer;
  deStream: TMemoryStream64;
begin
  Reset;
  FP := stream.Position;
  if stream.read(hflag, 2) <> 2 then
      Exit;
  if hflag = $8888 then
    begin
      if stream.read(ATotal, 4) <> 4 then
          Exit;
      if stream.read(aColumn, 4) <> 4 then
          Exit;
      inherited LoadFromStream(stream);
      FTotal := ATotal;
      FColumn := aColumn;
    end
  else
    begin
      stream.Position := FP;
      inherited LoadFromStream(stream);
      FTotal := 1;
      FColumn := 1;
    end;
end;

procedure TSequenceMemoryRaster.SaveToStream(stream: TCoreClassStream);
var
  hflag: Word;
  cStream: TMemoryStream64;
begin
  if FTotal > 1 then
    begin
      hflag := $8888;
      stream.write(hflag, 2);
      stream.write(FTotal, 4);
      stream.write(FColumn, 4);
      inherited SaveToZLibCompressStream(stream);
      Exit;
    end;
  inherited SaveToStream(stream);
end;

function TSequenceMemoryRaster.SequenceFrameRect(index: Integer): TRect;
begin
  Result := GetSequenceFrameRect(Self, Total, Column, index);
end;

procedure TSequenceMemoryRaster.ExportSequenceFrame(index: Integer; output: TMemoryRaster);
begin
  GetSequenceFrameOutput(Self, Total, Column, index, output);
end;

procedure TSequenceMemoryRaster.ReverseSequence(output: TSequenceMemoryRaster);
var
  i: Integer;
  r: TRect;
begin
  output.SetSize(width, height);
  for i := 0 to Total - 1 do
    begin
      r := SequenceFrameRect(i);
      BlockTransfer(output, r.Left, r.Top, output.BoundsRect, Self, SequenceFrameRect(Total - 1 - i), dmOpaque);
    end;
  output.FTotal := FTotal;
  output.FColumn := FColumn;
end;

procedure TSequenceMemoryRaster.GradientSequence(output: TSequenceMemoryRaster);
var
  i, j: Integer;
  SR, dr: TRect;
begin
  output.SetSize(FrameWidth * (Total * 2), FrameHeight);
  output.Column := Total * 2;
  output.Total := output.Column;

  j := 0;

  for i := 0 to Total - 1 do
    begin
      dr := output.SequenceFrameRect(j);
      SR := SequenceFrameRect(i);
      BlockTransfer(output, dr.Left, dr.Top, output.BoundsRect, Self, SR, dmOpaque);
      inc(j);
    end;

  for i := Total - 1 downto 0 do
    begin
      dr := output.SequenceFrameRect(j);
      SR := SequenceFrameRect(i);
      BlockTransfer(output, dr.Left, dr.Top, output.BoundsRect, Self, SR, dmOpaque);
      inc(j);
    end;
end;

function TSequenceMemoryRaster.FrameWidth: Integer;
begin
  with SequenceFrameRect(0) do
      Result := Right - Left;
end;

function TSequenceMemoryRaster.FrameHeight: Integer;
begin
  with SequenceFrameRect(0) do
      Result := Bottom - Top;
end;

function TSequenceMemoryRaster.FrameRect2D: TRectV2;
begin
  Result := MakeRectV2(0, 0, FrameWidth, FrameHeight);
end;

function TSequenceMemoryRaster.FrameRect: TRect;
begin
  Result := Rect(0, 0, FrameWidth, FrameHeight);
end; 
 
 
 
