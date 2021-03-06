unit logon;

{$MODE DELPHI}
{$LONGSTRINGS ON}

interface

uses
    Classes, SysUtils,variants,strutils,IniFiles, Process,md5,logs,unix,RegExpr in 'RegExpr.pas',zsystem,lighttpd,tcpip,openldap;



  type
  tlogon=class


private
     LOGS:Tlogs;
     D:boolean;
     GLOBAL_INI:TiniFIle;
     SYS:TSystem;
     artica_path:string;                      
     ldap:Topenldap;
     function GetLatestVersion():integer;
     function StripNumber(MyNumber:string):integer;
     procedure NightlyBuild();
     function GetLatestNightlyVersion():string;
     procedure ChangeDNS();
     function ParseResolvConf():string;
     function StatisticsAppliance():string;
     function GetIPInterface(eth:string):string;
     procedure WebConsoleSetup();
     procedure ChangeDNSMenu();
public
    procedure   Free;
    constructor Create();
    procedure Menu();
    procedure webaccess();
    procedure credentials();
    procedure ChangeIP();
    procedure ChangeRootpwd();
    procedure RegisterAgent();
    procedure ChangeArticaPort();

END;

implementation

constructor tlogon.Create();
begin
       forcedirectories('/etc/artica-postfix');
       SYS:=Tsystem.Create;
       LOGS:=tlogs.Create();
       D:=LOGS.COMMANDLINE_PARAMETERS('debug');




       if not DirectoryExists('/usr/share/artica-postfix') then begin
              artica_path:=ParamStr(0);
              artica_path:=ExtractFilePath(artica_path);
              artica_path:=AnsiReplaceText(artica_path,'/bin/','');

      end else begin
          artica_path:='/usr/share/artica-postfix';
      end;
end;
//##############################################################################
procedure tlogon.free();
begin
    logs.Free;
end;
//##############################################################################
function tlogon.GetIPInterface(eth:string):string;
var
 iptcp:ttcpip;
begin
     iptcp:=ttcpip.Create;
    result:=iptcp.IP_ADDRESS_INTERFACE(eth);
    if result='0.0.0.0' then begin
       if fileexists('/etc/artica-postfix/settings/Daemons/WizardSavedSettings') then begin
          if not FileExists('/etc/artica-postfix/TESTS_NETWORK_EXECUTED') then begin
               fpsystem('/usr/bin/php5 /usr/share/artica-postfix/exec.wizard-install.php --tests-network');
               result:=iptcp.IP_ADDRESS_INTERFACE(eth);
          end;
       end;
    end;

end;

procedure tlogon.Menu();
var
   a:string;
   answerA:string;
   lighttp:Tlighttpd;
   lightstatus:string;
   port,uris:string;
   slighttpd:Tlighttpd;
   SYSURIS:Tsystem;
   ArticaAgent:boolean;
   MASTER_CONSOLE:string;
   NODE_ID:string;
   eth:string;
   iptcp:ttcpip;
   CURRENTIP:string;
   squidbin:string;
   ARTICA_VERSION:string;
   ARTICA_PRODUCT_NAME:string;
   ARTICA_NIGHTLY_VERSION:string;
   htop_bin:string;
   InFluxDBIP:string;
   ISOCanDisplayUserNamePassword,ISOCanChangeIP,ISOCanReboot,ISOCanShutDown,ISOCanChangeRootPWD,ISOCanChangeLanguage:integer;
begin
ArticaAgent:=false;
logs.Debuglogs('Initialize menu....');
SYS:=Tsystem.Create;
if not TryStrToInt(SYS.GET_INFO('ISOCanDisplayUserNamePassword'),ISOCanDisplayUserNamePassword) then ISOCanDisplayUserNamePassword:=1;
if not TryStrToInt(SYS.GET_INFO('ISOCanChangeIP'),ISOCanChangeIP) then ISOCanChangeIP:=1;
if not TryStrToInt(SYS.GET_INFO('ISOCanReboot'),ISOCanReboot) then ISOCanReboot:=1;
if not TryStrToInt(SYS.GET_INFO('ISOCanShutDown'),ISOCanShutDown) then ISOCanShutDown:=1;
if not TryStrToInt(SYS.GET_INFO('ISOCanChangeRootPWD'),ISOCanChangeRootPWD) then ISOCanChangeRootPWD:=1;
if not TryStrToInt(SYS.GET_INFO('ISOCanChangeLanguage'),ISOCanChangeLanguage) then ISOCanChangeLanguage:=1;
 ARTICA_PRODUCT_NAME:='Artica';




if FileExists('/etc/artica-postfix/WEBSECURIZE') then ARTICA_PRODUCT_NAME:='Web Securize';

