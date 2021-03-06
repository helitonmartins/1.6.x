unit pdns;

{$MODE DELPHI}
{$LONGSTRINGS ON}

interface

uses
    Classes, SysUtils,variants,strutils,Process,logs,unix,RegExpr,zsystem,openldap,tcpip,bind9;



  type
  tpdns=class


private
     LOGS:Tlogs;
     SYS:TSystem;
     artica_path:string;
     zldap:Topenldap;
     cdirlist:string;
     DisablePowerDnsManagement:integer;
     EnablePDNS:integer;
    function   CONTROL_BIN_PATH():string;
    function   RECURSOR_BIN_PATH():string;
public
    procedure   Free;
    constructor Create(const zSYS:Tsystem);
    procedure   CONFIG_DEFAULT();

    function    VERSION():string;
    function    BIN_PATH():string;
    procedure   START();
    procedure   STOP();
    procedure   RELOAD();
    procedure   RECURSOR_STOP();
    procedure   RECURSOR_START();
    function    STATUS:string;


END;

implementation

constructor tpdns.Create(const zSYS:Tsystem);
begin
       forcedirectories('/etc/artica-postfix');
       LOGS:=tlogs.Create();
       SYS:=zSYS;
       zldap:=Topenldap.Create;
       DisablePowerDnsManagement:=0;
       if Not TryStrToInt(SYS.GET_INFO('DisablePowerDnsManagement'),DisablePowerDnsManagement) then DisablePowerDnsManagement:=0;
       if Not TryStrToInt(SYS.GET_INFO('EnablePDNS'),EnablePDNS) then EnablePDNS:=1;



       if not DirectoryExists('/usr/share/artica-postfix') then begin
              artica_path:=ParamStr(0);
              artica_path:=ExtractFilePath(artica_path);
              artica_path:=AnsiReplaceText(artica_path,'/bin/','');

      end else begin
          artica_path:='/usr/share/artica-postfix';
      end;
end;
//##############################################################################
procedure tpdns.free();
begin
    logs.Free;
    zldap.Free;
end;
//##############################################################################
function tpdns.BIN_PATH():string;
begin
   exit(SYS.LOCATE_PDNS_BIN());

end;
//##############################################################################
function tpdns.RECURSOR_BIN_PATH():string;
begin
   if FileExists('/usr/sbin/pdns_recursor') then exit('/usr/sbin/pdns_recursor');

end;
//##############################################################################
function tpdns.CONTROL_BIN_PATH():string;
begin
   if FileExists('/usr/sbin/pdns_control') then exit('/usr/sbin/pdns_control');

end;
//##############################################################################
function tpdns.VERSION():string;
var
    RegExpr:TRegExpr;
    FileDatas:TStringList;
    i:integer;
    filetmp:string;
    D:boolean;
begin
D:=false;
D:=SYS.COMMANDLINE_PARAMETERS('--verbose');
result:=SYS.GET_CACHE_VERSION('APP_PDNS');
if length(result)>0 then exit;

filetmp:=logs.FILE_TEMP();
if not FileExists(BIN_PATH()) then begin
   logs.Debuglogs('unable to find pdns');
   exit;
end;

logs.Debuglogs(BIN_PATH()+' --version >'+filetmp+' 2>&1');
fpsystem(BIN_PATH()+' --version >'+filetmp+' 2>&1');

    RegExpr:=TRegExpr.Create;
    RegExpr.Expression:='Version:\s+([0-9\.]+)';
    FileDatas:=TStringList.Create;
    FileDatas.LoadFromFile(filetmp);
    logs.DeleteFile(filetmp);
    for i:=0 to FileDatas.Count-1 do begin
        writeln(FileDatas.Strings[i]);
        if RegExpr.Exec(FileDatas.Strings[i]) then begin
             result:=RegExpr.Match[1];
             break;
        end;
    end;

FileDatas.Clear;
if length(trim(result))=0 then begin
     logs.Debuglogs(RECURSOR_BIN_PATH()+' --version >'+filetmp+' 2>&1');
     fpsystem(RECURSOR_BIN_PATH()+' --version >'+filetmp+' 2>&1');
     RegExpr.Expression:='version:\s+([0-9\.]+)';
     FileDatas.LoadFromFile(filetmp);
    logs.DeleteFile(filetmp);
    for i:=0 to FileDatas.Count-1 do begin

        if RegExpr.Exec(FileDatas.Strings[i]) then begin
            if D then writeln('found',FileDatas.Strings[i]);
             result:=RegExpr.Match[1];
             break;
        end else begin
            if D then writeln('Not found',FileDatas.Strings[i], ' for ', RegExpr.Expression);
        end;
    end;
end;

RegExpr.free;
FileDatas.Free;
SYS.SET_CACHE_VERSION('APP_PDNS',result);

end;
//#############################################################################
procedure tpdns.START();
begin
    fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.pdns_server.php --start');
end;


//#############################################################################
procedure tpdns.RECURSOR_START();
begin
    fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.pdns.php --start-recursor');
end;


//#############################################################################

procedure tpdns.RELOAD();
begin
fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.pdns_server.php --reload');
end;
//#############################################################################



procedure tpdns.STOP();
begin
fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.pdns_server.php --stop');
end;


//#############################################################################
procedure tpdns.RECURSOR_STOP();
begin
    fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.pdns.php --stop-recursor');
end;
//#############################################################################
function tpdns.STATUS:string;
var
pidpath:string;
begin
pidpath:=logs.FILE_TEMP();
fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.status.php --pdns >'+pidpath +' 2>&1');
result:=logs.ReadFromFile(pidpath);
logs.DeleteFile(pidpath);

end;
//#############################################################################
procedure tpdns.CONFIG_DEFAULT();
begin
end;








end.
