unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ImgList, XPMan, ComCtrls, ExtCtrls, ShellApi, Spin,
  Buttons, DateUtils, ArgumentParser;

type
  TForm1 = class(TForm)
    ListView1: TListView;
    XPManifest1: TXPManifest;
    ImageList1: TImageList;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Image1: TImage;
    ListView2: TListView;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    ImageList2: TImageList;
    ImageList3: TImageList;
    Label6: TLabel;
    Label7: TLabel;
    Button4: TButton;
    ProgressBar1: TProgressBar;
    ComboBox1: TComboBox;
    Label8: TLabel;
    Label9: TLabel;
    Edit1: TEdit;
    GroupBox1: TGroupBox;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    GroupBox2: TGroupBox;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    Edit2: TEdit;
    Label10: TLabel;
    BitBtn1: TBitBtn;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    CheckBox5: TCheckBox;
    Button5: TButton;
    CheckBox6: TCheckBox;
    CheckBox7: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ListView1SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure ListView2SelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure ComboBox1Select(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure RadioButton1Click(Sender: TObject);
    procedure RadioButton2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CheckBox2Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure CheckBox3Click(Sender: TObject);
    procedure CheckBox4Click(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure CheckBox5Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button5Click(Sender: TObject);
    procedure CheckBox7Click(Sender: TObject);
    procedure CheckBox6Click(Sender: TObject);
  private
    procedure FillDriveTable;
    procedure CalculateStandardBlockSize;
    { Private declarations }
  public
    { Public declarations }
  end;

type
  TZgErasingUnit = class(TThread)
  private
      errtype:      integer;
      value:      integer;
      CurrentBlock: Int64;
      BlocksCount:  Int64;
      procedure BlockControls;
      procedure UnblockControls;
      procedure ReportCurrentProgress;
      procedure ReportBlocksCount;
      procedure ReportOperationComplete;
      procedure ReportError;
      procedure ResetProgress;
      procedure TurnStartToStop;
      procedure TurnStopToStart;
      procedure UpdateDriveList;
  public
      procedure Execute; override;
end;

type
  PTZgHandleListI = ^TZgHandleListI;
  TZgHandleListI = record
    value:  THandle;
    index:  integer;
    next:   PTZgHandleListI;
  end;

type
  TZgHandleList = class
  private
    hcount: integer;
    list: PTZgHandleListI;
    function GetPointer(index: integer): PTZgHandleListI;
    function GetValue(index: integer): THandle;
    procedure SetValue(index: integer; const H: THandle);
    function GetCount: integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(H: THandle);
    procedure Clear;
    procedure Delete(index: integer);
    procedure Free;
    function IndexOf(entry: THandle): integer;
    property Count: integer read GetCount;
    property Handles[index: integer]: THandle read GetValue write SetValue;
end;

//****************************************************************
type
  NTSTATUS = longint;
//****************************************************************

type
  STORAGE_DEVICE_NUMBER = packed record
    DeviceType:       DWORD;
    DeviceNumber:     DWORD;
    PartitionNumber:  DWORD;
  end;
  PSTORAGE_DEVICE_NUMBER = ^STORAGE_DEVICE_NUMBER;

type
  PGET_LENGTH_INFORMATION = ^GET_LENGTH_INFORMATION;
  GET_LENGTH_INFORMATION = packed record
    Length: LARGE_INTEGER;
  end;

type
  PDISK_GEOMETRY = ^DISK_GEOMETRY;
  DISK_GEOMETRY = packed record
    Cylinders:          LARGE_INTEGER;
    MediaType:          DWORD;
    TracksPerCylinder:  DWORD;
    SectorsPerTrack:    DWORD;
    BytesPerSector:     DWORD;
end;

type
  PZG_GPT_ENTRY = ^ZG_GPT_ENTRY;
  ZG_GPT_ENTRY = packed record
    PartitionTypeGUID:    array[0..15] of BYTE;
    UniquePartitionGUID:  array[0..15] of BYTE;
    StartingLBA:          Int64;
    EndingLBA:            Int64;
    Attributes:           Int64;
    PartitionName:        array[0..35] of WideChar;
  end;

const
  FSCTL_LOCK_VOLUME = $90018;
  FSCTL_DISMOUNT_VOLUME = $90020;

  //IOCTL_STORAGE_QUERY_PROPERTY = $2d1400;
  IOCTL_STORAGE_GET_DEVICE_NUMBER = $2d1080;
  IOCTL_DISK_GET_LENGTH_INFO = $7405c;
  IOCTL_DISK_GET_DRIVE_GEOMETRY = $70000;
  IOCTL_DISK_UPDATE_PROPERTIES = $70140;
  ZG_ERR_STRING = '###error###';
  ZG_NA_STRING = 'N/A';
  ZG_ERR_DWORD = 4294967295;

  //TB_BASE = 1024 {bytes} * 1024 {KB} * 1024 {MB} * 1024 {GB};
  GB_BASE = 1024 {bytes} * 1024 {KB} * 1024 {MB};
  MB_BASE = 1024 {bytes} * 1024 {KB};
  KB_BASE = 1024 {bytes};

  PDRIVE_BASE = '\\.\PhysicalDrive';
  ASYSDV_MSG = '###NotALocalDriveOnThisPC!###';
  ADRIVE_MSG = '###NotALocalDriveOnThisPC!###';

  ZG_PARTSTYLE_UNKNOWN = 3;
  ZG_PARTSTYLE_GPT = 2;
  ZG_PARTSTYLE_MBR = 1;
  ZG_PARTSTYLE_RAW = 0;
  ZG_PARTSTYLE_ERR = 4294967295; //Just max DWORD value, also equals -1

  ZG_PARTSTYLE_UNKNOWN_STR = 'Unknown';
  ZG_PARTSTYLE_GPT_STR = 'GUID Partition Table (GPT)';
  ZG_PARTSTYLE_MBR_STR = 'Master Boot Record (MBR)';
  ZG_PARTSTYLE_RAW_STR = 'RAW';
  ZG_PARTSTYLE_ERR_STR = 'Error during get drive partition style information';
  ZG_PARTSTYLE_NA_STR = 'N/A';

  ZG_SELDRIVE_BASE = 'Selected Drive:';
  ZG_SELDRIVE_NONSELECTED = 'Not selected';
  ZG_PARTSTYLE_BASE = 'Partition Style:';

  FILE_DEVICE_DISK = $7;
  FILE_DEVICE_VIRTUAL_DISK = $24;

  ZG_CURRBLOCK_STR = 'Current block:';
  ZG_FULLBLOCK_STR = 'Total blocks count:';

  ZG_CUSTOMBLOCKSIZE_DEFAULT = 16777216;

  ZG_4KBBLOCKSIZE = 4096;
  ZG_8KBBLOCKSIZE = 8192;
  ZG_16KBBLOCKSIZE = 16384;
  ZG_32KBBLOCKSIZE = 32768;
  ZG_64KBBLOCKSIZE = 65536;
  ZG_128KBBLOCKSIZE = 131072;
  ZG_256KBBLOCKSIZE = 262144;
  ZG_512KBBLOCKSIZE = 524288;
  ZG_1MBBLOCKSIZE = 1048576;
  ZG_2MBBLOCKSIZE = 2097152;
  ZG_4MBBLOCKSIZE = 4194304;
  ZG_8MBBLOCKSIZE = 8388608;
  ZG_16MBBLOCKSIZE = 16777216;
  ZG_32MBBLOCKSIZE = 33554432;
  ZG_64MBBLOCKSIZE = 67108864;
  ZG_128MBBLOCKSIZE = 134217728;

  ZG_MAXBLOCKSIZE = 1073741824;

  ZG_STARTBUTTON_START = 'Start';
  ZG_STARTBUTTON_STOP = 'Stop';

  ZG_CONFIRMERASINGMSG = 'Do you really want to ERASE selected drive? Even you press stop button, changes anyway will be applied to selected drive. But you can anyway press "STOP" button to halt current operation.';
  ZG_CANCELERASINGMSG = 'Do you really want to STOP current operation? You''ll need to start again to complete current operation.';

  SAD_DEVELOPER_MESSAGE = 'Help file not found!';

  MIN_ALLOWED_RESX = 650;
  MIN_ALLOWED_RESY = 650;

  UPSCALE_MINX = 1024;
  UPSCALE_MINY = 768;

  ZG_FAILUPSCALEMSG = 'HEPE failed to upscale your screen resolution! Launch HEPE with flag /dontcheckres if you want to launch HEPE anyway!';
  ZG_RESNOTALLOWEDMSG = 'HEPE detected that your screen resolution is not match minimal allowed values. Use flag /dontcheckres to not check resolution or flag /upscaletominres to try upscaling your screen resolution to allowed value!';

  ShutdownNoReboot = 0;
  ShutdownReboot = 1;
  ShutdownPowerOff = 2;

  //if you met computer with more count of partitions,
  //please link with me;
  ZG_HV_MAX_COUNT = 128;

  //new in 1.3.2 and newer - version constants
  HEPE_VERSION = '1.3.2';
  HEPE_VERSION_LOG_NAME = 'hepe132.log';
var
  Form1:              TForm1;
  OpStarted:          boolean;
  BlockSize:          ULONG;
  CurrentPos:         Int64;
  BlocksCount:        Int64;
  CancellationMarker: boolean;
  ZgEraser:           TZgErasingUnit;
  BlockPartList:      TStringList;
  SelDriveIndex:      integer;
  SOEFlag:            boolean;
  SOLFlag:            boolean;
  CAOFlag:            boolean;
  SilentFlag:         boolean;
  SOLLocation:        string;
  isopsuccessful:     boolean;
  shutdownflag:       boolean;
  needtopmost:        boolean;
  dontforceshutdown:  boolean;
  dsvflag:            boolean;
  dlvflag:            boolean;
  hdvflag:            boolean;
  hdvcount:           integer;
  hdverrflag:         boolean;

function NtShutdownSystem(SHUTDOWN_ACTION: DWORD): DWORD; stdcall;
      external 'ntdll.dll';

function DeleteVolumeMountPointA(MPoint: PAnsiChar): boolean stdcall;
      external 'kernel32.dll';

function ZgFileSeek(target: THandle; distance: Int64; MoveMethod: DWORD):
      Int64 cdecl; external 'HEPEH.dll';
function ZgGetDriveVendor(Drive: PAnsiChar; outbuffer: PAnsiChar;
      outbufferlen: DWORD): boolean cdecl; external 'HEPEH.dll';
function ZgGetDriveModel(Drive: PAnsiChar; outbuffer: PAnsiChar;
      outbufferlen: DWORD): boolean cdecl; external 'HEPEH.dll';
function ZgGetDriveRevision(Drive: PAnsiChar; outbuffer: PAnsiChar;
      outbufferlen: DWORD): boolean cdecl; external 'HEPEH.dll';
function ZgGetSymLinkTarget(filename: PAnsiChar; outbuffer: PAnsiChar;
      outbufferlen: DWORD): boolean cdecl; external 'HEPEH.dll';
function ZgGetPartitionStyleInformation(DrivePath: PCHAR): DWORD cdecl;
      external 'HEPEH.dll';
function ZgIsDiskGPT(DiskName: PAnsiChar): boolean cdecl;
      external 'HEPEH.dll';
function ZgQueryGPTPartitionsCount(DiskName: PAnsiChar): DWORD cdecl;
      external 'HEPEH.dll';
function ZgQueryGPTPartitionInformationByIndex(DiskName: PCHAR;
      entry: PZG_GPT_ENTRY; index: DWORD): boolean cdecl; external 'HEPEH.dll';
function ZgGetDriveSectorSize(DiskName: PCHAR): DWORD cdecl;
      external 'HEPEH.dll';
function ZgWriteZeroBlockToTarget(target: THandle; blocksize: ULONG):
      boolean cdecl; external 'HEPEH.dll';
function ZgWriteZeroBlockToTarget2(target: THandle; blocksize: ULONG):
      NTSTATUS cdecl; external 'HEPEH.dll';

//ZG functions that are realized in this module
procedure ZgMStoMSSMH(MsI: Int64; var Ms, S, M, H: Int64);
function ZgMStoString(MS: Int64): string;
function ZgSorMtoString(SorM: Int64): string;
function ZgHToString(H: Int64): string;
function ZgGUIDToString(guid: array of BYTE): string;
function ZgGetDrivePartStyleStr(DriveName: string): string;
function ZgGetVolumeLabel(RootChar: char): string;
procedure ZgGetICO(fl: string; var ib: TBitMap);
function ZgGetDiskId(partname: PWCHAR): integer;
function ZgGetPartitionId(partname: PWCHAR): integer;
function ZgGetDiskTypeId(partname: PWCHAR): integer;
function ZgGetDriveInfoStr(DrivePath: PWCHAR): string;
function ZgGetDriveSizeInBytes(DrivePath: PCHAR): Int64;
function ZgGetDriveSizeStr(DrivePath: PWCHAR): string;
function ZgGetDriveSizeByLBAStr(StartLBA: Int64; EndLBA: Int64; SectorSize: DWORD): string;
function ZgGetSystemDriveExclusionStr: string;
function ZgGetApplicationDriveExclusionStr: string;
function ZgGetLogFileDriveExclusionStr(logfile: string): string;
function ZgGetPhysicalDriveList: TStringList;
function ZgGetIndexFromPDPath(PDPath: string): string;
function ZgTryStrToDWORD(const S: string; out Value: DWORD): Boolean;
function ZgAdjustProcessPrivilegeByStr(Process: THandle; PrivName: string): boolean;
function ZgBuildBlockPartList2(driveindex: integer; logdata: TStringList): TStringList;
procedure ZgShutdownWindows;

implementation

uses Math;

{$R *.dfm}

procedure ZgMStoMSSMH(MsI: Int64; var Ms, S, M, H: Int64);
begin
  Ms:=MsI mod 1000;
  S:=MsI div 1000 mod 60;
  M:=MsI div 1000 div 60 mod 60;
  H:=MsI div 1000 div 60 div 60;
end;

function ZgMStoString(MS: Int64): string;
var
  tmpMS: Int64;
begin
  if (MS >= 1000) then
  begin
    tmpMS:=MS mod 1000;

    if (tmpMS < 100) then
    begin
      result:='0' + inttostr(tmpMS);
      exit;
    end;

    if (tmpMS < 10) then
    begin
      result:='00' + inttostr(tmpMS);
      exit;
    end;

    result:=inttostr(tmpMS);
    exit;
  end;

  if (MS < 100) then
  begin
    result:='0' + inttostr(MS);
    exit;
  end;

  if (MS < 10) then
  begin
    result:='00' + inttostr(MS);
    exit;
  end;

  result:=inttostr(MS);
end;

function ZgSorMtoString(SorM: Int64): string;
var
  tmpSorM: Int64;
begin
  if (SorM >= 60) then
  begin
    tmpSorM := SorM mod 60;

    if (tmpSorM < 10) then
    begin
      result:='0' + inttostr(tmpSorM);
      exit;
    end;

    result:=inttostr(tmpSorM);
    exit;
  end;

  if (SorM < 10) then
  begin
    result:='0' + inttostr(SorM);
    exit;
  end;

  result:=inttostr(SorM);
end;

function ZgHToString(H: Int64): string;
begin
  if (H < 10) then
  begin
    result:='0' + inttostr(H);
    exit;
  end;

  result:=inttostr(H);
end;

function ZgGUIDToString(guid: array of BYTE): string;
begin
  result:='{' +
          inttohex(guid[3], 2) +
          inttohex(guid[2], 2) +
          inttohex(guid[1], 2) +
          inttohex(guid[0], 2) +
          '-' +
          inttohex(guid[5], 2) +
          inttohex(guid[4], 2) +
          '-' +
          inttohex(guid[7], 2) +
          inttohex(guid[6], 2) +
          '-' +
          inttohex(guid[8], 2) +
          inttohex(guid[9], 2) +
          '-' +
          inttohex(guid[10], 2) +
          inttohex(guid[11], 2) +
          inttohex(guid[12], 2) +
          inttohex(guid[13], 2) +
          inttohex(guid[14], 2) +
          inttohex(guid[15], 2) +
          '}';
end;

function ZgGetDrivePartStyleStr(DriveName: string): string;
var
  dResult: DWORD;
begin
  dResult:=ZgGetPartitionStyleInformation(PAnsiChar(DriveName));
  case dResult of
    ZG_PARTSTYLE_UNKNOWN: result:=ZG_PARTSTYLE_UNKNOWN_STR;
    ZG_PARTSTYLE_GPT: result:=ZG_PARTSTYLE_GPT_STR;
    ZG_PARTSTYLE_MBR: result:=ZG_PARTSTYLE_MBR_STR;
    ZG_PARTSTYLE_RAW: result:=ZG_PARTSTYLE_RAW_STR;
    ZG_PARTSTYLE_ERR: result:=ZG_PARTSTYLE_ERR_STR;
    else result:=ZG_PARTSTYLE_NA_STR;
  end;
end;

function ZgGetVolumeLabel(RootChar: char): string;
var
  Root: string;
  VolumeName, FileSystemNameBuffer: PChar;
  MaxLength, Flags: cardinal;
  ErrorMode: Word;
begin
  ErrorMode := SetErrorMode(SEM_FAILCRITICALERRORS);
  Root := RootChar + ':\';
  VolumeName := AllocMem(512);
  FileSystemNameBuffer := AllocMem(512);
  GetVolumeInformation(PChar(Root), VolumeName, 512, nil, MaxLength, Flags, FileSystemNameBuffer, 512);
  Result := string(VolumeName);
  // tidy up the result:
  if not (Result = '') then Result := Copy(Result, 1, 1) + LowerCase(Copy(Result, 2, 511));
  FreeMem(VolumeName);
  FreeMem(FileSystemNameBuffer);
  SetErrorMode(ErrorMode);
end;

procedure ZgGetICO(fl: string; var ib: TBitMap);
var
  Icon: TIcon;
  FileInfo: SHFILEINFO;
begin
   //Getting icon
   icon := TIcon.Create;
   ib.Height:=16;
   ib.Width:=16;
   SHGetFileInfo(PChar(fl), 0, FileInfo, SizeOf(FileInfo),
   SHGFI_SMALLICON or SHGFI_ICON or SHGFI_SYSICONINDEX);
   Icon.Handle := FileInfo.hIcon;
   ib.Canvas.Draw(0, 0, Icon);
   icon.Free;
end;

function ZgGetDiskId(partname: PWCHAR): integer;
var
  HPartition: THandle;
  dpi:        STORAGE_DEVICE_NUMBER;
  bResult:    boolean;
  retbytes:   DWORD;
begin
  HPartition:=CreateFileW(partname, 0, FILE_SHARE_READ,
                  nil, OPEN_EXISTING, 0, 0);

  if (HPartition = INVALID_HANDLE_VALUE) then
  begin
    //MessageBox(0, PAnsiChar(inttostr(GetLastError)), 'HEPE1', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    result:=-1;
    exit;
  end;

  bResult:=DeviceIoControl(HPartition,
                IOCTL_STORAGE_GET_DEVICE_NUMBER,
                nil,
                0,
                @dpi,
                sizeof(dpi),
                retBytes,
                nil);

  if (not bResult) then
  begin
    if (not SOEFlag) then MessageBox(0, PAnsiChar('Can''t get disk id with code: ' + inttostr(GetLastError)), 'HEPE2', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    result:=-1;
    CloseHandle(HPartition);
    exit;
  end;

  CloseHandle(HPartition);

  result:=dpi.DeviceNumber;
end;

function ZgGetPartitionId(partname: PWCHAR): integer;
var
  HPartition: THandle;
  dpi:        STORAGE_DEVICE_NUMBER;
  bResult:    boolean;
  retbytes:   DWORD;
begin
  HPartition:=CreateFileW(partname, 0, FILE_SHARE_READ,
                  nil, OPEN_EXISTING, 0, 0);

  if (HPartition = INVALID_HANDLE_VALUE) then
  begin
    //MessageBox(0, PAnsiChar(inttostr(GetLastError)), 'HEPE1', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    result:=-1;
    exit;
  end;

  bResult:=DeviceIoControl(HPartition,
                IOCTL_STORAGE_GET_DEVICE_NUMBER,
                nil,
                0,
                @dpi,
                sizeof(dpi),
                retBytes,
                nil);

  if (not bResult) then
  begin
    if (not SOEFlag) then MessageBox(0, PAnsiChar('Can''t get partition id with code: ' + inttostr(GetLastError)), 'HEPE2', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    result:=-1;
    CloseHandle(HPartition);
    exit;
  end;

  CloseHandle(HPartition);

  result:=dpi.PartitionNumber;
end;

function ZgGetDiskTypeId(partname: PWCHAR): integer;
var
  HPartition: THandle;
  dpi:        STORAGE_DEVICE_NUMBER;
  bResult:    boolean;
  retbytes:   DWORD;
begin
  HPartition:=CreateFileW(partname, 0, FILE_SHARE_READ,
                  nil, OPEN_EXISTING, 0, 0);

  if (HPartition = INVALID_HANDLE_VALUE) then
  begin
    //MessageBox(0, PAnsiChar(inttostr(GetLastError)), 'HEPE1', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    result:=-1;
    exit;
  end;

  bResult:=DeviceIoControl(HPartition,
                IOCTL_STORAGE_GET_DEVICE_NUMBER,
                nil,
                0,
                @dpi,
                sizeof(dpi),
                retBytes,
                nil);

  if (not bResult) then
  begin
    if (not SOEFlag) then MessageBox(0, PAnsiChar('Can''t get drive type id with code ' + inttostr(GetLastError)), 'HEPE2', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    result:=-1;
    CloseHandle(HPartition);
    exit;
  end;

  CloseHandle(HPartition);

  result:=dpi.DeviceType;
end;

function ZgGetDriveInfoStr(DrivePath: PWCHAR): string;
var
  DrivePath2:       string;
  VendorInfo:       array[0..MAX_PATH] of char;
  ModelInfo:        array[0..MAX_PATH] of char;
  RevisionInfo:     array[0..MAX_PATH] of char;
begin
  result:='';
  DrivePath2:=DrivePath;
  ZgGetDriveVendor(PAnsiChar(DrivePath2), addr(VendorInfo), MAX_PATH);
  result := result + VendorInfo;
  if (string(VendorInfo) <> '') then result := result + ' ';
  ZgGetDriveModel(PAnsiChar(DrivePath2), addr(ModelInfo), MAX_PATH);
  result := result + ModelInfo;
  if (string(ModelInfo) <> '') then result := result + ' ';
  ZgGetDriveRevision(PAnsiChar(DrivePath2), addr(RevisionInfo), MAX_PATH);
  result := result + RevisionInfo;
  if (string(RevisionInfo) <> '') then result := result + ' ';
end;

function ZgGetDriveSizeInBytes(DrivePath: PCHAR): Int64;
var
  HDrive:     THandle;
  bResult:    boolean;
  retBytes:   DWORD;
  leninfo:    GET_LENGTH_INFORMATION;
begin
  HDrive:=CreateFileA(DrivePath,
            GENERIC_READ or GENERIC_WRITE,
            FILE_SHARE_READ or FILE_SHARE_WRITE,
            nil,
            OPEN_EXISTING,
            0,
            0);

  if (HDrive = INVALID_HANDLE_VALUE) then
  begin
    result:=-1;
    exit;
  end;

  bResult:=DeviceIoControl(
    HDrive,
    IOCTL_DISK_GET_LENGTH_INFO,
    nil,
    0,
    @leninfo,
    sizeof(leninfo),
    retBytes,
    nil
  );

  if (not bResult) then
  begin
    //MessageBox(0, PAnsiChar(inttostr(GetLastError)), '', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    CloseHandle(HDrive);
    result:=-1;
    exit;
  end;

  result:=leninfo.Length.QuadPart;

  CloseHandle(HDrive);
end;

function ZgGetDriveSizeStr(DrivePath: PWCHAR): string;
var
  HDrive:     THandle;
  bResult:    boolean;
  retBytes:   DWORD;
  leninfo:    GET_LENGTH_INFORMATION;
  finalsize:  Extended;
  sizecap:    string;
begin
   HDrive:=CreateFileW(DrivePath,
            GENERIC_READ or GENERIC_WRITE,
            FILE_SHARE_READ or FILE_SHARE_WRITE,
            nil,
            OPEN_EXISTING,
            0,
            0);

  if (HDrive = INVALID_HANDLE_VALUE) then
  begin
    result:=ZG_ERR_STRING;
    exit;
  end;

  bResult:=DeviceIoControl(
    HDrive,
    IOCTL_DISK_GET_LENGTH_INFO,
    nil,
    0,
    @leninfo,
    sizeof(leninfo),
    retBytes,
    nil
  );

  if (not bResult) then
  begin
    if (not SOEFlag) then MessageBox(0, PAnsiChar('Can''t get size with code: ' + inttostr(GetLastError)), '', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    CloseHandle(HDrive);
    result:=ZG_ERR_STRING;
    exit;
  end;

  finalsize:=leninfo.Length.QuadPart;
  if (leninfo.Length.QuadPart >= KB_BASE) then
  begin
    finalsize := finalsize / 1024;
    sizecap:='KB';
  end;
  if (leninfo.Length.QuadPart >= MB_BASE) then
  begin
    finalsize := finalsize / 1024;
    sizecap:='MB';
  end;
  if (leninfo.Length.QuadPart >= GB_BASE) then
  begin
    finalsize := finalsize / 1024;
    sizecap:='GB';
  end;

  finalsize:=RoundTo(finalsize, -2);

  result:=floattostr(finalsize) + ' ' + sizecap;

  CloseHandle(HDrive);
end;

function ZgGetDriveSizeByLBAStr(StartLBA: Int64; EndLBA: Int64; SectorSize: DWORD): string;
var
  finalsize, tmpsize:  extended;
  sizecap:    string;
begin
  finalsize := (EndLBA - StartLBA) * SectorSize;
  tmpsize:=finalsize;
  if (finalsize >= KB_BASE) then
  begin
    tmpsize := tmpsize / 1024;
    sizecap:='KB';
  end;
  if (finalsize >= MB_BASE) then
  begin
    tmpsize := tmpsize / 1024;
    sizecap:='MB';
  end;
  if (finalsize >= GB_BASE) then
  begin
    tmpsize := tmpsize / 1024;
    sizecap:='GB';
  end;

  tmpsize:=RoundTo(tmpsize, -2);

  result:=floattostr(tmpsize) + ' ' + sizecap;
end;

function ZgGetSystemDriveExclusionStr: string;
var
  dl:     char;
  strwd2: array[0..MAX_PATH] of AnsiChar;
  tmp:    string;
  tmp2:   array[0..MAX_PATH] of WideChar;
  tmp3:   string;
begin
  result:=ADRIVE_MSG;
  //result:='\\.\PhysicalDrive0';
  for dl:='A' to 'Z' do
  begin
    tmp:='\\.\' + dl + ':';
    tmp3:=dl+':';
    GetWindowsDirectory(@strwd2, MAX_PATH);
    if (pos(tmp3, strwd2) <> 0) then
    begin
      StringToWideChar(tmp, @tmp2, MAX_PATH - 1);
      result:=PDRIVE_BASE + inttostr(ZgGetDiskId(tmp2));
    end;
  end;
end;

function ZgGetApplicationDriveExclusionStr: string;
var
  dl:     char;
  strwd2: array[0..MAX_PATH] of AnsiChar;
  tmp:    string;
  tmp2:   array[0..MAX_PATH] of WideChar;
  tmp3:   string;
begin
  result:=ADRIVE_MSG;
  //result:='\\.\PhysicalDrive0';
  for dl:='A' to 'Z' do
  begin
    tmp:='\\.\' + dl + ':';
    tmp3:=dl+':';
    ZgGetSymLinkTarget(PAnsiChar(Application.ExeName), @strwd2, MAX_PATH);
    if (pos(ExtractFileDrive(strwd2), tmp3) <> 0) then
    begin
      StringToWideChar(tmp, @tmp2, MAX_PATH - 1);
      result:=PDRIVE_BASE + inttostr(ZgGetDiskId(tmp2));
    end;
  end;
end;

function ZgGetLogFileDriveExclusionStr(logfile: string): string;
var
  dl:     char;
  strwd2: array[0..MAX_PATH] of AnsiChar;
  tmp:    string;
  tmp2:   array[0..MAX_PATH] of WideChar;
  tmp3:   string;
begin
  result:=ADRIVE_MSG;
  //result:='\\.\PhysicalDrive0';
  for dl:='A' to 'Z' do
  begin
    tmp:='\\.\' + dl + ':';
    tmp3:=dl+':';
    ZgGetSymLinkTarget(PAnsiChar(ExtractFileDir(logfile)), @strwd2, MAX_PATH);
    if (pos(ExtractFileDrive(strwd2), tmp3) <> 0) then
    begin
      StringToWideChar(tmp, @tmp2, MAX_PATH - 1);
      result:=PDRIVE_BASE + inttostr(ZgGetDiskId(tmp2));
    end;
  end;
end;

function ZgGetPhysicalDriveList: TStringList;
var
  i:      integer;
  HDrive: THandle;
  DrivePath:      string;
  sde, ade, lde:  string;
begin
  i:=0;

  result:=TStringList.Create;

  while (true) do
  begin
    DrivePath:=PDRIVE_BASE + IntToStr(i);
    HDrive:=CreateFile(PAnsiChar(DrivePath),
            0,
            FILE_SHARE_READ or FILE_SHARE_WRITE,
            nil,
            OPEN_EXISTING,
            0,
            0);
    if (HDrive = INVALID_HANDLE_VALUE) then break;
    CloseHandle(HDrive);
    i:=i+1;
    sde:=ZgGetSystemDriveExclusionStr;
    ade:=ZgGetApplicationDriveExclusionStr;
    if (SOLFlag = true) then lde:=ZgGetLogFileDriveExclusionStr(SOLLocation);
    if (DrivePath = sde) then continue;
    if (DrivePath = ade) then continue;
    if (SOLFlag = true) then
      if (DrivePath = lde) then continue;
    result.Add(DrivePath);
  end;
end;

function ZgGetIndexFromPDPath(PDPath: string): string;
var
  tmp: string;
begin
  tmp:=PDPath;
  tmp:=StringReplace(tmp, PDRIVE_BASE, '', [rfReplaceAll, rfIgnoreCase]);
  result:=tmp;
end;

function ZgTryStrToDWORD(const S: string; out Value: DWORD): Boolean;
var
  E: Integer;
begin
  Val(S, Value, E);
  Result := E = 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  ArgParser:        ZgArgumentParserCIS;
  ArgParserResult:  ZgParseResultCIS;
  founddi:          boolean;
  i:                integer;
  tdi:              string;
  tmploglocation:   string;
  canautostart:     boolean;
  needautostart:    boolean;
  tmpebs:           string;
  tsbs:             integer;
  tcbs:             DWORD;
  dm:               TDEVMODE;
begin
  //*****************************************
  //Now we can try to parse command line args
  ArgParser:=ZgArgumentParserCIS.Create();
  ArgParser.AddArgument('/autostart', saBool);
  ArgParser.AddArgument('-autostart', saBool);
  ArgParser.AddArgument('/autoclose', saBool);
  ArgParser.AddArgument('-autoclose', saBool);
  ArgParser.AddArgument('/driveindex', saStore);
  ArgParser.AddArgument('-driveindex', saStore);
  ArgParser.AddArgument('/ebstype', saStore);
  ArgParser.AddArgument('-ebstype', saStore);
  ArgParser.AddArgument('/ebsstandardsize', saStore);
  ArgParser.AddArgument('-ebsstandardsize', saStore);
  ArgParser.AddArgument('/ebscustomsize', saStore);
  ArgParser.AddArgument('-ebscustomsize', saStore);
  ArgParser.AddArgument('/silent', saBool);
  ArgParser.AddArgument('-silent', saBool);
  ArgParser.AddArgument('/skiponerrors', saBool);
  ArgParser.AddArgument('-skiponerrors', saBool);
  ArgParser.AddArgument('/saveoperationlog', saBool);
  ArgParser.AddArgument('-saveoperationlog', saBool);
  ArgParser.AddArgument('/saveoperationloglocation', saStore);
  ArgParser.AddArgument('-saveoperationloglocation', saStore);
  ArgParser.AddArgument('/help', saBool);
  ArgParser.AddArgument('-help', saBool);
  ArgParser.AddArgument('/h', saBool);
  ArgParser.AddArgument('-h', saBool);
  ArgParser.AddArgument('/?', saBool);
  ArgParser.AddArgument('-?', saBool);
  //NEW: screen resolution flags;
  ArgParser.AddArgument('/upscaletominres', saBool);
  ArgParser.AddArgument('-upscaletominres', saBool);
  ArgParser.AddArgument('/dontcheckres', saBool);
  ArgParser.AddArgument('-dontcheckres', saBool);
  //NEW: screenbit and topmost flags;
  ArgParser.AddArgument('/upscaleto32bits', saBool);
  ArgParser.AddArgument('-upscaleto32bits', saBool);
  ArgParser.AddArgument('/topmost', saBool);
  ArgParser.AddArgument('-topmost', saBool);
  //NEW: fullscreen and shutdownonclose flags;
  ArgParser.AddArgument('/fullscreen', saBool);
  ArgParser.AddArgument('-fullscreen', saBool);
  ArgParser.AddArgument('/shutdownonclose', saBool);
  ArgParser.AddArgument('-shutdownonclose', saBool);
  //NEW2: dontforceshutdown flag added;
  ArgParser.AddArgument('/dontforceshutdown', saBool);
  ArgParser.AddArgument('-dontforceshutdown', saBool);
  //NEW for 1.3: added dontscanvolumes and dontlockvolumes flags
  ArgParser.AddArgument('/dontscanvolumes', saBool);
  ArgParser.AddArgument('-dontscanvolumes', saBool);
  ArgParser.AddArgument('/dontlockvolumes', saBool);
  ArgParser.AddArgument('-dontlockvolumes', saBool);
  //NEW for 1.3.2: added hdvlock and hdvlockcount flags ALSO hdverrflag
  ArgParser.AddArgument('/hdvlock', saBool);
  ArgParser.AddArgument('-hdvlock', saBool);
  ArgParser.AddArgument('/hdvlockcount', saStore);
  ArgParser.AddArgument('-hdvlockcount', saStore);
  ArgParser.AddArgument('/hdverrflag', saBool);
  ArgParser.AddArgument('-hdverrflag', saBool);

  try
    ArgParserResult:=ArgParser.ParseArgs;
  except
    on E: Exception do
    begin
      MessageBox(0, PCHAR(E.Message), 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
      ArgParserResult:=ZgParseResultCIS.Create;
      Application.Terminate;
    end;
  end;

  if ((ArgParserResult.HasArgument('help')) or
      (ArgParserResult.HasArgument('h')) or
      (ArgParserResult.HasArgument('?'))) then
  begin
    if (FileExists(ExtractFilePath(Application.ExeName) + 'hepeargs.txt')) then
    begin
      ShellExecute(
        0,
        'open',
        'notepad.exe',
        PAnsiChar(ExtractFilePath(Application.ExeName) + 'hepeargs.txt'),
        nil,
        SW_SHOWDEFAULT
      );
      Application.Terminate;
    end else
    begin
      MessageBox(0, SAD_DEVELOPER_MESSAGE, 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
      Application.Terminate;
    end;
  end;

  //NEW: checking for minimal resolution;
  if (not ArgParserResult.HasArgument('dontcheckres')) then
  begin
    if ((self.Monitor.Height <= MIN_ALLOWED_RESY) or
        (self.Monitor.Width <= MIN_ALLOWED_RESX)) then
    begin
       if (ArgParserResult.HasArgument('upscaletominres')) then
       begin
         dm.dmSize:=sizeof(dm);
         dm.dmPelsWidth:=UPSCALE_MINX;
         dm.dmPelsHeight:=UPSCALE_MINY;
         if (ArgParserResult.HasArgument('upscaleto32bits')) then
         begin
           dm.dmBitsPerPel:=32;
           dm.dmFields:=DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL;
         end else
         begin
           dm.dmFields:=DM_PELSWIDTH or DM_PELSHEIGHT;
         end;
         if (ChangeDisplaySettings(dm, CDS_FULLSCREEN) <> DISP_CHANGE_SUCCESSFUL) then
         begin
            MessageBox(0, ZG_FAILUPSCALEMSG, 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
            Application.Terminate;
         end;
       end else
       begin
         MessageBox(0, ZG_RESNOTALLOWEDMSG, 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
         Application.Terminate;
       end;
    end;
  end;

  //NEW: launch HEPE in fullscreenmode
  if (ArgParserResult.HasArgument('fullscreen')) then
  begin
    self.BorderIcons:=[biSystemMenu, biMaximize, biMinimize];
    self.BorderStyle:=bsSizeable;
    self.BorderStyle:=bsNone;
    self.Height:=Self.Monitor.Height;
    self.Width:=Self.Monitor.Width;
    self.WindowState:=wsMaximized;
  end;

  //NEW: setting current form topmost
  if (ArgParserResult.HasArgument('topmost')) then
  begin
    SetWindowPos(self.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  end;

  //NEW: setting shutdown on close flag;
  shutdownflag:=false;
  if (ArgParserResult.HasArgument('shutdownonclose')) then
  begin
    CheckBox5.Checked:=true;
    self.CheckBox5Click(nil);
  end;

  //NEW2: setting dont force shutdown flag
  if (ArgParserResult.HasArgument('dontforceshutdown')) then
      dontforceshutdown:=true;

  //NEW for 1.3: setting dontscanvolumes and dontlockvolumes flags
  dsvflag:=false;
  dlvflag:=false;
  if (ArgParserResult.HasArgument('dontscanvolumes')) then
  begin
    CheckBox6.Checked:=true;
    Self.CheckBox6Click(nil);
  end
  else if (ArgParserResult.HasArgument('dontlockvolumes')) then
  begin
    CheckBox7.Checked:=true;
    self.CheckBox7Click(nil);
  end;

  //var first init
  BlockPartList:=TStringList.Create;
  OpStarted:=false;
  CancellationMarker:=false;
  isopsuccessful:=true;

  //new in 1.3.2 - volume blocking list model
  hdvflag:=false;
  hdvcount:=ZG_HV_MAX_COUNT;
  if (ArgParserResult.HasArgument('hdvlock')) then
  begin
    hdvflag:=true;
    if (ArgParserResult.HasArgument('hdvlockcount')) then
    begin
      if not (TryStrToInt(ArgParserResult.GetValue('hdvlockcount'), hdvcount)) then
      begin
        MessageBox(0, 'Invalid volumes count value! Set to default (128 max) value!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
        hdvcount:=ZG_HV_MAX_COUNT;
      end else
      begin
        if (hdvcount < 1) then
        begin
          MessageBox(0, 'Volume count value cannot be less than 1! Set to default (128 max) value!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
          hdvcount:=ZG_HV_MAX_COUNT;
        end;
      end;
    end;
    if (ArgParserResult.HasArgument('hdverrflag')) then
      hdverrflag:=true
    else
      hdverrflag:=false;
  end;

  needautostart:=false;
  if (ArgParserResult.HasArgument('autostart')) then needautostart:=true;

  SOEFlag:=false;
  if (ArgParserResult.HasArgument('skiponerrors')) then
  begin
    CheckBox1.Checked:=true;
    Self.CheckBox1Click(nil);
  end;

  BlockSize:=ZG_CUSTOMBLOCKSIZE_DEFAULT;
  self.RadioButton1Click(nil);
  Edit1.Text:=inttostr(BlockSize);
  if (ArgParserResult.HasArgument('ebstype')) then
  begin
    tmpebs:=LowerCase(ArgParserResult.GetValue('ebstype'));
    if (tmpebs = 'standard') then
    begin
      RadioButton1.Checked:=true;
      self.RadioButton1Click(nil);
      ComboBox1.ItemIndex:=0;
      self.ComboBox1Select(nil);
      if (ArgParserResult.HasArgument('ebsstandardsize')) then
      begin
        if (TryStrToInt(ArgParserResult.GetValue('ebsstandardsize'), tsbs) = true) then
        begin
          if ((tsbs >= 0) and (tsbs <= 15)) then
          begin
            ComboBox1.ItemIndex:=tsbs;
            self.ComboBox1Select(nil);
          end else
            MessageBox(0, 'Invalid standard block size index!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
        end else
          MessageBox(0, 'Invalid index value!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
      end;
    end else if (tmpebs = 'custom') then
    begin
      RadioButton2.Checked:=true;
      self.RadioButton2Click(nil);
      if (ArgParserResult.HasArgument('ebscustomsize')) then
      begin
        if (ZgTryStrToDWORD(ArgParserResult.GetValue('ebscustomsize'), tcbs) = true) then
        begin
          BlockSize:=tcbs;
          Edit1.Text:=IntToStr(tcbs);
        end else
          MessageBox(0, 'Invalid integer value for custom block size!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
      end;
    end else
      MessageBox(0, 'Invalid block size type!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
  end;

  CAOFlag:=false;
  if (ArgParserResult.HasArgument('autoclose')) then
  begin
    CheckBox3.Checked:=true;
    self.CheckBox3Click(nil);
  end;

  SelDriveIndex:=-1;
  self.FillDriveTable;
  canautostart:=false;
  if (ArgParserResult.HasArgument('driveindex')) then
  begin
     tdi:=ArgParserResult.GetValue('driveindex');
     founddi:=false;
     for i:=0 to ListView1.Items.Count - 1 do
     begin
        if (tdi = ListView1.Items.Item[i].Caption) then
        begin
          ListView1.Items.Item[i].Selected:=true;
          canautostart:=True;
          founddi:=true;
          break;
        end;
     end;
     if (founddi = false) then
        MessageBox(0, 'Drive with specified index not found!', 'HEPE' , MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
  end;

  SilentFlag:=false;
  if (ArgParserResult.HasArgument('silent')) then
  begin
    CheckBox4.Checked:=true;
    Self.CheckBox4Click(nil);
  end;

  SOLFlag:=false;
  SOLLocation:=ExtractFilePath(Application.ExeName) + HEPE_VERSION_LOG_NAME;
  Edit2.Text:=SOLLocation;
  if (ArgParserResult.HasArgument('saveoperationlog')) then
  begin
    CheckBox2.Checked:=true;
    Self.CheckBox2Click(nil);
    if (ArgParserResult.HasArgument('saveoperationloglocation')) then
    begin
      tmploglocation:=ArgParserResult.GetValue('saveoperationloglocation');
      if (DirectoryExists(ExtractFileDir(tmploglocation))) then
      begin
         SOLLocation:=tmploglocation;
         Edit2.Text:=tmploglocation;
      end else begin
         MessageBox(0, 'Path does not exist!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
      end;
    end;
  end;

  ArgParserResult.Free;
  ArgParser.Free;

  if (needautostart = true) then
    if (canautostart = true) then
      self.Button3Click(nil)
    else
      MessageBox(
          0,
          'For /autostart flag you need at least correct specified /driveindex flag.',
          'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
end;

procedure TForm1.FillDriveTable;
var
  i:          integer;
  DriveList:  TStringList;
  tmp:        array[0..MAX_PATH] of WideChar;
begin
  ListView1.Items.Clear;
  DriveList:=ZgGetPhysicalDriveList;
  for i:=0 to DriveList.Count - 1 do
  begin
    with ListView1.Items.Add do
    begin
      Caption:=ZgGetIndexFromPDPath(DriveList[i]);
      StringToWideChar(DriveList[i], @tmp, MAX_PATH);
      SubItems.Add(AnsiString(ZgGetDriveInfoStr(@tmp)));
      SubItems.Add(ZgGetDriveSizeStr(@tmp));
      SubItems.Add(inttostr(ZgGetDriveSectorSize(PAnsiChar(DriveList[i]))) + ' bytes');
      ImageIndex:=0;
    end;
  end;
  if (ListView1.Items.Count > 0) then
  begin
    ListView1.Items[0].Selected:=true;
    image1.Picture.Bitmap:=nil;
    image1.Picture.Bitmap.Canvas.Brush.Style:=bsClear;
    ImageList2.GetBitmap(1, image1.Picture.Bitmap);
  end;
  if (ListView1.Items.Count <= 0) then
  begin
    MessageBoxW(
        0,
        'No one drive is accesible to erasing!' + #13 +
        'Be sure that target drive is connected properly and has been detected by Windows' +
        ' in diskmgmt.msc tool' + #13 +
        'WARNING! You can''t erase the system drive and the application startup drive.' + #13 +
        'Notice that symbolic links in the HEPE path are also resolved!' + #13 +
        'It is a good practice to launch HEPE from Windows PE USB!',
        'HEPE',
        MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
    );
    image1.Picture.Bitmap:=nil;
    image1.Picture.Bitmap.Canvas.Brush.Style:=bsClear;
    ImageList2.GetBitmap(0, image1.Picture.Bitmap);
    label2.Caption:=ZG_SELDRIVE_BASE + ' ' + ZG_SELDRIVE_NONSELECTED;
    label3.Caption:=ZG_PARTSTYLE_BASE + ' ' + ZG_PARTSTYLE_NA_STR;
    end;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (OpStarted = true) then
  begin
    MessageBox(
        0,
        'You can''t close this window until operation has been done!',
        'HEPE',
        MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
    );
    CanClose:=false;
    self.Invalidate;
    exit;
  end;
end;

procedure TForm1.ListView1SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  tmp:    TBitmap;
  dl:     char;
  dlt:    string;
  tmp2:   array[0..MAX_PATH] of WideChar;
  cs1:    string;
  cs2:    string;
  dt:     integer;
  vlbl:   string;
  vlbl2:  string;
begin
  //OK, this event is called during FormDestroy, so i need to be more careful
  //with this stringlist
  if (not Assigned(BlockPartList)) then exit;

  ListView2.Items.Clear;
  BlockPartList.Clear;

  if (ListView1.SelCount > 0) then
  begin
    SelDriveIndex:=StrToInt(Item.Caption);
    label2.Caption:=ZG_SELDRIVE_BASE + ' ' + Item.Caption;
    label3.Caption:=ZG_PARTSTYLE_BASE + ' ' + ZgGetDrivePartStyleStr(PDRIVE_BASE + Item.Caption);
    imagelist3.Clear;

    //NEW in 1.3 disabling scanning volume if dontscanvolumes flag specified;
    if (not dsvflag) then //dsvflag
    begin

    for dl:='A' to 'Z' do
    begin
      dlt:='\\.\'+dl+':';
      StringToWideChar(dlt, @tmp2, MAX_PATH - 1);
      cs1:=PDRIVE_BASE + inttostr(ZgGetDiskId(@tmp2));
      cs2:=PDRIVE_BASE + Item.Caption;
      dt:=ZgGetDiskTypeId(@tmp2);
      if ((cs1 = cs2) and ((dt = FILE_DEVICE_DISK)
          or (dt = FILE_DEVICE_VIRTUAL_DISK))) then
      begin
        BlockPartList.Add(dlt);
        with ListView2.Items.Add do
        begin
          tmp:=TBitmap.Create;
          ZgGetICO(dl + ':\', tmp);
          ImageList3.Add(tmp, nil);
          Caption:=inttostr(ZgGetPartitionId(@tmp2));
          vlbl:=ZgGetVolumeLabel(dl);
          if (vlbl = '') then vlbl2 := '' else
            vlbl2:=' (' + vlbl + ')';
          SubItems.Add(dl + ':' + vlbl2);
          SubItems.Add(ZgGetDriveSizeStr(tmp2));
          ImageIndex:=ImageList3.Count - 1;
          tmp.Free;
        end;
      end;
    end;

    end; //if dsvflag

  end else
  begin
    SelDriveIndex:=-1;
    label2.Caption:=ZG_SELDRIVE_BASE + ' ' + ZG_SELDRIVE_NONSELECTED;
    label3.Caption:=ZG_PARTSTYLE_BASE + ' ' + ZG_PARTSTYLE_NA_STR;
    imagelist3.Clear;
  end;
end;

procedure TForm1.ListView2SelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  Item.Selected:=false;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  self.FillDriveTable;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  self.Close;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  i, count, sectorsize: DWORD;
  entry:                ZG_GPT_ENTRY;
  opresult:             boolean;
begin
  //NEW in 1.3: disabling scanning volume if dontscanvolumes flag specified;
  if (not dsvflag) then //dsvflag
  begin

  if (ListView1.SelCount > 0) then
  begin
    if (ZgIsDiskGPT(PAnsiChar(PDRIVE_BASE + ListView1.Selected.Caption))) then
    begin
      sectorsize:=ZgGetDriveSectorSize(PAnsiChar(PDRIVE_BASE + ListView1.Selected.Caption));
      if (sectorsize = ZG_ERR_DWORD) then
      begin
        MessageBox(
            0,
            PAnsiChar('Can''t get sector size with code: ' + inttostr(GetLastError)),
            'HEPE',
            MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL 
        );
        exit;
      end;
      count:=ZgQueryGPTPartitionsCount(PAnsiChar(PDRIVE_BASE + ListView1.Selected.Caption));
      if (count = ZG_ERR_DWORD) then
      begin
        MessageBox(
            0,
            PAnsiChar('Can''t get partitions count with code: ' + inttostr(GetLastError)),
            'HEPE',
            MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
        );
        exit;
      end;
      if (ListView2.Items.Count > 0) then
      begin
        for i:=ListView2.Items.Count - 1 downto 0 do
        begin
          if (pos(ZG_NA_STRING, ListView2.Items[i].Caption) <> 0) then
              ListView2.Items.Delete(i);
        end;
      end;
      for i:=0 to count - 1 do
      begin
        opresult:=ZgQueryGPTPartitionInformationByIndex(
           PAnsiChar(PDRIVE_BASE + ListView1.Selected.Caption),
           @entry,
           i
        );
        if (opresult <> true) then
        begin
          MessageBox(
            0,
            PAnsiChar('Can''t get partition entry with index ' +
              inttostr(i) +
              ' with code: ' +
              inttostr(GetLastError)),
            'HEPE',
            MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
          );
          continue;
        end;
        with ListView2.Items.Add do
        begin
          Caption:=ZG_NA_STRING + ' (' + inttostr(i + 1) + ')';
          SubItems.Add(ZgGUIDToString(entry.UniquePartitionGUID));
          SubItems.Add(ZgGetDriveSizeByLBAStr(entry.StartingLBA, entry.EndingLBA, sectorsize));
          ImageIndex:=-1;
        end;
      end;
    end else
    begin
      MessageBox(
        0,
        'Selected Drive doesn''t have GPT partition style!',
        'HEPE',
        MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
      );
    end;
  end else
  begin
    MessageBox(
      0,
      'You didn''t select any physical drive to scan!',
      'HEPE',
      MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
    );
  end;

  end //dsvflag
  else begin
    MessageBox(0, 'Please uncheck "Don''t scan volumes" flag!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
  end;
end;

procedure TForm1.CalculateStandardBlockSize;
begin
  case ComboBox1.ItemIndex of
    0:BlockSize:=ZG_4KBBLOCKSIZE;
    1:BlockSize:=ZG_8KBBLOCKSIZE;
    2:BlockSize:=ZG_16KBBLOCKSIZE;
    3:BlockSize:=ZG_32KBBLOCKSIZE;
    4:BlockSize:=ZG_64KBBLOCKSIZE;
    5:BlockSize:=ZG_128KBBLOCKSIZE;
    6:BlockSize:=ZG_256KBBLOCKSIZE;
    7:BlockSize:=ZG_512KBBLOCKSIZE;
    8:BlockSize:=ZG_1MBBLOCKSIZE;
    9:BlockSize:=ZG_2MBBLOCKSIZE;
    10:BlockSize:=ZG_4MBBLOCKSIZE;
    11:BlockSize:=ZG_8MBBLOCKSIZE;
    12:BlockSize:=ZG_16MBBLOCKSIZE;
    13:BlockSize:=ZG_32MBBLOCKSIZE;
    14:BlockSize:=ZG_64MBBLOCKSIZE;
    15:BlockSize:=ZG_128MBBLOCKSIZE;
  end;
end;

procedure TForm1.ComboBox1Select(Sender: TObject);
begin
  self.CalculateStandardBlockSize;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  tmpblocksize:   integer;
  CResult:        DWORD;
  tmpsectorsize:  Cardinal(*integer*);
begin
  if (OpStarted <> true) then
  begin
    if (RadioButton2.Checked = true) then
    begin
        tmpblocksize:=BlockSize;
        try
            BlockSize:=StrToInt(Edit1.Text);
        except
            on EConvertError do
            begin
                MessageBox(
                    0,
                    'Can''t assign custom block size. Be sure that you entered correct integer value!',
                    'HEPE',
                    MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
                );
                BlockSize:=tmpblocksize;
                Edit1.Text:=inttostr(tmpblocksize);
                exit;
            end;
        end;
        if ((BlockSize <= 0) or (BlockSize > ZG_MAXBLOCKSIZE)) then
        begin
            MessageBox(
                  0,
                  PAnsiChar('Block can''t be less or equal than zero or be more than ' + inttostr(ZG_MAXBLOCKSIZE) + ' bytes!'),
                  'HEPE',
                  MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
            );
            BlockSize:=tmpblocksize;
            Edit1.Text:=inttostr(tmpblocksize);
            exit;
        end;
        tmpsectorsize:=ZgGetDriveSectorSize(PAnsiChar(PDRIVE_BASE + inttostr(SelDriveIndex)));
        if (BlockSize mod tmpsectorsize <> 0) then
        begin
           MessageBox(
                  0,
                  PAnsiChar('Block size must be a multiple of the sector size: ' + inttostr(tmpsectorsize) + ' bytes!'),
                  'HEPE',
                  MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
            );
            BlockSize:=tmpblocksize;
            Edit1.Text:=inttostr(tmpblocksize);
            exit;
        end;
    end;

    if (SelDriveIndex = -1) then
    begin
        MessageBox(
          0,
          'You didn''t select any drive to erase!',
          'HEPE',
            MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL
        );
        exit;
    end;

    if (SOLFlag = true) then
      if (PDRIVE_BASE + inttostr(SelDriveIndex) = ZgGetLogFileDriveExclusionStr(SOLLocation)) then
      begin
        MessageBox(0, 'Can''t erase drive where placed program log file!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
        exit;
      end;

    if (SilentFlag = true) then
      CResult:=IDYES
    else
      CResult:=MessageBox(0, PChar(ZG_CONFIRMERASINGMSG), 'HEPE', MB_YESNO or MB_ICONEXCLAMATION or MB_TASKMODAL(*MB_APPLMODAL*));

    if (CResult = IDYES) then
    begin
      ZgEraser:=TZgErasingUnit.Create(true);
      ZgEraser.FreeOnTerminate:=true;
      ZgEraser.Resume;
    end;

  end else begin
    if (SilentFlag = true) then
      CResult:=IDYES
    else
      CResult:=MessageBox(0, PChar(ZG_CANCELERASINGMSG), 'HEPE', MB_YESNO or MB_ICONEXCLAMATION or MB_TASKMODAL);

    if (CResult = ID_YES) then
    begin
      CancellationMarker:=true;
      (*since of setting cancellation marker we just need some time
      to wait for execution thread to stop the operation*)
    end;
  end;
end;

procedure TForm1.RadioButton1Click(Sender: TObject);
begin
  Self.CalculateStandardBlockSize;
  ComboBox1.Enabled:=true;
  Edit1.Enabled:=false;
end;

procedure TForm1.RadioButton2Click(Sender: TObject);
begin
  ComboBox1.Enabled:=false;
  Edit1.Enabled:=true;
end;

procedure TZgErasingUnit.BlockControls;
begin
  Form1.ListView1.Enabled:=false;
  Form1.ListView2.Enabled:=false;
  Form1.Button4.Enabled:=false;
  Form1.GroupBox1.Enabled:=false;
  Form1.RadioButton1.Enabled:=false;
  Form1.RadioButton2.Enabled:=false;
  if (Form1.RadioButton1.Checked) then Form1.ComboBox1.Enabled:=false
    else Form1.Edit1.Enabled:=false;
  Form1.CheckBox1.Enabled:=false;
  Form1.CheckBox2.Enabled:=false;
  if (Form1.CheckBox2.Checked = true) then
  begin
    Form1.Edit2.Enabled:=false;
    Form1.BitBtn1.Enabled:=false;
  end;
  Form1.CheckBox3.Enabled:=false;
  Form1.CheckBox4.Enabled:=false;
  Form1.Button2.Enabled:=false;
  //block new controls
  Form1.CheckBox5.Enabled:=false;
  if (Form1.CheckBox6.Checked) then
      Form1.CheckBox6.Enabled:=false
  else begin
    Form1.CheckBox6.Enabled:=false;
    Form1.CheckBox7.Enabled:=false;
  end;
  Form1.Button5.Enabled:=false;
end;

procedure TZgErasingUnit.UnblockControls;
begin
  Form1.ListView1.Enabled:=true;
  Form1.ListView2.Enabled:=true;
  Form1.Button4.Enabled:=true;
  Form1.GroupBox1.Enabled:=true;
  Form1.RadioButton1.Enabled:=true;
  Form1.RadioButton2.Enabled:=true;
  if (Form1.RadioButton1.Checked) then Form1.ComboBox1.Enabled:=true
    else Form1.Edit1.Enabled:=true;
  Form1.CheckBox1.Enabled:=true;
  Form1.CheckBox2.Enabled:=true;
  if (Form1.CheckBox2.Checked = true) then
  begin
    Form1.Edit2.Enabled:=true;
    Form1.BitBtn1.Enabled:=true;
  end;
  Form1.CheckBox3.Enabled:=true;
  Form1.CheckBox4.Enabled:=true;
  Form1.Button2.Enabled:=true;
  //unblock new controls
  Form1.CheckBox5.Enabled:=true;
  if (Form1.CheckBox6.Checked) then
      Form1.CheckBox6.Enabled:=true
  else begin
    Form1.CheckBox6.Enabled:=true;
    Form1.CheckBox7.Enabled:=true;
  end;
  Form1.Button5.Enabled:=true;
end;

procedure TZgErasingUnit.ReportCurrentProgress;
begin
  Form1.ProgressBar1.Position:=Self.value;
  Form1.Label8.Caption:=ZG_CURRBLOCK_STR + ' ' + inttostr(Self.CurrentBlock);
end;

procedure TZgErasingUnit.ReportBlocksCount;
begin
  Form1.Label9.Caption:=ZG_FULLBLOCK_STR + ' ' + inttostr(Self.BlocksCount);
end;

procedure TZgErasingUnit.ReportOperationComplete;
begin
  if (isopsuccessful = true) then
    MessageBox(0, 'Operation is complete successful!', 'HEPE', MB_OK or MB_ICONINFORMATION or MB_TASKMODAL)
  else
    MessageBox(0, 'Operation is complete unsuccessful!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL)
end;

procedure TZgErasingUnit.ReportError;
begin
  case Self.errtype of
    1: MessageBox(0, 'Unskippable error! Can''t open volume for locking and dismounting!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    2: MessageBox(0, 'Unskippable error! Can''t lock volume!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    3: MessageBox(0, 'Unskippable error! Can''t dismount volume!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    4: MessageBox(0, 'Unskippable error! Can''t get drive size!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    5: MessageBox(0, 'Unskippable error! Can''t open drive for erasing!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    6: MessageBox(0, PCHAR('Can''t erase block: ' + inttostr(self.CurrentBlock) + ' due error'), 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
  end;
end;

procedure TZgErasingUnit.ResetProgress;
begin
  Form1.ProgressBar1.Position:=0;
  Form1.Label8.Caption:=ZG_CURRBLOCK_STR;
  Form1.Label9.Caption:=ZG_FULLBLOCK_STR;
end;

procedure TZgErasingUnit.TurnStartToStop;
begin
  Form1.Button3.Caption:=ZG_STARTBUTTON_STOP;
end;

procedure TZgErasingUnit.TurnStopToStart;
begin
  Form1.Button3.Caption:=ZG_STARTBUTTON_START;
end;

procedure TZgErasingUnit.UpdateDriveList;
begin
  Form1.Button2.OnClick(nil);
end;

function ZgBuildBlockPartList2(driveindex: integer; logdata: TStringList): TStringList;
const
  hdvbase = '\\.\GLOBALROOT\Device\HarddiskVolume';
var
  tmp:        TStringList;
  counter:    integer;
  targetid:   integer;
  tmpid:      integer;
begin
  targetid:=driveindex;
  tmp:=TStringList.Create;
  //counter:=1;
  //COUNTER MUST BE STARTED WITH 1
  for counter:=1 to hdvcount (*not fixed in 1.3.2*) do
  begin
    tmpid:=ZgGetDiskId(PWideChar(WideString(hdvbase + inttostr(counter))));

    if (tmpid <> -1) then
    begin
      if (tmpid = targetid) then tmp.Add(hdvbase + inttostr(counter));
    end else
    begin
      //new in version 1.3.2: last error code 2 means that
      //this volume name is not assigned to real volume
      //so we can skip this error code in order to make
      //size of log file less.
      if ((GetLastError <> 2) or (hdverrflag)) then
      logdata.Add('Can''t open volume ' +
           hdvbase + inttostr(counter) +
           ' for blocking with Win32 code ' +
           inttostr(GetLastError));
    end;
  end;

  result:=tmp;
end;


procedure TZgErasingUnit.Execute;
label gotoend;
var
  logdata:          TStringList;
  BlockDrives:      TZgHandleList;
  tmphandle:        THandle;
  i:                integer;
  opresult:         boolean;
  retBytes:         DWORD;
  targetdrive:      string;
  blockscount:      Int64;
  lastblocksize:    DWORD;
  targetdriveh:     THandle;
  DrivePointer:     Int64;
  ErrorMode:        Word;
  j:                Int64;
  nwfresult:        NTSTATUS;
  StartTime:        TDateTime;
  SpentHours:       Int64;
  SpentMinutes:     Int64;
  SpentSeconds:     Int64;
  SpentMS:          Int64;
  //new in 1.3.1: use \Device\HarddiskVolume to block partitions
  blockpartlist2:   TStringList;
begin
  targetdriveh:=INVALID_HANDLE_VALUE;
  targetdrive:=PDRIVE_BASE + inttostr(SelDriveIndex);
  isopsuccessful:=true;
  CancellationMarker:=false;
  self.Synchronize(self.BlockControls);
  self.Synchronize(self.TurnStartToStop);
  OpStarted:=True;

  //now we can start doing operations to erasing harddisk...
  logdata:=TStringList.Create;
  BlockDrives:=TZgHandleList.Create;

  StartTime:=Time;
  if (SOLFlag = true) then logdata.Add('HEPE ' + HEPE_VERSION + ' started - ' + DateToStr(Now) + ' ' + TimeToStr(Now));

  //NEW in 1.3: disabling blocking partition step if dontlockvolumes flag turned on;
  if (not dlvflag) then //dlvflag
  begin

  //NEW in 1.3.1: using new BlockPartList to block EVERY volume on target drive:
  //NEW in 1.3.2: WOW, that is pretty simple to use hdvflag
  if (hdvflag) then
    blockpartlist2:=ZgBuildBlockPartList2(SelDriveIndex, logdata)
  else begin
    blockpartlist2:=TStringList.Create;
    for i:=0 to BlockPartList.Count - 1 do
      blockpartlist2.Add(BlockPartList.Strings[i]);
  end;

  //step1: we need to block every partition in BlockPartList
  for i:=0 to blockpartlist2.Count - 1 do
  begin
    tmphandle:=CreateFileA(
                PAnsiChar(blockpartlist2.Strings[i]),
                GENERIC_READ or GENERIC_WRITE,
                FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
                nil,
                OPEN_EXISTING,
                0,
                0);

    if (tmphandle = INVALID_HANDLE_VALUE) then
    begin
       if (SOLFlag = true) then logdata.Add('Can''t open volume ' + blockpartlist2[i] + ' for blocking with Win32 code ' + inttostr(GetLastError()));
       self.errtype:=1;
       if (not SilentFlag = true) then Self.Synchronize(
            self.ReportError
       );
       isopsuccessful:=false;
       goto gotoend;
    end;

    if (SOLFlag = true) then logdata.Add('Volume ' + blockpartlist2[i] + ' is opened for blocking and unmounting!');
    BlockDrives.Add(tmphandle);

    opresult:=DeviceIoControl(
                tmphandle,
                FSCTL_LOCK_VOLUME,
                nil,
                0,
                nil,
                0,
                retBytes,
                nil
    );

    if (not opresult=true) then
    begin
      if (SOLFlag = true) then logdata.Add('Can''t lock volume ' + blockpartlist2[i] + ' with Win32 code ' + inttostr(GetLastError()));
      self.errtype:=2;
      if (not SilentFlag = true) then Self.Synchronize(self.ReportError);
      isopsuccessful:=false;
      goto gotoend;
    end;

    opresult:=DeviceIoControl(
                tmphandle,
                FSCTL_DISMOUNT_VOLUME,
                nil,
                0,
                nil,
                0,
                retBytes,
                nil
    );

    if (not opresult=true) then
    begin
      if (SOLFlag = true) then logdata.Add('Can''t dismount volume ' + blockpartlist2[i] + ' with Win32 code ' + inttostr(GetLastError()));
      self.errtype:=3;
      if (not SilentFlag = true) then Self.Synchronize(self.ReportError);
      isopsuccessful:=false;
      goto gotoend;
    end;

    if (SOLFlag = true) then logdata.Add('Volume ' + blockpartlist2[i] + ' is locked and dismounted!');
  end;

  //NEW in 1.3.1: clear blockpartlist2
  blockpartlist2.Free;

  end; //dlvflag

  //step2: we need to get totalblock size
  blockscount:=ZgGetDriveSizeInBytes(PAnsiChar(targetdrive));

  if (blockscount = -1) then
  begin
    if (SOLFlag = true) then logdata.Add('Can''t get drive size: ' + targetdrive + ' with Win32 code ' + inttostr(GetLastError()));
    self.errtype:=4;
    if (not SilentFlag = true) then Self.Synchronize(self.ReportError);
    isopsuccessful:=false;
    goto gotoend;
  end;

  if (SOLFlag = true) then logdata.Add('Target drive size is: ' + inttostr(blockscount) + ' bytes.');
  if (SOLFlag = true) then logdata.Add('Erasing block size is: ' + inttostr(BlockSize) + ' bytes.');

  Self.BlocksCount:=blockscount div BlockSize;
  if (blockscount mod BlockSize <> 0) then
  begin
    //Self.BlocksCount:=Self.BlocksCount + 1;
    lastblocksize:=blockscount - ((blockscount div BlockSize) * BlockSize);
  end else
  begin
    Self.BlocksCount:=Self.BlocksCount - 1;
    lastblocksize:=BlockSize;
    //lastblocksize:=0;
  end;

  if (SOLFlag = true) then logdata.Add('Total blocks count is: ' + inttostr(Self.BlocksCount) + '.');

  //step3: now we can erase harddisk
  Self.Synchronize(Self.ReportBlocksCount);

  targetdriveh:=CreateFileA(
      PAnsiChar(targetdrive),
      (*GENERIC_READ or*) GENERIC_WRITE,
      (*0*)FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
      nil,
      OPEN_EXISTING,
      (*0*)(*FILE_ATTRIBUTE_NORMAL*)FILE_FLAG_NO_BUFFERING or FILE_FLAG_WRITE_THROUGH or $40(*FILE_ATTRIBUTE_DEVICE*),
      0
  );

  if (targetdriveh = INVALID_HANDLE_VALUE) then
  begin
    if (SOLFlag = true) then logdata.Add('Can''t open drive for erasing: ' + targetdrive + ' with Win32 code ' + inttostr(GetLastError()));
    self.errtype:=5;
    if (not SilentFlag = true) then Self.Synchronize(self.ReportError);
    isopsuccessful:=false;
    goto gotoend;
  end;

  if (SOLFlag = true) then logdata.Add('Drive: ' + targetdrive + ' is opened for erasing.');

  ErrorMode := SetErrorMode(SEM_FAILCRITICALERRORS);
  //TODO: erasing code;
  j:=0;
  DrivePointer:=0;
  while (j <= self.BlocksCount) do
  begin
    if (CancellationMarker = true) then break;
    if (ZgFileSeek(targetdriveh, DrivePointer, FILE_BEGIN) = -1) then
    begin
      if (SOLFlag = true) then logdata.Add('Can''t seek to block ' + inttostr(j));
      if (SOEFlag = false) then
      begin
        Self.errtype:=6;
        Self.Synchronize(Self.ReportError);
      end;
      DrivePointer:=DrivePointer + BlockSize;
      j:=j+1;
      continue;
    end;
    if (j = self.BlocksCount) then
    begin
      //opresult:=ZgWriteZeroBlockToTarget(targetdriveh, lastblocksize);
      nwfresult:=ZgWriteZeroBlockToTarget2(targetdriveh, lastblocksize);
      //if (not opresult) then
      if (nwfresult <> 0) then
      begin
         //if (SOLFlag = true) then logdata.Add('Can''t write to block ' + inttostr(j) + ' with Win32 code: ' + inttostr(GetLastError));
         if (SOLFlag = true) then logdata.Add('Can''t write to block ' + inttostr(j) + ' with NtStatus code: 0x' + IntToHex(nwfresult, 8));
         if (SOEFlag = false) then
         begin
            Self.errtype:=6;
            Self.Synchronize(Self.ReportError);
         end;
         break;
      end;
      self.CurrentBlock:=j;
      self.value:=(self.CurrentBlock * 100) div self.BlocksCount;
      self.Synchronize(self.ReportCurrentProgress);
      if (SOLFlag = true) then logdata.Add('Block erased: ' + inttostr(j) + '.');
      break;
    end else begin
      //opresult:=ZgWriteZeroBlockToTarget(targetdriveh, BlockSize);
      nwfresult:=ZgWriteZeroBlockToTarget2(targetdriveh, BlockSize);
      //if (not opresult) then
      if (nwfresult <> 0) then
      begin
         //if (SOLFlag = true) then logdata.Add('Can''t write to block ' + inttostr(j) + ' with Win32 code: ' + inttostr(GetLastError));
         if (SOLFlag = true) then logdata.Add('Can''t write to block ' + inttostr(j) + ' with NtStatus code: 0x' + IntToHex(nwfresult, 8));
         if (SOEFlag = false) then
         begin
            Self.errtype:=6;
            Self.Synchronize(Self.ReportError);
         end;
         DrivePointer:=DrivePointer + BlockSize;
         j:=j+1;
         continue;
      end;
      self.CurrentBlock:=j;
      self.value:=(self.CurrentBlock * 100) div self.BlocksCount;
      self.Synchronize(self.ReportCurrentProgress);
      if (SOLFlag = true) then logdata.Add('Block erased: ' + inttostr(j) + '.');
    end;
    DrivePointer:=DrivePointer + BlockSize;
    j:=j+1;
  end;
  SetErrorMode(ErrorMode);

  //we need to say Windows that partition table on drive has been erased so
  //it must update this.
  DeviceIoControl(targetdriveh, IOCTL_DISK_UPDATE_PROPERTIES, nil, 0, nil, 0, retBytes, nil);

  gotoend:

  CloseHandle(targetdriveh);

  if (SOLFlag = true) then
  begin
    if (isopsuccessful = true) then
    begin
      logdata.Add('Operation completed successfully!');
      ZgMStoMSSMH(
          MilliSecondsBetween(Time, StartTime),
          SpentMS,
          SpentSeconds,
          SpentMinutes,
          SpentHours
      );
      logdata.Add(
          'Spent time: ' +
          ZgHToString(SpentHours) + ':' +
          ZgSorMtoString(SpentMinutes) + ':' +
          ZgSorMtoString(SpentSeconds) + '.' +
          ZgMStoString(SpentMS)
      );
    end
    else
      logdata.Add('Operation FAILED!');
    logdata.Add('***End of log!***');
    logdata.SaveToFile(SOLLocation);
  end;

  for i:=0 to BlockDrives.Count - 1 do CloseHandle(BlockDrives.Handles[i]);

  BlockDrives.Free;
  logdata.Free;

  if (not SilentFlag = true) then
    self.Synchronize(self.ReportOperationComplete);

  OpStarted:=false;
  self.Synchronize(self.ResetProgress);
  self.Synchronize(self.TurnStopToStart);
  self.Synchronize(self.UnblockControls);
  self.Synchronize(self.UpdateDriveList);

  if (CAOFlag = true) then self.Synchronize(Form1.Close);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  BlockPartList.Clear;
  BlockPartList.Free;
  BlockPartList:=nil;
end;

function TZgHandleList.GetPointer(index: integer): PTZgHandleListI;
var
  tmp: PTZgHandleListI;
begin
  if (self.Count = 0) then
  begin
    result:=nil;
    exit;
  end;

  tmp:=self.list;
  while ((tmp <> nil) and (tmp^.index <> index)) do
    tmp:=tmp^.next;

  if (tmp = nil) then
    result:=nil
  else
    result:=tmp;
end;

function TZgHandleList.GetValue(index: integer): THandle;
begin
  if (self.list = nil) then
  begin
    raise EAccessViolation.Create('TZgHandleList: Can''t access empty list!');
    exit;
  end;

  if (index < 0) then
  begin
    raise ERangeError.Create('TZgHandleList: Index out of range!');
    exit;
  end;

  if (index >= Self.Count) then
  begin
    raise ERangeError.Create('TZgHandleList: Index out of range!');
    exit;
  end;

  result:=self.GetPointer(index)^.value;
end;

procedure TZgHandleList.SetValue(index: integer; const H: THandle);
begin
  if (self.list = nil) then
  begin
    raise EAccessViolation.Create('TZgHandleList: Can''t access empty list!');
    exit;
  end;

  if (index < 0) then
  begin
    raise ERangeError.Create('TZgHandleList: Index out of range!');
    exit;
  end;

  if (index >= Self.Count) then
  begin
    raise ERangeError.Create('TZgHandleList: Index out of range!');
    exit;
  end;

  self.GetPointer(index)^.value:=H;
end;

function TZgHandleList.GetCount: integer;
begin
  result:=hcount;
end;

constructor TZgHandleList.Create;
begin
  inherited;
  self.list:=nil;
  self.hcount:=0;
end;

destructor TZgHandleList.Destroy;
begin
  self.Clear;
  self.list:=nil;
  self.hcount:=0;
  inherited;
end;

procedure TZgHandleList.Add(H: THandle);
var
  tmp: PTZgHandleListI;
begin
  if (self.Count = 0) then
  begin
    GetMem(self.list, sizeof(TZgHandleListI));
    self.list^.value:=H;
    self.list^.index:=0;
    self.list^.next:=nil;
    self.hcount:=1;
  end else begin
    tmp:=self.GetPointer(self.Count - 1);
    GetMem(tmp^.next, sizeof(TZgHandleListI));
    tmp^.next^.value:=H;
    tmp^.next^.index:=tmp^.index + 1;
    tmp^.next^.next:=nil;
    self.hcount:=self.hcount + 1;
  end;
end;

procedure TZgHandleList.Clear;
var
  i: integer;
begin
  if (self.Count < 1) then exit;

  if (self.Count = 1) then
  begin
    FreeMem(self.list);
    self.list:=nil;
    self.hcount:=0;
    exit;
  end;

  i:=self.Count - 1;
  FreeMem(self.GetPointer(i));
  self.GetPointer(i - 1)^.next:=nil;
  self.hcount:=self.hcount - 1;
  self.Clear;
end;

procedure TZgHandleList.Delete(index: integer);
var
  tmp, tmp2: PTZgHandleListI;
begin
  if (self.list = nil) then
  begin
    raise EAccessViolation.Create('TZgHandleList: Can''t access empty list!');
    exit;
  end;

  if (index < 0) then
  begin
    raise ERangeError.Create('TZgHandleList: Index out of range!');
    exit;
  end;

  if (index >= Self.Count) then
  begin
    raise ERangeError.Create('TZgHandleList: Index out of range!');
    exit;
  end;

  if (index = 0) then
  begin
    tmp:=Self.list;
    Self.list:=Self.list^.next;
    FreeMem(tmp);
  end else begin
    tmp:=Self.GetPointer(index - 1);
    tmp2:=Self.GetPointer(index);
    if (tmp2 = nil) then exit;
    tmp^.next:=tmp2^.next;
    FreeMem(tmp2);
  end;
  Self.hcount:=Self.hcount-1;
end;

procedure TZgHandleList.Free;
begin
  self.Destroy;
end;

function TZgHandleList.IndexOf(entry: THandle): integer;
var
  i: integer;
begin
  for i:=0 to self.Count - 1 do
  begin
    if (self.Handles[i] = entry) then
    begin
      result:=i;
      exit;
    end;
  end;

  result:=-1;
end;

procedure TForm1.CheckBox2Click(Sender: TObject);
begin
  if (CheckBox2.Checked) then
  begin
    edit2.Enabled:=true;
    bitbtn1.Enabled:=true;
    SOLFlag:=true;
  end else begin
    edit2.Enabled:=false;
    bitbtn1.Enabled:=false;
    SOLFlag:=false;
  end;
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  if (CheckBox1.Checked) then
    SOEFlag:=true
  else
    SOEFlag:=false;
end;

procedure TForm1.CheckBox3Click(Sender: TObject);
begin
  if (CheckBox3.Checked) then
    CAOFlag:=true
  else
    CAOFlag:=false;
end;

procedure TForm1.CheckBox4Click(Sender: TObject);
begin
  if (CheckBox4.Checked) then
    SilentFlag:=true
  else
    SilentFlag:=false;
end;

procedure TForm1.BitBtn1Click(Sender: TObject);
var
  sd: TSaveDialog;
begin
  sd:=TSaveDialog.Create(Form1);
  sd.FileName:=SOLLocation;
  sd.Filter:='log file|*.log';
  sd.Title:='Select log location';
  if (sd.Execute) then
  begin
    Edit2.Text:=sd.FileName;
    SOLLocation:=sd.FileName;
  end;
  sd.Free;
end;

procedure TForm1.CheckBox5Click(Sender: TObject);
begin
  if (CheckBox5.Checked) then
    shutdownflag:=true
  else
    shutdownflag:=false;
end;

function ZgAdjustProcessPrivilegeByStr(Process: THandle; PrivName: string): boolean;
var
  hToken: THandle;
  tkp: TTokenPrivileges;
  tkpo: TTokenPrivileges;
  zero: DWORD;
begin
  zero:=0;
  if not OpenProcessToken(Process, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken) then
  begin
    MessageBox(0, 'OpenProcessToken() Failed', 'Exit Error', MB_OK);
    result:=false;
    Exit;
  end;

  if not LookupPrivilegeValue( nil, PAnsiChar(PrivName), tkp.Privileges[0].Luid ) then
  begin
    MessageBox(0, 'LookupPrivilegeValue() Failed', 'Exit Error', MB_OK);
    result:=false;
    Exit;
  end;

  tkp.PrivilegeCount:=1;
  tkp.Privileges[0].Attributes:=SE_PRIVILEGE_ENABLED;

  result:=AdjustTokenPrivileges(hToken, False, tkp, SizeOf( TTokenPrivileges ), tkpo, zero);
end;

procedure ZgShutdownWindows;
var
  opresult: boolean;
begin
  ZgAdjustProcessPrivilegeByStr(GetCurrentProcess(), 'SeDebugPrivilege');
  ZgAdjustProcessPrivilegeByStr(GetCurrentProcess(), 'SeRemoteShutdownPrivilege');
  ZgAdjustProcessPrivilegeByStr(GetCurrentProcess(), 'SeShutdownPrivilege');
  opresult:=InitiateSystemShutdown(nil, nil, 0, false, false);
  if (not opresult) then
    if (dontforceshutdown) then
    begin
      MessageBox(0, PAnsiChar('Failed to shutdown Windows with code: ' + inttostr(GetLastError)), 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    end else
      NtShutdownSystem(ShutdownNoReboot);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if (shutdownflag) then ZgShutdownWindows;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  if (MessageBox(0, 'Do you really want to shutdown Windows?',
        'HEPE', MB_YESNO or MB_ICONEXCLAMATION or MB_TASKMODAL) = IDYES) then
        ZgShutdownWindows;
end;

procedure TForm1.CheckBox7Click(Sender: TObject);
begin
  if (CheckBox7.Checked) then
    dlvflag:=true
  else
    dlvflag:=false;
end;

procedure TForm1.CheckBox6Click(Sender: TObject);
begin
  if (CheckBox6.Checked) then
  begin
    dsvflag:=true;
    dlvflag:=true;
    CheckBox7.Checked:=true;
    CheckBox7.Enabled:=false;
  end else begin
    dsvflag:=false;
    dlvflag:=false;
    CheckBox7.Enabled:=true;
    CheckBox7.Checked:=false;
  end;
end;

end.