if not FileExists('/usr/share/artica-postfix/ressources/settings.inc') then begin
    writeln('');
    writeln('');
    writeln('### Please Wait, building settings.... ###');
    writeln('');
    writeln('');

    fpsystem('/usr/share/artica-postfix/bin/process1 --force >/dev/null 2>&1');
    fpsystem('clear');
    writeln('');
    writeln('');
    writeln('### Please Wait, restarting Web-console ###');
    writeln('');
    writeln('');
    fpsystem('/etc/init.d/artica-webconsole restart >/dev/null 2>&1');
    sleep(2000);
    Menu();
    exit;
end;

eth:=SYS.GET_INFO('ArticaLogonEth');
if length(eth)=0 then eth:='eth0';
htop_bin:=SYS.LOCATE_GENERIC_BIN('htop');

    iptcp:=ttcpip.Create;

    CURRENTIP:=GetIPInterface(eth);
    if CURRENTIP='0.0.0.0' then CURRENTIP:=GetIPInterface('eth1');
    if CURRENTIP='0.0.0.0' then CURRENTIP:=GetIPInterface('br0');
    if CURRENTIP='0.0.0.0' then CURRENTIP:=GetIPInterface('br1');


    if CURRENTIP='0.0.0.0' then begin
       if FileExists('/etc/init.d/artica-ifup') then begin
          fpsystem('clear');
          writeln('Please wait, configuring the network...');
          fpsystem('/etc/init.d/artica-ifup start');
          fpsystem('clear');
       end;
    end;

    if CURRENTIP='0.0.0.0' then begin
       CURRENTIP:=GetIPInterface(eth);
       if CURRENTIP='0.0.0.0' then CURRENTIP:=GetIPInterface('eth1');
       if CURRENTIP='0.0.0.0' then CURRENTIP:=GetIPInterface('br0');
       if CURRENTIP='0.0.0.0' then CURRENTIP:=GetIPInterface('br1');
    end;
    logs.Debuglogs('Initialize menu done....');
    fpsystem('clear');

    if CURRENTIP='0.0.0.0' then begin
       Writeln('No IP configuration detected, you should run the "N" option');
    end;

try
   lighttp:=Tlighttpd.Create(SYS);
except
   logs.Debuglogs(' Tlighttpd.Create crashed');
end;
if FileExists('/opt/artica-agent/usr/share/artica-agent/artica-agent.php') then ArticaAgent:=true;

if ArticaAgent then  ISOCanDisplayUserNamePassword:=0;
squidbin:=SYS.LOCATE_GENERIC_BIN('squid');
if Not FileExists(squidbin) then squidbin:=SYS.LOCATE_GENERIC_BIN('squid3');

if not  ArticaAgent then  begin
   ARTICA_VERSION:= trim(SYS.ARTICA_VERSION());
   ARTICA_NIGHTLY_VERSION:=GetLatestNightlyVersion();
   writeln(''+ARTICA_PRODUCT_NAME+' version ' + ARTICA_VERSION);
   fpsystem('/usr/bin/nohup /etc/init.d/artica-webconsole start >/dev/null 2>&1 &');
   fpsystem('/usr/bin/nohup /etc/init.d/artica-framework start >/dev/null 2>&1 &');
   fpsystem('/usr/bin/nohup /etc/init.d/artica-process1 start >/dev/null 2>&1 &');
   slighttpd:=Tlighttpd.Create(SYS);
   port:=trim(slighttpd.LIGHTTPD_LISTEN_PORT());
   SYSURIS:=Tsystem.Create();
   if length(port)<2 then port:='9000';
   if port='80' then port := '9000';
   try
      uris:=SYSURIS.txt_uris(port);
   except
         writeln('SYSURIS.txt_uris crashed');
         logs.Debuglogs('SYSURIS.txt_uris crashed');
   end;
       logs.Debuglogs('display menu....');

       writeln(ARTICA_PRODUCT_NAME+' "'+ARTICA_VERSION+'" WebAccess');
       writeln('Uri(s) you can use with your web browser:');
       writeln(uris);
end else begin

    writeln(SYS.txt_ip_agents());
    MASTER_CONSOLE:=SYS.GET_INFO('ARTICA_MASTER');
    NODE_ID:=SYS.GET_INFO('NODE_ID');
    writeln('-------------------------------------------------------');
    writeln('TinyProxy Version................: '+logs.ReadFromFile('/opt/artica-agent/usr/share/artica-agent/VERSION'));
    writeln('Artica statisics master appliance: '+MASTER_CONSOLE);
    writeln('Node ID..........................: '+NODE_ID);
    writeln('Network..........................: '+SYS.txt_ip_agents_line());
    writeln('-------------------------------------------------------');
    if length(MASTER_CONSOLE)=0 then begin
        writeln('');
        writeln('This node has not been linked to a statistics appliance');
        writeln('Open the web console on your statistics appliance and add this node');
        writeln('');
    end;

