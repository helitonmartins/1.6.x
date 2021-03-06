unit principale;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,variants, Process,unix,logs,
  RegExpr,zsystem,IniFiles,
  global_conf in 'global_conf.pas',common,process_infos,cyrus,clamav,spamass,pureftpd,roundcube,openldap,spfmilter,samba,mimedefang,bogofilter,squid,stunnel4,dkimfilter,
  postfix_class,mailgraph_daemon,lighttpd,miltergreylist,dansguardian,monitorix,kav4samba,awstats,ntpd,kav4proxy,bind9,fdm,p3scan,syslogng,kas3,isoqlog,dhcp_server,cups,wifi,
  dnsmasq,kavmilter,  jcheckmail, rdiffbackup,openvpn,strutils,xapian,dstat,BaseUnix,nfsserver,policyd_weight,tcpip,pdns,mysql_daemon,assp,postfilter, vmwaretools,phpldapadmin,zarafa_server,squidguard,backuppc,auditd,sshd,toolsversions,apachesrc,amanda,tomcat,
  collectd         in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/collectd.pas',crossroads,
  fetchmail        in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/fetchmail.pas',
  mailspy_milter   in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/mailspy_milter.pas',
  imapsync         in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/imapsync.pas',
  amavisd_milter   in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/amavisd_milter.pas',
  mailmanctl       in '/home/dtouzeau/developpement/artica-postfix/bin/src/artica-install/mailmanctl.pas',openemm;


type
  Tprocess1=class
  private
    LOGS:Tlogs;
    GLOBAL_INI:myconf;
    COMMON:Tcommon;
    Cyr:Tcyrus;
    SYS:Tsystem;
    debug:boolean;
    PHP_PATH:string;
    processINFOS:Tprocessinfos;
    D:boolean;
    roundcube:Troundcube;
    mldap:Topenldap;
    postfix:tpostfix;
    mailgraph:tMailgraphClass;
    lighttpd:Tlighttpd;
    miltergreylist:tmilter_greylist;
    dansguardian:Tdansguardian;
    monitorix:tmonitorix;
    kav4samba:Tkav4samba;
    awstats:tawstats;
    bind9:tbind9;
    fdm:Tfdm;
    fetchmail:tfetchmail;
    xapian:txapian;
    syslogng:tsyslogng;
    function ExecPipe(commandline:string):string;
    procedure killfile(path:string);

    function TEST_PROCSTAT():boolean;
    function bdb_recover_check():boolean;
    procedure WatchDogExecutor();

    procedure Execute;

    procedure AddMeToCron();
    procedure CheckSyslog(BigSize:integer;syslog_path:string);
    procedure KillArticaBackup();
    procedure CleanAmavisLogs();
    procedure CreateYorelUpdate();
    function get_LDAP_ADMIN():string;
    function get_LDAP_PASSWORD():string;
    function SLAPD_CONF_PATH():string;
    function get_LDAP_suffix():string;
    function LOCATE_PROCSTAT():string;
  public
    PROCEDURE web_settings(NoExecution:boolean=false);
    procedure DeadArticaInstall();
    procedure move_kas3_stats();
    procedure cleanlogs();
    procedure KillsfUpdatesBadProcesses();
    procedure maillog_multiples();
    function  IOSTAT():string;
    procedure mailgraph_log();
    procedure exec_dstat_top_php();
    procedure CleanCpulimit();
    constructor Create(noload:boolean=false);
    procedure TestLDAP();
    end;

implementation

//##############################################################################
procedure Tprocess1.Execute;
var
   squid:Tsquid;
begin
  D:=false;
  if ParamStr(1)='-V' then D:=true;
  if ParamStr(2)='-V' then D:=true;
  if ParamStr(2)='--verbose' then D:=true;
  SYS:=Tsystem.Create();

  AddMeToCron();
  GLOBAL_INI.SET_ARTICA_LOCAL_SECOND_PORT(0);
  COMMON:=Tcommon.Create;
  processINFOS:=Tprocessinfos.Create;
  monitorix:=Tmonitorix.Create;

  logs.Debuglogs('Tprocess1.Execute -> web_settings()');
  logs.Debuglogs('-> web_settings()');
  web_settings();
  DeadArticaInstall();
  // /var/log/artica-postfix/executor-daemon.log
  WatchDogExecutor();

  if SYS.isoverloaded() then begin
       logs.Debuglogs('Tprocess1.Execute -> OVERLOADED');
       exit;
  end;
  logs.Debuglogs('Tprocess1.Execute -> DeleteLogs()');
  logs.Debuglogs('-> DeleteLogs()');
  logs.DeleteLogs();

//  logs.Debuglogs('Tprocess1.Execute -> CROSSROADS_SEND_REQUESTS_TO_SERVER()');
//GLOBAL_INI.CROSSROADS_SEND_REQUESTS_TO_SERVER('');

    logs.Debuglogs('Tprocess1.Execute -> SQUID_RRD_EXECUTE()');
    squid:=Tsquid.create;
    squid.SQUID_RRD_EXECUTE();
    squid.free;

  if D then begin
  if FileExists('/etc/artica-postfix/autokill') then writeln('Tprocess1.Execute ->/etc/artica-postfix/autokill exists aborting');
  end;


  TEST_PROCSTAT();
  logs.Debuglogs('-> CreateYorelUpdate()');
  CreateYorelUpdate();
  logs.Debuglogs('-> MAILGRAPH_GENERATE()');
  mailgraph.MAILGRAPH_GENERATE();
  logs.Debuglogs('-> YOREL_VERIFY_START()');
  GLOBAL_INI.YOREL_VERIFY_START();
  logs.Debuglogs('-> maillog_multiples()');
  maillog_multiples();
  logs.Debuglogs('-> move_kas3_stats()');
  move_kas3_stats();
  logs.Debuglogs('-> cleanlogs()');
  cleanlogs();
  logs.Debuglogs('-> mailgraph_log()');
   mailgraph_log();

  logs.Debuglogs('-> exec_dstat_top_php()');
  exec_dstat_top_php();
  logs.Debuglogs('Execute() function was executed successfully....');

end;

//##############################################################################
constructor Tprocess1.Create(noload:boolean);
begin
   D:=false;
   forcedirectories('/etc/artica-postfix');
   GLOBAL_INI:=myConf.Create();
   SYS:=GLOBAL_INI.SYS;
   D:=GLOBAL_INI.COMMANDLINE_PARAMETERS('-V');
   if not D then if ParamStr(1)='-V' then D:=true;
   LOGS:=Tlogs.Create;

   if ParamStr(1)='--cpulimit' then exit;

   Cyr:=Tcyrus.Create(GLOBAL_INI.SYS);
   roundcube:=Troundcube.Create(GLOBAL_INI.SYS);
   mldap:=Topenldap.Create;
   postfix:=tpostfix.Create(GLOBAL_INI.SYS);
   mailgraph:=tMailgraphClass.Create(GLOBAL_INI.SYS);
   lighttpd:=Tlighttpd.Create(GLOBAL_INI.SYS);



   miltergreylist:=tmilter_greylist.Create(GLOBAL_INI.SYS);
   dansguardian:=Tdansguardian.Create(GLOBAL_INI.SYS);
   awstats:=Tawstats.Create(GLOBAL_INI.SYS);
   bind9:=Tbind9.Create(GLOBAL_INI.SYS);
   processINFOS:=Tprocessinfos.Create;
  logs.Debuglogs('process 1 execute....');
  if not noload then begin
   if ParamStr(1)='-mysql' then exit;
   if ParamStr(1)='-kasstat' then exit;
   if ParamStr(1)='--kill' then exit;
   if ParamStr(1)='--iostat' then exit;
   if ParamStr(1)='--mailgraph' then exit;
   if ParamStr(1)='--ldap' then exit;
   if ParamStr(1)='--checkout' then begin
      web_settings();
      exit;
   end;
   
   Execute;
  end;
end;

//##############################################################################
procedure Tprocess1.DeadArticaInstall();
var i,mins:Integer;
begin
   SYS.AllPidsByPatternInPath('artica-install --startall');
   
   logs.Debuglogs('DeadArticaInstall():: found (' + IntToStr(SYS.ProcessIDList.count) + ') artica-install --startall instances');
   
   for i:=0 to SYS.ProcessIDList.Count-1 do begin

      if not FileExists('/proc/' + SYS.ProcessIDList.Strings[i]+'/cmdline') then continue;
      mins:=SYS.FILE_TIME_BETWEEN_MIN('/proc/' + SYS.ProcessIDList.Strings[i]+'/cmdline');
      logs.Debuglogs('DeadArticaInstall():: found ID ' + SYS.ProcessIDList.Strings[i] + ' Minutes=' + IntToStr(mins));
      if mins>5 then begin
         logs.Syslogs('DeadArticaInstall():: Kill artica-install process ID ' + SYS.ProcessIDList.Strings[i] + ' cause a ghost more than 5 minutes');
         fpsystem('/bin/kill ' +SYS.ProcessIDList.Strings[i]);
      end;
   end;

   SYS.ProcessIDList.Clear;
end;
//##############################################################################
procedure Tprocess1.TestLDAP();
var i,mins:Integer;
openldap_admin, openldap_password,openldap_server:string;
begin
    openldap_admin:=trim(GLOBAL_INI.get_LDAP('admin'));
    openldap_password:=trim(GLOBAL_INI.get_LDAP('password'));
    openldap_server:=trim(GLOBAL_INI.get_LDAP('server'));


    writeln('openldap_admin: ',openldap_admin);
    writeln('openldap_password: ',openldap_password);
    writeln('openldap_server: ',openldap_server);

    if length(trim(openldap_admin))=0 then openldap_admin:=get_LDAP_ADMIN();
    if length(trim(openldap_password))=0 then openldap_password:=get_LDAP_PASSWORD();

    writeln('2) openldap_admin: ',openldap_admin);
    writeln('2) openldap_password: ',openldap_password);
    writeln('2) openldap_server: ',openldap_server);
    writeln('2) slapd.conf: ',mldap.SLAPD_CONF_PATH() );

end;
//##############################################################################


procedure Tprocess1.maillog_multiples();
var
   l:TstringList;
   i:Integer;
   log_path:string;
begin
log_path:=SYS.MAILLOG_PATH();
l:=Tstringlist.Create;
l.AddStrings(SYS.PIDOF_PATTERN_PROCESS_LIST('/usr/bin/tail -f -n 0 '+log_path));
if l.Count>1 then begin
   try
   for i:=0 to l.Count-2 do begin
       if length(trim(l.Strings[i]))=0 then continue;
       logs.Syslogs('Killing bad process maillog '+ l.Strings[i]);
       fpsystem('/bin/kill '+l.Strings[i]);
   end;
   except
   logs.Debuglogs('Tprocess1.maillog_multiples:: Fatal error');
   exit;
   end;
  end;

end;
//##############################################################################

procedure Tprocess1.move_kas3_stats();
var
l:TstringList;
i:integer;
ffpath,ftpath:string;
begin
  l:=TstringList.Create;
  
  if not DirectoryExists('/usr/local/ap-mailfilter3/control/www/stat') then exit;
  
  forceDirectories('/opt/artica/share/www/kas3');
  
  l.AddStrings(SYS.DirFiles('/usr/local/ap-mailfilter3/control/www/stat','*.*'));
  for i:=0 to l.Count-1 do begin
     ffpath:='/usr/local/ap-mailfilter3/control/www/stat/'+l.Strings[i];
     ftpath:='/opt/artica/share/www/kas3/'+l.Strings[i];
     logs.OutputCmd('/bin/cp -f '+ffpath + ' ' + ftpath);
  end;
  
  l.free;


end;
//##############################################################################
procedure Tprocess1.AddMeToCron();
begin
SYS.CRON_CREATE_SCHEDULE('0 * * * *','/etc/init.d/artica-process1 start','artica-process1');
end;
//##############################################################################
procedure Tprocess1.mailgraph_log();
var
   logssize:longint;
begin
if not FileExists('/var/log/mailgraph.log') then exit;
logssize:=SYS.FileSize_ko('/var/log/mailgraph.log');
if  logssize>2500 then begin
    logs.DeleteFile('/var/log/mailgraph.log');
    fpsystem('/etc/init.d/artica-postfix restart mailgraph');
end;
end;
//##############################################################################
procedure Tprocess1.exec_dstat_top_php();
var
   list:tstringlist;
   i:integer;
begin
list:=Tstringlist.Create;
list.AddStrings(SYS.PIDOF_PATTERN_PROCESS_LIST('exec.dstat.top.php'));
if list.Count>2 then begin
   for i:=0 to list.Count-1 do begin
       if SYS.PROCESS_EXIST(list.Strings[i]) then begin
          logs.Syslogs('Killing  (exec_dstat_top_php) PID '+list.Strings[i]);
          fpsystem('/bin/kill '+list.Strings[i]);

       end;
   end;
end;

end;
//##############################################################################





PROCEDURE Tprocess1.web_settings(NoExecution:boolean);
var

   application_postgrey:string;
   courier_authdaemon,courier_imap,courier_imap_ssl,courier_pop,courier_pop_ssl,kav_mail,KAV_MILTER_PID,LinuxDistributionCodeName:string;
   authmodulelist,mysql_init_path,LOCATE_APACHE_MODULES_PATH:string;
   verbosed              :boolean;
   hostname              :string;
   list                  :TstringList;
   fetchmail_path        :string;
   crossroads_master_name:string;
   clamav                :Tclamav;
   spamass               :Tspamass;
   Cpureftpd             :Tpureftpd;
   spf                   :tspf;
   samba                 :Tsamba;
   mimedef               :Tmimedefang;
   bogo                  :Tbogofilter;
   squid                 :Tsquid;
   stunnel               :Tstunnel;
   dkim                  :Tdkim;
   zntpd                 :tntpd;
   kavProxy              :tkav4proxy;
   p3scan                :tp3scan;
   kas3                  :tkas3;
   dnsmasq               :tdnsmasq;
   kavmilter             :tkavmilter;
   collectd              :tcollectd;
   APP_SIMPLE_GROUPEWARE :string;
   APP_ATOPENMAIL        :string;
   mailspy               :tmailspy;
   amavis                :tamavis;
   imapsync              :timapsync;
   EnableMysqlFeatures   :integer;
   isoqlog               :tisoqlog;
   jcheckmail            :tjcheckmail;
   mailman               :tmailman;
   dhcp3                 :tdhcp3;
   ddar                  :trdiffbackup;
   openvpn               :topenvpn;
   cups                  :tcups;
   dstat                 :tdstat;
   nfs                   :tnfs;
   pol                   :tpolicyd_weight;
   tcp                   :ttcpip;
   pdns                  :tpdns;
   mysqld                :tmysql_daemon;
   openldap              :topenldap;
   assp                  :tassp;
   postfilter            :tpostfilter;
   vmwaretools           :tvmtools;
   phpldap               :tphpldapadmin;
   zarafa                :tzarafa_server;
   squidguard            :tsquidguard;
   WifiCardOk            :integer;
   wifi                  :twifi;
   APACHE_MODULES_PATH   :string;
   backuppc              :tbackuppc;
   auditd                :tauditd;
   roundcube_web_folder  :string;
   sshd                 :tsshd;
   toolsversions        :ttoolsversions;
   apachesrc            :tapachesrc;
   amanda               :tamanda;
   tomcat               :ttomcat;
   openemm              :topenemm;
   ArticaDBPath         :string;
   openldap_admin,openldap_password,openldap_server,corp,phpfpm:string;
   crossroads          :tcrossroads;
   POSTFIX_INSTALLED:boolean;
