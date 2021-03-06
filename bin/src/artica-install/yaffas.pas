unit yaffas;

{$MODE DELPHI}
{$LONGSTRINGS ON}

interface

uses
    Classes, SysUtils,variants,strutils,Process,logs,unix,RegExpr in 'RegExpr.pas',zsystem,IniFiles;



  type
  tyaffast=class


private
     LOGS:Tlogs;
     SYS:TSystem;
     artica_path:string;
     EnableYaffas:integer;
     OcsServerDest:string;
     OcsServerDestPort:integer;
     OcsServerUseSSL:integer;
     binpath:string;

public
    procedure   Free;
    constructor Create(const zSYS:Tsystem);
    procedure   START();
    procedure   STOP();
    function    SUPERVISOR_PID():string;
    function  VERSION():string;
END;

implementation

constructor tyaffast.Create(const zSYS:Tsystem);
begin

       LOGS:=tlogs.Create();
       SYS:=zSYS;
       binpath:='/opt/yaffas/etc/webmin/start';
       if not TryStrToInt(SYS.GET_INFO('EnableYaffas'),EnableYaffas) then EnableYaffas:=1;

end;
//##############################################################################
procedure tyaffast.free();
begin
    logs.Free;
end;
//##############################################################################

procedure tyaffast.STOP();
var
   count:integer;
   RegExpr:TRegExpr;
   servername:string;
   pids:Tstringlist;
   pidstring:string;
   fpid,i:integer;
begin
if not FileExists(binpath) then begin
   writeln('Stopping Yaffas..............: Not Installed');
   exit;
end;

if not SYS.PROCESS_EXIST(SUPERVISOR_PID()) then begin
       writeln('Stopping Yaffas..............: already Stopped');
       exit;
end;




   writeln('Stopping Yaffas..............: ' + SUPERVISOR_PID() + ' PID..');

   fpsystem('/opt/yaffas/etc/webmin/stop');

    pidstring:=SUPERVISOR_PID();
   count:=0;
   while SYS.PROCESS_EXIST(pidstring) do begin
        sleep(200);
        count:=count+1;
        if count>20 then begin
            if length(pidstring)>0 then begin
               if SYS.PROCESS_EXIST(pidstring) then begin
                 writeln('Stopping Yaffas..............: kill pid '+ pidstring+' after timeout');
                  fpsystem('/bin/kill -9 ' + pidstring);
               end;
            end;
            break;
        end;
  end;


  if not SYS.PROCESS_EXIST(SUPERVISOR_PID()) then writeln('Stopping Yaffas..............: Stopped');
end;

 //##############################################################################

procedure tyaffast.START();
var
   count:integer;
   cmd:string;
   su,nohup:string;
   conf:TiniFile;
   enabled:integer;
   RegExpr:TRegExpr;
   servername:string;
   tmpfile:string;
   http_port:integer;
   prefix,serverstring:string;
begin

   if not FileExists(binpath) then begin
         logs.DebugLogs('Starting......: Yaffas: Product is not installed');
         exit;
   end;


if EnableYaffas=0 then begin
   logs.DebugLogs('Starting......:  Yaffas is disabled');
   STOP();
   exit;
end;



if SYS.PROCESS_EXIST(SUPERVISOR_PID()) then begin
   logs.DebugLogs('Starting......:  Yaffas Already running using PID ' +SUPERVISOR_PID()+ '...');
   exit;
end;

   logs.DebugLogs('Starting......:  Yaffas "/opt/yaffas/etc/webmin/start"....');

   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.zarafa.build.stores.php --yaffas');


   cmd:='/opt/yaffas/etc/webmin/start';
   fpsystem(cmd);
   count:=0;
   while not SYS.PROCESS_EXIST(SUPERVISOR_PID()) do begin
     sleep(150);
     inc(count);
     if count>50 then begin
       logs.DebugLogs('Starting......: Yaffas (timeout!!!)');
       logs.DebugLogs('Starting......: Yaffas "'+cmd+'"');
       break;
     end;
   end;




   if not SYS.PROCESS_EXIST(SUPERVISOR_PID()) then begin
       logs.DebugLogs('Starting......: Yaffas (failed!!!)');
   end else begin
       logs.DebugLogs('Starting......: Yaffas started with new PID '+SUPERVISOR_PID());
   end;

end;
//##############################################################################
 function tyaffast.SUPERVISOR_PID():string;
begin
 result:=SYS.GET_PID_FROM_PATH('/opt/yaffas/var/miniserv.pid');
end;
 //##############################################################################
  function tyaffast.VERSION():string;
var
   l:TstringList;
   i:integer;
   RegExpr:TRegExpr;
   tmpstr:string;
begin

    if length(binpath)=0 then exit;
    if Not Fileexists(binpath) then exit;
    result:=SYS.GET_CACHE_VERSION('APP_YAFFAS');
     if length(result)>2 then exit;


    tmpstr:='/opt/yaffas/etc/installed-products';
    if not FileExists(tmpstr) then exit;
    l:=TstringList.Create;
    l.LoadFromFile(tmpstr);


    RegExpr:=TRegExpr.Create;
    RegExpr.Expression:='framework=yaffas v([0-9\.]+)';
    for i:=0 to l.Count-1 do begin
         if RegExpr.Exec(l.Strings[i]) then begin
            result:=RegExpr.Match[1];
            break;
         end;
    end;
 SYS.SET_CACHE_VERSION('APP_YAFFAS',result);
l.free;
RegExpr.free;
end;
//##############################################################################

end.