end;


writeln('Menu :');
if not  ArticaAgent then writeln('[A]..... Restart all '+ARTICA_PRODUCT_NAME+' services');
if FileExists('/opt/kaspersky/klms/bin/klms-control') then begin
   writeln('[B]..... Reset Kaspersky Web Administration password');
   writeln('[C]..... Restart Kaspersky Services');
end;
if not  ArticaAgent then writeln('[C]..... Synchronize settings & remove cache');
writeln('[D]..... Upgrade '+ARTICA_PRODUCT_NAME);
if FileExists('/usr/bin/htop') then writeln('[E]..... Process Monitor');
writeln('[G]..... '+ARTICA_PRODUCT_NAME+' service setup');
if FileExists(htop_bin) then writeln('[H]..... Tasks Manager');
if FileExists('/opt/influxdb/influx') then writeln('[I]..... Statistics database');


writeln('[L]..... Configure languages');
writeln('[N]..... Network settings');
writeln('[O]..... Meta client tasks');
writeln('[P]..... Modify root password');
writeln('[R]..... Reboot');
writeln('[S]..... Shutdown');

if FileExists('/bin/setupcon') then begin
   writeln('[K]..... Keyboard setup');
end;








if FileExists('/usr/sbin/dpkg-reconfigure') then begin
   // writeln('[L]..... Configure the system language');
end;

writeln('[Q]..... Exit and enter to the system');
writeln(lightstatus);
writeln('Your command: ');
readln(a);

a:=UpperCase(a);

if a='A' then begin
   writeln('Building init.d scripts');
   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.initslapd.php');
   fpsystem('/etc/init.d/artica-webservices restart');
   writeln('Restarting Artica-status');
   fpsystem('/etc/init.d/artica-status restart --force');
   writeln('Restarting monit');
   fpsystem('/etc/init.d/monit restart');
   writeln('Starting process1');
   fpsystem('/etc/init.d/artica-process1 start');
   writeln('[Enter] key to Exit');
   readln();
end;

if a='E' then begin
   fpsystem('/usr/bin/htop');
   Menu();
   exit;
end;



if a='G' then begin
   WebConsoleSetup();
   Menu();
   exit;
end;


if a='H' then begin
   fpsystem(htop_bin);
   Menu();
   exit;
end;

if a='I' then begin
   InFluxDBIP:=SYS.GET_INFO('InfluxApiIP');
   if FileExists('/etc/artica-postfix/STATS_APPLIANCE') then InFluxDBIP:='127.0.0.1';
   fpsystem('/opt/influxdb/influx -host '+InFluxDBIP+' -port 8086');
   Menu();
   exit;
end;


if a='B' then begin
   fpsystem('/opt/kaspersky/klms/bin/klms-control --set-web-admin-password');
   writeln('[Enter] key to Exit');
   readln();
   Menu();
   exit;
end;
 if a='C' then begin
   fpsystem('/etc/init.d/klmsdb restart');
   fpsystem('/etc/init.d/klms restart');
   Menu();
   exit;
end;


if a='L' then begin
   if ISOCanChangeLanguage=0 then begin
      Writeln('Operation not permitted');
      Menu();
      exit;
   end;
   fpsystem('/usr/sbin/dpkg-reconfigure locales');
   Menu();
   exit;
end;

if a='M' then begin
   Writeln('This operation will change DNS parameters, type [ENTER] key to continue..');
   readln();
   ChangeDNS();
   Menu();
   exit;

end;
if a='N' then begin
   if ISOCanReboot=0 then begin
      Writeln('Operation not permitted');
      Menu();
      exit;
   end;
   ChangeIP();
   Menu();
   exit;
end;

if a='D' then begin
   Writeln('Upgrade to a nightly build, please wait....');
   NightlyBuild();
   Menu();
   exit;
end;

if a='1' then begin
   RegisterAgent();
   Menu();
   exit;
end;


if a='P' then begin
   if ISOCanChangeRootPWD=0 then begin
      Writeln('Operation not permitted');
      Menu();
      exit;
   end;
   ChangeRootpwd();
   Menu();
   exit;
end;


if a='W' then begin
   webaccess();
   Menu();
   exit;
end;

if a='R' then begin
   if ISOCanChangeIP=0 then begin
      Writeln('Operation not permitted');
      Menu();
      exit;
   end;

  fpsystem(sys.LOCATE_GENERIC_BIN('reboot'));
  exit;
