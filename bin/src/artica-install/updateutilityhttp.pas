unit updateutilityhttp;

{$MODE DELPHI}
{$LONGSTRINGS ON}

interface

uses
    Classes, SysUtils,variants,strutils, Process,logs,unix,RegExpr in 'RegExpr.pas',zsystem,awstats;

type
  TStringDynArray = array of string;

  type
  tupdateutility=class


private
     LOGS:Tlogs;
     SYS:TSystem;
     artica_path:string;
     awstats:tawstats;
     mem_pid:string;

public
    EnableLighttpd:integer;
    InsufficentRessources:Boolean;
    procedure   Free;
    constructor Create(const zSYS:Tsystem);
    procedure   START();
    function    LIGHTTPD_BIN_PATH():string;
    function    LIGHTTPD_PID():string;
    procedure   STOP();
    procedure   INSTALL_INIT_D();

END;

implementation

constructor tupdateutility.Create(const zSYS:Tsystem);
begin
       forcedirectories('/etc/artica-postfix');
       forcedirectories('/opt/artica/tmp');
       LOGS:=tlogs.Create();
       SYS:=zSYS;
       EnableLighttpd:=0;
       awstats:=tawstats.Create(SYS);
       InsufficentRessources:=SYS.ISMemoryHiger1G();
       if not TryStrToInt(SYS.GET_INFO('UpdateUtilityEnableHTTP'),EnableLighttpd) then EnableLighttpd:=0;


       if not DirectoryExists('/usr/share/artica-postfix') then begin
              artica_path:=ParamStr(0);
              artica_path:=ExtractFilePath(artica_path);
              artica_path:=AnsiReplaceText(artica_path,'/bin/','');

      end else begin
          artica_path:='/usr/share/artica-postfix';
      end;
end;
//##############################################################################
procedure tupdateutility.free();
begin
    logs.Free;
    SYS.Free;
end;
//##############################################################################
function tupdateutility.LIGHTTPD_BIN_PATH():string;
begin
exit(SYS.LOCATE_LIGHTTPD_BIN_PATH());
end;
//##############################################################################
procedure tupdateutility.START();
var
  pid:string;
begin


logs.Debuglogs('###################### UPDATE UTILITY HTTPD #####################');

   pid:=LIGHTTPD_PID();

   if EnableLighttpd=0 then begin
        logs.Debuglogs('Starting......: UpdateUtility daemon is disabled');
        if SYS.PROCESS_EXIST(pid) then STOP();
        exit;
   end;
   if not FileExists('/etc/init.d/UpdateUtility-httpd') then  INSTALL_INIT_D();

   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.keepup2date.php --update-utility-httpd');

   if SYS.PROCESS_EXIST(pid) then begin
      logs.Debuglogs('Starting......: UpdateUtility daemon is already running using PID ' + LIGHTTPD_PID() + '...');
      logs.Debuglogs('LIGHTTPD_START():: UpdateUtility already running with PID number ' + pid);
      exit();
   end;

   logs.OutputCmd(LIGHTTPD_BIN_PATH()+ ' -f /etc/UpdateUtility/lighttpd.conf');


   if not SYS.PROCESS_EXIST(LIGHTTPD_PID()) then begin
      logs.Debuglogs('Starting UpdateUtility...........: Failed "' + LIGHTTPD_BIN_PATH()+ ' -f /etc/UpdateUtility/lighttpd.conf"');
    end else begin
      logs.Debuglogs('Starting UpdateUtility...........: Success (PID ' + LIGHTTPD_PID() + ')');
   end;

end;
//##############################################################################
procedure tupdateutility.STOP();
 var
    count      :integer;
begin

     count:=0;

     logs.DeleteFile('/etc/artica-postfix/cache.global.status');
     if SYS.PROCESS_EXIST(LIGHTTPD_PID()) then begin
        writeln('Stopping UpdateUtility.......: ' + LIGHTTPD_PID() + ' PID..');
        logs.OutputCmd('/bin/kill ' + LIGHTTPD_PID());

        while SYS.PROCESS_EXIST(LIGHTTPD_PID()) do begin
              sleep(100);
              inc(count);
              if count>100 then begin
                 writeln('Stopping UpdateUtility.......: Failed force kill');
                 logs.OutputCmd('/bin/kill -9 '+LIGHTTPD_PID());
                 exit;
              end;
        end;

      end else begin
        writeln('Stopping UpdateUtility.......: Already stopped');
     end;

