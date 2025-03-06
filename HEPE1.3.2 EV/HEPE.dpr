program HEPE;

uses
  Windows,
  Forms,
  MainForm in 'MainForm.pas' {Form1};

{$R *.res}

begin
  CreateMutex(nil, true, 'HEPE_ZEROGRAVITY');
  if (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    MessageBox(0, 'HEPE already started!', 'HEPE', MB_OK or MB_ICONEXCLAMATION or MB_TASKMODAL);
    exit;
  end;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