end;


if a='U' then begin
   if ISOCanDisplayUserNamePassword=0 then begin
      Writeln('Operation not permitted');
      Menu();
      exit;
   end;
   credentials();
   Menu();
   exit;
end;

if a='S' then begin
   if ISOCanShutDown=0 then begin
      Writeln('Operation not permitted');
      Menu();
      exit;
   end;
   fpsystem('init 0');
   exit;
end;

if a='L' then begin
   fpsystem('sudo /usr/sbin/dpkg-reconfigure locales');
   fpsystem('sudo dpkg-reconfigure console-data');
   Menu();
   exit;
end;

if a='O' then begin
   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.user.ask.meta-client.php');
   Menu();
   exit;
end;


if a='C' then begin
   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.initslapd.php');
   fpsystem('/usr/share/artica-postfix/bin/process1 --force');
   fpsystem('/bin/rm -f /usr/share/artica-postfix/ressources/logs/cache/*');
   fpsystem('/bin/rm -rf /usr/share/artica-postfix/ressources/logs/web/cache/*');
   fpsystem('/bin/rm -f /usr/share/artica-postfix/ressources/logs/jGrowl-new-versions.txt');
   fpsystem('/bin/rm -f /etc/artica-postfix/versions.cache');
   fpsystem('/bin/rm -f /usr/share/artica-postfix/ressources/logs/global.versions.conf');
   fpsystem('/usr/share/artica-postfix/bin/artica-install --write-versions');
   fpsystem('/usr/share/artica-postfix/bin/process1 --force fsjfklshkjfhkfsh');
   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.shm.php --remove');
   fpsystem('/etc/init.d/artica-postfix restart artica-status &');
   fpsystem('rm -rf /usr/share/artica-postfix/ressources/web/logs/*.cache');
   Menu();
   exit;
end;

if a='Q' then begin
   fpsystem('/bin/login.old');
   halt(0);
end;

if a='K' then begin
   fpsystem('/usr/sbin/dpkg-reconfigure console-setup');
   fpsystem('/bin/setupcon');
   fpsystem('/usr/sbin/dpkg-reconfigure keyboard-configuration');
   writeln('You need to reboot in order to apply changes');
   writeln('Do you want to reboot ? [Y/N]:');
   readln(answerA);
   answerA:=UpperCase(trim(answerA));
   if answerA='Y' then fpsystem('reboot');
end;



if a='Y' then begin
   ChangeArticaPort();
   writeln('[Enter] key to return to menu');
   readln();
end;
Menu();

end;
//##############################################################################
procedure tlogon.webaccess();
var
   slighttpd:Tlighttpd;
   ip:ttcpip;
   port,uris:string;
begin

   slighttpd:=Tlighttpd.Create(SYS);
   port:=slighttpd.LIGHTTPD_LISTEN_PORT();
   uris:=SYS.txt_uris(port);
   fpsystem('clear');
   writeln('Access to the Artica Web interface');
   writeln('**********************************************');
   writeln('');
   writeln('Here it is uris you can type on your web browser in order');
   writeln('to access to the front-end.');
   writeln('');
   writeln(uris);
   writeln('[Enter] key to Exit');
   readln();
end;

//##############################################################################
procedure tlogon.credentials();
var
   slighttpd:Tlighttpd;
   port,uris:string;
begin
   ldap:=Topenldap.Create;


   fpsystem('clear');
   writeln('Access to the Artica Web interface');
   writeln('**********************************************');
   writeln('');
   writeln('Once connected to the web front-end, use');
   writeln('following parameters');
   writeln('');
   writeln('Username..................:'+ldap.ldap_settings.admin);
   writeln('Password..................:'+ldap.ldap_settings.password);
   writeln('[Enter] key to Exit');
   readln();
end;
//##############################################################################
procedure tlogon.ChangeArticaPort();
var
   slighttpd:Tlighttpd;
   Defport:string;
   SetPort:integer;
   InpuTPort:string;
   InpuTPortInt:integer;
begin
  slighttpd:=Tlighttpd.Create(SYS);
  Defport:=slighttpd.LIGHTTPD_LISTEN_PORT();
  if Not TryStrToInt(SYS.GET_INFO('ArticaHttpsPort'),SetPort) then begin
      if Not TryStrToInt(Defport,SetPort) then SetPort:=9000;
  end;
   fpsystem('clear');
   writeln('Change the Web Console Administration port');
   writeln('**********************************************');
   writeln('Give the new port [',SetPort,']:');
   readln(InpuTPort);
   if Not TryStrToInt(InpuTPort,InpuTPortInt) then InpuTPortInt:=SetPort;
   if InpuTPortInt<>SetPort then begin
      SYS.set_INFO('ArticaHttpsPort',IntToStr(InpuTPortInt));
      writeln('Restarting the Web Administration console, please Wait');
      fpsystem('/etc/init.d/artica-postfix restart apache >/dev/null 2>&1');
   end;
   writeln('[Enter] key to return to menu');
   readln();