end;
//##############################################################################
function tupdateutility.LIGHTTPD_PID():string;
var
   lighttpd_bin:string;
   pid:string;
begin

   pid:=SYS.GET_PID_FROM_PATH('/var/run/UpdateUtility/lighttpd.pid');
   if SYS.PROCESS_EXIST(pid) then begin
        result:=pid;
        mem_pid:=pid;
       exit;
   end;

   lighttpd_bin:=LIGHTTPD_BIN_PATH();
   if FileExists(lighttpd_bin) then begin
      lighttpd_bin:=ExtractFileName(lighttpd_bin);
      result:=SYS.PIDOF_PATTERN(lighttpd_bin + ' -f /etc/UpdateUtility/lighttpd.conf');
      mem_pid:=result;
      exit;
   end;
   lighttpd_bin:=SYS.LOCATE_APACHE_BIN_PATH();
   if FileExists(lighttpd_bin) then begin
      lighttpd_bin:=ExtractFileName(lighttpd_bin);
      result:=SYS.PIDOF_PATTERN(lighttpd_bin + ' -f /etc/UpdateUtility/lighttpd.conf');
      mem_pid:=result;
      exit;
   end;
end;
//##############################################################################
procedure tupdateutility.INSTALL_INIT_D();
var
   l:Tstringlist;
begin
l:=Tstringlist.Create;
l.add('#!/bin/sh');
 if fileExists('/sbin/chkconfig') then begin
    l.Add('# chkconfig: 2345 11 89');
    l.Add('# description: UpdateUtility-httpd Daemon');
 end;
l.add('### BEGIN INIT INFO');
l.add('# Provides:          UpdateUtility-httpd ');
l.add('# Required-Start:    $local_fs');
l.add('# Required-Stop:     $local_fs');
l.add('# Should-Start:');
l.add('# Should-Stop:');
l.add('# Default-Start:     2 3 4 5');
l.add('# Default-Stop:      0 1 6');
l.add('# Short-Description: Start UpdateUtility-httpd daemon');
l.add('# chkconfig: 2345 11 89');
l.add('# description: UpdateUtility-httpd Daemon');
l.add('### END INIT INFO');
l.add('');
l.add('case "$1" in');
l.add(' start)');
l.add('    /usr/share/artica-postfix/bin/artica-install -watchdog UpdateUtility $2');
l.add('    ;;');
l.add('');
l.add('  stop)');
l.add('    /usr/share/artica-postfix/bin/artica-install -shutdown UpdateUtility $2');
l.add('    ;;');
l.add('');
l.add(' restart)');
l.add('     /usr/share/artica-postfix/bin/artica-install -shutdown UpdateUtility $2');
l.add('     sleep 3');
l.add('     /usr/share/artica-postfix/bin/artica-install -watchdog UpdateUtility $2');
l.add('    ;;');
l.add('');
l.add('  *)');
l.add('    echo "Usage: $0 {start|stop|restart}"');
l.add('    exit 1');
l.add('    ;;');
l.add('esac');
l.add('exit 0');

logs.WriteToFile(l.Text,'/etc/init.d/UpdateUtility-httpd');
 fpsystem('/bin/chmod +x /etc/init.d/UpdateUtility-httpd >/dev/null 2>&1');

 if FileExists('/usr/sbin/update-rc.d') then begin
    fpsystem('/usr/sbin/update-rc.d -f UpdateUtility-httpd defaults >/dev/null 2>&1');
 end;

  if FileExists('/sbin/chkconfig') then begin
     fpsystem('/sbin/chkconfig --add UpdateUtility-httpd >/dev/null 2>&1');
     fpsystem('/sbin/chkconfig --level 2345 UpdateUtility-httpd on >/dev/null 2>&1');
  end;

   LOGS.Debuglogs('Starting......: framework install init.d scripts........:OK (/etc/init.d/UpdateUtility-httpd {start,stop,restart})');



end;
//##############################################################################
end.

