<?php
if(is_file("/etc/artica-postfix/FROM_ISO")){if(is_file("/etc/init.d/artica-cd")){print "Starting......: artica-". basename(__FILE__)." Waiting Artica-CD to finish\n";die();}}
if(posix_getuid()<>0){die("Cannot be used in web server mode\n\n");}
$GLOBALS["FORCE"]=false;
$GLOBALS["RECONFIGURE"]=false;
$GLOBALS["SWAPSTATE"]=false;
if(preg_match("#--verbose#",implode(" ",$argv))){$GLOBALS["VERBOSE"]=true;$GLOBALS["OUTPUT"]=true;$GLOBALS["debug"]=true;ini_set('display_errors', 1);ini_set('error_reporting', E_ALL);ini_set('error_prepend_string',null);ini_set('error_append_string',null);}
if(preg_match("#--output#",implode(" ",$argv))){$GLOBALS["OUTPUT"]=true;}
if(preg_match("#schedule-id=([0-9]+)#",implode(" ",$argv),$re)){$GLOBALS["SCHEDULE_ID"]=$re[1];}
if(preg_match("#--force#",implode(" ",$argv),$re)){$GLOBALS["FORCE"]=true;}
if(preg_match("#--reconfigure#",implode(" ",$argv),$re)){$GLOBALS["RECONFIGURE"]=true;}
$GLOBALS["AS_ROOT"]=true;
include_once(dirname(__FILE__).'/framework/class.unix.inc');
include_once(dirname(__FILE__).'/framework/frame.class.inc');
include_once(dirname(__FILE__).'/framework/class.settings.inc');


	$GLOBALS["ARGVS"]=implode(" ",$argv);
	if($argv[1]=="--stop"){$GLOBALS["OUTPUT"]=true;stop();die();}
	if($argv[1]=="--start"){$GLOBALS["OUTPUT"]=true;start();die();}
	if($argv[1]=="--restart"){$GLOBALS["OUTPUT"]=true;restart();die();}
	if($argv[1]=="--status"){$GLOBALS["OUTPUT"]=true;status();die();}


function restart(){
	$unix=new unix();
	$pidfile="/etc/artica-postfix/pids/".basename(__FILE__).".".__FUNCTION__.".pid";
	$oldpid=$unix->get_pid_from_file($pidfile);
	if($unix->process_exists($oldpid,basename(__FILE__))){
		$time=$unix->PROCCESS_TIME_MIN($oldpid);
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Already Artica task running PID $oldpid since {$time}mn\n";}
		return;
	}
	@file_put_contents($pidfile, getmypid());
	stop(true);
	start(true);	
	
	
}	
	
function stop($aspid=false){
	$unix=new unix();
	if(!$aspid){
		$pidfile="/etc/artica-postfix/pids/".basename(__FILE__).".".__FUNCTION__.".pid";
		$oldpid=$unix->get_pid_from_file($pidfile);
		if($unix->process_exists($oldpid,basename(__FILE__))){
			$time=$unix->PROCCESS_TIME_MIN($oldpid);
			if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Already Artica task running PID $oldpid since {$time}mn\n";}
			return;
		}
		@file_put_contents($pidfile, getmypid());
	}
	
	$pid=LIGHTTPD_PID();
	
	
	if(!$unix->process_exists($pid)){
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Framework service already stopped...\n";}
		return;
	}	
	$pid=LIGHTTPD_PID();
	$nohup=$unix->find_program("nohup");
	$php5=$unix->LOCATE_PHP5_BIN();
	$lighttpd_bin=$unix->find_program("lighttpd");
	$kill=$unix->find_program("kill");
	
	
	
	if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Framework shutdown pid $pid...\n";}
	shell_exec("$kill $pid >/dev/null 2>&1");
	for($i=0;$i<5;$i++){
		$pid=LIGHTTPD_PID();
		if(!$unix->process_exists($pid)){break;}
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service waiting pid:$pid $i/5...\n";}
		sleep(1);
	}	
	
	$pid=LIGHTTPD_PID();
	if(!$unix->process_exists($pid)){
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Framework service success...\n";}
		killallphpcgi();
		return;
	}

	if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Framework shutdown - force - pid $pid...\n";}
	shell_exec("$kill -9 $pid >/dev/null 2>&1");
	for($i=0;$i<5;$i++){
		$pid=LIGHTTPD_PID();
		if(!$unix->process_exists($pid)){break;}
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service waiting pid:$pid $i/5...\n";}
		sleep(1);
	}	
	
	if(!$unix->process_exists($pid)){
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Framework service success...\n";}
		killallphpcgi();
		return;
	}else{
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Framework service failed...\n";}
	}	
}