end;
//##############################################################################
procedure tlogon.WebConsoleSetup();
var
  CONF       :TiniFile;
  a    :string;
  LastestBuild:Integer;
  LighttpdMinimalLibraries:integer;
  EnableArticaFrontEndToNGninx:integer;
  EnableArticaFrontEndToApache:integer;
  MyCurrentVersionTXT:string;
  MasterIndexFile:string;
  answer:string;
  perform:string;
begin
  fpsystem('clear');
   writeln('Artica Web Console Menu');
   writeln('**********************************************');
   writeln('');
   writeln('Restart Artica Web console service........: [R]');

   if not TryStrToInt(SYS.GET_INFO('LighttpdMinimalLibraries'),LighttpdMinimalLibraries) then LighttpdMinimalLibraries:=0;
   if not TryStrToInt(SYS.GET_INFO('EnableArticaFrontEndToNGninx'),EnableArticaFrontEndToNGninx) then EnableArticaFrontEndToNGninx:=0;
   if not TryStrToInt(SYS.GET_INFO('EnableArticaFrontEndToApache'),EnableArticaFrontEndToApache) then EnableArticaFrontEndToApache:=0;
if LighttpdMinimalLibraries=0 then begin
   writeln('Turn ON loading minimal PHP libraires.....: [M]');
end;
if LighttpdMinimalLibraries=1 then begin
   writeln('Turn OFF loading minimal PHP libraires....: [M]');
end;

if FileExists(SYS.LOCATE_GENERIC_BIN('nginx')) then begin
   writeln('Use NGINX as Web engine...................: [N]');
end;
   writeln('Use Apache as Web engine..................: [A]');
   writeln('Use LIGHTTPD as Web engine................: [B]');
   writeln('MySQL service setup.......................: [C]');
   writeln('SuperAdmin Account & Password.............: [D]');
   writeln('Change the Artica Web console listen port.: [L]');
   writeln('Create an Artica Web console with FreeWebs: [F]');
   writeln('Restart the framework service.............: [G]');
   writeln('Generate the Main configuration file......: [H]');
   writeln('Rebuild Web console certificate...........: [I]');
   writeln('Reset all server settings.................: [J]');



   writeln('Press Q and [Enter]  key to Exit');
   readln(a);
   a:=UpperCase(a);

   if a='Q' then exit;

   if a='J' then begin
      fpsystem('clear');
      fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.users.reset.php');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;

   if a='C' then begin
      fpsystem('clear');
      fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.users.mysql-menu.php');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;

   if a='D' then begin
      fpsystem('clear');
      fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.users.SuperAdmin.php');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;

   if a='R' then begin
      writeln('Please wait... Restarting the Artica Web console service...');
      fpsystem('/etc/init.d/artica-webconsole restart');
      fpsystem('clear');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;

   if a='R' then begin
      fpsystem('rm -f /opt/artica/ssl/certs/*');
      fpsystem('rm -f /etc/ssl/certs/apache/server.crt');
      fpsystem('rm -f /etc/ssl/certs/apache/server.key');
      writeln('Please wait... Restarting the Artica Web console service...');
      fpsystem('/etc/init.d/artica-webconsole restart');
      fpsystem('clear');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;



 if a='N' then begin
 writeln('Activate NGNIX as web engine...');
 writeln('Stopping Artica Web Interface...');
 fpsystem('/etc/init.d/artica-webconsole stop');
 writeln('Stopping NGNIX service...');
 fpsystem('/etc/init.d/nginx stop');
 SYS.set_INFOS('EnableArticaFrontEndToNGninx','1');
 SYS.set_INFOS('EnableArticaFrontEndToApache','0');
 writeln('Restarting NGNIX service...');
 fpsystem('/etc/init.d/nginx restart');
 writeln('Restarting NGNIX service done...');
 fpsystem('/etc/init.d/artica-status restart');
 WebConsoleSetup();
 exit;
 end;

 if a='B' then begin
    writeln('Activate LIGHTTPD as web engine...');
   writeln('Stopping Artica Web Interface...');
   fpsystem('/etc/init.d/artica-webconsole stop');
   writeln('Stopping NGNIX service...');
   fpsystem('/etc/init.d/nginx stop');
   SYS.set_INFOS('EnableArticaFrontEndToNGninx','0');
   SYS.set_INFOS('EnableArticaFrontEndToApache','0');
   writeln('Restarting NGNIX service...');
   fpsystem('/etc/init.d/nginx restart');
   writeln('Starting Artica Web console service...');
   fpsystem('/etc/init.d/artica-webconsole start');
   fpsystem('/etc/init.d/artica-status restart');
   WebConsoleSetup();
   exit;
 end;

 if a='A' then begin
    writeln('Activate Apache as web engine...');
   writeln('Stopping Artica Web Interface...');
   fpsystem('/etc/init.d/artica-webconsole stop');
   writeln('Stopping NGNIX service...');
   fpsystem('/etc/init.d/nginx stop');
   SYS.set_INFOS('EnableArticaFrontEndToNGninx','0');
   SYS.set_INFOS('EnableArticaFrontEndToApache','1');
   writeln('Restarting NGNIX service...');
   fpsystem('/etc/init.d/nginx restart');
   writeln('Starting Artica Web console service...');
   fpsystem('/etc/init.d/artica-webconsole start');
   fpsystem('/etc/init.d/artica-status restart');
   WebConsoleSetup();
   exit;
 end;

   if a='L' then begin
      ChangeArticaPort();
      WebConsoleSetup();
      exit;
   end;


   if a='F' then begin
      fpsystem('clear');
      writeln('Give the name of your Web server eg "admin.yourdomain.com"');
      readln(answer);
      fpsystem(SYS.LOCATE_PHP5_BIN() +' /usr/share/artica-postfix/exec.wizard.install.php --articaweb "'+ answer+'"');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;
   if a='G' then begin
      fpsystem('clear');
      fpsystem('/etc/init.d/artica-postfix restart framework');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;

   if a='H' then begin
      fpsystem('clear');
      fpsystem('/usr/share/artica-postfix/bin/process1 --web-settings');
      writeln('Press [Enter] key to Exit');
      readln();
      WebConsoleSetup();
      exit;
   end;

   writeln('Unable to understand command: "',a,'"');
   writeln('Press [Enter] key to Exit');
   readln();
   exit;
