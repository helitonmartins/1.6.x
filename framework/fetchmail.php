<?php

include_once(dirname(__FILE__)."/frame.class.inc");
include_once(dirname(__FILE__)."/class.unix.inc");


if(isset($_GET["reconfigure"])){reconfigure();exit;}
if(isset($_GET["debug-rule"])){execute_debug();exit;}
if(isset($_GET["import"])){import_fetchmail_rules();exit;}
if(isset($_GET["reload-fetchmail"])){reload();exit;}
if(isset($_GET["import-compiled"])){import_fetchmail_compiled_rules();exit;}

while (list ($num, $line) = each ($_GET)){$f[]="$num=$line";}

writelogs_framework("unable to understand query !!!!!!!!!!!..." .@implode(",",$f),"main()",__FILE__,__LINE__);
die();


function execute_debug(){
	$unix=new unix();
	$php=$unix->LOCATE_PHP5_BIN();
	$nohup=$unix->find_program("nohup");
	$su=$unix->find_program("su");
	$cmd=trim("$nohup $php /usr/share/artica-postfix/exec.fetchmail.php --single-debug {$_GET["debug-rule"]} >/dev/null 2>&1 &");
	shell_exec($cmd);
	writelogs_framework("$cmd",__FUNCTION__,__FILE__,__LINE__);
}

function reconfigure(){
	$unix=new unix();
	$php=$unix->LOCATE_PHP5_BIN();
	$nohup=$unix->find_program("nohup");
	$su=$unix->find_program("su");
	$cmd=trim("$php /usr/share/artica-postfix/exec.fetchmail.php >/dev/null 2>&1");
	shell_exec($cmd);
	writelogs_framework("$cmd",__FUNCTION__,__FILE__,__LINE__);
}

function import_fetchmail_rules(){
	$path=base64_decode($_GET["path"]);
	if(!is_file($path)){return;}
	$unix=new unix();
	$php=$unix->LOCATE_PHP5_BIN();
	$nohup=$unix->find_program("nohup");
	$cmd=trim("$nohup $php /usr/share/artica-postfix/exec.fetchmail.php --import \"$path\" >/usr/share/artica-postfix/ressources/logs/web/fetchmail.import.log 2>&1 &");
	shell_exec($cmd);
}
function import_fetchmail_compiled_rules(){
	$path=base64_decode($_GET["path"]);
	if(!is_file($path)){return;}
	$unix=new unix();
	$php=$unix->LOCATE_PHP5_BIN();
	$nohup=$unix->find_program("nohup");
	$cmd=trim("$php /usr/share/artica-postfix/exec.fetchmail.php --import-file \"$path\"");
	shell_exec($cmd);	
}
function reload(){
	$unix=new unix();
	$php=$unix->LOCATE_PHP5_BIN();
	$nohup=$unix->find_program("nohup");
	$cmd=trim("$nohup $php /usr/share/artica-postfix/exec.fetchmail.php --reload >/dev/null 2>&1 &");
	if(isset($_GET["tenir"])){
		$cmd="$php /usr/share/artica-postfix/exec.fetchmail.php --reload >/dev/null 2>&1";
	}
	writelogs_framework("$cmd",__FUNCTION__,__FILE__,__LINE__);	
	
}