function killallphpcgi(){
	
	$unix=new unix();
	$phpcgi=$unix->LIGHTTPD_PHP5_CGI_BIN_PATH();
	$kill=$unix->find_program("kill");
	$array=$unix->PIDOF_PATTERN_ALL($phpcgi);
	if(count($array)==0){
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: No ghost processes...\n";}
		return;
	}
	$c=0;
	while (list ($pid, $line) = each ($array) ){
		$username=$unix->PROCESS_GET_USER($pid);
		if($username==null){continue;}
		if($username<>"root"){continue;}
		$c++;
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: Stopping ghots processes $pid\n";}
		shell_exec("$kill -9 $pid 2>&1");
	}
	
	if($c==0){
		if($GLOBALS["OUTPUT"]){echo "Stopping......: [INIT]: No ghost processes...\n";}
	}
	
}

function status(){
	$unix=new unix();
	$phpcgi=$unix->LIGHTTPD_PHP5_CGI_BIN_PATH();	
	$pidfile="/etc/artica-postfix/pids/".basename(__FILE__).".".__FUNCTION__.".pid";
	$pidtime="/etc/artica-postfix/pids/".basename(__FILE__).".".__FUNCTION__.".time";
	$oldpid=$unix->get_pid_from_file($pidfile);
	if($unix->process_exists($oldpid,basename(__FILE__))){
		$time=$unix->PROCCESS_TIME_MIN($oldpid);
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Already Artica task running PID $oldpid since {$time}mn\n";}
		return;
	}
	
	if(!$GLOBALS["VERBOSE"]){
		$timeExec=$unix->file_time_min($pidtime);
		if($timeExec<15){return;}
	}
	@unlink($pidtime);
	@file_put_contents($pidtime, time());
	@file_put_contents($pidfile, getmypid());	
	
	$pid=LIGHTTPD_PID();
	$unix=new unix();
	if($unix->process_exists($pid)){
		$timepid=$unix->PROCCESS_TIME_MIN($pid);
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service running $pid since {$timepid}Mn...\n";}
	}else{
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service stopped...\n";}
		start();
		return;
	}
	$MAIN_PID=$pid;
	$phpcgi=$unix->LIGHTTPD_PHP5_CGI_BIN_PATH();
	$kill=$unix->find_program("kill");
	$array=$unix->PIDOF_PATTERN_ALL($phpcgi);
	if(count($array)==0){
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: no php-cgi processes...\n";}
		return;
	}
	while (list ($pid, $line) = each ($array) ){
		$username=$unix->PROCESS_GET_USER($pid);
		if($username==null){continue;}
		if($username<>"root"){continue;}
		$time=$unix->PROCCESS_TIME_MIN($pid);
		$arrayPIDS[$pid]=$time;
		$ppid=$unix->PPID_OF($pid);
		if($time>20){
			if($ppid<>$MAIN_PID){
				if($GLOBALS["VERBOSE"]){echo "killing $pid {$time}mn ppid:$ppid/$MAIN_PID\n";}
				shell_exec("$kill -9 $pid 2>&1");
			}
		}
	}

	if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: ".count($arrayPIDS)." php-cgi processes...\n";}
	
}