end;

procedure tlogon.NightlyBuild();
var
  CONF       :TiniFile;
  Lastest    :string;
  LastestBuild:Integer;
  MyCurrentVersion:integer;
  MyCurrentVersionTXT:string;
  MasterIndexFile:string;
  answer:string;
  perform:string;
begin
  MyCurrentVersionTXT:= SYS.ARTICA_VERSION();

  Lastest:=GetLatestNightlyVersion();
  if length(Lastest)=0 then begin
     Writeln('No new version available');
     writeln('[Enter] key to return to menu');
     readln();
     exit;
  end;
  LastestBuild:=StripNumber(Lastest);
  MyCurrentVersion:=StripNumber(MyCurrentVersionTXT);
  writeln('Artica version.: ' + MyCurrentVersionTXT,' (',MyCurrentVersion,')');
  writeln('Nightly version: ' + Lastest,' (',LastestBuild,')');
if LastestBuild=MyCurrentVersion then begin
    writeln('Up-to-date, latest nightly was ',Lastest);
    writeln('[Enter] key to return to menu');
    readln();
    exit;
end;

if LastestBuild<MyCurrentVersion then begin
    writeln('Up-to-date, latest nightly was ',Lastest);
    writeln('[Enter] key to return to menu');
    readln();
    exit;
end;
   writeln('Update to nightly build "',Lastest,'" ?:[Y/N]');
   readln(answer);
   if length(trim(answer))>0 then perform:=UpperCase(answer) else perform:='Y';
   if perform='o' then perform:='Y';
   if perform='0' then perform:='Y';

   if perform<>'Y' then begin
      writeln('Operation aborted...[Enter] key to Exit');
      readln(answer);
      exit;
    end;

  fpsystem(SYS.LOCATE_PHP5_BIN() + ' /usr/share/artica-postfix/exec.nightly.php --force-nightly');
  writeln('[Enter] key to return to menu');
  readln();
  exit;
end;
//#############################################################################
function tlogon.StripNumber(MyNumber:string):integer;
var
  tmpstr     :string;
  uri        :string;
begin
   result:=0;
   tmpstr:=MyNumber;
   tmpstr:=AnsiReplaceText(tmpstr,'.','');
   If Not TryStrToInt(tmpstr,result) then result:=0;
end;
//#############################################################################
function tlogon.GetLatestVersion():integer;
var
  CONF       :TiniFile;
  autoupdate :TIniFile;
  tmpstr     :string;
  uri        :string;
