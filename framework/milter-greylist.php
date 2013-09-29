<?php
include_once(dirname(__FILE__)."/frame.class.inc");

if(isset($_GET["empty-database"])){database_empty();exit;}

if(isset($_GET["dump-database"])){database_list();exit;}
function database_list(){
	$db="/var/milter-greylist/greylist.db";
	$inc_file="/usr/share/artica-postfix/ressources/logs/mgrelist-db.inc";
	if(isset($_GET["db_path"])){
		$db=base64_decode(trim($_GET["db_path"]));
		$inc_file="/usr/share/artica-postfix/ressources/logs/mgrelist-{$_GET["hostname"]}.inc";
		}
	
	$datas=file_get_contents($db);
	
	$tbl=explode("\n",$datas);
	if(!is_array($tbl)){return null;}
	
	while (list ($num, $line) = each ($tbl) ){
		if(trim($line)==null){continue;}
		if(preg_match("#greylisted tuples#",$line)){$KEY="GREY";continue;}
		if(preg_match("#stored tuples#",$line)){$KEY="GREY";continue;}
		if(preg_match("#Auto-whitelisted tuples#",$line)){$KEY="WHITE";continue;}
		
		if(preg_match("#([0-9\.]+)\s+<(.+?)>\s+<(.+?)>#",$line,$re)){
			$conf[]="\$MGREYLIST_DB[\"$KEY\"][]=array('{$re[1]}','{$re[2]}','{$re[3]}');";
			continue;
		}
		
		writelogs_framework("unable to preg_match $line",__FUNCTION__,__FILE__,__LINE__);
	}
	writelogs_framework("DB FILE=\"$db\"",__FUNCTION__,__FILE__,__LINE__);
	writelogs_framework("INC FILE=$inc_file",__FUNCTION__,__FILE__,__LINE__);
	
	$file="<?php\n";
	if(is_array($conf)){
	$file=$file.implode("\n",$conf);
	}
	$file=$file."\n";
	$file=$file."?>";
	
	@file_put_contents($inc_file,$file);
	@chmod($inc_file,0755);
	
	
}

function database_empty(){
	$hostname=$_GET["hostname"];
	if($hostname==null){$hostname="master";}
	if($hostname=="master"){
		$d[]="/var/milter-greylist/greylist.db";
		$d[]="/usr/share/artica-postfix/ressources/logs/mgrelist-db.inc";
	}
	if($hostname<>"master"){
		$d[]="/var/milter-greylist/$hostname/greylist.db";
		$d[]="/usr/share/artica-postfix/ressources/logs/mgrelist-{$_GET["hostname"]}.inc";
	}
	$d[]="/usr/share/artica-postfix/ressources/logs/greylist-count-$hostname.tot";
	$d[]="/usr/share/artica-postfix/ressources/logs/mgrelist-$hostname.inc";
	while (list ($num, $line) = each ($d) ){
		if(is_file($line)){@unlink($line);}
	}
	$unix=new unix();
	$nohup=$unix->find_program("nohup");
	shell_exec("$nohup /etc/init.d/milter-greylist restart >/dev/null 2>&1 &");
}

?>