function start($aspid=false){
	$unix=new unix();
	
	
	if(!$aspid){
		$pidfile="/etc/artica-postfix/pids/".basename(__FILE__).".".__FUNCTION__.".pid";
		$oldpid=$unix->get_pid_from_file($pidfile);
		if($unix->process_exists($oldpid,basename(__FILE__))){
			$time=$unix->PROCCESS_TIME_MIN($oldpid);
			if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Already Artica task running PID $oldpid since {$time}mn\n";}
			return;
		}
		@file_put_contents($pidfile, getmypid());
	}	
	
	$pid=LIGHTTPD_PID();
	
	if($unix->process_exists($pid)){
		$timepid=$unix->PROCCESS_TIME_MIN($pid);
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service already started $pid since {$timepid}Mn...\n";}
		return;
	}
		
	
	$nohup=$unix->find_program("nohup");
	$php5=$unix->LOCATE_PHP5_BIN();
	$lighttpd_bin=$unix->find_program("lighttpd");
	if(!is_file($lighttpd_bin)){
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service lighttpd not found..\n";}
		return;
	}
	
	@mkdir("/var/run/lighttpd",0755,true);
	$cmd="$nohup $php5 /usr/share/artica-postfix/exec.web-community-filter.php --register-lic >/dev/null 2>&1 &";
	if($GLOBALS["VERBOSE"]){echo "$cmd\n";}
	shell_exec($cmd);
	buildConfig();
	$cmd="$lighttpd_bin -f /etc/artica-postfix/framework.conf";
	if($GLOBALS["VERBOSE"]){echo "$cmd\n";}
	shell_exec($cmd);
	
	for($i=0;$i<6;$i++){
		$pid=LIGHTTPD_PID();
		if($unix->process_exists($pid)){break;}
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service waiting $i/6...\n";}
		sleep(1);
	}
	
	$pid=LIGHTTPD_PID();
	if($unix->process_exists($pid)){
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework Success service started pid:$pid...\n";}
	}else{
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Framework service failed...\n";}
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: $cmd\n";}
	}
	
	
}

function LIGHTTPD_PID(){
	$unix=new unix();
	$pid=$unix->get_pid_from_file('/var/run/lighttpd/framework.pid');
	if($unix->process_exists($pid)){return $pid;}
	$lighttpd_bin=$unix->find_program("lighttpd");
	return $unix->PIDOF_PATTERN($lighttpd_bin." -f /etc/artica-postfix/framework.conf");
}

function PHP_FPM_Params(){
	$unix=new unix();
	if(isset($GLOBALS["PHP-PARAMS"])){return $GLOBALS["PHP-PARAMS"];}
	$daemon_path=$unix->APACHE_LOCATE_PHP_FPM();
	exec("$daemon_path -h 2>&1",$array);


	while (list ($index, $line) = each ($array) ){
		if(preg_match("#-([a-zA-Z]),\s+--(.+?)\s+#", $line,$re)){
			$GLOBALS["PHP-PARAMS"][$re[1]]=true;
			$GLOBALS["PHP-PARAMS"][$re[2]]=true;
			continue;
		}

		if(preg_match("#-([a-zA-Z]),\s+--(.+?)$#", $line,$re)){
			$GLOBALS["PHP-PARAMS"][$re[1]]=true;
			$GLOBALS["PHP-PARAMS"][$re[2]]=true;
			continue;
		}

		if(preg_match("#-([a-zA-Z])\s+#", $line,$re)){
			$GLOBALS["PHP-PARAMS"][$re[1]]=true;
		}

	}

	return $GLOBALS["PHP-PARAMS"];

}