begin
   result:=0;

   if not FileExists('/etc/artica-postfix/artica-update.conf') then exit;
   autoupdate:=TiniFile.Create('/etc/artica-postfix/autoupdate.conf');
   tmpstr:=autoupdate.ReadString('NEXT','artica','0');
   tmpstr:=AnsiReplaceText(tmpstr,'.','');
   result:=StrToInt(tmpstr);
end;
//#############################################################################
function tlogon.GetLatestNightlyVersion():string;
var
  CONF       :TiniFile;
  autoupdate :TIniFile;
  tmpstr     :string;
  MasterIndexFile        :string;
begin
   result:='0';
   MasterIndexFile:='/usr/share/artica-postfix/ressources/index.ini';
   if not FileExists(MasterIndexFile) then begin
      fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.nightly.php  --refresh --force >/dev/null 2>&1 &');
      exit;
   end;

   try
      autoupdate:=TiniFile.Create(MasterIndexFile);
   except
    exit();
   end;
   tmpstr:=autoupdate.ReadString('NEXT','artica-nightly','');
   if length(tmpstr)=0 then exit;
   result:=tmpstr;
end;
//#############################################################################
procedure tlogon.ChangeRootpwd();
var
   pass1,pass2:string;
begin



   fpsystem('clear');
   writeln('Change the root password');
   writeln('**********************************************');
   writeln('Give the password:');
   readln(pass1);
   if length(pass1)=0 then begin
      writeln('Null root password is not allowed, exiting..');
      writeln('[Enter] key to Exit');
      readln(pass1);
      exit;
   end;

    writeln('retype the password:');
    readln(pass2);

    if pass1<>pass2 then begin
         writeln('Passwords did not match');
         writeln('Press [ENTER] to restart');
         readln(pass2);
         ChangeRootpwd();
         exit;
    end;

    fpsystem('echo "root:'+pass2+'" | chpasswd 2>&1');
    writeln('Updated..');
    writeln('[Enter] key to Exit');
    readln(pass2);
    exit;

end;
//#############################################################################
procedure tlogon.RegisterAgent();
var
   ipaddr,ipaddr2:string;
   NetagentPort:integer;
   RegExpr:TRegExpr;
begin
   ipaddr:=SYS.GET_INFO('ARTICA_MASTER');
   if not TryStrToInt(SYS.GET_INFO('NetagentPort'),NetagentPort) then NetagentPort:=9001;

   fpsystem('clear');
   writeln('Set here the URI to the Artica master');
   writeln('This uri must point to the Artica master Web administration interface');
   writeln('Example: https://10.10.10.2:9000');
   writeln('Example: http://10.10.10.2:9000');
   writeln('**********************************************');
   writeln('Give the uri:'+ipaddr);

   readln(ipaddr2);
   ipaddr2:=trim(ipaddr2);
   RegExpr:=TRegExpr.Create;


   if(length(ipaddr2)>0) then begin
       RegExpr.Expression:='htt.*?:\/\/.+?:[0-9]+';
       if not RegExpr.Exec(ipaddr2) then begin
             writeln('"',ipaddr2,'" is not an uri like http(s)://something:somenumber');
             writeln('type [ENTER] key to exit.');
             readln(ipaddr2);
             exit;
       end;
   end;
       SYS.set_INFO('ARTICA_MASTER',ipaddr2);

   writeln('Give the local listen port of this node:'+IntToStr(NetagentPort));
   readln(ipaddr2);
   if(length(ipaddr2)>0) then SYS.set_INFO('NetagentPort',ipaddr2);


   fpsystem('/opt/artica-agent/usr/share/artica-agent/artica-agent.php --register');
   fpsystem('/opt/artica-agent/usr/share/artica-agent/artica-agent.php --restart');
   writeln('type [ENTER] key to exit.');
   readln(ipaddr2);
   exit;

end;
//################################################################################
procedure tlogon.ChangeDNSMenu();
var
   EnablePDNS:integer;
   DNS,answer:string;
begin

if not FileExists(SYS.LOCATE_GENERIC_BIN('pdns_server')) then  begin
   ChangeDNS();
   exit;
end;
if not TryStrToInt(SYS.GET_INFO('EnablePDNS'),EnablePDNS) then EnablePDNS:=0;

if EnablePDNS=0 then writeln('[E]..... Activate PowerDNS service');
writeln('[S]..... Change System DNS addresses');
writeln('[Q]..... Exit menu');
readln(answer);
answer:=trim(answer);
answer:=UpperCase(answer);

// forward-zones=.=a,b

if answer ='E' then begin
   fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.pdns.php --wizard-on');
   exit;