begin
       verbosed:=false;
       POSTFIX_INSTALLED:=false;
       if ParamStr(1)='--verbose' then verbosed:=true;
       if ParamStr(2)='--verbose' then verbosed:=true;
       if ParamStr(3)='--verbose' then verbosed:=true;
       if ParamStr(1)='--web-settings' then  NoExecution:=true;
       cyr:=Tcyrus.Create(SYS);
       clamav:=Tclamav.Create;
       logs.Debuglogs('##################### web_settings:: writing status for artica-postfix php service #####################');
       php_path:=GLOBAL_INI.get_ARTICA_PHP_PATH();
        if SYS.verbosed then writeln('web_settings:: 0.1%');
       authmodulelist:='';
        if verbosed then writeln('web_settings:: 0.2%');
       Cpureftpd:=Tpureftpd.Create;
        if verbosed then writeln('web_settings:: 0.3%');
       spf:=tspf.Create;
        if verbosed then writeln('web_settings:: 0.4%');
       samba:=Tsamba.Create;
       if verbosed then writeln('web_settings:: Loading SYS');
       if verbosed then writeln('web_settings:: 0.5%');
       SYS:=Tsystem.Create;
       if verbosed then writeln('web_settings:: 0.6%');
       mimedef:=Tmimedefang.Create(SYS);
       bogo:=Tbogofilter.Create;
       squid:=Tsquid.Create;
       stunnel:=Tstunnel.Create(SYS);
       dkim:=tdkim.Create(SYS);
       kav4samba:=Tkav4samba.Create();
       zntpd:=tntpd.Create;
       kavProxy:=tkav4proxy.CReate(SYS);
       fdm:=tfdm.Create(SYS);
       p3scan:=tp3scan.Create(SYS);
       spamass:=Tspamass.Create(SYS);
       mailspy:=tmailspy.Create(SYS);
       amavis:=Tamavis.Create(SYS);
       ddar:=trdiffbackup.Create;
       openvpn:=topenvpn.Create(SYS);
       sshd:=tsshd.Create(SYS);
       tomcat:=ttomcat.Create(SYS);

       toolsversions:=ttoolsversions.Create(SYS);
          forceDirectories('/etc/pango');
        if verbosed then writeln('web_settings:: -> SYS.LOCATE_APACHE_MODULES_PATH()');
       LOCATE_APACHE_MODULES_PATH:=SYS.LOCATE_APACHE_MODULES_PATH();

       WifiCardOk:=0;
       kas3:=Tkas3.Create(SYS);
       dnsmasq:=tdnsmasq.Create(SYS);
       kavmilter:=tkavmilter.Create(SYS);
       list:=TstringList.Create;
       list.Add('<?php');
       logs.Debuglogs('web_settings:: starting writing php file');
       if FileExists(GLOBAL_INI.get_ARTICA_PHP_PATH()+'/upload.php') then begin
          logs.Syslogs('Kill security hole found by no-root: see http://nonroot.blogspot.com/2008/10/i-have-reason-artica-case.html');
          logs.DeleteFile(GLOBAL_INI.get_ARTICA_PHP_PATH()+'/upload.php')
       end;




       
   if verbosed then writeln('web_settings:: 5%');
   if FileExists('/usr/local/share/artica/.lic') then begin
      corp:=trim(logs.ReadFromFile('/usr/local/share/artica/.lic'));
      StringReplace(corp, #13#10, '', [rfReplaceAll]);

      if trim(corp)='TRUE' then begin
           list.Add('$_GLOBAL["CORP_LICENSE"]=True;');
      end else begin
          if verbosed then writeln('web_settings:: 7%, license error:"',corp,'"');
      end;
   end else begin
        if verbosed then writeln('web_settings:: 7%, license error');
   end;
   if FileExists('/usr/share/artica-postfix/bin/setup-ubuntu') then if not FileExists('/etc/artica-postfix/settings/Daemons/LinuxDistributionCodeName') then logs.OutputCmd('/usr/share/artica-postfix/bin/setup-ubuntu --kill');
   if FIleExists('/etc/artica-postfix/MYCOSI_APPLIANCE') then list.Add('$_GLOBAL["MYCOSI_APPLIANCE"]=True;');
   if FIleExists('/etc/artica-postfix/SQUID_APPLIANCE') then list.Add('$_GLOBAL["SQUID_APPLIANCE"]=True;');
   if FIleExists('/etc/artica-postfix/LOAD_BALANCE_APPLIANCE') then list.Add('$_GLOBAL["LOAD_BALANCE_APPLIANCE"]=True;');
   if FIleExists('/etc/artica-postfix/SAMBA_APPLIANCE') then list.Add('$_GLOBAL["SAMBA_APPLIANCE"]=True;');
   if FIleExists('/etc/artica-postfix/GATEWAY_APPLIANCE') then list.Add('$_GLOBAL["GATEWAY_APPLIANCE"]=True;');
   if FIleExists('/etc/artica-postfix/HAPRROXY_APPLIANCE') then list.Add('$_GLOBAL["HAPRROXY_APPLIANCE"]=True;') else list.Add('$_GLOBAL["HAPRROXY_APPLIANCE"]=false;');
   if FIleExists('/etc/artica-postfix/SMTP_RELAY') then list.Add('$_GLOBAL["SMTP_APPLIANCE"]=True;') else list.Add('$_GLOBAL["SMTP_APPLIANCE"]=false;');
   if FIleExists('/etc/artica-postfix/FULL_APPLIANCE') then list.Add('$_GLOBAL["FULL_APPLIANCE"]=True;') else list.Add('$_GLOBAL["FULL_APPLIANCE"]=false;');
   if FIleExists('/etc/artica-postfix/FROM_SETUP') then list.Add('$_GLOBAL["FROM_SETUP"]=True;') else list.Add('$_GLOBAL["FROM_SETUP"]=false;');
   if FileExists('/etc/artica-postfix/KASPER_MAIL_APP') then list.Add('$_GLOBAL["KASPERSKY_SMTP_APPLIANCE"]=True;') else list.Add('$_GLOBAL["KASPERSKY_SMTP_APPLIANCE"]=false;');
   if FileExists('/etc/artica-postfix/ZARAFA_APPLIANCE') then list.Add('$_GLOBAL["ZARAFA_APPLIANCE"]=True;') else list.Add('$_GLOBAL["ZARAFA_APPLIANCE"]=false;');
   if FileExists('/etc/artica-postfix/CYRUS_APPLIANCE') then list.Add('$_GLOBAL["CYRUS_APPLIANCE"]=True;') else list.Add('$_GLOBAL["CYRUS_APPLIANCE"]=false;');
   if FileExists('/proc/user_beancounters') then list.Add('$_GLOBAL["VPS_OPENVZ"]=True;') else list.Add('$_GLOBAL["VPS_OPENVZ"]=false;');
   if FileExists('/etc/artica-postfix/LIGHT_INSTALL') then list.Add('$_GLOBAL["LIGHT_INSTALL"]=True;') else list.Add('$_GLOBAL["LIGHT_INSTALL"]=false;');
   if FileExists('/etc/artica-postfix/PROXYTINY_APPLIANCE') then list.Add('$_GLOBAL["PROXYTINY_APPLIANCE"]=True;') else list.Add('$_GLOBAL["PROXYTINY_APPLIANCE"]=false;');
   if FileExists('/usr/bin/pactester') then list.Add('$_GLOBAL["PACTESTER_INSTALLED"]=True;') else list.Add('$_GLOBAL["PACTESTER_INSTALLED"]=false;');


   if FileExists('/usr/share/tomcat6/bin/bootstrap.jar') then begin
      list.Add('$_GLOBAL["APP_TOMCAT6_INSTALLED"]=True;');
      list.Add('$_GLOBAL["APP_TOMCAT6_VERSION"]="'+tomcat.DEB_VERSION()+'";');
   end
      else begin
           list.Add('$_GLOBAL["APP_TOMCAT6_INSTALLED"]=false;');
           list.Add('$_GLOBAL["APP_TOMCAT6_VERSION"]="";');
      end;

   if FileExists('/usr/share/z-push/version.php') then list.Add('$_GLOBAL["Z_PUSH_INSTALLED"]=True;') else list.Add('$_GLOBAL["Z_PUSH_INSTALLED"]=false;');
   if FileExists('/etc/artica-postfix/INNODB_FILE_PER_TABLE_INSTALL') then list.Add('$_GLOBAL["INNODB_FILE_PER_TABLE_INSTALL"]=True;') else list.Add('$_GLOBAL["INNODB_FILE_PER_TABLE_INSTALL"]=false;');
   if FIleExists('/opt/kaspersky/klmsui/libexec/mod_klwi3.so') then list.Add('$_GLOBAL["KLMS_WEB_INSTALLED"]=True;') else list.Add('$_GLOBAL["KLMS_WEB_INSTALLED"]=false;');
   if FIleExists('/opt/kaspersky/klms/libexec/klms-milter') then list.Add('$_GLOBAL["KLMS_INSTALLED"]=True;') else list.Add('$_GLOBAL["KLMS_INSTALLED"]=false;');
   if FIleExists('/usr/share/owncloud/index.php') then list.Add('$_GLOBAL["OWNCLOUD_INSTALLED"]=True;') else list.Add('$_GLOBAL["OWNCLOUD_INSTALLED"]=false;');

   if FIleExists('/etc/artica-postfix/WEBSTATS_APPLIANCE') then begin
      list.Add('$_GLOBAL["WEBSTATS_APPLIANCE"]=True;');
      SYS.set_INFO('EnableWebProxyStatsAppliance','1');
      SYS.set_INFO('CategoriesRepositoryEnable','1');
   end else begin
        list.Add('$_GLOBAL["WEBSTATS_APPLIANCE"]=False;');
   end;
   if FIleExists(SYS.LOCATE_SMBCLIENT()) then list.Add('$_GLOBAL["smbclient_installed"]=True;') else list.Add('$_GLOBAL["smbclient_installed"]=False;');
   if FIleExists(SYS.LOCATE_ZABBIX_SERVER()) then list.Add('$_GLOBAL["ZABBIX_INSTALLED"]=True;') else list.Add('$_GLOBAL["ZABBIX_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('kinit')) then list.Add('$_GLOBAL["KINIT_INSTALLED"]=True;') else list.Add('$_GLOBAL["KINIT_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('ipband')) then list.Add('$_GLOBAL["IPBAN_INSTALLED"]=True;') else list.Add('$_GLOBAL["IPBAN_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('haproxy')) then list.Add('$_GLOBAL["HAPROXY_INSTALLED"]=True;') else list.Add('$_GLOBAL["HAPROXY_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('sshfs')) then list.Add('$_GLOBAL["SSHFS_INSTALLED"]=True;') else list.Add('$_GLOBAL["SSHFS_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('mkfs.btrfs')) then list.Add('$_GLOBAL["BTRFS_INSTALLED"]=True;') else list.Add('$_GLOBAL["BTRFS_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('gfs2_tool')) then list.Add('$_GLOBAL["GFS2_INSTALLED"]=True;') else list.Add('$_GLOBAL["GFS2_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('httrack')) then list.Add('$_GLOBAL["HTTRACK_INSTALLED"]=True;') else list.Add('$_GLOBAL["HTTRACK_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('mimedefang')) then list.Add('$_GLOBAL["MIMEDEFANG_INSTALLED"]=True;') else list.Add('$_GLOBAL["MIMEDEFANG_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('suricata')) then list.Add('$_GLOBAL["SURICATA_INSTALLED"]=True;') else list.Add('$_GLOBAL["SURICATA_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('wsgate')) then list.Add('$_GLOBAL["WSGATE_INSTALLED"]=True;') else list.Add('$_GLOBAL["WSGATE_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('urlsnarf')) then list.Add('$_GLOBAL["URLSNARF_INSTALLED"]=True;') else list.Add('$_GLOBAL["URLSNARF_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('ettercap')) then list.Add('$_GLOBAL["ETTERCAP_INSTALLED"]=True;') else list.Add('$_GLOBAL["ETTERCAP_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('ftp-proxy')) then list.Add('$_GLOBAL["APP_FTP_PROXY"]=True;') else list.Add('$_GLOBAL["APP_FTP_PROXY"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('chilli')) then list.Add('$_GLOBAL["APP_CHILLI_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_CHILLI_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('ucarp')) then list.Add('$_GLOBAL["UCARP_INSTALLED"]=True;') else list.Add('$_GLOBAL["UCARP_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('haarp')) then list.Add('$_GLOBAL["HAARP_INSTALLED"]=True;') else list.Add('$_GLOBAL["HAARP_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('cntlm')) then list.Add('$_GLOBAL["CNTLM_INSTALLED"]=True;') else list.Add('$_GLOBAL["CNTLM_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('iscsid')) then list.Add('$_GLOBAL["ISCSID_INSTALLED"]=True;') else list.Add('$_GLOBAL["ISCSID_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('vde_switch')) then list.Add('$_GLOBAL["VDESWITCH_INSTALLED"]=True;') else list.Add('$_GLOBAL["VDESWITCH_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('rdpproxy')) then list.Add('$_GLOBAL["RDPPROXY_INSTALLED"]=True;') else list.Add('$_GLOBAL["RDPPROXY_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('shorewall')) then list.Add('$_GLOBAL["SHOREWALL_INSTALLED"]=True;') else list.Add('$_GLOBAL["SHOREWALL_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('conntrackd')) then list.Add('$_GLOBAL["CONNTRACK_INSTALLED"]=True;') else list.Add('$_GLOBAL["CONNTRACK_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('wifidog')) then list.Add('$_GLOBAL["WIFIDOG_INSTALLED"]=True;') else list.Add('$_GLOBAL["WIFIDOG_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('l7-filter')) then list.Add('$_GLOBAL["l7FILTER_INSTALLED"]=True;') else list.Add('$_GLOBAL["l7FILTER_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('syncthing')) then list.Add('$_GLOBAL["SYNCTHING_INSTALLED"]=True;') else list.Add('$_GLOBAL["SYNCTHING_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('policyd-spf')) then list.Add('$_GLOBAL["POLICYD_SPF"]=True;') else list.Add('$_GLOBAL["POLICYD_SPF"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('sensors-detect')) then list.Add('$_GLOBAL["SENSORS_INSTALLED"]=True;') else list.Add('$_GLOBAL["SENSORS_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('ss5')) then list.Add('$_GLOBAL["SS5_INSTALLED"]=True;') else list.Add('$_GLOBAL["SS5_INSTALLED"]=False;');
   if FileExists('/lib/squid3/hypercache-plugin') then list.Add('$_GLOBAL["HYPERCACHE_STOREID"]=True;') else list.Add('$_GLOBAL["HYPERCACHE_STOREID"]=False;');
   if FileExists('/usr/local/sbin/firehol') then list.Add('$_GLOBAL["FIREHOL"]=True;') else list.Add('$_GLOBAL["FIREHOL"]=False;');
   if FileExists('/opt/influxdb/influxd') then list.Add('$_GLOBAL["INFLUXDB"]=True;') else list.Add('$_GLOBAL["INFLUXDB"]=False;');

   if FileExists('/etc/artica-postfix/WEBSECURIZE') then list.Add('$_GLOBAL["WEBSECURIZE"]=True;') else list.Add('$_GLOBAL["WEBSECURIZE"]=False;');
   if FileExists('/etc/artica-postfix/LANWANSAT') then list.Add('$_GLOBAL["LANWANSAT"]=True;') else list.Add('$_GLOBAL["LANWANSAT"]=False;');
   if FileExists('/etc/artica-postfix/BAMSIGHT') then list.Add('$_GLOBAL["BAMSIGHT"]=True;') else list.Add('$_GLOBAL["BAMSIGHT"]=False;');
   if FileExists('/etc/artica-postfix/STATS_APPLIANCE') then list.Add('$_GLOBAL["STATS_APPLIANCE"]=True;') else list.Add('$_GLOBAL["STATS_APPLIANCE"]=False;');
   if FileExists('/usr/bin/wanproxy') then list.Add('$_GLOBAL["WANPROXY"]=True;') else list.Add('$_GLOBAL["WANPROXY"]=False;');
   if FileExists('/usr/local/bin/krake') then list.Add('$_GLOBAL["WANPROXY"]=True;') else list.Add('$_GLOBAL["KRAKE"]=False;');


   phpfpm:=SYS.LOCATE_GENERIC_BIN('php5-fpm')  ;
   if not fileExists(phpfpm) then phpfpm:=SYS.LOCATE_GENERIC_BIN('php-fpm');
   if FileExists(phpfpm) then list.Add('$_GLOBAL["PHPFPM_INSTALLED"]=True;') else list.Add('$_GLOBAL["PHPFPM_INSTALLED"]=False;');




   if FileExists('/usr/lib/perl5/Apache2/AuthenNTLM.pm') then list.Add('$_GLOBAL["PERL_AUTHNTLM"]=True;') else list.Add('$_GLOBAL["PERL_AUTHNTLM"]=False;');

   if verbosed then writeln('web_settings:: 6%');
   if verbosed then writeln('Testsing Apache libraries in "'+LOCATE_APACHE_MODULES_PATH+'"' );
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_authnz_ldap.so') then list.Add('$_GLOBAL["APACHE_MOD_AUTHNZ_LDAP"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_AUTHNZ_LDAP"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_qos.so') then list.Add('$_GLOBAL["APACHE_MOD_QOS"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_QOS"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_security2.so') then list.Add('$_GLOBAL["APACHE_MOD_SECURITY"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_SECURITY"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_evasive20.so') then list.Add('$_GLOBAL["APACHE_MOD_EVASIVE"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_EVASIVE"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_cache.so') then list.Add('$_GLOBAL["APACHE_MOD_CACHE"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_CACHE"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_geoip.so') then list.Add('$_GLOBAL["APACHE_MOD_GEOIP"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_GEOIP"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_pagespeed.so') then list.Add('$_GLOBAL["APACHE_MOD_PAGESPEED"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_PAGESPEED"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_info.so') then list.Add('$_GLOBAL["APACHE_MOD_INFO"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_INFO"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_status.so') then list.Add('$_GLOBAL["APACHE_MOD_STATUS"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_STATUS"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_suexec.so') then list.Add('$_GLOBAL["APACHE_MOD_SUEXEC"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_SUEXEC"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_fcgid.so') then list.Add('$_GLOBAL["APACHE_MOD_FCGID"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_FCGID"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_log_sql_mysql.so') then list.Add('$_GLOBAL["APACHE_MOD_LOGSSQL"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_LOGSSQL"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_bw.so') then list.Add('$_GLOBAL["APACHE_MOD_BW"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_BW"]=False;');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_python.so') then list.Add('$_GLOBAL["APACHE_MOD_PYTHON"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_PYTHON"]=False;');
   if verbosed then writeln(LOCATE_APACHE_MODULES_PATH+'/mod_suphp.so ??');
   if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_suphp.so') then list.Add('$_GLOBAL["APACHE_MOD_SUPHP"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_SUPHP"]=False;');

   if not FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_rpaf-2.0.so') then begin
    if not NoExecution then begin
      fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/compile-apache-mod.php >/dev/null 2>&1 &');

    end;
   end;
   if FIleExists(SYS.LOCATE_PYTHON_PACKAGE('pyntlm.py')) then list.Add('$_GLOBAL["APP_PYAUTHENNTLM"]=True;') else list.Add('$_GLOBAL["APP_PYAUTHENNTLM"]=False;');




   if FIleExists(SYS.LOCATE_GENERIC_BIN('cgrulesengd')) then list.Add('$_GLOBAL["CGROUPS_INSTALLED"]=True;') else list.Add('$_GLOBAL["CGROUPS_INSTALLED"]=False;');

   crossroads:=tcrossroads.Create(SYS);
   list.add('$_GLOBAL["CROSSROADS_VERSION"]="'+crossroads.VERSION()+'";');
   crossroads.free;

   if FileExists('/etc/artica-postfix/FROM_ISO') then list.Add('$_GLOBAL["FROM_ISO"]=True;') else list.Add('$_GLOBAL["FROM_ISO"]=False;');
   if FileExists('/etc/artica-postfix/APACHE_APPLIANCE') then list.Add('$_GLOBAL["APACHE_APPLIANCE"]=True;') else list.Add('$_GLOBAL["APACHE_APPLIANCE"]=False;');
   if FileExists('/etc/artica-postfix/AS_KIMSUFFI') then list.Add('$_GLOBAL["AS_KIMSUFFI"]=True;') else list.Add('$_GLOBAL["AS_KIMSUFFI"]=False;');
   if FileExists('/etc/artica-postfix/SQUID_REVERSE_APPLIANCE') then begin
      list.Add('$_GLOBAL["SQUID_REVERSE_APPLIANCE"]=True;');
      SYS.set_INFO('SquidActHasReverse','1');
   end else begin list.Add('$_GLOBAL["SQUID_REVERSE_APPLIANCE"]=False;'); end;



   if FileExists(SYS.LOCATE_GENERIC_BIN('monit')) then list.Add('$_GLOBAL["MONIT_INSTALLED"]=True;') else list.Add('$_GLOBAL["MONIT_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('mysqld_multi')) then list.Add('$_GLOBAL["MYSQLD_MULTI_INSTALLED"]=True;') else list.Add('$_GLOBAL["MYSQLD_MULTI_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('afpd')) then list.Add('$_GLOBAL["NETATALK_INSTALLED"]=True;') else list.Add('$_GLOBAL["NETATALK_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('iptaccount')) then list.Add('$_GLOBAL["IPTABLES_ACCOUNTING_EXISTS"]=True;') else list.Add('$_GLOBAL["IPTABLES_ACCOUNTING_EXISTS"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('pdnssec')) then list.Add('$_GLOBAL["PDNSSEC_INSTALLED"]=True;') else list.Add('$_GLOBAL["PDNSSEC_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('nscd')) then list.Add('$_GLOBAL["NSCD_INSTALLED"]=True;') else list.Add('$_GLOBAL["NSCD_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('msktutil')) then list.Add('$_GLOBAL["MSKTUTIL_INSTALLED"]=True;') else list.Add('$_GLOBAL["MSKTUTIL_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('arpd')) then list.Add('$_GLOBAL["ARPD_INSTALLED"]=True;') else list.Add('$_GLOBAL["ARPD_INSTALLED"]=False;');
   if FileExists('/usr/share/drupal7/index.php') then list.Add('$_GLOBAL["DRUPAL7_INSTALLED"]=True;') else list.Add('$_GLOBAL["DRUPAL7_INSTALLED"]=False;');
   if FileExists('/usr/share/piwik/core/Version.php') then list.Add('$_GLOBAL["PIWIK_INSTALLED"]=True;') else list.Add('$_GLOBAL["PIWIK_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('quotacheck')) then list.Add('$_GLOBAL["QUOTA_INSTALLED"]=True;') else list.Add('$_GLOBAL["QUOTA_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('memcached')) then list.Add('$_GLOBAL["MEMCACHED_INSTALLED"]=True;') else list.Add('$_GLOBAL["MEMCACHED_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('freshclam')) then list.Add('$_GLOBAL["FRESHCLAM_INSTALLED"]=True;') else list.Add('$_GLOBAL["FRESHCLAM_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('UpdateUtility-Console')) then list.Add('$_GLOBAL["UPDATE_UTILITYV2_INSTALLED"]=True;') else list.Add('$_GLOBAL["UPDATE_UTILITYV2_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('freeradius')) then list.Add('$_GLOBAL["FREERADIUS_INSTALLED"]=True;') else list.Add('$_GLOBAL["FREERADIUS_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('ntpdate')) then list.Add('$_GLOBAL["NTPDATE"]=True;') else list.Add('$_GLOBAL["NTPDATE"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('nginx')) then list.Add('$_GLOBAL["NGINX_INSTALLED"]=True;') else list.Add('$_GLOBAL["NGINX_INSTALLED"]=False;');

   if FileExists('/usr/share/filez/index.php') then list.Add('$_GLOBAL["APP_FILEZ_WEB"]=True;') else list.Add('$_GLOBAL["APP_FILEZ_WEB"]=False;');
   if FileExists('/usr/local/share/artica/joomla17_src/includes/version.php') then list.Add('$_GLOBAL["JOOMLA17_INSTALLED"]=True;') else list.Add('$_GLOBAL["JOOMLA17_INSTALLED"]=False;');
   if FileExists('/usr/share/concrete5/concrete/config/version.php') then list.Add('$_GLOBAL["CONCRETE5_INSTALLED"]=True;') else list.Add('$_GLOBAL["CONCRETE5_INSTALLED"]=False;');
   if FileExists('/usr/libexec/squid/ecap_adapter_av.so') then list.Add('$_GLOBAL["ECAPAV_INSTALLED"]=True;') else list.Add('$_GLOBAL["ECAPAV_INSTALLED"]=False;');
   if FileExists('/usr/share/zarafa-webapp/index.php') then list.Add('$_GLOBAL["ZARAFA_WEBAPP_INSTALLED"]=True;') else list.Add('$_GLOBAL["ZARAFA_WEBAPP_INSTALLED"]=False;');
   if FileExists('/usr/share/zarafa-webaccess-mobile/index.php') then list.Add('$_GLOBAL["ZARAFA_WEBACCESS_MOBILE_INSTALLED"]=True;') else list.Add('$_GLOBAL["ZARAFA_WEBACCESS_MOBILE_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('ejabberd')) then list.Add('$_GLOBAL["EJABBERD_INSTALLED"]=True;') else list.Add('$_GLOBAL["EJABBERD_INSTALLED"]=False;');
   if FileExists('/usr/share/pymsnt/PyMSNt.py') then  list.Add('$_GLOBAL["PYMSNT_INSTALLED"]=True;') else list.Add('$_GLOBAL["PYMSNT_INSTALLED"]=False;');
   if FileExists('/usr/share/pyicqt/src/main.py') then  list.Add('$_GLOBAL["PYICQT_INSTALLED"]=True;') else list.Add('$_GLOBAL["PYICQT_INSTALLED"]=False;');
   if FileExists('/opt/arkeia/bin/arkboot') then list.Add('$_GLOBAL["APP_ARKEIA_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_ARKEIA_INSTALLED"]=False;');
   if FileExists('/usr/lib/jvm/default-java/bin/keytool') then list.Add('$_GLOBAL["APP_JAVA_JDK_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_JAVA_JDK_INSTALLED"]=False;');
   if FileExists('/opt/zarafa-db/bin/mysqld') then list.Add('$_GLOBAL["APP_ZARAFADB_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_ZARAFADB_INSTALLED"]=False;');
   if DirectoryExists('/opt/squidsql/data/squidlogs') then list.Add('$_GLOBAL["APP_SQUIDDB_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_SQUIDDB_INSTALLED"]=False;');

   if FileExists('/home/openemm/bin/openemm.sh') then begin
      list.Add('$_GLOBAL["OPENEMM_INSTALLED"]=True;');
      openemm:=Topenemm.Create(SYS);
      list.Add('$_GLOBAL["OPENEMM_VERSION"]="'+openemm.VERSION()+'";');
      list.Add('$_GLOBAL["OPENEMM_SENDMAIL_VERSION"]="'+openemm.SENDMAIL_VERSION()+'";');
      if FileExists('/home/openemm/sendmail/sbin/sendmail') then  list.Add('$_GLOBAL["OPENEMM_SENDMAIL_INSTALLED"]=True;') else list.Add('$_GLOBAL["OPENEMM_SENDMAIL_INSTALLED"]=False;');
      openemm.Free;
   end else begin
      list.Add('$_GLOBAL["OPENEMM_INSTALLED"]=False;');
      list.add('$_GLOBAL["OPENEMM_VERSION"]="";');
      list.add('$_GLOBAL["OPENEMM_SENDMAIL_VERSION"]="";');
      list.Add('$_GLOBAL["OPENEMM_SENDMAIL_INSTALLED"]=False;');
   end;



   if FIleExists(tomcat.BIN_PATH()) then begin
      list.Add('$_GLOBAL["TOMCAT_INSTALLED"]=True;');
      list.add('$_GLOBAL["TOMCAT_VERSION"]="'+tomcat.VERSION()+'";');
      list.add('$_GLOBAL["TOMCAT_JAVA"]="'+tomcat.JAVA_HOME_GET()+'";');
      list.add('$_GLOBAL["TOMCAT_DIR"]="'+tomcat.ROOT_DIR()+'";');
      if FIleExists(LOCATE_APACHE_MODULES_PATH+'/mod_jk.so') then list.Add('$_GLOBAL["APACHE_MOD_TOMCAT"]=True;') else list.Add('$_GLOBAL["APACHE_MOD_TOMCAT"]=False;');
   end else begin
      list.Add('$_GLOBAL["TOMCAT_INSTALLED"]=False;');
      list.add('$_GLOBAL["TOMCAT_VERSION"]="";');
      list.add('$_GLOBAL["TOMCAT_JAVA"]="";');
      list.add('$_GLOBAL["TOMCAT_DIR"]="";');
      list.Add('$_GLOBAL["APACHE_MOD_TOMCAT"]=False;');
   end;
   tomcat.free;

   amanda:=tamanda.Create(SYS);
   if FileExists(amanda.BIN_PATH()) then list.Add('$_GLOBAL["APP_AMANDA_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_AMANDA_INSTALLED"]=False;');
   amanda.Free;

   if FIleExists(SYS.LOCATE_GENERIC_BIN('ietd')) then list.add('$_GLOBAL["ISCSI_INSTALLED"]=True;') else list.Add('$_GLOBAL["ISCSI_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('iscsiadm')) then list.add('$_GLOBAL["ISCSI_CLIENT_INSTALLED"]=True;') else list.Add('$_GLOBAL["ISCSI_CLIENT_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('lxc-version')) then list.add('$_GLOBAL["LXC_INSTALLED"]=True;') else list.Add('$_GLOBAL["LXC_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('vconfig')) then list.add('$_GLOBAL["VLAN_INSTALLED"]=True;') else list.Add('$_GLOBAL["VLAN_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('losetup')) then list.add('$_GLOBAL["LOSETUP_INSTALLED"]=True;') else list.Add('$_GLOBAL["LOSETUP_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('snort')) then list.add('$_GLOBAL["SNORT_INSTALLED"]=True;') else list.Add('$_GLOBAL["SNORT_INSTALLED"]=False;');
   if FileExists('/usr/local/share/artica/eyeos_src/eyeos/extern/js/eyeos.js') then begin
      list.add('$_GLOBAL["APP_EYEOS_INSTALLED"]=True;');
      list.add('$_GLOBAL["EYEOS_VERSION"]="'+ toolsversions.EYEOS_VERSION()+'";');

   end else begin
       list.Add('$_GLOBAL["APP_EYEOS_INSTALLED"]=False;');
       list.add('$_GLOBAL["EYEOS_VERSION"]="";');
   end;
    if verbosed then writeln('web_settings:: 6%');


   if verbosed then writeln('web_settings:: 6%');
   if SYS.IS_INSIDE_VPS() then list.add('$_GLOBAL["AS_VPS_CLIENT"]=True;') else list.Add('$_GLOBAL["AS_VPS_CLIENT"]=False;');
   list.Add('$_GLOBAL["disks_size"]="' + SYS.DISKS_STATUS_DEV()+'";');
   list.Add('$_GLOBAL["disks_inodes"]="' + trim(SYS.DISKS_INODE_DEV())+'";');
   list.Add('$_GLOBAL["LOCATE_AUTHLOG_PATH"]="' + trim(SYS.LOCATE_AUTHLOG_PATH())+'";');


   if verbosed then writeln('web_settings:: 10%');
   // vf http://arnaud.aucher.net/?page_id=80
   if FIleExists(SYS.LOCATE_GENERIC_BIN('racoon')) then list.Add('$_GLOBAL["RACOON_INSTALLED"]=True;') else list.Add('$_GLOBAL["RACOON_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('pptpd')) then list.Add('$_GLOBAL["PPTPD_INSTALLED"]=True;') else list.Add('$_GLOBAL["PPTPD_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('pptp')) then list.Add('$_GLOBAL["PPTP_INSTALLED"]=True;') else list.Add('$_GLOBAL["PPTP_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('ipsec')) then list.Add('$_GLOBAL["IPSEC_INSTALLED"]=True;') else list.Add('$_GLOBAL["IPSEC_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('apt-mirror')) then list.Add('$_GLOBAL["APT_MIRROR_INSTALLED"]=True;') else list.Add('$_GLOBAL["APT_MIRROR_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('greensql-fw')) then list.Add('$_GLOBAL["APP_GREENSQL_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_GREENSQL_INSTALLED"]=False;');
   if FileExists('/root/.dropbox-dist/dropbox') then list.Add('$_GLOBAL["DROPBOX_INSTALLED"]=True;') else list.Add('$_GLOBAL["DROPBOX_INSTALLED"]=False;');

   if FileExists(SYS.LOCATE_GENERIC_BIN('tc')) then begin
      list.Add('$_GLOBAL["qos_tools_installed"]=True;');
      list.Add('$_GLOBAL["tc_version"]="'+global_ini.TC_VERSION()+'";');
   end else begin
      list.Add('$_GLOBAL["qos_tools_installed"]=False;');
   end;

   if FIleExists(SYS.LOCATE_GENERIC_BIN('vnstati')) then begin
      list.Add('$_GLOBAL["APP_VNSTAT_INSTALLED"]=True;');
      if FileExists('/usr/share/artica-postfix/exec.vnstat.php') then SYS.THREAD_COMMAND_SET(SYS.LOCATE_PHP5_BIN()+ ' /usr/share/artica-postfix/exec.vnstat.php --stats');
   end else begin
      list.Add('$_GLOBAL["APP_VNSTAT_INSTALLED"]=False;');

   end;

   if verbosed then writeln('web_settings:: 15%');
   SYS.set_INFO('syslog_path',SYS.LOCATE_SYSLOG_PATH());

   if not TryStrToInt(SYS.GET_INFO('EnableMysqlFeatures'),EnableMysqlFeatures) then EnableMysqlFeatures:=1;
   if verbosed then writeln('web_settings:: 16%');

   LinuxDistributionCodeName:=SYS.GET_INFO('LinuxDistributionCodeName');
   if FileExists('/usr/share/artica-postfix/bin/setup-ubuntu') then begin
      if length(LinuxDistributionCodeName)=0 then begin
         fpsystem('/usr/share/artica-postfix/bin/setup-ubuntu --distri >/dev/null');
         LinuxDistributionCodeName:=SYS.GET_INFO('LinuxDistributionCodeName');
      end;
   end;
   if verbosed then writeln('web_settings:: 17%');
   list.Add('$_GLOBAL["LinuxDistriCode"]="'+SYS.GET_INFO('LinuxDistributionCodeName')+'";');
   list.Add('$_GLOBAL["LinuxDistriFullName"]="'+SYS.GET_INFO('LinuxDistributionFullName')+'";');
   list.Add('$_GLOBAL["ArchStruct"]="'+IntToStr(SYS.ArchStruct())+'";');
   list.Add('$_GLOBAL["OPENSSH_VER"]="'+sshd.VERSION()+'";');
   list.Add('$_GLOBAL["PEAR_PACKAGES"]="'+SYS.PEAR_MODULES()+'";');
   if verbosed then writeln('web_settings:: 18%');


   if verbosed then writeln('web_settings:: 19%');
   openldap:=topenldap.Create;
   if verbosed then writeln('web_settings:: 20%');
   list.Add('$_GLOBAL["SLAPD_CONF_PATH"]="'+openldap.SLAPD_CONF_PATH()+'";');
   if FileExists(openldap.FindModulepath('syncprov.so')) then begin
      list.Add('$_GLOBAL["LDAP_SYNCPROV"]=True;');
   end else begin
       if FileExists(openldap.FindModulepath('syncprov-2.4.so.2')) then begin
         list.Add('$_GLOBAL["LDAP_SYNCPROV"]=True;');
       end else begin
         list.Add('$_GLOBAL["LDAP_SYNCPROV"]=False;');
       end;
   end;
   if FileExists(openldap.FindModulepath('back_meta.so')) then list.Add('$_GLOBAL["LDAP_BACKMETA"]=True;') else list.Add('$_GLOBAL["LDAP_BACKMETA"]=False;');
   if FileExists(openldap.FindModulepath('back_ldap.so')) then list.Add('$_GLOBAL["LDAP_BACKLDAP"]=True;') else list.Add('$_GLOBAL["LDAP_BACKLDAP"]=False;');
   if FileExists(openldap.FindModulepath('back_relay.so')) then list.Add('$_GLOBAL["LDAP_BACKRELAY"]=True;') else list.Add('$_GLOBAL["LDAP_BACKRELAY"]=False;');
   if FileExists(openldap.FindModulepath('rwm.so')) then list.Add('$_GLOBAL["LDAP_RWM"]=True;') else list.Add('$_GLOBAL["LDAP_RWM"]=False;');


   if verbosed then writeln('web_settings:: 20%');
   phpldap:=Tphpldapadmin.Create(SYS);
   if FileExists(phpldap.BIN_PATH()) then list.Add('$_GLOBAL["phpldapadmin_installed"]=True;') else list.Add('$_GLOBAL["phpldapadmin_installed"]=False;');
   phpldap.FRee;
   if FileExists('/usr/share/phpmyadmin/index.php') then list.Add('$_GLOBAL["phpmyadmin_installed"]=True;') else list.Add('$_GLOBAL["phpmyadmin_installed"]=False;');

   if FIleExists('/etc/artica-postfix/KASPERSKY_WEB_APPLIANCE') then begin
      list.Add('$_GLOBAL["KASPERSKY_WEB_APPLIANCE"]=True;');
      if not FileExists('/opt/kaspersky/kav4proxy/bin/kav4proxy-keepup2date') then SYS.THREAD_COMMAND_SET('/usr/share/artica-postfix/bin/artica-make APP_KAV4PROXY');
      if not FileExists(samba.SMBD_PATH()) then SYS.THREAD_COMMAND_SET('/usr/share/artica-postfix/bin/artica-make APP_SAMBA');
      if not FileExists(SYS.LOCATE_GENERIC_BIN('ufdbguardd')) then SYS.THREAD_COMMAND_SET('/usr/share/artica-postfix/bin/artica-make APP_UFDBGUARD');

   end else begin
   list.Add('$_GLOBAL["KASPERSKY_WEB_APPLIANCE"]=False;');
   end;

   if FIleExists('/etc/artica-postfix/OPENVPN_APPLIANCE') then  list.Add('$_GLOBAL["OPENVPN_APPLIANCE"]=True;') else  list.Add('$_GLOBAL["OPENVPN_APPLIANCE"]=False;');
   if FIleExists('/etc/artica-postfix/WORDPRESS_APPLIANCE') then  list.Add('$_GLOBAL["WORDPRESS_APPLIANCE"]=True;') else  list.Add('$_GLOBAL["WORDPRESS_APPLIANCE"]=False;');

   
   // collectd
   collectd:=tcollectd.Create(SYS);
   if FileExists(collectd.BIN_PATH()) then begin
       list.Add('$_GLOBAL["collectd_installed"]=True;');
       list.Add(collectd.PHP_DATA_DIR())
    end else begin
        list.Add('$_GLOBAL["collectd_installed"]=False;');
    end;
   collectd.Free;

     if verbosed then writeln('web_settings:: 25%');
   if FileExists('/usr/sbin/automount') then list.Add('$_GLOBAL["autofs_installed"]=True;') else list.Add('$_GLOBAL["autofs_installed"]=False;');

   //TCP
   tcp:=ttcpip.CReate;
   list.Add('$_GLOBAL["TCP_ARRAY"]=array('+tcp.PHP_INTERFACES()+');');
   // Imapsync
   imapsync:=timapsync.Create(SYS);
   if FileExists(imapsync.BIN_PATH()) then list.Add('$_GLOBAL["imapsync_installed"]=True;') else list.Add('$_GLOBAL["imapsync_installed"]=False;');
   //mailsync
   if FileExists(imapsync.MAILSYNC_BIN_PATH()) then list.Add('$_GLOBAL["mailsync_installed"]=True;') else list.Add('$_GLOBAL["mailsync_installed"]=False;');
   imapsync.Free;



   //winexe
   if FileExists('/usr/bin/winexe') then list.Add('$_GLOBAL["winexe_installed"]=True;') else list.Add('$_GLOBAL["winexe_installed"]=False;');

   //OCS
   if FileExists('/usr/share/ocsinventory-reports/ocsreports/index.php') then list.Add('$_GLOBAL["OCSI_INSTALLED"]=True;') else list.Add('$_GLOBAL["OCSI_INSTALLED"]=False;');

   //dhcp
   dhcp3:=tdhcp3.CReate(SYS);
   if FileExists(dhcp3.BIN_PATH()) then list.Add('$_GLOBAL["dhcp_installed"]=True;') else list.Add('$_GLOBAL["dhcp_installed"]=False;');

   //glfuse
   if FileExists(SYS.LOCATE_GENERIC_BIN('glusterfsd')) then list.Add('$_GLOBAL["GLUSTER_INSTALLED"]=True;') else list.Add('$_GLOBAL["GLUSTER_INSTALLED"]=False;');




   //pdns
   pdns:=tpdns.Create(SYS);
   if FileExists(pdns.BIN_PATH()) then begin
          list.Add('$_GLOBAL["POWER_DNS_INSTALLED"]=True;');
          list.Add('$_GLOBAL["POWER_DNS_MYSQL"]=True;');
          if FileExists('/usr/share/poweradmin/index.php') then  list.Add('$_GLOBAL["POWERADMIN_INSTALLED"]=True;') else list.Add('$_GLOBAL["POWERADMIN_INSTALLED"]=False;');
   end else begin
       list.Add('$_GLOBAL["POWER_DNS_INSTALLED"]=False;');
       list.Add('$_GLOBAL["POWER_DNS_MYSQL"]=False;');
       list.Add('$_GLOBAL["POWERADMIN_INSTALLED"]=False;');
   end;



   pdns.free;

   //zarafa
   zarafa:=tzarafa_server.Create(SYS);
   if FileExists(zarafa.SERVER_BIN_PATH()) then begin
      list.ADD('$_GLOBAL["ZARAFA_INSTALLED"]=True;');
      if FileExists(SYS.LOCATE_GENERIC_BIN('zarafa-search')) then list.ADD('$_GLOBAL["ZARAFA_SEARCH_INSTALLED"]=True;') else list.Add('$_GLOBAL["ZARAFA_SEARCH_INSTALLED"]=False;');
      if FileExists(SYS.LOCATE_GENERIC_BIN('zarafa-indexer')) then list.ADD('$_GLOBAL["ZARAFA_INDEXER_INSTALLED"]=True;') else list.Add('$_GLOBAL["ZARAFA_INDEXER_INSTALLED"]=False;');



   end else begin
       list.Add('$_GLOBAL["ZARAFA_INSTALLED"]=False;');
   end;

   zarafa.free;

   //DAR
   if FileExists(ddar.dar_bin_path()) then list.Add('$_GLOBAL["dar_installed"]=True;') else list.Add('$_GLOBAL["dar_installed"]=False;');

   //CRYPTSETUP
   if FileExists(SYS.LOCATE_CRYPTSETUP()) then list.Add('$_GLOBAL["CRYPTSETUP_INSTALLED"]=True;') else list.Add('$_GLOBAL["CRYPTSETUP_INSTALLED"]=False;');

   //openvpn
   if FileExists(openvpn.BIN_PATH()) then list.Add('$_GLOBAL["OPENVPN_INSTALLED"]=True;') else list.Add('$_GLOBAL["OPENVPN_INSTALLED"]=False;');
   openvpn.free;

   //lvm
   if FIleExists(SYS.LOCATE_PVCREATE()) then list.Add('$_GLOBAL["LVM_INSTALLED"]=True;') else list.Add('$_GLOBAL["LVM_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('quotacheck')) then list.Add('$_GLOBAL["QUOTA_INSTALLED"]=True;') else list.Add('$_GLOBAL["QUOTA_INSTALLED"]=False;');



   if FIleExists(SYS.LOCATE_GENERIC_BIN('ltsp-build-client')) then list.Add('$_GLOBAL["LTSP_INSTALLED"]=True;') else list.Add('$_GLOBAL["LTSP_INSTALLED"]=False;');
   if FIleExists('/opt/kaspersky/UpdateUtility/UpdateUtility-Console') then list.Add('$_GLOBAL["KASPERSKY_UPDATE_UTILITY_INSTALLED"]=True;') else list.Add('$_GLOBAL["KASPERSKY_UPDATE_UTILITY_INSTALLED"]=False;');


   //mysql-cluster
   if FIleExists(SYS.LOCATE_NDB_MGMD()) then list.Add('$_GLOBAL["MYSQL_NDB_MGMD_INSTALLED"]=True;') else list.Add('$_GLOBAL["MYSQL_NDB_MGMD_INSTALLED"]=False;');

   //rsync
   if FileExists(SYS.LOCATE_GENERIC_BIN('rsync')) then list.Add('$_GLOBAL["RSYNC_INSTALLED"]=True;') else list.Add('$_GLOBAL["RSYNC_INSTALLED"]=False;');

   //DRUPAL
   if FileExists('/usr/share/drupal/install.php') then list.Add('$_GLOBAL["DRUPAL_INSTALLED"]=True;') else list.Add('$_GLOBAL["DRUPAL_INSTALLED"]=False;');

   //emailrelay
   if FileExists(SYS.LOCATE_GENERIC_BIN('emailrelay')) then list.Add('$_GLOBAL["EMAILRELAY_INSTALLED"]=True;') else list.Add('$_GLOBAL["EMAILRELAY_INSTALLED"]=False;');

   //mldonkey
   if FileExists(SYS.LOCATE_GENERIC_BIN('mlnet')) then list.Add('$_GLOBAL["MLDONKEY_INSTALLED"]=True;') else list.Add('$_GLOBAL["MLDONKEY_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('curlftpfs')) then list.Add('$_GLOBAL["CURLFTPFS_INSTALLED"]=True;') else list.Add('$_GLOBAL["CURLFTPFS_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('mount.cifs')) then list.Add('$_GLOBAL["CIFS_INSTALLED"]=True;') else list.Add('$_GLOBAL["CIFS_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('mount.davfs')) then list.Add('$_GLOBAL["DAVFS_INSTALLED"]=True;') else list.Add('$_GLOBAL["DAVFS_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('shorewall')) then list.Add('$_GLOBAL["SHOREWALL_INSTALLED"]=True;') else list.Add('$_GLOBAL["SHOREWALL_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('vsftpd')) then list.Add('$_GLOBAL["VSFTPD_INSTALLED"]=True;') else list.Add('$_GLOBAL["VSFTPD_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('miniupnpd')) then list.Add('$_GLOBAL["MINIUPNPD_INSTALLED"]=True;') else list.Add('$_GLOBAL["MINIUPNPD_INSTALLED"]=False;');

   //auditd
   auditd:=Tauditd.Create(SYS);
   if FileExists(auditd.BIN_PATH()) then list.Add('$_GLOBAL["APP_AUDITD_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_AUDITD_INSTALLED"]=False;');



   if verbosed then writeln('web_settings:: 30%');
   if FileExists('/opt/kaspersky/kav4fs/bin/kav4fs-control') then list.Add('$_GLOBAL["KAV4FS_INSTALLED"]=True;') else list.Add('$_GLOBAL["KAV4FS_INSTALLED"]=False;');
   if FileExists('/usr/local/bin/ocsinventory-agent') then list.Add('$_GLOBAL["OCS_LNX_AGENT_INSTALLED"]=True;') else list.Add('$_GLOBAL["OCS_LNX_AGENT_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('VirtualBox')) then list.Add('$_GLOBAL["VIRTUALBOX_INSTALLED"]=True;') else list.Add('$_GLOBAL["VIRTUALBOX_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('in.tftpd')) then list.Add('$_GLOBAL["TFTPD_INSTALLED"]=True;') else list.Add('$_GLOBAL["TFTPD_INSTALLED"]=False;');
   if FileExists('/opt/thinstation/build') then list.Add('$_GLOBAL["THINSTATION_INSTALLED"]=True;') else list.Add('$_GLOBAL["THINSTATION_INSTALLED"]=False;');
   if FileExists(SYS.LOCATE_GENERIC_BIN('xr')) then list.Add('$_GLOBAL["crossroads_installed"]=True;') else list.Add('$_GLOBAL["crossroads_installed"]=False;');

   if FileExists(SYS.LOCATE_GENERIC_BIN('fusermount')) then begin
      logs.Debuglogs('DEDUPLICATION: fusermount found');
       if FileExists(SYS.LOCATE_GENERIC_BIN('zfs-fuse')) then begin
             logs.Debuglogs('DEDUPLICATION: zfs-fuse found');
             if FileExists(SYS.LOCATE_GENERIC_BIN('tcamgr')) then begin
                 logs.Debuglogs('DEDUPLICATION: tcamgr found');
                if FileExists(SYS.LOCATE_GENERIC_BIN('lessfs')) then begin
                   logs.Debuglogs('DEDUPLICATION: lessfs found');
                   list.Add('$_GLOBAL["deduplication_installed"]=True;')
                end else begin
                    logs.Debuglogs('DEDUPLICATION: lessfs not found');
                end;
             end;
       end;
   end;

   if bdb_recover_check() then list.Add('$_GLOBAL["DB_RECOVER_INSTALLED"]=True;') else list.Add('$_GLOBAL["DB_RECOVER_INSTALLED"]=False;');

   //BackupPC
   backuppc:=Tbackuppc.Create(SYS);
   if FileExists(backuppc.BIN_PATH()) then begin
      list.Add('$_GLOBAL["BACKUPPC_INSTALLED"]=True;');
      list.Add('$_GLOBAL["BACKUPPC_BIN_PATH"]="'+backuppc.BIN_PATH()+'";');
   end
      else begin
           list.Add('$_GLOBAL["BACKUPPC_INSTALLED"]=False;');
      end;
   //cpu,mem...
   list.Add('$_GLOBAL["CPU_NUMBER"]="'+ IntToStr(sys.CPU_NUMBER())+'";');
   list.Add('$_GLOBAL["LOAD_AVERAGE"]="'+ sys.LOAD_AVERAGE()+'";');

   //hostapd


   if FileExists(SYS.LOCATE_GENERIC_BIN('wpa_supplicant')) then list.Add('$_GLOBAL["WPA_SUPPLIANT_INSTALLED"]=True;') else list.Add('$_GLOBAL["WPA_SUPPLIANT_INSTALLED"]=False;');

   if FileExists(SYS.LOCATE_GENERIC_BIN('hostapd')) then begin
      wifi:=twifi.Create(SYS);
      list.Add('$_GLOBAL["HOSTAPD_INSTALLED"]=True;');
      list.Add('$_GLOBAL["HOSTAPD_BINVER"]="'+IntTOSTr(wifi.HOSTAPD_BINVER())+'";');
   end else begin
    list.Add('$_GLOBAL["HOSTAPD_INSTALLED"]=False;');
   end;



   //smartd
   if FileExists('/usr/sbin/smartctl') then list.Add('$_GLOBAL["SMARTMONTOOLS_INSTALLED"]=True;') else list.Add('$_GLOBAL["SMARTMONTOOLS_INSTALLED"]=False;');
   if FileExists('/usr/bin/iostat') then begin
      list.Add('$_GLOBAL["IOSTAT_INSTALLED"]=True;');
      list.Add('$_GLOBAL["IOSTAT_ARRAY"]=array('+ IOSTAT()+');');
   end else begin
       list.Add('$_GLOBAL["IOSTAT_INSTALLED"]=False;');
   end;

   if  SYS.ISMemoryHiger1G() then list.Add('$_GLOBAL["MEM_HIGER_1G"]=True;') else list.Add('$_GLOBAL["MEM_HIGER_1G"]=False;');


   //dstat
   if FileExists('/usr/bin/dstat') then begin
       list.Add('$_GLOBAL["DSTAT_INSTALLED"]=True;');
       dstat:=Tdstat.Create(SYS);
       if dstat.IS_GNUPLOT_PNG() then list.Add('$_GLOBAL["GNUPLOT_PNG"]=True;') else list.Add('$_GLOBAL["GNUPLOT_PNG"]=False;');
       dstat.free;
    end else begin
        list.Add('$_GLOBAL["DSTAT_INSTALLED"]=False;');
    end;

    //vmware
    if SYS.VMWARE_HOST() then begin
         list.Add('$_GLOBAL["VMWARE_HOST"]=True;');
         vmwaretools:=tvmtools.Create(SYS);
         if FIleExists(vmwaretools.BIN_PATH()) then list.Add('$_GLOBAL["VMWARE_TOOLS_INSTALLED"]=True;') else list.Add('$_GLOBAL["VMWARE_TOOLS_INSTALLED"]=False;');
    end else begin
         list.Add('$_GLOBAL["VMWARE_HOST"]=False;');
         list.Add('$_GLOBAL["VMWARE_TOOLS_INSTALLED"]=False;');
    end;


    if SYS.VIRTUALBOX_HOST() then begin
        list.Add('$_GLOBAL["VIRTUALBOX_HOST"]=True;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('VBoxService')) then list.Add('$_GLOBAL["APP_VBOXADDINTION_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_VBOXADDINTION_INSTALLED"]=false;');
    end else begin
         list.Add('$_GLOBAL["VIRTUALBOX_HOST"]=False;');
         list.Add('$_GLOBAL["APP_VBOXADDINTION_INSTALLED"]=False;');
    end;

     if SYS.XenServer() then begin
        list.Add('$_GLOBAL["XEN_HOST"]=True;');
      end else begin
         list.Add('$_GLOBAL["XEN_HOST"]=False;');
    end;

     if SYS.HyperV() then begin
        list.Add('$_GLOBAL["HYPERV_HOST"]=True;');
      end else begin
         list.Add('$_GLOBAL["HYPERV_HOST"]=False;');
    end;



    //nfs
    nfs:=tnfs.Create(SYS);
    if FileExists(nfs.BIN_PATH()) then list.Add('$_GLOBAL["NFS_SERVER_INTSALLED"]=True;') else list.Add('$_GLOBAL["NFS_SERVER_INTSALLED"]=False;');
    nfs.free;

   if FileExists('/usr/local/share/artica/opengoo/version.php') then list.Add('$_GLOBAL["OPENGOO_INSTALLED"]=True;') else list.Add('$_GLOBAL["OPENGOO_INSTALLED"]=False;');
   if FileExists('/usr/local/share/artica/joomla_src/includes/mambo.php') then list.Add('$_GLOBAL["JOOMLA_INSTALLED"]=True;') else list.Add('$_GLOBAL["JOOMLA_INSTALLED"]=False;');
   if FileExists('/usr/local/share/artica/sugarcrm_src/sugar_version.php') then list.Add('$_GLOBAL["SUGARCRM_INSTALLED"]=True;') else list.Add('$_GLOBAL["SUGARCRM_INSTALLED"]=False;');
   if FIleExists('/usr/local/share/artica/lmb_src/__install_lmb_files/bdd/bdd_liste_files.txt') then list.Add('$_GLOBAL["LMB_LUNDIMATIN_INSTALLED"]=True;') else list.Add('$_GLOBAL["LMB_LUNDIMATIN_INSTALLED"]=False;');
   if FIleExists('/usr/local/share/artica/group-office/classes/base/config.class.inc.php') then  list.Add('$_GLOBAL["GROUPOFFICE_INSTALLED"]=True;') else list.Add('$_GLOBAL["GROUPOFFICE_INSTALLED"]=False;');
   if FIleExists('/usr/local/share/artica/piwigo_src/include/constants.php') then  list.Add('$_GLOBAL["PIWIGO_INSTALLED"]=True;') else list.Add('$_GLOBAL["PIWIGO_INSTALLED"]=False;');
   if FIleExists('/usr/share/wordpress-src/wp-includes/version.php') then  list.Add('$_GLOBAL["WORDPRESS_INSTALLED"]=True;') else list.Add('$_GLOBAL["WORDPRESS_INSTALLED"]=False;');
   if FIleExists('/opt/yaffas/webmin/miniserv.pl') then  list.Add('$_GLOBAL["YAFFAS_INSTALLED"]=True;') else list.Add('$_GLOBAL["YAFFAS_INSTALLED"]=False;');
   if FIleExists('/opt/kaspersky/khse/libexec/libms-icap.so') then list.Add('$_GLOBAL["APP_KHSE_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_KHSE_INSTALLED"]=False;');
   if FIleExists(SYS.LOCATE_GENERIC_BIN('sabnzbdplus')) then  list.Add('$_GLOBAL["APP_SABNZBDPLUS_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_SABNZBDPLUS_INSTALLED"]=False;');

   ArticaDBPath:=SYS.GET_INFO('ArticaDBPath');
   if length(ArticaDBPath) = 0 then ArticaDBPath:='/opt/articatech';

   if FIleExists(ArticaDBPath+'/bin/articadb') then  list.Add('$_GLOBAL["ARTICADB_INSTALLED"]=True;') else list.Add('$_GLOBAL["ARTICADB_INSTALLED"]=False;');


      if not FileExists(php_path) then begin
          LOGS.logs('thProcThread.web_settings()::ERROR -> Unable to locate ressourcespath [' + php_path + ']');
          exit;
      end;

      logs.Debuglogs('web_settings() -> quarantine -> ' + GLOBAL_INI.PROCMAIL_QUARANTINE_PATH());
      if not DirectoryExists(GLOBAL_INI.PROCMAIL_QUARANTINE_PATH()) then begin
         forcedirectories(GLOBAL_INI.PROCMAIL_QUARANTINE_PATH());
          if not NoExecution then begin
                   fpsystem('/bin/chown ' + GLOBAL_INI.PROCMAIL_USER() +' ' +  GLOBAL_INI.PROCMAIL_QUARANTINE_PATH() + ' >/dev/null 2>&1');
          end;
      end;



    application_postgrey:='False';
    courier_authdaemon:='False';
    courier_imap:='False';
    courier_imap_ssl:='False';
    courier_pop:='False';
    courier_pop_ssl:='False';
    kav_mail:='False';


    if FileExists('/opt/kav/5.5/kav4mailservers/bin/aveserver') then kav_mail:='True';
    if FileExists('/etc/init.d/aveserver') then kav_mail:='True';


    list.Add('$_GLOBAL["postgrey"]=' +application_postgrey + ';');
    list.Add('$_GLOBAL["courier_authdaemon"]=' +courier_authdaemon + ';');
    list.Add('$_GLOBAL["courier_imap"]=' +courier_imap + ';');
    list.Add('$_GLOBAL["courier_imap_ssl"]=' +courier_imap_ssl + ';');
    list.Add('$_GLOBAL["courier_pop"]=' +courier_pop + ';');
    list.Add('$_GLOBAL["courier_pop_ssl"]=' +courier_pop_ssl + ';');
    list.Add('$_GLOBAL["kav_mail"]=' +kav_mail + ';');
    list.Add('$_GLOBAL["authmodulelist"]="' +  authmodulelist + '";');
    list.Add('$_GLOBAL["kav_mail"]=' +  kav_mail + ';');
    list.Add('$_GLOBAL["kav_ver"]="' +  GLOBAL_INI.get_INFOS('kaspersky_version') + '";');
    list.Add('$_GLOBAL["aveserver_pattern_date"]="' +  GLOBAL_INI.AVESERVER_PATTERN_DATE() + '";');
    list.Add('$_GLOBAL["ARTICA_ROOT_PATH"]="' +  GLOBAL_INI.get_ARTICA_PHP_PATH() + '";');
    list.Add('$_GLOBAL["maillog_path"]="' +  SYS.MAILLOG_PATH() + '";');
    list.Add('$_GLOBAL["PHP_BIN_PATH"]="' +  SYS.LOCATE_PHP5_BIN() + '";');
    list.Add('$_GLOBAL["EXEC_NICE"]="' +  SYS.EXEC_NICE()+ '";');

    if length(SYS.LOCATE_GENERIC_BIN('hdparm'))>0 then list.Add('$_GLOBAL["HDPARM_INSTALLED"]=True;') else list.Add('$_GLOBAL["HDPARM_INSTALLED"]=False;');
    
    //------------ openldap
    if FileExists(SYS.LOCATE_SLAPD()) then  begin
        list.Add('$_GLOBAL["openldap_installed"]=True;');
        if FileExists('/etc/artica-postfix/no-ldap-change') then list.Add('$_GLOBAL["SLPAD_LOCKED"]=True;') else list.Add('$_GLOBAL["SLPAD_LOCKED"]=False;');
        if mldap.USE_SUSE_SCHEMA()=True then list.Add('$_GLOBAL["USE_SUSE_SCHEMA"]=True;') else list.Add('$_GLOBAL["USE_SUSE_SCHEMA"]=False;');
        if mldap.IS_DYNALITS() then list.Add('$_GLOBAL["OPENLDAP_DYNLIST"]=True;') else list.Add('$_GLOBAL["OPENLDAP_DYNLIST"]=False;');
     end else begin
         list.Add('$_GLOBAL["openldap_installed"]=false;');
     end;


     
    if FIleExists('/usr/share/dotclear/index.php') then list.Add('$_GLOBAL["DOTCLEAR_INSTALLED"]=True;') else list.Add('$_GLOBAL["DOTCLEAR_INSTALLED"]=false;');

    xapian:=txapian.Create(SYS);
    if FileExists(xapian.PHP_SO_PATH()) then list.Add('$_GLOBAL["XAPIAN_PHP_INSTALLED"]=True;') else list.Add('$_GLOBAL["XAPIAN_PHP_INSTALLED"]=false;');
    xapian.free;



    openldap_admin:=trim(GLOBAL_INI.get_LDAP('admin'));
    openldap_password:=trim(GLOBAL_INI.get_LDAP('password'));
    openldap_server:=trim(GLOBAL_INI.get_LDAP('server'));

    if length(trim(openldap_admin))=0 then openldap_admin:=get_LDAP_ADMIN();
    if length(trim(openldap_password))=0 then openldap_password:=get_LDAP_PASSWORD();




    if length(openldap_admin)=0 then begin
       writeln('Warning openldap admin length = 0');
       if openldap_server='127.0.0.1' then begin
          if not FileExists(SYS.LOCATE_SLAPD()) then begin
               openldap_admin:='Manager';
               if length(trim(openldap_password))=0 then openldap_password:='secret';
          end else begin
               if not FileExists(mldap.SLAPD_CONF_PATH()) then begin
                    writeln('Warning slpad.conf, no such file, restarting LDAP server');
                    fpsystem('/usr/share/artica-postfix/bin/artica-install --slapdconf');
               end;
          end;
       end;
    end;



    list.Add('$_GLOBAL["ldap_admin"]="' +  openldap_admin + '";');
    list.Add('$_GLOBAL["ldap_password"]=''' + openldap_password + ''';');
    list.Add('$_GLOBAL["ldap_root_database"]="' +  GLOBAL_INI.get_LDAP('suffix') + '";');
    list.Add('$_GLOBAL["ldap_host"]="' +  openldap_server+ '";');
    list.Add('$_GLOBAL["ldap_port"]="' +  GLOBAL_INI.get_LDAP('port') + '";');
    list.Add('$_GLOBAL["cyrus_ldap_admin"]="' +  GLOBAL_INI.get_LDAP('cyrus_admin') + '";');
    list.Add('$_GLOBAL["cyrus_ldap_admin_password"]="' +  GLOBAL_INI.get_LDAP('cyrus_password') + '";');
    list.Add('$_GLOBAL["cyrus_admin_password"]="' +  GLOBAL_INI.Cyrus_get_adminpassword() + '";');
    list.Add('$_GLOBAL["cyrus_admin_username"]="' +  GLOBAL_INI.Cyrus_get_admin_name() + '";');
    list.Add('$_GLOBAL["MEM_TOTAL_INSTALLEE"]="' +  IntTostr(SYS.MEM_TOTAL_INSTALLEE()) + '";');




    if FileExists(SYS.LOCATE_CYRUS_SQUATTER()) then list.Add('$_GLOBAL["cyrus_squatter_exists"]=True;') else list.Add('$_GLOBAL["cyrus_squatter_exists"]=False;');
    if FileExists(SYS.LOCATE_CYRUS_IPURGE()) then list.Add('$_GLOBAL["cyrus_ipurge_exists"]=True;') else list.Add('$_GLOBAL["cyrus_ipurge_exists"]=False;');
    if FIleExists(SYS.LOCATE_GENERIC_BIN('clamscan')) then list.Add('$_GLOBAL["CLAMSCAN_INSTALLED"]=True;') else list.Add('$_GLOBAL["CLAMSCAN_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('ipset')) then list.Add('$_GLOBAL["IPSET_INSTALLED"]=True;') else list.Add('$_GLOBAL["IPSET_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('aspell')) then list.Add('$_GLOBAL["ASPELL_INSTALLED"]=True;') else list.Add('$_GLOBAL["ASPELL_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('munin-node')) then list.Add('$_GLOBAL["MUNIN_CLIENT_INSTALLED"]=True;') else list.Add('$_GLOBAL["MUNIN_CLIENT_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('ebtables')) then list.Add('$_GLOBAL["APP_EBTABLES_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_EBTABLES_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('squid27')) then list.Add('$_GLOBAL["APP_SQUID27_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_SQUID27_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('streamsquidcache')) then list.Add('$_GLOBAL["APP_SQUIDSTREAM_INSTALLED"]=True;') else list.Add('$_GLOBAL["APP_SQUIDSTREAM_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_GENERIC_BIN('ntopng')) then list.Add('$_GLOBAL["APP_NTOPNG"]=True;') else list.Add('$_GLOBAL["APP_NTOPNG"]=False;');




    if SYS.APACHE_IS_MOD_PROXY() then list.Add('$_GLOBAL["APACHE_PROXY_MODE"]=True;') else list.Add('$_GLOBAL["APACHE_PROXY_MODE"]=False;');

    if fileexists('/opt/artica/bin/testsaslauthd') then fpsystem('/opt/artica/bin/testsaslauthd -u ' + GLOBAL_INI.Cyrus_get_admin_name() + ' -p ' + GLOBAL_INI.Cyrus_get_adminpassword() + ' >/dev/null 2>&1');

    //------------ mysql

    list.Add('$_GLOBAL["mysql_password"]="' +  sys.MYSQL_INFOS('password')+ '";');
    list.Add('$_GLOBAL["mysql_admin"]="' +  sys.MYSQL_INFOS('root') + '";');
    list.Add('$_GLOBAL["mysql_server"]="' +  sys.MYSQL_INFOS('server') + '";');

    mysqld:=tmysql_daemon.CReate(SYS);
    list.Add('$_GLOBAL["mysqld_version"]="' +  mysqld.VERSION() + '";');
    list.Add('$_GLOBAL["mysqld_datadir"]="' +  mysqld.SERVER_PARAMETERS('datadir') + '";');

     
    if EnableMysqlFeatures=1 then  list.Add('$_GLOBAL["mysql_enabled"]=True;') else list.Add('$_GLOBAL["mysql_enabled"]=false;');


    list.Add('$_GLOBAL["ARTICA_DAEMON_PORT"]=' +  IntToStr(GLOBAL_INI.get_ARTICA_LOCAL_PORT()) + ';');
    list.Add('$_GLOBAL["ARTICA_SECOND_PORT"]=' +  IntToStr(GLOBAL_INI.get_ARTICA_LOCAL_SECOND_PORT()) + ';');
    list.Add('$_GLOBAL["ARTICA_DAEMON_IP"]="' +  GLOBAL_INI.get_ARTICA_LISTEN_IP() + '";');
    
    
    //-------------Fethcmail
    fetchmail:=tfetchmail.Create(SYS);

    

    
    
     fetchmail_path:=fetchmail.FETCHMAIL_BIN_PATH();

     if length(fetchmail_path)>0 then begin
          list.Add('$_GLOBAL["fetchmail_path"]="' + fetchmail_path + '";');
          list.Add('$_GLOBAL["fetchmail_installed"]=True;');

          if FileExists('/etc/fetchmailrc') then list.Add('$_GLOBAL["fetchmail_configured"]=True;') else list.Add('$_GLOBAL["fetchmail_configured"]=False;');
          list.Add('$_GLOBAL["FETCHMAIL_VERSION"]="' + fetchmail.FETCHMAIL_VERSION(true) + '";');
     end else begin
         list.Add('$_GLOBAL["fetchmail_installed"]=False;');
     end;

    if SYS.GET_INFO('EnableManageUsersTroughActiveDirectory')='1' then list.Add('$_GLOBAL["EnableManageUsersTroughActiveDirectory"]=true;') else list.Add('$_GLOBAL["EnableManageUsersTroughActiveDirectory"]=false;');
    list.Add('$_GLOBAL["ActiveDirectoryCredentials"]='''+trim(logs.ReadFromFile('/etc/artica-postfix/settings/Daemons/ActiveDirectoryCredentials'))+''';');
    list.Add('$_GLOBAL["fqdn_hostname"]="' +  GLOBAL_INI.SYSTEM_FQDN() + '";');
    list.Add('$_GLOBAL["netbiosname"]="' +  SYS.NetBiosName() + '";');
    list.Add('$_GLOBAL["phpcgi"]="' +  lighttpd.PHP5_CGI_BIN_PATH() + '";');
    list.Add('$_GLOBAL["cpumhz"]="' +  sys.CPU_MHZ() + '";');
    list.Add('$_GLOBAL["MAIN_CONSOLE_PORT"]="' +  lighttpd.LIGHTTPD_LISTEN_PORT() + '";');
    list.Add('$_GLOBAL["SIEVE_PORT"]="' +  sys.SIEVE_PORT() + '";');



    
    if FileExists(SYS.LOCATE_PRELOAD()) then list.Add('$_GLOBAL["preload_installed"]=True;') else list.Add('$_GLOBAL["preload_installed"]=False;');
    if FileExists(mailspy.BIN_PATH()) then list.Add('$_GLOBAL["MILTER_SPY_INSTALLED"]=True;') else list.Add('$_GLOBAL["MILTER_SPY_INSTALLED"]=False;');
    if FileExists(SYS.LOCATE_SMBMOUNT()) then list.Add('$_GLOBAL["smbmount_installed"]=True;') else list.Add('$_GLOBAL["smbmount_installed"]=False;');


    if FileExists(fdm.bin_path()) then begin
         list.Add('$_GLOBAL["fdm_installed"]=True;');
        if fdm.CACHE_EXISTS() then list.Add('$_GLOBAL["fdm_cache"]=True;') else list.Add('$_GLOBAL["fdm_cache"]=False;');
    end else begin
         list.Add('$_GLOBAL["fdm_installed"]=false;');
    end;
    
    
    if FileExists(SYS.LOCATE_BLKID()) then list.Add('$_GLOBAL["blkid_installed"]=True;') else list.Add('$_GLOBAL["blkid_installed"]=False;');
    if FileExists(p3scan.DEAMON_BIN_PATH()) then list.Add('$_GLOBAL["p3scan_installed"]=True;') else list.Add('$_GLOBAL["p3scan_installed"]=false;');
    if length(sys.DEBIAN_VERSION())>0 then list.Add('$_GLOBAL["AsDebianSystem"]=True;') else list.Add('$_GLOBAL["AsDebianSystem"]=False;');

    
    
    if FileExists(SYS.LOCATE_NMAP()) then begin
       list.Add('$_GLOBAL["nmap_installed"]=True;');
       list.Add('$_GLOBAL["nmap_path"]="'+SYS.LOCATE_NMAP()+'";');
       list.Add('$_GLOBAL["nmap_version"]="'+toolsversions.NMAP_VERSION()+'";');
    end else begin
        list.Add('$_GLOBAL["nmap_installed"]=False;');
    end;

    if FileExists(SYS.LOCATE_ZIP()) then list.Add('$_GLOBAL["zip_installed"]=True;') else list.Add('$_GLOBAL["zip_installed"]=False;');


    if FileExists('/usr/bin/msmtp') then list.Add('$_GLOBAL["msmtp_installed"]=True;');
    
    
    if FileExists(bogo.DEAMON_BIN_PATH()) then begin
          list.Add('$_GLOBAL["bogofilter_installed"]=True;');
    end else begin
          list.Add('$_GLOBAL["bogofilter_installed"]=False;');
    end;
    
    
    if FileExists(syslogng.DEAMON_BIN_PATH()) then begin
          list.Add('$_GLOBAL["syslogng_installed"]=True;');
    end else begin
          list.Add('$_GLOBAL["syslogng_installed"]=False;');
    end;

    
    hostname:=GLOBAL_INI.get_INFOS('hostname');
    if length(hostname)=0 then begin
          GLOBAL_INI.set_INFOS('hostname',GLOBAL_INI.SYSTEM_FQDN());
          hostname:=GLOBAL_INI.SYSTEM_FQDN();
    end;
    
    list.Add('$_GLOBAL["fixed_hostname"]="' +  hostname + '";');
    list.Add('$_GLOBAL["ChangeAutoInterface"]="' + GLOBAL_INI.get_INFOS('ChangeAutoInterface') + '";');
    list.Add('$_GLOBAL["POSTFIX_STATUS"]="' + postfix.POSTFIX_STATUS()+ '";');
    list.Add('$_GLOBAL["KAS_STATUS"]="' + kas3.KAS_STATUS() + '";');
    list.Add('$_GLOBAL["ARTICA_FILTER_QUEUE_PATH"]="' + GLOBAL_INI.ARTICA_FILTER_QUEUEPATH() + '";');
    list.Add('$_GLOBAL["ARTICA_VERSION"]="' + GLOBAL_INI.ARTICA_VERSION() + GLOBAL_INI.ARTICA_PATCH_VERSION()+'";');
    list.Add('$_GLOBAL["POSTFIX_VERSION"]="' + postfix.POSTFIX_VERSION() + '";');
    list.Add('$_GLOBAL["POSTFIX_MAILDROP_PATH"]="' + SYS.LOCATE_POSTFIX_MAILDROP() + '";');
    
    


   // if lighttpd.IS_AUTH_LDAP() then list.Add('$_GLOBAL["LIGHTTPD_LDAP_AUTH"]=True;')  else list.Add('$_GLOBAL["LIGHTTPD_LDAP_AUTH"]=False;');
    
    




     logs.Debuglogs('ARTICA_FILTER_MAXSUBQUEUE="'+IntToStr(GLOBAL_INI.ARTICA_SEND_MAX_SUBQUEUE_NUMBER())+'"');

     list.Add('$_GLOBAL["ARTICA_FILTER_MAXSUBQUEUE"]="' + IntToStr(GLOBAL_INI.ARTICA_SEND_MAX_SUBQUEUE_NUMBER()) + '";');

     if FileExists(SYS.LOCATE_APACHE_BIN_PATH()) then begin
        apachesrc:=tapachesrc.Create(SYS);
        list.Add('$_GLOBAL["APACHE_INSTALLED"]=True;');
        if apachesrc.MODULE_EXISTS('mpm_itk_module') then list.Add('$_GLOBAL["MPM_ITK_MODULE"]=True;') else  list.Add('$_GLOBAL["MPM_ITK_MODULE"]=False;');
        list.Add('$_GLOBAL["APACHE_PORT"]="'+SYS.APACHE_STANDARD_PORT()+'";');
        list.Add('$_GLOBAL["APACHE_DIR_SITES_ENABLED"]="'+apachesrc.APACHE_DIR_SITES_ENABLED()+'";');
        list.Add('$_GLOBAL["APACHE_RUN_USER"]="'+apachesrc.APACHE_SRC_ACCOUNT()+'";');
        APACHE_MODULES_PATH:=SYS.LOCATE_APACHE_MODULES_PATH();
        list.Add('$_GLOBAL["APACHE_MODULES_PATH"]="'+APACHE_MODULES_PATH+'";');
        if FileExists(APACHE_MODULES_PATH+'/mod_ldap.so') then begin
              list.Add('$_GLOBAL["APACHE_MOD_LDAP"]=True;');
              if FileExists('/usr/share/backuppc/bin/BackupPC') then list.Add('$_GLOBAL["BACKUPPC_APACHE"]=True;') else list.Add('$_GLOBAL["BACKUPPC_APACHE"]=False;');
        end;

        if FileExists(APACHE_MODULES_PATH+'/mod_vhost_ldap.so') then  list.Add('$_GLOBAL["APACHE_MODE_VHOSTS_LDAP"]=True;') else list.Add('$_GLOBAL["APACHE_MODE_VHOSTS_LDAP"]=False;');
        if FileExists(APACHE_MODULES_PATH+'/mod_bw.so') then  list.Add('$_GLOBAL["APACHE_MODE_BW"]=True;') else list.Add('$_GLOBAL["APACHE_MODE_BW"]=False;');


        if FileExists(APACHE_MODULES_PATH+'/mod_dav.so') then begin
           if FileExists(APACHE_MODULES_PATH+'/mod_ldap.so') then begin
               list.Add('$_GLOBAL["APACHE_MODE_WEBDAV"]=True;');
           end else begin
               list.Add('$_GLOBAL["APACHE_MODE_WEBDAV"]=False;');
           end;
        end else begin
               list.Add('$_GLOBAL["APACHE_MODE_WEBDAV"]=False;');
        end;
     end else begin
         list.Add('$_GLOBAL["APACHE_INSTALLED"]=False;');
         list.Add('$_GLOBAL["APACHE_MODE_WEBDAV"]=False;');
     end;


     if DirectoryExists('/usr/share/obm') then list.Add('$_GLOBAL["OBM_INSTALLED"]=True;') else list.Add('$_GLOBAL["OBM_INSTALLED"]=False;');
     if FileExists('/opt/artica/install/sources/obm/obminclude/global.inc') then list.Add('$_GLOBAL["OBM2_INSTALLED"]=True;') else list.Add('$_GLOBAL["OBM2_INSTALLED"]=False;');
     if FileExists('/usr/bin/hamachi') then list.Add('$_GLOBAL["HAMACHI_INSTALLED"]=True;') else list.Add('$_GLOBAL["HAMACHI_INSTALLED"]=False;');



     APP_SIMPLE_GROUPEWARE:=trim(GLOBAL_INI.SIMPLE_CALENDAR_VERSION());
     if length(APP_SIMPLE_GROUPEWARE)>0 then begin
           list.Add('$_GLOBAL["SIMPLE_GROUPEWARE_INSTALLED"]=True;');
           list.Add('$_GLOBAL["SIMPLE_GROUPEWARE_VERSION"]="'+APP_SIMPLE_GROUPEWARE+'";');
     end else begin
           list.Add('$_GLOBAL["SIMPLE_GROUPEWARE_INSTALLED"]=False;');
           list.Add('$_GLOBAL["SIMPLE_GROUPEWARE_VERSION"]="'+APP_SIMPLE_GROUPEWARE+'";');
     end;

     APP_ATOPENMAIL:=trim(toolsversions.ATMAIL_VERSION());
     if length(APP_ATOPENMAIL)>0 then begin
           list.Add('$_GLOBAL["APP_ATOPENMAIL_INSTALLED"]=True;');
           list.Add('$_GLOBAL["APP_ATOPENMAIL_VERSION"]="'+APP_ATOPENMAIL+'";');
     end else begin
           list.Add('$_GLOBAL["APP_ATOPENMAIL_INSTALLED"]=False;');
           list.Add('$_GLOBAL["APP_ATOPENMAIL_VERSION"]="'+APP_ATOPENMAIL+'";');
     end;

     if FileExists(stunnel.DAEMON_BIN_PATH()) then list.Add('$_GLOBAL["stunnel4_installed"]=True;') else list.Add('$_GLOBAL["stunnel4_installed"]=False;');
     if FileExists('/usr/local/share/GeoIP/GeoIP.dat') then list.Add('$_GLOBAL["GeoIPDat_Path"]="/usr/local/share/GeoIP/GeoIP.dat";');
     if FileExists(lighttpd.LIGHTTPD_BIN_PATH()) then list.Add('$_GLOBAL["lighttpd_installed"]=True;');
     list.Add('$_GLOBAL["BadMysqlPassword"]="' + GLOBAL_INI.get_INFOS('BadMysqlPassword') + '";');
    

//*********************************** POSTFIX **********************************
logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING POSTFIX #######################');
if FileExists(SYS.LOCATE_GENERIC_BIN('postconf')) then POSTFIX_INSTALLED:=true;
if FileExists('/etc/artica-postfix/DO_NOT_DETECT_POSTFIX') then POSTFIX_INSTALLED:=false;
if POSTFIX_INSTALLED then begin
        list.Add('$_GLOBAL["POSTFIX_INSTALLED"]=True;');
        if FileExists(SYS.LOCATE_POSTSCREEN()) then list.Add('$_GLOBAL["POSTSCREEN_INSTALLED"]=True;') else list.Add('$_GLOBAL["POSTSCREEN_INSTALLED"]=False;');

          // offlineimap
   if FileExists(SYS.LOCATE_GENERIC_BIN('offlineimap')) then begin
      list.Add('$_GLOBAL["offlineimap_installed"]=True;') end else begin
      fpsystem('/usr/share/artica-postfix/bin/artica-make APP_OFFLINEIMAP >/dev/null 2>&1 &');
      list.Add('$_GLOBAL["offlineimap_installed"]=False;');
   end;

        //------------- policyd-weight
        try
           pol:=tpolicyd_weight.Create(SYS);
           list.Add('$_GLOBAL["POLICYD_WEIGHT_PORT"]="'+pol.GET_VALUE('TCP_PORT')+'";');
        except
          logs.Syslogs('FATAL ERROR FOR POLICYD_WEIGHT_PORT value')
        end;

        if FileExists(SYS.LOCATE_GENERIC_BIN('cbpolicyd')) then list.Add('$_GLOBAL["CLUEBRINGER_INSTALLED"]=True;') else list.Add('$_GLOBAL["CLUEBRINGER_INSTALLED"]=False;');

        try
           postfilter:=tpostfilter.Create(SYS);
           if FileExists(postfilter.BIN_PATH()) then list.Add('$_GLOBAL["POSTFILTER_INSTALLED"]=True;') else list.Add('$_GLOBAL["POSTFILTER_INSTALLED"]=False;');
        except
          logs.Syslogs('FATAL ERROR FOR POSTFILTER_INSATLLED value')
        end;

        
         list.Add('$_GLOBAL["CURL_PATH"]="'+SYS.LOCATE_CURL()+'";');
        if FileExists(miltergreylist.MILTER_GREYLIST_BIN_PATH()) then begin
           list.Add('$_GLOBAL["MILTERGREYLIST_INSTALLED"]=True;');

        end else begin
            list.Add('$_GLOBAL["MILTERGREYLIST_INSTALLED"]=False;');
        end;

        if FileExists(SYS.LOCATE_GENERIC_BIN('dk-filter')) then list.Add('$_GLOBAL["DKFILTER_INSTALLED"]=True;') else list.Add('$_GLOBAL["DKFILTER_INSTALLED"]=False;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('opendkim')) then list.Add('$_GLOBAL["OPENDKIM_INSTALLED"]=True;') else list.Add('$_GLOBAL["OPENDKIM_INSTALLED"]=False;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('dkim-filter')) then list.Add('$_GLOBAL["MILTER_DKIM_INSTALLED"]=True;') else list.Add('$_GLOBAL["MILTER_DKIM_INSTALLED"]=False;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('dkimproxy.in')) then list.Add('$_GLOBAL["DKIMPROXY_INSTALLED"]=True;') else list.Add('$_GLOBAL["DKIMPROXY_INSTALLED"]=False;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('postmulti')) then list.Add('$_GLOBAL["POSTMULTI"]=True;') else list.Add('$_GLOBAL["POSTMULTI"]=False;');

        if postfix.POSTFIX_LDAP_COMPLIANCE() then list.Add('$_GLOBAL["POSTFIX_LDAP_COMPLIANCE"]=True;') else list.Add('$_GLOBAL["POSTFIX_LDAP_COMPLIANCE"]=False;');
        if postfix.POSTFIX_PCRE_COMPLIANCE() then list.Add('$_GLOBAL["POSTFIX_PCRE_COMPLIANCE"]=True;') else list.Add('$_GLOBAL["POSTFIX_PCRE_COMPLIANCE"]=False;');
        if FileExists(postfix.gnarwl_path()) then list.Add('$_GLOBAL["GNARWL_INSTALLED"]=True;') else list.Add('$_GLOBAL["GNARWL_INSTALLED"]=False;');
        if SYS.PROCESS_EXIST(SYS.PIDOF('master'))=True then list.Add('$_GLOBAL["postfix_on_memorie"]=True;') else list.Add('$_GLOBAL["postfix_on_memorie"]=False;');
        if FileExists(spamass.PYZOR_BIN_PATH()) then list.Add('$_GLOBAL["pyzor_installed"]=True;') else list.Add('$_GLOBAL["pyzor_installed"]=False;');
        if FileExists(spf.SPFMILTER_INITD()) then list.Add('$_GLOBAL["spfmilter_installed"]=True;') else list.Add('$_GLOBAL["spfmilter_installed"]=False;');



        //------------- spamassassin
        if FileExists(spamass.SPAMASSASSIN_BIN_PATH()) then begin
           list.Add('$_GLOBAL["spamassassin_installed"]=True;');
           list.Add('$_GLOBAL["spamassassin_conf_path"]="'+spamass.SPAMASSASSIN_LOCAL_CF()+'";');
           list.Add('$_GLOBAL["spamassassin_bin_path"]="'+spamass.SPAMASSASSIN_BIN_PATH()+'";');
           list.Add('$_GLOBAL["spamassassin_version"]="'+spamass.SPAMASSASSIN_VERSION()+'";');
           if SYS.CHECK_PERL_MODULES('IP::Country::Fast') then  list.Add('$_GLOBAL["spamassassin_ipcountry"]=True;') else list.Add('$_GLOBAL["spamassassin_ipcountry"]=False;');
        end else begin
             list.Add('$_GLOBAL["spamassassin_installed"]=False;');
        end;
        
        //-------------Razor
        if FileExists(spamass.RAZOR_ADMIN_PATH()) then begin
          list.Add('$_GLOBAL["razor_installed"]=True;');
          list.Add('$_GLOBAL["razor_config"]="'+spamass.RAZOR_AGENT_CONF_PATH()+'";');
        end else begin
          list.Add('$_GLOBAL["razor_installed"]=False;');
        end;
        
        //-------------pflogsumm
        if FileExists('/usr/sbin/pflogsumm') then list.Add('$_GLOBAL["PFLOGSUMM_INSTALLED"]=True;') else list.Add('$_GLOBAL["PFLOGSUMM_INSTALLED"]=False;');

        //-------------ASSP
        if FileExists('/usr/share/assp/assp.pl') then begin
        list.Add('$_GLOBAL["ASSP_INSTALLED"]=True;');
        assp:=tassp.Create(SYS);
        list.Add('$_GLOBAL["ASSP_VERSION"]="'+assp.VERSION()+'";');

        end else begin
        list.Add('$_GLOBAL["ASSP_INSTALLED"]=False;');
        end;
        
        //-------------amavis
        amavis:=tamavis.Create(SYS);
           if FileExists(amavis.MILTER_BIN_PATH()) then list.Add('$_GLOBAL["AMAVIS_MILTER_INSTALLED"]=True;') else list.Add('$_GLOBAL["AMAVIS_MILTER_INSTALLED"]=False;');
           if FileExists(amavis.AMAVISD_BIN_PATH()) then begin
              list.Add('$_GLOBAL["AMAVIS_INSTALLED"]=True;');
              list.Add('$_GLOBAL["AMAVISD_VERSION"]="'+amavis.AMAVISD_VERSION()+'";');
              if FileExists(amavis.altermime_bin_path()) then list.Add('$_GLOBAL["ALTERMIME_INSTALLED"]=True;') else list.Add('$_GLOBAL["ALTERMIME_INSTALLED"]=False;');
              list.Add('$_GLOBAL["MAIL_DKIM_VERSION"]="'+SYS.CHECK_PERL_MODULES_VER('Mail::DKIM')+'";');
           end else begin
              list.Add('$_GLOBAL["AMAVIS_INSTALLED"]=False;');
           end;




        
     
        //-------------j-checkmail
        jcheckmail:=tjcheckmail.Create(SYS);
        if FileExists(jcheckmail.BIN_PATH()) then begin
           list.Add('$_GLOBAL["JCHECKMAIL_INSTALLED"]=True;');
           list.Add('$_GLOBAL["JCHECKMAIL_SOCKET"]="'+jcheckmail.SOCK_PATH()+'";')
           
        end else list.Add('$_GLOBAL["JCHECKMAIL_INSTALLED"]=False;');
        jcheckmail.Free;
        
        //-------------mailman
        mailman:=tmailman.Create(SYS);
        logs.Debuglogs('Tprocess1.web_settings():: Mailman :'+mailman.BIN_PATH());
        if fileExists(mailman.BIN_PATH()) then list.Add('$_GLOBAL["MAILMAN_INSTALLED"]=True;') else list.Add('$_GLOBAL["MAILMAN_INSTALLED"]=false;');
        mailman.Free;

        //-------------pommo
        if DirectoryExists('/usr/share/pommo') then list.Add('$_GLOBAL["POMMO_INSTALLED"]=True;') else list.Add('$_GLOBAL["POMMO_INSTALLED"]=false;');




        
end else begin
         list.Add('$_GLOBAL["POSTFIX_INSTALLED"]=False;');

end;
//*********************************** POSTFIX END **********************************

 logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING BIND9 #######################');
     
     if FileExists(bind9.bin_path()) then begin
        list.Add('$_GLOBAL["BIND9_INSTALLED"]=True;');
        if FileExists('/usr/sbin/bind-rrd-collect.pl') then list.Add('$_GLOBAL["bindrrd_installed"]=True;') else list.Add('$_GLOBAL["bindrrd_installed"]=False;');
     end else begin
         list.Add('$_GLOBAL["BIND9_INSTALLED"]=False;');
         list.Add('$_GLOBAL["bindrrd_installed"]=False;');
     end;
     
 logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING PUREFTPD #######################');
     
 if FileExists(Cpureftpd.DAEMON_BIN_PATH()) then begin
        list.Add('$_GLOBAL["PUREFTP_INSTALLED"]=True;');
        if not FileExists('/etc/pure-ftpd/pureftpd.pdb') then list.Add('$_GLOBAL["PUREFTP_USERS"]=False;') else list.Add('$_GLOBAL["PUREFTP_USERS"]=True;');
     end else begin
         list.Add('$_GLOBAL["PUREFTP_INSTALLED"]=False;');
     end;
     

 logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING NTPD #######################');
 if FileExists(zntpd.DEAMON_BIN_PATH()) then list.Add('$_GLOBAL["NTPD_INSTALLED"]=True;') else list.Add('$_GLOBAL["NTPD_INSTALLED"]=False;');


 logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING SAMBA #######################');
     
 if FileExists(samba.SMBD_PATH()) then begin
        list.Add('$_GLOBAL["SAMBA_INSTALLED"]=True;');
        list.Add('$_GLOBAL["SAMBA_VERSION"]="'+samba.SAMBA_VERSION()+'";');
        if(samba.CLUSTER_SUPPORT()) then  list.Add('$_GLOBAL["SAMBA_CLUSTER_SUPPORT"]=True;') else list.Add('$_GLOBAL["SAMBA_CLUSTER_SUPPORT"]=False;');
        if FileExists(samba.vfs_path()+'/mysql_audit.so')  then list.Add('$_GLOBAL["SAMBA_MYSQL_AUDIT"]=True;') else list.Add('$_GLOBAL["SAMBA_MYSQL_AUDIT"]=False;');
        if FileExists('/usr/sbin/scannedonlyd_clamav')  then list.Add('$_GLOBAL["SCANNED_ONLY_INSTALLED"]=True;') else list.Add('$_GLOBAL["SCANNED_ONLY_INSTALLED"]=False;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('winbindd')) then list.Add('$_GLOBAL["WINBINDD_INSTALLED"]=True;') else list.Add('$_GLOBAL["WINBINDD_INSTALLED"]=False;');
        if FileExists(SYS.LOCATE_GENERIC_BIN('greyhole')) then list.Add('$_GLOBAL["GREYHOLE_INSTALLED"]=True;') else list.Add('$_GLOBAL["GREYHOLE_INSTALLED"]=False;');
        cups:=tcups.Create;
        if FileExists(cups.Daemon_bin_path()) then list.Add('$_GLOBAL["CUPS_INSTALLED"]=True;') else list.Add('$_GLOBAL["CUPS_INSTALLED"]=False;');
        cups.free;


        if  FileExists(kav4samba.bin_path()) then begin
            list.Add('$_GLOBAL["KAV4SAMBA_INSTALLED"]=True;');
            list.Add('$_GLOBAL["KAV4SAMBA_VFS"]="'+kav4samba.VFS_MODULE()+'";');
        end;


            
 end else begin
        list.Add('$_GLOBAL["SAMBA_INSTALLED"]=False;');
        list.Add('$_GLOBAL["KAV4SAMBA_INSTALLED"]=False;');

 end;
 
 list.Add('$_GLOBAL["LOCAL_SID"]="' + GLOBAL_INI.SYSTEM_LOCAL_SID() +'";');


      if length(SYS.LOCATE_GENERIC_BIN('ufdbguardd'))>5 then begin
         list.add('$_GLOBAL["APP_UFDBGUARD_INSTALLED"]=True;');
         list.add('$_GLOBAL["ufdbgclient_path"]="'+SYS.LOCATE_GENERIC_BIN('ufdbgclient')+'";');
      end else begin
         list.add('$_GLOBAL["APP_UFDBGUARD_INSTALLED"]=False;');
      end;

       if FileExists(dansguardian.C_ICAP_BIN_PATH()) then begin
          list.Add('$_GLOBAL["C_ICAP_INSTALLED"]=True;');
          if FileExists('/usr/lib/c_icap/dnsbl_tables.so') then list.add('$_GLOBAL["C_ICAP_DNSBL"]=True;') else list.add('$_GLOBAL["C_ICAP_DNSBL"]=False;');
       end else begin
           list.Add('$_GLOBAL["C_ICAP_INSTALLED"]=False;');
       end;
     


  logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING SQUID #######################');

    if FileExists(squid.SQUID_BIN_PATH()) then begin
       logs.Debuglogs('Tprocess1.web_settings():: Squid is installed writing $_GLOBAL["SQUID_INSTALLED"]=True;');
       list.Add('$_GLOBAL["SQUID_INSTALLED"]=True;');
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid environment...');
       list.Add('$_GLOBAL["SQUID_VERSION"]="' + squid.SQUID_VERSION() + '";' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid Version OK...');
       list.Add('$_GLOBAL["SQUID_LDAP_AUTH"]="' + squid.ldap_auth_path() + '";' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid ldap_auth_path OK...');
       list.Add('$_GLOBAL["SQUID_NTLM_AUTH"]="' + squid.ntml_auth_path() + '";' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid ntml_auth_path OK...');
       list.Add('$_GLOBAL["SQUID_BIN_PATH"]="' + squid.SQUID_BIN_PATH() + '";' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid SQUID_BIN_PATH OK...');
       list.Add('$_GLOBAL["SQUID_CACHMGR"]="' + squid.cachemgr_path() + '";' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid version...');
       list.Add('$_GLOBAL["SQUID_BIN_VERSION"]=' + IntToStr(squid.SQUID_BIN_VERSION(squid.SQUID_VERSION())) + ';' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid SQUID_BIN_VERSION OK...');
       list.Add('$_GLOBAL["squid_kerb_auth_path"]="' + squid.squid_kerb_auth_path() + '";' );
       logs.Debuglogs('Tprocess1.web_settings():: Scanning Squid ext_session_acl_path OK...');
       list.Add('$_GLOBAL["squid_ext_session_acl"]="' + squid.ext_session_acl_path() + '";' );
       logs.Debuglogs('Tprocess1.web_settings -> purge ???');


       if FileExists(SYS.LOCATE_GENERIC_BIN('purge')) then list.Add('$_GLOBAL["SQUID_PURGE_INSTALLED"]=True;') else list.Add('$_GLOBAL["SQUID_PURGE_INSTALLED"]=False;');

       if squid.ntlm_enabled() then  list.Add('$_GLOBAL["SQUID_NTLM_ENABLED"]=True;') else list.Add('$_GLOBAL["SQUID_NTLM_ENABLED"]=False;');
       if squid.SQUID_ARP_ACL_ENABLED()=1 then list.Add('$_GLOBAL["SQUID_ARP_ACL_ENABLED"]=True;') else list.Add('$_GLOBAL["SQUID_ARP_ACL_ENABLED"]=False;');



      if length(SYS.LOCATE_GENERIC_BIN('squidclamav'))>5 then begin
         list.add('$_GLOBAL["APP_SQUIDCLAMAV_INSTALLED"]=True;');
         list.add('$_GLOBAL["squidclamav_path"]="'+SYS.LOCATE_GENERIC_BIN('squidclamav')+'";');
      end else begin
         list.add('$_GLOBAL["APP_SQUIDCLAMAV_INSTALLED"]=False;');
      end;







       squidguard:=Tsquidguard.Create(SYS);
       if FileExists(squidguard.BIN_PATH()) then begin
          list.Add('$_GLOBAL["SQUIDGUARD_INSTALLED"]=True;');
          list.Add('$_GLOBAL["SQUIDGUARD_BINVER"]="'+IntToStr(squidguard.VERSIONNUM())+'";');
          list.Add('$_GLOBAL["SQUIDGUARD_BIN_PATH"]="'+squidguard.BIN_PATH()+'";');
       end else begin
           list.Add('$_GLOBAL["SQUIDGUARD_INSTALLED"]=False;');
           list.Add('$_GLOBAL["SQUIDGUARD_BINVER"]="0";');
       end;
       squidguard.free;


       if FIleExists('/usr/bin/zapchain') then begin
          list.Add('$_GLOBAL["ADZAPPER_INSTALLED"]=True;');
       end  else begin
       list.Add('$_GLOBAL["ADZAPPER_INSTALLED"]=False;');
       end;

       if FIleExists(dansguardian.BIN_PATH()) then begin
          list.Add('$_GLOBAL["DANSGUARDIAN_INSTALLED"]=True;');
          list.Add('$_GLOBAL["DANSGUARDIAN_VERSION"]="'+dansguardian.DANSGUARDIAN_VERSION()+'";');
       end  else begin
       list.Add('$_GLOBAL["DANSGUARDIAN_INSTALLED"]=False;');
       end;





       if FileExists('/usr/bin/sarg') then list.Add('$_GLOBAL["SARG_INSTALLED"]=True;') else list.Add('$_GLOBAL["SARG_INSTALLED"]=False;');

       if FileExists('/opt/kaspersky/kav4proxy/sbin/kav4proxy-kavicapserver') then begin
          list.Add('$_GLOBAL["KAV4PROXY_INSTALLED"]=True;');
          list.Add('$_GLOBAL["KAV4PROXY_PID"]="' + kavProxy.KAV4PROXY_PID() + '";' );
          list.Add('$_GLOBAL["KAV4PROXY_MEMORY"]="' + IntTOStr(GLOBAL_INI.SYSTEM_PROCESS_MEMORY(kavProxy.KAV4PROXY_PID()))+ '";' );
          list.Add('$_GLOBAL["KAV4PROXY_VERSION"]="' + kavProxy.VERSION()+ '";' );
          list.Add('$_GLOBAL["KAV4PROXY_PATTERN"]="' +kavProxy.PATTERN_DATE()+ '";' );
          list.Add('$_GLOBAL["KAV4PROXY_LICENSE_ERROR"]=' +kavProxy.LICENSE_ERROR()+ ';' );
          list.Add('$_GLOBAL["KAV4PROXY_LICENSE_ERROR_TEXT"]="' +kavProxy.LICENSE_ERROR_TEXT+ '";' );
       end else begin list.Add('$_GLOBAL["KAV4PROXY_INSTALLED"]=False;'); end;
       



       end else begin
       logs.Debuglogs('Tprocess1.web_settings():: $_GLOBAL["SQUID_INSTALLED"]=False;');
       list.Add('$_GLOBAL["SQUID_INSTALLED"]=False;');
       end;
       
       



    logs.Debuglogs('web_settings() -> 55%');
    //---------------------- DNSASQ STATUS --------------------------------------------------
    if fileExists(dnsmasq.DNSMASQ_BIN_PATH()) then begin
              list.Add('$_GLOBAL["dnsmasq_installed"]=True;');
    end else begin
              list.Add('$_GLOBAL["dnsmasq_installed"]=false;');
    end;
   //--------------------------------------------------------------------------------------------

   
   if fileExists(GLOBAL_INI.IPTABLES_PATH()) then list.Add('$_GLOBAL["IPTABLES_INSTALLED"]=True;') else list.Add('$_GLOBAL["IPTABLES_INSTALLED"]=False;');
   if GLOBAL_INI.PROCMAIL_INSTALLED()=True then list.Add('$_GLOBAL["procmail_installed"]=True;') else list.Add('$_GLOBAL["procmail_installed"]=False;');


 if FileExists(clamav.CLAMD_BIN_PATH()) then begin
         list.Add('$_GLOBAL["CLAMD_INSTALLED"]=True;');
         list.Add('$_GLOBAL["CLAMAV_SOCKET"]="' + clamav.CLAMD_GETINFO('LocalSocket')+'";');
         list.Add('$_GLOBAL["CLAMD_CONF_PATH"]="' + clamav.CLAMD_CONF_PATH()+'";');
         list.Add('$_GLOBAL["CLAMD_DATABASE_PATH"]="' + clamav.CLAMD_GETINFO('DatabaseDirectory')+'";');
 end;

 if FileExists('/usr/bin/clamscan') then begin
    list.Add('$_GLOBAL["CLAMAV_INSTALLED"]=True;');
 end;


 //--------------------------------------------------------------------------------------------
 
 if FileExists(clamav.MILTER_DAEMON_PATH()) then begin
       list.Add('$_GLOBAL["CLAMAV_MILTER_INSTALLED"]=True;');
       list.Add('$_GLOBAL["CLAMAV_MILTER_SOCKET"]="' + clamav.MILTER_SOCK_PATH() + '";' );
 end else begin
     list.Add('$_GLOBAL["CLAMAV_MILTER_INSTALLED"]=False;');
 end;
 //--------------------------------------------------------------------------------------------
 
 if FileExists(spamass.MILTER_DAEMON_BIN_PATH()) then begin
     list.Add('$_GLOBAL["SPAMASS_MILTER_INSTALLED"]=True;');
     list.Add('$_GLOBAL["SPAMASS_MILTER_SOCKET"]="' + spamass.MILTER_SOCKET_PATH() + '";' );
  end else begin
     list.Add('$_GLOBAL["SPAMASS_MILTER_INSTALLED"]=False;');
 end;
 //--------------------------------------------------------------------------------------------
 

 

 //isoqlog
 isoqlog:=tisoqlog.Create(SYS);
 if FileExists(isoqlog.BIN_PATH()) then list.Add('$_GLOBAL["ISOQLOG_INSTALLED"]=True;') else list.Add('$_GLOBAL["ISOQLOG_INSTALLED"]=False;');
 isoqlog.Free;
 
 
 if FileExists('/usr/bin/mhonarc') then begin
     list.Add('$_GLOBAL["MHONARC_INSTALLED"]=True;');
     list.Add('$_GLOBAL["MHONARC_VERSION"]="' +GLOBAL_INI.MHONARC_VERSION() + '";');
 end else begin
     list.Add('$_GLOBAL["MHONARC_INSTALLED"]=False;');
 end;
 //--------------------------------------------------------------------------------------------
 
 if FileExists(dkim.DAEMON_BIN_PATH()) then begin
     list.Add('$_GLOBAL["DKIMFILTER_INSTALLED"]=True;');
     list.Add('$_GLOBAL["DKIMFILTER_SOCKET"]="' +dkim.SOCKET_PATH() + '";');
 end else begin
     list.Add('$_GLOBAL["DKIMFILTER_INSTALLED"]=False;');
 end;
 //--------------------------------------------------------------------------------------------

logs.Debuglogs('web_settings() -> 70%');
     if fileExists('/usr/local/ap-mailfilter3/etc/filter.conf') then list.Add('$_GLOBAL["kas_installed"]=True;') else list.Add('$_GLOBAL["kas_installed"]=false;');
     

     if fileExists('/etc/init.d/aveserver') then list.Add('$_GLOBAL["aveserver_installed"]=True;') else list.Add('$_GLOBAL["aveserver_installed"]=false;');


     if fileExists('/opt/kav/5.6/kavmilter/bin/kavmilter') then begin
              KAV_MILTER_PID:=kavmilter.KAV_MILTER_PID();
              list.Add('$_GLOBAL["kavmilter_installed"]=True;');
              list.Add('$_GLOBAL["KAVMILTER_PID"]="' + KAV_MILTER_PID + '";');
     end;

     if fileExists('/opt/kaspersky/kav4lms/bin/kav4lms-cmd') then list.Add('$_GLOBAL["kavmilter_installed"]=True;');



          
if FileExists('/opt/artica/sbin/hotwayd') then list.Add('$_GLOBAL["hotwayd_installed"]=True;') else list.Add('$_GLOBAL["hotwayd_installed"]=False;');


logs.Debuglogs('web_settings() -> 75%');


 //-----------------------------------------------------------------------------------------------------
     logs.Debuglogs('Tprocess1.web_settings():: ############# CHECKING CYRUS #######################');
     if length(cyr.CYRUS_DAEMON_BIN_PATH())>0 then begin
          if fileExists(cyr.CYRUS_DAEMON_BIN_PATH()) then begin
             logs.Debuglogs('Tprocess1.web_settings():: Cyrus is installed...');
             list.Add('$_GLOBAL["cyrus_imapd_installed"]=True;');
             list.Add('$_GLOBAL["cyrus_initd_path"]="' + cyr.CYRUS_GET_INITD_PATH() + '";');
             list.Add('$_GLOBAL["cyrus_lmtp_path"]="' + cyr.LMTPD_PATH() + '";');
             list.Add('$_GLOBAL["cyr_deliver_path"]="' + GLOBAL_INI.CYRUS_DELIVER_BIN_PATH() + '";');
             list.Add('$_GLOBAL["cyr_partition_default"]="' + cyr.IMAPD_GET('partition-default') + '";');
             list.Add('$_GLOBAL["cyr_config_directory"]="' + cyr.IMAPD_GET('configdirectory') + '";');
             list.Add('$_GLOBAL["ctl_mboxlist"]="' + SYS.LOCATE_ctl_mboxlist() + '";');
             
             if SYS.GET_INFO('EnableVirtualDomainsInMailBoxes')='1' then list.Add('$_GLOBAL["EnableVirtualDomainsInMailBoxes"]=True;') else list.Add('$_GLOBAL["EnableVirtualDomainsInMailBoxes"]=False;');
             if FileExists(cyr.CYRUS_PROXYD_BIN_PATH()) then list.Add('$_GLOBAL["cyrus_murder_installed"]=True;')  else list.Add('$_GLOBAL["cyrus_murder_installed"]=False;');

              if FileExists(cyr.CYRUS_SYNC_SERVER_BIN_PATH()) then list.Add('$_GLOBAL["cyrus_syncserver_installed"]=True;')  else list.Add('$_GLOBAL["cyrus_syncserver_installed"]=False;');


             if FileExists(cyr.CYRUS_SYNC_CLIENT_BIN_PATH()) then begin
                list.Add('$_GLOBAL["cyrus_sync_installed"]=True;');
                list.Add('$_GLOBAL["cyrus_sync_client_path"]="'+cyr.CYRUS_SYNC_CLIENT_BIN_PATH()+'";');

             end else begin
                 list.Add('$_GLOBAL["cyrus_sync_installed"]=False;');
             end;
             
             end else begin
               logs.Debuglogs('Tprocess1.web_settings():: Cyrus is not installed not stat CYRUS_DAEMON_BIN_PATH...');
               list.Add('$_GLOBAL["cyrus_imapd_installed"]=false;');
               list.Add('$_GLOBAL["EnableVirtualDomainsInMailBoxes"]=False;');
             end;
     end else begin
         logs.Debuglogs('Tprocess1.web_settings():: CYRUS_DAEMON_BIN_PATH=null');
         list.Add('$_GLOBAL["cyrus_imapd_installed"]=false;');
         list.Add('$_GLOBAL["EnableVirtualDomainsInMailBoxes"]=False;');
     end;

 //-----------------------------------------------------------------------------------------------------

     logs.Debuglogs('web_settings() -> 80%');
     logs.Debuglogs('web_settings() Checking rrdtool...');
     if fileexists(GLOBAL_INI.RRDTOOL_BIN_PATH()) then begin
             list.Add('$_GLOBAL["rrdtool_installed"]=True;');
             end else begin
               list.Add('$_GLOBAL["rrdtool_installed"]=false;');
    end;
    logs.Debuglogs('web_settings() Checking mysql...');
     if fileexists(SYS.LOCATE_mysqld_bin()) then begin
             list.Add('$_GLOBAL["mysql_installed"]=True;');
             end else begin
             list.Add('$_GLOBAL["mysql_installed"]=false;');
    end;

    logs.Debuglogs('web_settings() Checking mailgraph...');
    if FileExists('/etc/init.d/mailgraph-init') then begin
     list.Add('$_GLOBAL["mailgraph_installed"]=True;');
             end else begin
             list.Add('$_GLOBAL["mailgraph_installed"]=false;');
    end;


    logs.Debuglogs('web_settings() Checking artica_queuegraph...');
    if FileExists('/etc/cron.d/artica_queuegraph') then list.Add('$_GLOBAL["queuegraph_installed"]=True;') else  list.Add('$_GLOBAL["queuegraph_installed"]=false;');

    logs.Debuglogs('web_settings() Checking artica_yorel...');
    if FileExists('/etc/cron.d/artica_yorel') then begin
     list.Add('$_GLOBAL["yorel_installed"]=True;');
             end else begin
             list.Add('$_GLOBAL["yorel_installed"]=false;');
    end;

    if fileExists(SYS.LOCATE_AWSTATS_BIN_PATH()) then  begin
          list.Add('$_GLOBAL["awstats_installed"]=True;');
          list.Add('$_GLOBAL["awstats_www_path"]="'+awstats.AWSTATS_www_root()+'";');
          
    end  else begin
          list.Add('$_GLOBAL["awstats_installed"]=False;');
    end;


    logs.Debuglogs('web_settings() -> 90%');
    logs.Debuglogs('web_settings() Checking procmail_quarantine_path...');
    list.Add('$_GLOBAL["procmail_quarantine_path"]="' + GLOBAL_INI.PROCMAIL_QUARANTINE_PATH() + '";');
    list.Add('$_GLOBAL["mailgraph_virus_database"]="' + GLOBAL_INI.get_MAILGRAPH_RRD_VIRUS() + '";');
    list.Add('$_GLOBAL["mailgraph_postfix_database"]="' + GLOBAL_INI.get_MAILGRAPH_RRD() + '";');


    roundcube_web_folder:=roundcube.web_folder();
    logs.Debuglogs('web_settings() Checking roundcube..."'+roundcube_web_folder+'"');
    if DirectoryExists(roundcube_web_folder) then begin
          list.Add('$_GLOBAL["roundcube_installed"]=True;');
          list.Add('$_GLOBAL["roundcube_folder"]="'+roundcube.main_folder() + '";');
          list.Add('$_GLOBAL["roundcube_mysql_sources"]="'+roundcube.MYSQL_SOURCE_PATH() + '";');
          list.Add('$_GLOBAL["roundcube_web_folder"]="'+roundcube_web_folder+ '";');
          list.Add('$_GLOBAL["roundcube_version"]="'+roundcube.VERSION() + '";');
          list.Add('$_GLOBAL["roundcube_intversion"]="'+InttOStr(roundcube.INTVERSION(roundcube.VERSION())) + '";');
          list.Add('$_GLOBAL["roundcube_plugins"]="'+roundcube.PluginsList() + '";');
          if FileExists(roundcube_web_folder+'/plugins/subscriptions_option/subscriptions_option.php') then list.Add('$_GLOBAL["roundcube_subscriptions_option"]=True;') else list.Add('$_GLOBAL["roundcube_subscriptions_option"]=False;');
     end else begin
             list.Add('$_GLOBAL["roundcube_installed"]=false;');
    end;
       if verbosed then writeln('web_settings:: 95%');
    LOGS.Debuglogs('web_settings() -> 95%');
    list.Add('?>');


    forcedirectories(php_path + '/ressources');
    LOGS.Debuglogs('web_settings() Terminate save file settings.new.inc');
     try
         list.SaveToFile('/usr/share/artica-postfix/ressources/settings.new.inc');
    except
        LOGS.Debuglogs('web_settings() !!! FATAL ERROR !!! unable to save /usr/share/artica-postfix/ressources/settings.new.inc');
        exit;
   end;
    LOGS.Debuglogs('web_settings() verify file...');
    LOGS.Debuglogs(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.tests-settings.php');
    fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.tests-settings.php >/tmp/exec.tests-settings.txt 2>&1');
    LOGS.Debuglogs('web_settings() ' + logs.ReadFromFile('/tmp/exec.tests-settings.txt'));
    if not FileExists(php_path + '/ressources/settings.inc') then begin
       LOGS.Debuglogs('web_settings() verify file failed ( exec.tests-settings.php return null)..');
    end;
    if not FileExists(php_path + '/ressources/settings.new.inc') then begin
        LOGS.Debuglogs('web_settings() verify file success.. ( settings.new.inc still exists)');
    end else begin
        LOGS.Debuglogs('web_settings() !!!! verify file failed !!!! ressources/settings.new.inc still exists..');
    end;

    fpchmod(php_path + '/ressources/settings.inc',&755);
    logs.Debuglogs('thProcThread.web_settings('+ php_path + ') -> TERM');
    list.Free;;
    if verbosed then writeln('web_settings:: 100%');


end;
//##############################################################################
procedure Tprocess1.killfile(path:string);
Var F : Text;
begin
 if not FileExists(path) then begin
        LOGS.logs('Error:thProcThread.killfile -> file not found (' + path + ')');
        exit;
 end;
TRY
 Assign (F,path);
 Erase (f);
 EXCEPT
 LOGS.logs('Error:thProcThread.killfile -> unable to delete (' + path + ')');
 end;
end;
//##############################################################################
function Tprocess1.ExecPipe(commandline:string):string;
const
  READ_BYTES = 2048;
  CR = #$0d;
  LF = #$0a;
  CRLF = CR + LF;

var
  S: TStringList;
  M: TMemoryStream;
  P: TProcess;
  n: LongInt;
  BytesRead: LongInt;
  xRes:string;

begin
  // writeln(commandline);
  xRes:='';
  M := TMemoryStream.Create;
  BytesRead := 0;
  P := TProcess.Create(nil);
  P.CommandLine := commandline;
  P.Options := [poUsePipes];
  if debug then LOGS.Logs('MyConf.ExecPipe -> ' + commandline);

  P.Execute;
  while P.Running do begin
    M.SetSize(BytesRead + READ_BYTES);
    n := P.Output.Read((M.Memory + BytesRead)^, READ_BYTES);
    if n > 0 then begin
      Inc(BytesRead, n);
    end
    else begin
      Sleep(100);
    end;

  end;

  repeat
    M.SetSize(BytesRead + READ_BYTES);
    n := P.Output.Read((M.Memory + BytesRead)^, READ_BYTES);
    if n > 0 then begin
      Inc(BytesRead, n);
    end;
  until n <= 0;
  M.SetSize(BytesRead);
  S := TStringList.Create;
  S.LoadFromStream(M);
  if debug then LOGS.Logs('Tprocessinfos.ExecPipe -> ' + IntTostr(S.Count) + ' lines');
  for n := 0 to S.Count - 1 do
  begin
    if length(S[n])>1 then begin

      xRes:=xRes + S[n] +CRLF;
    end;
  end;
  if debug then LOGS.Logs('Tprocessinfos.ExecPipe -> exit');
  S.Free;
  P.Free;
  M.Free;
  exit( xRes);
end;
//##############################################################################
function Tprocess1.bdb_recover_check():boolean;
begin
result:=false;
if FileExists(SYS.LOCATE_GENERIC_BIN('db4.9_recover')) then exit(true);
if FileExists(SYS.LOCATE_GENERIC_BIN('db4.8_recover')) then exit(true);
if FileExists(SYS.LOCATE_GENERIC_BIN('db4.7_recover')) then exit(true);
if FileExists(SYS.LOCATE_GENERIC_BIN('db4.6_recover')) then exit(true);
if FileExists(SYS.LOCATE_GENERIC_BIN('db4.5_recover')) then exit(true);
if FileExists(SYS.LOCATE_GENERIC_BIN('db4.4_recover')) then exit(true);
if FileExists(SYS.LOCATE_GENERIC_BIN('db_recover')) then exit(true);
end;
//##############################################################################

procedure Tprocess1.cleanlogs();

var

l:Tstringlist;
i:Integer;
dstat:tdstat;

begin
l:=tstringlist.Create;

l.AddStrings(sys.SearchFilesInPath(GLOBAL_INI.get_ARTICA_PHP_PATH()+'/ressources/logs','*.cache'));
for i:=0 to l.Count-1 do begin
    if SYS.FILE_TIME_BETWEEN_MIN(l.Strings[i])>30 then begin
       logs.DeleteFile(l.Strings[i]);
    end;
end;

CleanAmavisLogs();
KillArticaBackup();
KillsfUpdatesBadProcesses();
logs.Debuglogs('################ clean dstat files ##################' );
dstat:=tdstat.Create(sys);
dstat.FOLLOWFILES();
logs.Debuglogs('################ clean dstat files end ##################' );


end;
//##############################################################################
procedure Tprocess1.CreateYorelUpdate();
var
   l:Tstringlist;
begin
l:=Tstringlist.Create;
l.add('#!/bin/bash');
l.add('');
l.add('# HDD usage is collected with the following command,');
l.add('#  which can only be run as root');
l.add('/bin/chmod 644 /opt/artica/var/rrd/yorel');
l.add('/usr/share/artica-postfix/bin/install/rrd/yorel-upd');
logs.WriteToFile(l.Text,'/usr/share/artica-postfix/bin/install/rrd/yorel_cron');
logs.OutputCmd('/bin/chmod 777 /usr/share/artica-postfix/bin/install/rrd/yorel_cron');
l.free;
end;
//##############################################################################
function Tprocess1.get_LDAP_ADMIN():string;
var
   RegExpr:TRegExpr;
   l:TstringList;
   i:integer;

begin
  if not FileExists(SLAPD_CONF_PATH()) then exit;
  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  TRY
  l.LoadFromFile(SLAPD_CONF_PATH());
  RegExpr.Expression:='rootdn\s+"cn=(.+?),';
  for i:=0 to l.Count-1 do begin
      if  RegExpr.Exec(l.Strings[i]) then begin
             result:=trim(RegExpr.Match[1]);
             break;
      end;
  end;
  FINALLY
   l.free;
   RegExpr.free;
  END;
end;
//#############################################################################
function Tprocess1.get_LDAP_PASSWORD():string;
var
   RegExpr:TRegExpr;
   l:TstringList;
   i:integer;

begin
  if not FileExists(SLAPD_CONF_PATH()) then exit;
  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  TRY
  l.LoadFromFile(SLAPD_CONF_PATH());
  RegExpr.Expression:='rootpw\s+(.+)';
  for i:=0 to l.Count-1 do begin
      if  RegExpr.Exec(l.Strings[i]) then begin
             result:=trim(RegExpr.Match[1]);
             result:=AnsiReplaceText(result,'"','');
             result:=AnsiReplaceText(result,'"','');
             break;
      end;
  end;
  FINALLY
   l.free;
   RegExpr.free;
  END;
end;
//#############################################################################
function Tprocess1.get_LDAP_suffix():string;
var
   RegExpr:TRegExpr;
   l:TstringList;
   i:integer;

begin
  if not FileExists(SLAPD_CONF_PATH()) then exit;
  RegExpr:=TRegExpr.Create;
  l:=TstringList.Create;
  TRY
  l.LoadFromFile(SLAPD_CONF_PATH());
  RegExpr.Expression:='^suffix\s+(.+)';
  for i:=0 to l.Count-1 do begin
      if  RegExpr.Exec(l.Strings[i]) then begin
             result:=trim(RegExpr.Match[1]);
             result:=AnsiReplaceText(result,'"','');
             result:=AnsiReplaceText(result,'"','');
             break;
      end;
  end;
  FINALLY
   l.free;
   RegExpr.free;
  END;
end;
//#############################################################################



procedure Tprocess1.CleanCpulimit();
var
   CpuPOurc:integer;
   l:Tstringlist;
   i:Integer;
   RegExpr:TRegExpr;
   cpulmit:string;
   tmpstr:string;
begin
     tmpstr:=logs.FILE_TEMP();
     cpulmit:=SYS.LOCATE_GENERIC_BIN('cpulimit');
     if not FIleExists(cpulmit) then exit;
     fpsystem(SYS.LOCATE_GENERIC_BIN('pgrep')+' -f -l "'+cpulmit+'" >'+tmpstr+' 2>&1');

     if not FileExists(tmpstr) then exit;
     l:=Tstringlist.Create;
     l.LoadFromFile(tmpstr);
     logs.DeleteFile(tmpstr);
     RegExpr:=TRegExpr.Create;
     RegExpr.Expression:='^([0-9]+).+?cpulimit -p\s+([0-9]+)';
     logs.Debuglogs('Tprocess1.CleanCpulimit(): Testing '+intToStr(l.Count)+' processes');
     for i:=0 to l.Count-1 do begin
         if not RegExpr.Exec(l.Strings[i]) then continue;

            logs.Debuglogs('Tprocess1.CleanCpulimit(): Testing '+RegExpr.Match[1]+' that watch '+RegExpr.Match[2]);
            if not SYS.PROCESS_EXIST(RegExpr.Match[2]) then begin
                  logs.Debuglogs('Tprocess1.CleanCpulimit(): killing '+RegExpr.Match[1]);
                  fpsystem('/bin/kill -9 '+RegExpr.Match[1]);
                  continue;
            end;

            CpuPOurc:=SYS.GET_CPU_POURCENT(StrToInt(RegExpr.Match[1]));
            logs.Debuglogs('Tprocess1.CleanCpulimit(): Testing '+RegExpr.Match[1]+'='+IntToStr(CpuPOurc)+'% CPU');
            if CpuPOurc>30 then begin
                logs.Debuglogs('Tprocess1.CleanCpulimit(): killing '+RegExpr.Match[1] +' Reach max then 30% cpu');
                 fpsystem('/bin/kill -9 '+RegExpr.Match[1]);
            end;

     end;

     //ps -p 14604 -o pcpu --no-heading

 l.free;
 RegExpr.free;
end;

procedure Tprocess1.CleanAmavisLogs();
var
zdate,tmp:string;
ArticaMaxLogsSize,FileSize:Integer;
begin
     ArticaMaxLogsSize:=0;
     zdate:=logs.DateTimeNowSQL();
     zdate:=AnsiReplaceText(zdate,' ','_');
     zdate:=AnsiReplaceText(zdate,':','');
     if not FileExists('/var/log/amavis/amavis.log') then exit;
     tmp:=SYS.GET_INFO('AmavisMaxLogSizeKo');
     if not TryStrToInt(tmp,ArticaMaxLogsSize) then ArticaMaxLogsSize:=150;
     if ArticaMaxLogsSize<5 then ArticaMaxLogsSize:=5;
     ArticaMaxLogsSize:=ArticaMaxLogsSize*1000;
     FileSize:=SYS.FileSize_ko('/var/log/amavis/amavis.log');
     logs.Debuglogs('Tprocess1.CleanAmavisLogs():: /var/log/amavis/amavis.log : '+IntToStr(FileSize)+'Ko <>' + IntToStr(ArticaMaxLogsSize)+'Ko');
     if FileSize>ArticaMaxLogsSize then begin
          fpsystem('/etc/init.d/artica-postfix stop amavis');
          logs.OutputCmd('/bin/tar -cvf /var/log/amavis/amavis_'+zdate+'.tgz /var/log/amavis/amavis.log');
          logs.DeleteFile('/var/log/amavis/amavis.log');
          logs.OutputCmd('/bin/touch /var/log/amavis/amavis.log');
          logs.OutputCmd('/bin/chown postfix:postfix /var/log/amavis/amavis.log');
          fpsystem('/etc/init.d/artica-postfix start amavis');
          logs.NOTIFICATION('[ARTICA]: (' + SYS.HOSTNAME_g()+') /var/log/amavis/amavis.log removed ',IntTostr(FileSize) + ' exceed '+ IntTostr(ArticaMaxLogsSize) +' Ko. logs has been saved in /var/log/amavis/amavis_'+zdate+'.tgz and amavis was restarted','system');
     end;
end;
//##############################################################################
function Tprocess1.SLAPD_CONF_PATH():string;
begin
   if FileExists('/etc/ldap/slapd.conf') then exit('/etc/ldap/slapd.conf');
   if FileExists('/etc/openldap/slapd.conf') then exit('/etc/openldap/slapd.conf');
   if FileExists('/etc/openldap/ldap.conf') then exit('/etc/openldap/slapd.conf');
   if FileExists('/opt/artica/etc/openldap/slapd.conf') then exit('/opt/artica/etc/openldap/slapd.conf');
   if FileExists('/usr/local/etc/openldap/slapd.conf') then exit('/usr/local/etc/openldap/slapd.conf');
   exit('/etc/ldap/slapd.conf');

end;
//##############################################################################
procedure Tprocess1.KillArticaBackup();
         const
            CR = #$0d;
            LF = #$0a;
            CRLF = CR + LF;
var
   i,maxtime,maxday,space:Integer;
   Directory:string;
   FileList:TstringList;
   TargetFile:string;
   text:string;
begin
  if Not TryStrToInt(SYS.GET_INFO('ArticaBackupMaxTimeToLiveInDay'),maxday) then begin
       Logs.Debuglogs('KillArticaBackup() ArticaBackupMaxTimeToLiveInDay is not integer, assume 7 days');
       maxday:=7;
  end;
  


  Directory:=SYS.GET_INFO('ArticaBackupTargetLocalPath');
  if length(Directory)=0 then begin
     logs.Debuglogs('KillArticaBackup() no target path specified');
     exit;
  end;
  
  if Not DirectoryExists(Directory) then begin
      Logs.Debuglogs('KillArticaBackup() ' + Directory + ' does not exists');
      exit;
  end;
  
  FileList:=TstringList.Create;
  maxday:=(maxday*24)*60;
  FileList.AddStrings(sys.DirFiles(Directory,'*.gz'));
  logs.Debuglogs(Directory+'=' + IntToStr(FileList.Count)+' file(s)');

    for i:=0 to FileList.Count-1 do begin
        TargetFile:=Directory+ '/'+FileList.Strings[i];
        maxtime:=SYS.FILE_TIME_BETWEEN_MIN(TargetFile);
        if maxtime>maxday then begin
           logs.Syslogs('Backup container '  + FileList.Strings[i] + ' have more than ' + IntToStr(maxday) +' Minutes, kill it');
           space:=SYS.FileSize_ko(TargetFile);
           logs.DeleteFile(TargetFile);
           text:='The Max day to live is ' + intToStr(maxday) + ' minutes'+CRLF;
           text:=text+'This file has ' + intToStr(maxtime) + ' minutes'+CRLF;
           text:=text+'it has been deleted and free  ' + intToStr(space) + 'ko space '+CRLF;
           logs.NOTIFICATION('[ARTICA]: (' + SYS.HOSTNAME_g()+') '+FileList.Strings[i]+' ('+IntTostr(space)+'Ko) backup container has been deleted',text,'system');
        end;
  end;
end;

//##############################################################################
procedure Tprocess1.KillsfUpdatesBadProcesses();
var
l:TstringList;
i:Integer;
pid:string;
begin
if not FileExists('/usr/local/ap-mailfilter3/bin/sfupdates') then exit;
l:=TstringList.Create;
l.AddStrings(SYS.AllPidsByPatternInPathTstrings('/usr/local/ap-mailfilter3/bin/sfupdates'));
logs.Debuglogs('Found ' + IntToStr(l.Count)+ ' PID(s)');

if l.Count>3 then begin
 for i:=0 to l.count-1 do begin
    pid:=trim(l.Strings[i]);
     if length(pid)=0 then continue;
     fpsystem('/bin/kill -9 ' + pid);
 end;

end;

l.free;
end;
//##############################################################################
procedure Tprocess1.CheckSyslog(BigSize:integer;syslog_path:string);
var
   msize:longint;


begin
  msize:=0;

  
  
  if BigSize<100 then begin
     logs.Syslogs('Tprocess1.CheckSyslog():: Fake ArticaMaxLogsSize !!!, abort');
     exit;
  end;

  if FileExists(syslog_path) then begin
        msize:=SYS.FileSize_ko(syslog_path);
        logs.Debuglogs('Tprocess1.CheckSyslog():: '+syslog_path + ':: ' + IntToStr(msize) + 'ko..');
        if msize>BigSize then begin
           logs.Debuglogs('Syslog exceed maximal size... Kill it');
           logs.DeleteFile(syslog_path);
           logs.NOTIFICATION('[ARTICA]: (' + SYS.HOSTNAME_g()+') syslog file exceed maximal size ('+IntTostr(msize)+'Ko)','This file was deleted because it exceed '+IntTostr(BigSize)+'Ko','system');
           syslogng:=Tsyslogng.Create(SYS);
           if FileExists(syslogng.DEAMON_BIN_PATH()) then begin
              syslogng.STOP();
              syslogng.START();
           end;

           if FIleExists('/etc/init.d/syslog') then fpsystem('/etc/init.d/syslog restart &');
           if FileExists('/etc/init.d/sysklogd') then fpsystem('/etc/init.d/sysklogd restart &');
           fpsystem('/etc/init.d/artica-postfix restart sysloger');
           
        end else begin
           logs.syslogs('Tprocess1.CheckSyslog():: '+syslog_path + ':: ' + IntToStr(msize) + 'ko.. SKIP must reach '+IntToStr(BigSize)+'ko before kill it');
        end;
  end;
  
end;
//##############################################################################
function Tprocess1.IOSTAT():string;
var
   i:Integer;
   RegExpr:TRegExpr;
   l:TstringList;
   tmpstr:string;
   s:Tstringlist;
begin

  if not FileExists('/usr/bin/iostat') then exit;
  tmpstr:=logs.FILE_TEMP();
  fpsystem('/usr/bin/iostat -x >'+tmpstr+' 2>&1');
  if not FileExists(tmpstr) then exit;

  l:=Tstringlist.Create;
  l.LoadFromFile(tmpstr);
  logs.DeleteFile(tmpstr);
  RegExpr:=TRegExpr.Create;
//  RegExpr.Expression:='^(.+?)\s+([0-9,\.]+)';
    RegExpr.Expression:='^([a-zA-Z0-9\.\_\-]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)\s+([0-9,\.]+)$';
  s:=Tstringlist.Create;

  for i:=0 to l.Count-1 do begin

      if RegExpr.Exec(l.Strings[i]) then begin
         s.Add('"'+RegExpr.Match[1]+'"=>"'+RegExpr.Match[12]+'",');
      end else begin

      end;
  end;

   result:=s.Text;
   l.free;
   RegExpr.free;
   s.free;
end;
//##############################################################################
procedure Tprocess1.WatchDogExecutor();
var
   timefile:integer;
   ArticaMetaPoolTimeMin:integer;
   ArticaMetaEnabled:integer;

begin
     if not TryStrToInt(SYS.GET_INFO('ArticaMetaPoolTimeMin'),ArticaMetaPoolTimeMin) then ArticaMetaPoolTimeMin:=15;
     if not TryStrToInt(SYS.GET_INFO('ArticaMetaEnabled'),ArticaMetaEnabled) then ArticaMetaEnabled:=0;
     if ArticaMetaPoolTimeMin<2 then ArticaMetaPoolTimeMin:=15;
     timefile:=SYS.FILE_TIME_BETWEEN_MIN('/var/log/artica-postfix/executor-daemon.log');
     if timefile>5 then begin
        logs.Debuglogs('WatchDogExecutor:: artica-executor seems freeze, restart it');
        fpsystem('/etc/init.d/artica-postfix restart artica-exec');
     end else begin
      logs.Debuglogs('WatchDogExecutor:: artica-executor '+IntTOstr( timefile)+'mn');
     end;


     timefile:=SYS.FILE_TIME_BETWEEN_MIN('/var/log/artica-postfix/status-daemon.log');
     if timefile>5 then begin
        logs.Debuglogs('WatchDogExecutor:: artica-status seems freeze, restart it');
        fpsystem('/etc/init.d/artica-postfix restart artica-status');
     end else begin
      logs.Debuglogs('WatchDogExecutor:: artica-status '+IntTOstr( timefile)+'mn');
     end;


     timefile:=SYS.FILE_TIME_BETWEEN_MIN('/var/log/artica-postfix/artica-orders.debug');
     if timefile>5 then begin
        logs.Debuglogs('WatchDogExecutor:: artica-order seems freeze, restart it');
        fpsystem('/etc/init.d/artica-postfix restart artica-back');
     end else begin
      logs.Debuglogs('WatchDogExecutor:: artica-order '+IntTOstr( timefile)+'mn');
     end;

     if ArticaMetaEnabled=1 then begin
         timefile:=SYS.FILE_TIME_BETWEEN_MIN('/var/log/artica-postfix/artica-meta-agent.log');
          if timefile>ArticaMetaPoolTimeMin then begin
          logs.Debuglogs('WatchDogExecutor:: artica-meta agent seems freeze, restart it');
          fpsystem(SYS.LOCATE_PHP5_BIN()+' /usr/share/artica-postfix/exec.artica.meta.php --status');
          end else begin
          logs.Debuglogs('WatchDogExecutor:: artica-meta agent '+IntTOstr( timefile)+'mn');
          end;
     end else begin
         logs.Debuglogs('WatchDogExecutor:: artica-meta agent is disabled');
     end;

end;
function Tprocess1.LOCATE_PROCSTAT():string;
begin
   if FileExists('/usr/share/artica-postfix/bin/procstat') then exit('/usr/share/artica-postfix/bin/procstat');
   if FileExists('/opt/artica-agent/bin/procstat') then exit('/opt/artica-agent/bin/procstat');
end;

function Tprocess1.TEST_PROCSTAT():boolean;
var
   i:Integer;
   RegExpr:TRegExpr;
   l:TstringList;
   tmpstr:string;
   binpath:string;
begin
result:=false;
binpath:=LOCATE_PROCSTAT();
if not FileExists(binpath) then begin
   if FileExists('/usr/share/artica-postfix/bin/install/procstat.c') then fpsystem('gcc -o /usr/share/artica-postfix/bin/procstat /usr/share/artica-postfix/bin/install/procstat.c');
   if FileExists('/opt/artica-agent/bin/procstat.c') then fpsystem('gcc -o /opt/artica-agent/bin/procstat /opt/artica-agent/bin/procstat.c');
   exit;
end;
tmpstr:=logs.FILE_TEMP();
fpsystem(binpath+' 0 >'+tmpstr+' 2>&1');
l:=Tstringlist.Create;
l.LoadFromFile(tmpstr);
logs.DeleteFile(tmpstr);
RegExpr:=TRegExpr.Create;
RegExpr.Expression:='GLIBC';
for i:=0 to l.Count-1 do begin
    if RegExpr.Exec(l.Strings[i]) then begin
       if FileExists('/usr/share/artica-postfix/bin/install/procstat.c') then fpsystem('gcc -o /usr/share/artica-postfix/bin/procstat /usr/share/artica-postfix/bin/install/procstat.c');
       if FileExists('/opt/artica-agent/bin/procstat.c') then fpsystem('gcc -o /opt/artica-agent/bin/procstat /opt/artica-agent/bin/procstat.c');
    end;
end;

RegExpr.free;
l.free;
end;



end.

