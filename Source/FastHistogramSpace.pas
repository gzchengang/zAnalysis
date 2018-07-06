{ ****************************************************************************** }
{ * fast Histogram of Oriented Gradient support                                * }
{ * create by QQ 600585@qq.com                                                 * }
{ ****************************************************************************** }
{ * https://github.com/PassByYou888/CoreCipher                                 * }
{ * https://github.com/PassByYou888/ZServer4D                                  * }
{ * https://github.com/PassByYou888/zExpression                                * }
{ * https://github.com/PassByYou888/zTranslate                                 * }
{ * https://github.com/PassByYou888/zSound                                     * }
{ * https://github.com/PassByYou888/zAnalysis                                  * }
{ * https://github.com/PassByYou888/zGameWare                                  * }
{ * https://github.com/PassByYou888/zRasterization                             * }
{ ****************************************************************************** }
unit FastHistogramSpace;

interface

{$INCLUDE zDefine.inc}


uses CoreClasses, MemoryRaster, Geometry2DUnit, LearnTypes;

type
  THOGTable = class(TCoreClassObject)
  private type
    TItpRec = packed record
      d: array [0 .. 3] of array [0 .. 1] of TLInt;
      w: array [0 .. 3] of TLInt;
    end;

    PItpRec = ^TItpRec;

    TItpRecArray = array of array of TItpRec;
    PItpRecArray = ^TItpRecArray;
  private
    nOriH, nOriF, cSiz, oriF, oriH: TLInt;
    oriHMatrix: TLIMatrix;
    oriFMatrix: TLIMatrix;
    magMatrix: TLMatrix;
    bwMatrix: TLMatrix;
    itpMatrix: TItpRecArray;
  public
    constructor Create(const numOriHalf, numOriFull, cellSize: TLInt);
    destructor Destroy; override;
  end;

  THOG = class(TCoreClassObject)
  public type
    THRec = packed record
      binH, binF, feat: TLVec;
      nOriH, nOriF, dim: TLInt;
      normH: TLFloat;
    end;

    PHRec      = ^THRec;
    THRecArray = array of array of THRec;
    PHRecArray = ^THRecArray;
  private
    nCX, nCY, cSiz, hSizX, hSizY, width, height: TLInt;
    dx, dy: TLIMatrix;
    procedure initialHist(const imgWidth, imgHeight, numOriHalf, numOriFull, cellSize: TLInt);
    procedure ComputeRGB_Diff(img: TMemoryRaster; const M: PLMatrix);
    procedure ComputeHistogram(const AntiLight: Boolean; const oriH, oriF: PLIMatrix; const BW: PLMatrix; const itp: THOGTable.PItpRecArray);
  public
    ori: THRecArray;
    OriDim: TLInt;
    constructor Create(Table: THOGTable; img: TMemoryRaster);
    constructor CreateAntiLight(Table: THOGTable; img: TMemoryRaster);
    destructor Destroy; override;

    property SizeX: TLInt read hSizX;
    property SizeY: TLInt read hSizY;

    procedure BuildFeatureMatrix(var M: TLMatrix);
    procedure BuildViewer(output: TMemoryRaster);
  end;

procedure TestHOG;

implementation

uses
  Math, DoStatusIO,
{$IFDEF parallel}
{$IFDEF FPC}
  mtprocs,
{$ELSE FPC}
  Threading,
{$ENDIF FPC}
{$ENDIF parallel}
  SyncObjs, Learn;

const
  NUM_DIFF      = 511;
  NUM_DIFF_DIV2 = 255;

constructor THOGTable.Create(const numOriHalf, numOriFull, cellSize: TLInt);
  function arcTanXY(const X, Y: TLFloat): TLInt; inline;
  begin
    Result := Trunc(ArcTan2(Y, X) / pi * 180 + 360);
  end;

var
  intervalFull, intervalHalf: TLFloat;
  Y, X: TLInt;
  d2, nearWeightX, farWeightX, nearWeightY, farWeightY: TLInt;
  cellSize2, w: TLInt;
  p: PItpRec;
begin
  inherited Create;
  nOriH := numOriHalf;
  nOriF := numOriFull;
  cSiz := cellSize;
  oriF := 360;
  oriH := 180;

  SetLength(oriFMatrix, NUM_DIFF, NUM_DIFF);
  SetLength(oriHMatrix, NUM_DIFF, NUM_DIFF);
  SetLength(magMatrix, NUM_DIFF, NUM_DIFF);
  SetLength(itpMatrix, cSiz, cSiz);
  SetLength(bwMatrix, cSiz * cSiz + 1, NUM_DIFF * NUM_DIFF);

  intervalFull := oriF / nOriF;
  intervalHalf := oriH / nOriH;
  for Y := -NUM_DIFF_DIV2 to NUM_DIFF_DIV2 do
    for X := -NUM_DIFF_DIV2 to NUM_DIFF_DIV2 do
      begin
        oriFMatrix[Y + NUM_DIFF_DIV2, X + NUM_DIFF_DIV2] := Trunc(arcTanXY(X, Y) mod oriF / intervalFull);
        oriHMatrix[Y + NUM_DIFF_DIV2, X + NUM_DIFF_DIV2] := Trunc(arcTanXY(X, Y) mod oriH / intervalHalf);
        magMatrix[Y + NUM_DIFF_DIV2, X + NUM_DIFF_DIV2] := Sqrt(X * X + Y * Y);
      end;

  d2 := cSiz div 2;
  for Y := -d2 to d2 - 1 do
    begin
      for X := -d2 to d2 - 1 do
        begin
          p := @itpMatrix[Y + d2, X + d2];
          if (Y < 0) and (X < 0) then
            begin
              nearWeightX := cSiz + X + 1;
              farWeightX := cSiz - nearWeightX;
              nearWeightY := cSiz + Y + 1;
              farWeightY := cSiz - nearWeightY;
              p^.d[0, 0] := 0;
              p^.d[0, 1] := 0;
              p^.w[0] := nearWeightX * nearWeightY;
              p^.d[1, 0] := 0;
              p^.d[1, 1] := -1;
              p^.w[1] := nearWeightX * farWeightY;
              p^.d[2, 0] := -1;
              p^.d[2, 1] := 0;
              p^.w[2] := farWeightX * nearWeightY;
              p^.d[3, 0] := -1;
              p^.d[3, 1] := -1;
              p^.w[3] := farWeightX * farWeightY;
            end
          else if (Y < 0) and (X >= 0) then
            begin
              nearWeightX := cSiz - X;
              farWeightX := cSiz - nearWeightX;
              nearWeightY := cSiz + Y + 1;
              farWeightY := cSiz - nearWeightY;
              p^.d[0, 0] := 0;
              p^.d[0, 1] := 0;
              p^.w[0] := nearWeightX * nearWeightY;
              p^.d[1, 0] := 0;
              p^.d[1, 1] := -1;
              p^.w[1] := nearWeightX * farWeightY;
              p^.d[2, 0] := 1;
              p^.d[2, 1] := 0;
              p^.w[2] := farWeightX * nearWeightY;
              p^.d[3, 0] := 1;
              p^.d[3, 1] := -1;
              p^.w[3] := farWeightX * farWeightY;
            end
          else if (Y >= 0) and (X >= 0) then
            begin
              nearWeightX := cSiz - X;
              farWeightX := cSiz - nearWeightX;
              nearWeightY := cSiz - Y;
              farWeightY := cSiz - nearWeightY;
              p^.d[0, 0] := 0;
              p^.d[0, 1] := 0;
              p^.w[0] := nearWeightX * nearWeightY;
              p^.d[1, 0] := 0;
              p^.d[1, 1] := 1;
              p^.w[1] := nearWeightX * farWeightY;
              p^.d[2, 0] := 1;
              p^.d[2, 1] := 0;
              p^.w[2] := farWeightX * nearWeightY;
              p^.d[3, 0] := 1;
              p^.d[3, 1] := 1;
              p^.w[3] := farWeightX * farWeightY;
            end
          else if (Y >= 0) and (X < 0) then
            begin
              nearWeightX := cSiz + X + 1;
              farWeightX := cSiz - nearWeightX;
              nearWeightY := cSiz - Y;
              farWeightY := cSiz - nearWeightY;
              p^.d[0, 0] := 0;
              p^.d[0, 1] := 0;
              p^.w[0] := nearWeightX * nearWeightY;
              p^.d[1, 0] := 0;
              p^.d[1, 1] := 1;
              p^.w[1] := nearWeightX * farWeightY;
              p^.d[2, 0] := -1;
              p^.d[2, 1] := 0;
              p^.w[2] := farWeightX * nearWeightY;
              p^.d[3, 0] := -1;
              p^.d[3, 1] := 1;
              p^.w[3] := farWeightX * farWeightY;
            end;
        end;
    end;

  cellSize2 := cSiz * cSiz;

  for w := 0 to cellSize2 do
    for Y := -NUM_DIFF_DIV2 to NUM_DIFF_DIV2 do
      for X := -NUM_DIFF_DIV2 to NUM_DIFF_DIV2 do
          bwMatrix[w, (Y + NUM_DIFF_DIV2) * NUM_DIFF + (X + NUM_DIFF_DIV2)] := magMatrix[Y + NUM_DIFF_DIV2, X + NUM_DIFF_DIV2] * w / cellSize2;
end;

destructor THOGTable.Destroy;
begin
  SetLength(oriFMatrix, 0, 0);
  SetLength(oriHMatrix, 0, 0);
  SetLength(magMatrix, 0, 0);
  SetLength(itpMatrix, 0, 0);
  SetLength(bwMatrix, 0, 0);
  inherited Destroy;
end;

procedure THOG.initialHist(const imgWidth, imgHeight, numOriHalf, numOriFull, cellSize: TLInt);
var
  Y, X: TLInt;
begin
  if (imgWidth mod cellSize <> 0) or (imgHeight mod cellSize <> 0) then
    begin
      RaiseInfo('image size is not N*cSiz');
      Exit;
    end;
  cSiz := cellSize;
  nCX := imgWidth div cSiz;
  nCY := imgHeight div cSiz;
  hSizX := nCX + 2;
  hSizY := nCY + 2;
  width := imgWidth;
  height := imgHeight;
  OriDim := 4 + (numOriFull + numOriHalf);

  SetLength(ori, hSizY, hSizX);

  for Y := 0 to hSizY - 1 do
    for X := 0 to hSizX - 1 do
      begin
        SetLength(ori[Y, X].binF, numOriFull);
        SetLength(ori[Y, X].binH, numOriHalf);
        ori[Y, X].dim := OriDim;
        SetLength(ori[Y, X].feat, ori[Y, X].dim);

        ori[Y, X].nOriF := numOriFull;
        ori[Y, X].nOriH := numOriHalf;
        ori[Y, X].normH := 0;
      end;

  SetLength(dx, height, width);
  SetLength(dy, height, width);
end;

procedure THOG.ComputeRGB_Diff(img: TMemoryRaster; const M: PLMatrix);
{$IFDEF parallel}
{$IFDEF FPC}
  procedure Nested_ParallelFor(pass: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
  var
    X, xDiffs, yDiffs, magni: TLInt;
    pcl, pcr, pct, pcb: TRasterColorEntry;
  begin
    for X := 0 to width - 1 do
      begin
        pcl.RGBA := img[X - 1, pass];
        pcr.RGBA := img[X + 1, pass];
        pct.RGBA := img[X, pass - 1];
        pcb.RGBA := img[X, pass + 1];

        dx[pass, X] := pcl.R - pcr.R;
        dy[pass, X] := pct.R - pcb.R;
        magni := Trunc(M^[dy[pass, X] + NUM_DIFF_DIV2, dx[pass, X] + NUM_DIFF_DIV2]);

        xDiffs := pcl.g - pcr.g;
        yDiffs := pct.g - pcb.g;
        if magni < M^[yDiffs + NUM_DIFF_DIV2, xDiffs + NUM_DIFF_DIV2] then
          begin
            dx[pass, X] := xDiffs;
            dy[pass, X] := yDiffs;
          end;

        xDiffs := pcl.b - pcr.b;
        yDiffs := pct.b - pcb.b;
        if magni < M^[yDiffs + NUM_DIFF_DIV2, xDiffs + NUM_DIFF_DIV2] then
          begin
            dx[pass, X] := xDiffs;
            dy[pass, X] := yDiffs;
          end;
      end;
  end;
{$ENDIF FPC}
{$ELSE parallel}
  procedure DoFor;
  var
    pass, X, xDiffs, yDiffs, magni: TLInt;
    pcl, pcr, pct, pcb: TRasterColorEntry;
  begin
    for pass := 0 to height - 1 do
      for X := 0 to width - 1 do
        begin
          pcl.RGBA := img[X - 1, pass];
          pcr.RGBA := img[X + 1, pass];
          pct.RGBA := img[X, pass - 1];
          pcb.RGBA := img[X, pass + 1];

          dx[pass, X] := pcl.R - pcr.R;
          dy[pass, X] := pct.R - pcb.R;
          magni := Trunc(M^[dy[pass, X] + NUM_DIFF_DIV2, dx[pass, X] + NUM_DIFF_DIV2]);

          xDiffs := pcl.g - pcr.g;
          yDiffs := pct.g - pcb.g;
          if magni < M^[yDiffs + NUM_DIFF_DIV2, xDiffs + NUM_DIFF_DIV2] then
            begin
              dx[pass, X] := xDiffs;
              dy[pass, X] := yDiffs;
            end;

          xDiffs := pcl.b - pcr.b;
          yDiffs := pct.b - pcb.b;
          if magni < M^[yDiffs + NUM_DIFF_DIV2, xDiffs + NUM_DIFF_DIV2] then
            begin
              dx[pass, X] := xDiffs;
              dy[pass, X] := yDiffs;
            end;
        end;
  end;
{$ENDIF parallel}

begin
{$IFDEF parallel}
{$IFDEF FPC}
  ProcThreadPool.DoParallelLocalProc(@Nested_ParallelFor, 0, height - 1);
{$ELSE FPC}
  TParallel.for(0, height - 1, procedure(pass: Integer)
    var
      X, xDiffs, yDiffs, magni: TLInt;
      pcl, pcr, pct, pcb: TRasterColorEntry;
    begin
      for X := 0 to width - 1 do
        begin
          pcl.RGBA := img[X - 1, pass];
          pcr.RGBA := img[X + 1, pass];
          pct.RGBA := img[X, pass - 1];
          pcb.RGBA := img[X, pass + 1];

          dx[pass, X] := pcl.R - pcr.R;
          dy[pass, X] := pct.R - pcb.R;
          magni := Trunc(M^[dy[pass, X] + NUM_DIFF_DIV2, dx[pass, X] + NUM_DIFF_DIV2]);

          xDiffs := pcl.g - pcr.g;
          yDiffs := pct.g - pcb.g;
          if magni < M^[yDiffs + NUM_DIFF_DIV2, xDiffs + NUM_DIFF_DIV2] then
            begin
              dx[pass, X] := xDiffs;
              dy[pass, X] := yDiffs;
            end;

          xDiffs := pcl.b - pcr.b;
          yDiffs := pct.b - pcb.b;
          if magni < M^[yDiffs + NUM_DIFF_DIV2, xDiffs + NUM_DIFF_DIV2] then
            begin
              dx[pass, X] := xDiffs;
              dy[pass, X] := yDiffs;
            end;
        end;
    end);
{$ENDIF FPC}
{$ELSE parallel}
  DoFor;
{$ENDIF parallel}
end;

procedure THOG.ComputeHistogram(const AntiLight: Boolean; const oriH, oriF: PLIMatrix; const BW: PLMatrix; const itp: THOGTable.PItpRecArray);
var
  setoff: TLInt;

  {$IFDEF parallel}
  {$IFDEF FPC}
    procedure Nested_ParallelFor_Weight(Y: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
    var
      X, n: TLInt;
      xDiff, yDiff, oriIdxFull, oriIdxHalf: TLInt;
      cellCoorX, cellCoorY, cellY, cellX, dstCellCoorX, dstCellCoorY, Weight: TLInt;
      weightedBinValue: TLFloat;
    begin
      for X := 0 to width - 1 do
        begin
          xDiff := dx[Y, X];
          yDiff := dy[Y, X];
          oriIdxFull := oriF^[yDiff + NUM_DIFF_DIV2, xDiff + NUM_DIFF_DIV2];
          oriIdxHalf := oriH^[yDiff + NUM_DIFF_DIV2, xDiff + NUM_DIFF_DIV2];
          cellCoorY := Y div cSiz + 1;
          cellCoorX := X div cSiz + 1;
          cellY := Y - (cellCoorY - 1) * cSiz;
          cellX := X - (cellCoorX - 1) * cSiz;

          for n := 0 to 3 do
            begin
              dstCellCoorY := cellCoorY + itp^[cellY, cellX].d[n, 1];
              dstCellCoorX := cellCoorX + itp^[cellY, cellX].d[n, 0];
              Weight := itp^[cellY, cellX].w[n];
              weightedBinValue := BW^[Weight, (yDiff + NUM_DIFF_DIV2) * NUM_DIFF + (xDiff + NUM_DIFF_DIV2)];
              LAdd(ori[dstCellCoorY, dstCellCoorX].binF[oriIdxFull], weightedBinValue);
              LAdd(ori[dstCellCoorY, dstCellCoorX].binH[oriIdxHalf], weightedBinValue);
            end;
        end;
    end;
    procedure Nested_ParallelFor_normH(cellY: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
    var
      cellX, n: TLInt;
      HP: PHRec;
    begin
      for cellX := 0 to hSizX - 1 do
        begin
          HP := @ori[cellY, cellX];
          for n := 0 to HP^.nOriH - 1 do
              LAdd(HP^.normH, HP^.binH[n mod HP^.nOriF] * HP^.binH[n mod HP^.nOriF]);
        end;
    end;
    procedure Nested_ParallelFor_Ori(cellY: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
    var
      cellX, n: TLInt;
      HP: PHRec;
      NW, ns: array [0 .. 3] of TLFloat;
      Sum: TLFloat;
    begin
      for cellX := 1 to nCX do
        begin
          HP := @ori[cellY, cellX];

          NW[0] := Learn.AP_Sqr(HP^.normH + ori[cellY - 1, cellX].normH + ori[cellY, cellX - 1].normH + ori[cellY - 1, cellX - 1].normH);
          NW[1] := Learn.AP_Sqr(HP^.normH + ori[cellY + 1, cellX].normH + ori[cellY, cellX - 1].normH + ori[cellY + 1, cellX - 1].normH);
          NW[2] := Learn.AP_Sqr(HP^.normH + ori[cellY + 1, cellX].normH + ori[cellY, cellX + 1].normH + ori[cellY + 1, cellX + 1].normH);
          NW[3] := Learn.AP_Sqr(HP^.normH + ori[cellY - 1, cellX].normH + ori[cellY, cellX + 1].normH + ori[cellY - 1, cellX + 1].normH);

          for n := 0 to HP^.nOriH - 1 do
            begin
              ns[0] := LSafeDivF(HP^.binH[n], NW[0]);
              ns[1] := LSafeDivF(HP^.binH[n], NW[1]);
              ns[2] := LSafeDivF(HP^.binH[n], NW[2]);
              ns[3] := LSafeDivF(HP^.binH[n], NW[3]);
              HP^.feat[n] := ns[0] + ns[1] + ns[2] + ns[3];
              LAdd(HP^.feat[setoff + 0], ns[0]);
              LAdd(HP^.feat[setoff + 1], ns[1]);
              LAdd(HP^.feat[setoff + 2], ns[2]);
              LAdd(HP^.feat[setoff + 3], ns[3]);
            end;

          for n := 0 to HP^.nOriF - 1 do
            begin
              ns[0] := LSafeDivF(HP^.binF[n], NW[0]);
              ns[1] := LSafeDivF(HP^.binF[n], NW[1]);
              ns[2] := LSafeDivF(HP^.binF[n], NW[2]);
              ns[3] := LSafeDivF(HP^.binF[n], NW[3]);
              HP^.feat[HP^.nOriH + n] := ns[0] + ns[1] + ns[2] + ns[3];
              LAdd(HP^.feat[setoff + 0], ns[0]);
              LAdd(HP^.feat[setoff + 1], ns[1]);
              LAdd(HP^.feat[setoff + 2], ns[2]);
              LAdd(HP^.feat[setoff + 3], ns[3]);
            end;

          if AntiLight then
            begin
              Sum := 0;
              for n := 0 to length(HP^.feat) - 1 do
                  LAdd(Sum, HP^.feat[n]);
              for n := 0 to length(HP^.feat) - 1 do
                  HP^.feat[n] := Learn.AP_Sqr(LSafeDivF(HP^.feat[n], Sum));
            end;
        end;
    end;
  {$ENDIF FPC}
  {$ELSE parallel}
    procedure DoFor_Weight;
    var
      Y, X, n: TLInt;
      xDiff, yDiff, oriIdxFull, oriIdxHalf: TLInt;
      cellCoorX, cellCoorY, cellY, cellX, dstCellCoorX, dstCellCoorY, Weight: TLInt;
      weightedBinValue: TLFloat;
    begin
      for Y := 0 to height - 1 do
        for X := 0 to width - 1 do
          begin
            xDiff := dx[Y, X];
            yDiff := dy[Y, X];
            oriIdxFull := oriF^[yDiff + NUM_DIFF_DIV2, xDiff + NUM_DIFF_DIV2];
            oriIdxHalf := oriH^[yDiff + NUM_DIFF_DIV2, xDiff + NUM_DIFF_DIV2];
            cellCoorY := Y div cSiz + 1;
            cellCoorX := X div cSiz + 1;
            cellY := Y - (cellCoorY - 1) * cSiz;
            cellX := X - (cellCoorX - 1) * cSiz;

            for n := 0 to 3 do
              begin
                dstCellCoorY := cellCoorY + itp^[cellY, cellX].d[n, 1];
                dstCellCoorX := cellCoorX + itp^[cellY, cellX].d[n, 0];
                Weight := itp^[cellY, cellX].w[n];
                weightedBinValue := BW^[Weight, (yDiff + NUM_DIFF_DIV2) * NUM_DIFF + (xDiff + NUM_DIFF_DIV2)];
                LAdd(ori[dstCellCoorY, dstCellCoorX].binF[oriIdxFull], weightedBinValue);
                LAdd(ori[dstCellCoorY, dstCellCoorX].binH[oriIdxHalf], weightedBinValue);
              end;
          end;
    end;
    procedure DoFor_normH;
    var
      cellY, cellX, n: TLInt;
      HP: PHRec;
    begin
      for cellY := 0 to hSizY - 1 do
        for cellX := 0 to hSizX - 1 do
          begin
            HP := @ori[cellY, cellX];
            for n := 0 to HP^.nOriH - 1 do
                LAdd(HP^.normH, HP^.binH[n mod HP^.nOriF] * HP^.binH[n mod HP^.nOriF]);
          end;
    end;
    procedure DoFor_Ori;
    var
      cellY, cellX, n: TLInt;
      HP: PHRec;
      NW, ns: array [0 .. 3] of TLFloat;
      Sum: TLFloat;
    begin
      for cellY := 1 to nCY do
        for cellX := 1 to nCX do
          begin
            HP := @ori[cellY, cellX];

            NW[0] := Learn.AP_Sqr(HP^.normH + ori[cellY - 1, cellX].normH + ori[cellY, cellX - 1].normH + ori[cellY - 1, cellX - 1].normH);
            NW[1] := Learn.AP_Sqr(HP^.normH + ori[cellY + 1, cellX].normH + ori[cellY, cellX - 1].normH + ori[cellY + 1, cellX - 1].normH);
            NW[2] := Learn.AP_Sqr(HP^.normH + ori[cellY + 1, cellX].normH + ori[cellY, cellX + 1].normH + ori[cellY + 1, cellX + 1].normH);
            NW[3] := Learn.AP_Sqr(HP^.normH + ori[cellY - 1, cellX].normH + ori[cellY, cellX + 1].normH + ori[cellY - 1, cellX + 1].normH);

            for n := 0 to HP^.nOriH - 1 do
              begin
                ns[0] := LSafeDivF(HP^.binH[n], NW[0]);
                ns[1] := LSafeDivF(HP^.binH[n], NW[1]);
                ns[2] := LSafeDivF(HP^.binH[n], NW[2]);
                ns[3] := LSafeDivF(HP^.binH[n], NW[3]);
                HP^.feat[n] := ns[0] + ns[1] + ns[2] + ns[3];
                LAdd(HP^.feat[setoff + 0], ns[0]);
                LAdd(HP^.feat[setoff + 1], ns[1]);
                LAdd(HP^.feat[setoff + 2], ns[2]);
                LAdd(HP^.feat[setoff + 3], ns[3]);
              end;

            for n := 0 to HP^.nOriF - 1 do
              begin
                ns[0] := LSafeDivF(HP^.binF[n], NW[0]);
                ns[1] := LSafeDivF(HP^.binF[n], NW[1]);
                ns[2] := LSafeDivF(HP^.binF[n], NW[2]);
                ns[3] := LSafeDivF(HP^.binF[n], NW[3]);
                HP^.feat[HP^.nOriH + n] := ns[0] + ns[1] + ns[2] + ns[3];
                LAdd(HP^.feat[setoff + 0], ns[0]);
                LAdd(HP^.feat[setoff + 1], ns[1]);
                LAdd(HP^.feat[setoff + 2], ns[2]);
                LAdd(HP^.feat[setoff + 3], ns[3]);
              end;

            if AntiLight then
              begin
                Sum := 0;
                for n := 0 to length(HP^.feat) - 1 do
                    LAdd(Sum, HP^.feat[n]);
                for n := 0 to length(HP^.feat) - 1 do
                    HP^.feat[n] := Learn.AP_Sqr(LSafeDivF(HP^.feat[n], Sum));
              end;
          end;
    end;
  {$ENDIF parallel}

begin
  setoff := ori[0, 0].nOriH + ori[0, 0].nOriF;

{$IFDEF parallel}
{$IFDEF FPC}
  ProcThreadPool.DoParallelLocalProc(@Nested_ParallelFor_Weight, 0, height - 1);
  ProcThreadPool.DoParallelLocalProc(@Nested_ParallelFor_normH, 0, hSizY - 1);
  ProcThreadPool.DoParallelLocalProc(@Nested_ParallelFor_Ori, 1, nCY - 1);
{$ELSE FPC}
  TParallel.for(0, height - 1, procedure(Y: Integer)
    var
      X, n: TLInt;
      xDiff, yDiff, oriIdxFull, oriIdxHalf: TLInt;
      cellCoorX, cellCoorY, cellY, cellX, dstCellCoorX, dstCellCoorY, Weight: TLInt;
      weightedBinValue: TLFloat;
    begin
      for X := 0 to width - 1 do
        begin
          xDiff := dx[Y, X];
          yDiff := dy[Y, X];
          oriIdxFull := oriF^[yDiff + NUM_DIFF_DIV2, xDiff + NUM_DIFF_DIV2];
          oriIdxHalf := oriH^[yDiff + NUM_DIFF_DIV2, xDiff + NUM_DIFF_DIV2];
          cellCoorY := Y div cSiz + 1;
          cellCoorX := X div cSiz + 1;
          cellY := Y - (cellCoorY - 1) * cSiz;
          cellX := X - (cellCoorX - 1) * cSiz;

          for n := 0 to 3 do
            begin
              dstCellCoorY := cellCoorY + itp^[cellY, cellX].d[n, 1];
              dstCellCoorX := cellCoorX + itp^[cellY, cellX].d[n, 0];
              Weight := itp^[cellY, cellX].w[n];
              weightedBinValue := BW^[Weight, (yDiff + NUM_DIFF_DIV2) * NUM_DIFF + (xDiff + NUM_DIFF_DIV2)];
              LAdd(ori[dstCellCoorY, dstCellCoorX].binF[oriIdxFull], weightedBinValue);
              LAdd(ori[dstCellCoorY, dstCellCoorX].binH[oriIdxHalf], weightedBinValue);
            end;
        end;
    end);
  TParallel.for(0, hSizY - 1, procedure(cellY: Integer)
    var
      cellX, n: TLInt;
      HP: PHRec;
    begin
      for cellX := 0 to hSizX - 1 do
        begin
          HP := @ori[cellY, cellX];
          for n := 0 to HP^.nOriH - 1 do
              LAdd(HP^.normH, HP^.binH[n mod HP^.nOriF] * HP^.binH[n mod HP^.nOriF]);
        end;
    end);
  TParallel.for(1, nCY - 1, procedure(cellY: Integer)
    var
      cellX, n: TLInt;
      HP: PHRec;
      NW, ns: array [0 .. 3] of TLFloat;
      Sum: TLFloat;
    begin
      for cellX := 1 to nCX do
        begin
          HP := @ori[cellY, cellX];

          NW[0] := Learn.AP_Sqr(HP^.normH + ori[cellY - 1, cellX].normH + ori[cellY, cellX - 1].normH + ori[cellY - 1, cellX - 1].normH);
          NW[1] := Learn.AP_Sqr(HP^.normH + ori[cellY + 1, cellX].normH + ori[cellY, cellX - 1].normH + ori[cellY + 1, cellX - 1].normH);
          NW[2] := Learn.AP_Sqr(HP^.normH + ori[cellY + 1, cellX].normH + ori[cellY, cellX + 1].normH + ori[cellY + 1, cellX + 1].normH);
          NW[3] := Learn.AP_Sqr(HP^.normH + ori[cellY - 1, cellX].normH + ori[cellY, cellX + 1].normH + ori[cellY - 1, cellX + 1].normH);

          for n := 0 to HP^.nOriH - 1 do
            begin
              ns[0] := LSafeDivF(HP^.binH[n], NW[0]);
              ns[1] := LSafeDivF(HP^.binH[n], NW[1]);
              ns[2] := LSafeDivF(HP^.binH[n], NW[2]);
              ns[3] := LSafeDivF(HP^.binH[n], NW[3]);
              HP^.feat[n] := ns[0] + ns[1] + ns[2] + ns[3];
              LAdd(HP^.feat[setoff + 0], ns[0]);
              LAdd(HP^.feat[setoff + 1], ns[1]);
              LAdd(HP^.feat[setoff + 2], ns[2]);
              LAdd(HP^.feat[setoff + 3], ns[3]);
            end;

          for n := 0 to HP^.nOriF - 1 do
            begin
              ns[0] := LSafeDivF(HP^.binF[n], NW[0]);
              ns[1] := LSafeDivF(HP^.binF[n], NW[1]);
              ns[2] := LSafeDivF(HP^.binF[n], NW[2]);
              ns[3] := LSafeDivF(HP^.binF[n], NW[3]);
              HP^.feat[HP^.nOriH + n] := ns[0] + ns[1] + ns[2] + ns[3];
              LAdd(HP^.feat[setoff + 0], ns[0]);
              LAdd(HP^.feat[setoff + 1], ns[1]);
              LAdd(HP^.feat[setoff + 2], ns[2]);
              LAdd(HP^.feat[setoff + 3], ns[3]);
            end;

          if AntiLight then
            begin
              Sum := 0;
              for n := 0 to length(HP^.feat) - 1 do
                  LAdd(Sum, HP^.feat[n]);
              for n := 0 to length(HP^.feat) - 1 do
                  HP^.feat[n] := Learn.AP_Sqr(LSafeDivF(HP^.feat[n], Sum));
            end;
        end;
    end);
{$ENDIF FPC}
{$ELSE parallel}
  DoFor_Weight;
  DoFor_normH;
  DoFor_Ori;
{$ENDIF parallel}
end;

constructor THOG.Create(Table: THOGTable; img: TMemoryRaster);
begin
  inherited Create;
  initialHist(
    img.width - img.width mod Table.cSiz,
    img.height - img.height mod Table.cSiz,
    Table.nOriH, Table.nOriF, Table.cSiz);
  ComputeRGB_Diff(img, @Table.magMatrix);
  ComputeHistogram(False, @Table.oriHMatrix, @Table.oriFMatrix, @Table.bwMatrix, @Table.itpMatrix);
end;

constructor THOG.CreateAntiLight(Table: THOGTable; img: TMemoryRaster);
begin
  inherited Create;
  initialHist(
    img.width - img.width mod Table.cSiz,
    img.height - img.height mod Table.cSiz,
    Table.nOriH, Table.nOriF, Table.cSiz);
  ComputeRGB_Diff(img, @Table.magMatrix);
  ComputeHistogram(True, @Table.oriHMatrix, @Table.oriFMatrix, @Table.bwMatrix, @Table.itpMatrix);
end;

destructor THOG.Destroy;
var
  Y, X: TLInt;
  HP: PHRec;
begin
  for Y := 0 to length(ori) - 1 do
    for X := 0 to length(ori[Y]) - 1 do
      begin
        HP := @ori[Y, X];
        SetLength(HP^.binH, 0);
        SetLength(HP^.binF, 0);
        SetLength(HP^.feat, 0);
      end;
  SetLength(ori, 0, 0);
  SetLength(dx, 0, 0);
  SetLength(dy, 0, 0);
  inherited Destroy;
end;

procedure THOG.BuildFeatureMatrix(var M: TLMatrix);
var
  i, J, n: TLInt;
  p: PHRec;
begin
  SetLength(M, hSizY, hSizX * OriDim);
  for J := 0 to length(ori) - 1 do
    for i := 0 to length(ori[J]) - 1 do
      begin
        p := @ori[J, i];
        for n := 0 to OriDim - 1 do
            M[J, i + n] := p^.feat[n];
      end;
end;

procedure THOG.BuildViewer(output: TMemoryRaster);
var
  bp, EP, cp, p: TVec2;
  numOri, MaxIdx: TLInt;
  MaxValue: TLInt;
  pixValue: TLInt;
  cellY, cellX, n: TLInt;
  maxBinValue: TLFloat;
begin
  output.SetSize(cSiz * nCX, cSiz * nCY, RasterColorF(0, 0, 0, 0));

  maxBinValue := -Learn.MaxRealNumber;

  for cellY := 1 to nCY do
    for cellX := 1 to nCX do
      begin
        numOri := ori[cellY, cellX].nOriF;
        for n := 0 to numOri - 1 do
            maxBinValue := IfThen(ori[cellY, cellX].binF[n] > maxBinValue, ori[cellY, cellX].binF[n], maxBinValue);
      end;

  for cellY := 1 to nCY do
    begin
      cp[1] := (cellY - 1) * cSiz + cellY / 2;
      for cellX := 1 to nCX do
        begin
          numOri := ori[cellY, cellX].nOriF;
          MaxIdx := 0;
          MaxValue := Trunc(ori[cellY, cellX].binF[0] / maxBinValue * 4096);
          cp[0] := (cellX - 1) * cSiz + cellX / 2;
          for n := 0 to numOri - 1 do
            begin
              pixValue := Trunc(ori[cellY, cellX].binF[n] / maxBinValue * 4096);
              if pixValue > MaxValue then
                begin
                  MaxValue := pixValue;
                  MaxIdx := n;
                end
              else
                begin
                  pixValue := LClamp(pixValue, 0, 255);
                  p := PointRotation(cp, cSiz * 0.5, (MaxIdx * (360 / numOri)));
                  output.LineF(PointLerpTo(p, cp, cSiz), p, RasterColor(pixValue, 0, 0, pixValue), True);
                end;
            end;
        end;
    end;
end;

procedure TestHOG;
var
  tab: THOGTable;
  HOG: THOG;
  img: TMemoryRaster;
  view: TMemoryRaster;
  i: TLInt;
  T: TTimeTick;
  M: TLMatrix;
begin
  img := NewRasterFromFile('c:\1.bmp');

  tab := THOGTable.Create(18, 36, 16);

  // t := GetTimeTick;
  // for i := 1 to 100 do
  // begin
  // hog := THOG.CreateAntiLight(tab, img);
  // disposeObject(hog);
  // end;
  // DoStatus('%dms', [GetTimeTick - t]);

  HOG := THOG.CreateAntiLight(tab, img);

  view := TMemoryRaster.Create;
  view.OpenAgg;
  HOG.BuildViewer(view);
  img.Draw(-8, -8, view);
  img.SaveToFile('c:\view.bmp');
  DisposeObject(view);

  DisposeObject(tab);
  DisposeObject(HOG);
  DisposeObject(img);
end;

end. 