end;
if answer ='S' then begin
   ChangeDNS();
   exit;
end;
if answer ='Q' then begin
   exit;
end;

end;
//################################################################################
procedure tlogon.ChangeDNS();
var
l:Tstringlist;
f:tstringlist;
RegExpr:TRegExpr;
i:integer;
DNS,answer:string;
begin
   l:=Tstringlist.Create;
   f:=Tstringlist.Create;
   RegExpr:=TRegExpr.Create;
   if FileExists('/etc/resolv.conf') then begin
   l.LoadFromFile('/etc/resolv.conf');
   for i:=0 to l.Count-1 do begin
       RegExpr.Expression:='nameserver\s+(.+)';
       if RegExpr.Exec(l.Strings[i]) then begin
          if RegExpr.Match[1]<>'127.0.0.1' then f.Add(RegExpr.Match[1]);
       end;
   end;

 if f.Count=0 then begin
   if FileExists('/etc/resolvconf/update.d/base') then begin
      f.LoadFromFile('/etc/resolv.conf');
      for i:=0 to l.Count-1 do begin
          RegExpr.Expression:='nameserver\s+(.+)';
          if RegExpr.Exec(l.Strings[i]) then begin
             if RegExpr.Match[1]<>'127.0.0.1' then f.Add(RegExpr.Match[1]);
          end;
      end;
  end;
 end;
 DNS:=f.Strings[0];
end;
  if length(DNS)=0 then DNS:='8.8.8.8';
  writeln('Give the First DNS ip address for this computer:['+DNS+']');
  readln(answer);
  if length(trim(answer))>0 then DNS:=answer;
  if length(DNS)=0 then exit;

  l.Add('nameserver   '+DNS);
  l.SaveToFile('/etc/resolv.conf');
  ForceDirectories('/etc/resolvconf/update.d');
  l.SaveToFile('/etc/resolvconf/update.d/base');

  l.free;f.free;RegExpr.free;
  exit;
end;
//################################################################################
procedure tlogon.ChangeIP();
begin

     fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.user.ask.network.php');
end;
function tlogon.StatisticsAppliance():string;
var
   inis:Tinifile;
   php:string;
   hostname,port,ssl,answer:string;
begin
   php:=SYS.LOCATE_PHP5_BIN();
   fpsystem(php+' /usr/share/artica-postfix/exec.netagent.php --register-infos');
   if not FileExists('/etc/artica-postfix/remote-appliance-settings.ini') then begin
          writeln('Fatal error while retreive informations...');
          writeln('[Enter] key to Exit');
          readln(answer);
          exit;
   end;
   inis:=Tinifile.Create('/etc/artica-postfix/remote-appliance-settings.ini');
   hostname:=inis.ReadString('INFO','server','10.10.10.1');
   port:=inis.ReadString('INFO','port','9000');
   ssl:=inis.ReadString('INFO','ssl','1');

   writeln('Give the hostname/IP of the Statistics appliance server:['+hostname+']');
   readln(answer);
   if length(trim(answer))>0 then hostname:=answer;

   writeln('Give the port number of the Statistics appliance Web interface:['+port+']');
   readln(answer);
   if length(trim(answer))>0 then port:=answer;

   if ssl='1' then ssl:='Y' else ssl:='N';
   writeln('Use ssl to connect to  '+port+' ? Y/N:['+ssl+']');
   readln(answer);
   answer:=UpperCase(answer);
   if length(trim(answer))>0 then ssl:=answer;

   writeln('Launching the connection procedure...');
   if ssl='Y' then ssl:='1' else ssl:='0';
   fpsystem(php+' /usr/share/artica-postfix/exec.netagent.php --register-console '+hostname+' '+port+' '+ssl);
   writeln('[Enter] key to Exit');
   readln(answer);
   exit;
end;

function tlogon.ParseResolvConf():string;
var
   IP:string;
   Gateway:string;
   DNS,answer:string;
   NETMASK:string;
   iptcp:ttcpip;
   Gayteway:string;
   perform:string;
   l:Tstringlist;
   RegExpr:TRegExpr;
   AutorizePerform:boolean;
   s:TstringList;
   i:integer;
begin
     l:=Tstringlist.Create;
     try
           l.LoadFromFile('/etc/resolv.conf');
     except
           exit;
     end;

     RegExpr:=TRegExpr.Create;
     RegExpr.Expression:='^nameserver\s+(.*)';
     for i:=0 to l.Count-1 do begin
         if RegExpr.Exec(l.Strings[i]) then begin
            result:=RegExpr.Match[1];
            RegExpr.free;
            l.free;
            exit;
         end;
     end;
end;






end.