function buildConfig(){
	$unix=new unix();
	$sock=new sockets();
	$phpcgi=$unix->LIGHTTPD_PHP5_CGI_BIN_PATH();
	@mkdir("/usr/share/artica-postfix/framework",0755,true);
	@mkdir("/usr/share/artica-postfix/ressources/sock",0755,true);
	@mkdir("/var/run/artica-framework",0755,true);
	$LighttpdRunAsminimal=$sock->GET_INFO("LighttpdRunAsminimal");
	$LighttpdArticaMaxProcs=$sock->GET_INFO("LighttpdArticaMaxProcs");
	$LighttpdArticaMaxChildren=$sock->GET_INFO("LighttpdArticaMaxChildren");
	$PHP_FCGI_MAX_REQUESTS=$sock->GET_INFO("PHP_FCGI_MAX_REQUESTS");
	
	if(!is_numeric($LighttpdRunAsminimal)){$LighttpdRunAsminimal=0;}
	if(!is_numeric($LighttpdArticaMaxProcs)){$LighttpdArticaMaxProcs=0;}
	if(!is_numeric($LighttpdArticaMaxChildren)){$LighttpdArticaMaxChildren=0;}
	if(!is_numeric($PHP_FCGI_MAX_REQUESTS)){$PHP_FCGI_MAX_REQUESTS=200;}
	
	$PHP_FCGI_CHILDREN=3;
	$max_procs=3;
	
	
	if($LighttpdArticaMaxProcs>0){$max_procs=$LighttpdArticaMaxProcs;}
	if($LighttpdArticaMaxChildren>0){$PHP_FCGI_CHILDREN=$LighttpdArticaMaxChildren;}
	
	if(!$unix->ISMemoryHiger1G()){
		$PHP_FCGI_CHILDREN=3;
		$max_procs=3;
		$PHP_FCGI_MAX_REQUESTS=1500;
	}
	
	if($LighttpdRunAsminimal==1){
		$max_procs=1;
		$PHP_FCGI_CHILDREN=2;
		$PHP_FCGI_MAX_REQUESTS=500;
	}
	
	if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: MAX Procs............: $max_procs\n";}
	if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Php5 processes.......: $PHP_FCGI_CHILDREN\n";}
	if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Max cnx/processes....: $PHP_FCGI_MAX_REQUESTS\n";}
	
	$phpfpm=$unix->APACHE_LOCATE_PHP_FPM();
	$EnablePHPFPMFrameWork=$sock->GET_INFO("EnablePHPFPMFrameWork");
	if(!is_numeric($EnablePHPFPMFrameWork)){$EnablePHPFPMFrameWork=0;}
	if(!is_file($phpfpm)){$EnablePHPFPM=0;}
	$PHP_FPM_Params=PHP_FPM_Params();
	if(!isset($ParseParams["allow-to-run-as-root"])){$EnablePHPFPMFrameWork=0;}
	
	if($EnablePHPFPM==1){
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Using PHP-FPM........: Yes\n";}
	}else{
		if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: Using PHP-FPM........: No\n";}
	}
	
	$phpcgi_path=$unix->LIGHTTPD_PHP5_CGI_BIN_PATH();
	if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: php-cgi path.........: $phpcgi_path\n";}
	$f[]="#artica-postfix saved by artica lighttpd.conf";
	$f[]="";
	$f[]="server.modules = (";
	$f[]="        \"mod_alias\",";
	$f[]="        \"mod_access\",";
	$f[]="        \"mod_accesslog\",";
	$f[]="        \"mod_compress\",";
	$f[]="        \"mod_fastcgi\",";
	$f[]="        \"mod_cgi\",";
	$f[]="	       \"mod_status\"";
	$f[]=")";
	$f[]="";
	$f[]="server.document-root        = \"/usr/share/artica-postfix/framework\"";
	$f[]="server.errorlog             = \"/var/log/artica-postfix/framework_error.log\"";
	$f[]="index-file.names            = ( \"index.php\")";
	$f[]="";
	$f[]="mimetype.assign             = (";
	$f[]="  \".pdf\"          =>      \"application/pdf\",";
	$f[]="  \".sig\"          =>      \"application/pgp-signature\",";
	$f[]="  \".spl\"          =>      \"application/futuresplash\",";
	$f[]="  \".class\"        =>      \"application/octet-stream\",";
	$f[]="  \".ps\"           =>      \"application/postscript\",";
	$f[]="  \".torrent\"      =>      \"application/x-bittorrent\",";
	$f[]="  \".dvi\"          =>      \"application/x-dvi\",";
	$f[]="  \".gz\"           =>      \"application/x-gzip\",";
	$f[]="  \".pac\"          =>      \"application/x-ns-proxy-autoconfig\",";
	$f[]="  \".swf\"          =>      \"application/x-shockwave-flash\",";
	$f[]="  \".tar.gz\"       =>      \"application/x-tgz\",";
	$f[]="  \".tgz\"          =>      \"application/x-tgz\",";
	$f[]="  \".tar\"          =>      \"application/x-tar\",";
	$f[]="  \".zip\"          =>      \"application/zip\",";
	$f[]="  \".mp3\"          =>      \"audio/mpeg\",";
	$f[]="  \".m3u\"          =>      \"audio/x-mpegurl\",";
	$f[]="  \".wma\"          =>      \"audio/x-ms-wma\",";
	$f[]="  \".wax\"          =>      \"audio/x-ms-wax\",";
	$f[]="  \".ogg\"          =>      \"application/ogg\",";
	$f[]="  \".wav\"          =>      \"audio/x-wav\",";
	$f[]="  \".gif\"          =>      \"image/gif\",";
	$f[]="  \".jar\"          =>      \"application/x-java-archive\",";
	$f[]="  \".jpg\"          =>      \"image/jpeg\",";
	$f[]="  \".jpeg\"         =>      \"image/jpeg\",";
	$f[]="  \".png\"          =>      \"image/png\",";
	$f[]="  \".xbm\"          =>      \"image/x-xbitmap\",";
	$f[]="  \".xpm\"          =>      \"image/x-xpixmap\",";
	$f[]="  \".xwd\"          =>      \"image/x-xwindowdump\",";
	$f[]="  \".css\"          =>      \"text/css\",";
	$f[]="  \".html\"         =>      \"text/html\",";
	$f[]="  \".htm\"          =>      \"text/html\",";
	$f[]="  \".js\"           =>      \"text/javascript\",";
	$f[]="  \".asc\"          =>      \"text/plain\",";
	$f[]="  \".c\"            =>      \"text/plain\",";
	$f[]="  \".cpp\"          =>      \"text/plain\",";
	$f[]="  \".log\"          =>      \"text/plain\",";
	$f[]="  \".conf\"         =>      \"text/plain\",";
	$f[]="  \".text\"         =>      \"text/plain\",";
	$f[]="  \".txt\"          =>      \"text/plain\",";
	$f[]="  \".dtd\"          =>      \"text/xml\",";
	$f[]="  \".xml\"          =>      \"text/xml\",";
	$f[]="  \".mpeg\"         =>      \"video/mpeg\",";
	$f[]="  \".mpg\"          =>      \"video/mpeg\",";
	$f[]="  \".mov\"          =>      \"video/quicktime\",";
	$f[]="  \".qt\"           =>      \"video/quicktime\",";
	$f[]="  \".avi\"          =>      \"video/x-msvideo\",";
	$f[]="  \".asf\"          =>      \"video/x-ms-asf\",";
	$f[]="  \".asx\"          =>      \"video/x-ms-asf\",";
	$f[]="  \".wmv\"          =>      \"video/x-ms-wmv\",";
	$f[]="  \".bz2\"          =>      \"application/x-bzip\",";
	$f[]="  \".tbz\"          =>      \"application/x-bzip-compressed-tar\",";
	$f[]="  \".tar.bz2\"      =>      \"application/x-bzip-compressed-tar\",";
	$f[]="  \"\"              =>      \"application/octet-stream\",";
	$f[]=" )";
	$f[]="";
	$f[]="";
	$f[]="accesslog.filename          = \"/var/log/artica-postfix/framework.log\"";
	$f[]="url.access-deny             = ( \"~\", \".inc\" )";
	$f[]="";
	$f[]="static-file.exclude-extensions = ( \".php\", \".pl\", \".fcgi\" )";
	$f[]="server.port                 = 47980";
	$f[]="server.bind                = \"127.0.0.1\"";
	$f[]="#server.error-handler-404   = \"/error-handler.html\"";
	$f[]="#server.error-handler-404   = \"/error-handler.php\"";
	$f[]="server.pid-file             = \"/var/run/lighttpd/framework.pid\"";
	$f[]="server.max-keep-alive-requests = 0";
	$f[]="server.max-keep-alive-idle = 4";
	$f[]="server.stat-cache-engine = \"simple\"";
	$f[]="server.max-fds 		   = 2048";
	$f[]="server.network-backend      = \"writev\"";
	$f[]="";
	if($EnablePHPFPM==0){
		$f[]="fastcgi.server = ( \".php\" =>((";
		$f[]="                \"bin-path\" => \"$phpcgi_path\",";
		$f[]="                \"socket\" => \"/var/run/artica-framework/fastcgi-\" + PID + \".sock\",";
		
	}else{
		$f[]="fastcgi.server = ( \".php\" =>((";
		$f[]="                \"socket\" => \"/var/run/php-fpm-framework.sock\",";
	}
	$f[]="                \"max-procs\" => $max_procs,";
	$f[]="                \"idle-timeout\" => 30,";
	$f[]="                \"bin-environment\" => (";
	$f[]="                        \"PHP_FCGI_CHILDREN\" => \"$PHP_FCGI_CHILDREN\",";
	$f[]="                        \"PHP_FCGI_MAX_REQUESTS\" => \"$PHP_FCGI_MAX_REQUESTS\",";
	$f[]="                        \"PATH\" => \"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/X11R6/bin:/usr/kerberos/bin\",";
	$f[]="                        \"LD_LIBRARY_PATH\" => \"/lib:/usr/local/lib:/usr/lib/libmilter:/usr/lib\",";
	$f[]="                        \"CPPFLAGS\" => \"-I/usr/include/libmilter -I/usr/include -I/usr/local/include -I/usr/include/linux -I/usr/include/sm/os\",";
	$f[]="                        \"LDFLAGS\" => \"-L/lib -L/usr/local/lib -L/usr/lib/libmilter -L/usr/lib\",";
	$f[]="                ),";
	$f[]="                \"broken-scriptfilename\" => \"enable\"";
	$f[]="        ))";
	$f[]=")";
	$f[]="ssl.engine                 = \"disable\"";
	$f[]="status.status-url          = \"/server-status\"";
	$f[]="status.config-url          = \"/server-config\"";
	$f[]="\$HTTP[\"url\"] =~ \"^/webmail\" {";
	$f[]="	server.follow-symlink = \"enable\"";
	$f[]="}";
	$f[]="alias.url += ( \"/cgi-bin/\" => \"/usr/lib/cgi-bin/\" )";
	$f[]="alias.url += ( \"/css/\" => \"/usr/share/artica-postfix/css/\" )";
	$f[]="alias.url += ( \"/img/\" => \"/usr/share/artica-postfix/img/\" )";
	$f[]="alias.url += ( \"/js/\" => \"/usr/share/artica-postfix/js/\" )";
	$f[]="";
	$f[]="cgi.assign= (";
	$f[]="	\".pl\"  => \"/usr/bin/perl\",";
	$f[]="	\".php\" => \"/usr/bin/php-cgi\",";
	$f[]="	\".py\"  => \"/usr/bin/python\",";
	$f[]="	\".cgi\"  => \"/usr/bin/perl\",";
	$f[]=")\n";
	
	@file_put_contents("/etc/artica-postfix/framework.conf", @implode("\n", $f));
	if($GLOBALS["OUTPUT"]){echo "Starting......: [INIT]: /etc/artica-postfix/framework.conf done\n";}
}
