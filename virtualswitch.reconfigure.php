<?php
	header("Pragma: no-cache");	
	header("Expires: 0");
	header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
	header("Cache-Control: no-cache, must-revalidate");	
	if(isset($_GET["verbose"])){$GLOBALS["VERBOSE"]=true;ini_set('display_errors', 1);ini_set('error_reporting', E_ALL);ini_set('error_prepend_string',null);ini_set('error_append_string',null);}
	include_once('ressources/class.templates.inc');
	include_once('ressources/class.ldap.inc');
	include_once('ressources/class.users.menus.inc');
	include_once('ressources/class.system.network.inc');
	include_once('ressources/class.system.nics.inc');
	include_once('ressources/class.maincf.multi.inc');
	include_once('ressources/class.tcpip.inc');
	$usersmenus=new usersMenus();
	if(!$usersmenus->AsArticaAdministrator){die();}
	
	if(isset($_GET["popup"])){popup();exit;}
	if(isset($_GET["step2"])){step2();exit;}
	if(isset($_GET["step3"])){step3();exit;}
js();


function js(){
	
	$q=new mysql();
	$tpl=new templates();
	$page=CurrentPageName();
	$t=$_GET["t"];
	header("content-type: application/x-javascript");
	$switch=$_GET["switch"];
	$title=$tpl->javascript_parse_text("{install_virtual_switch}:$switch");
	echo "YahooWin2('750','$page?popup=yes&switch=$switch&t=$t','$title')";
	
}

function popup(){
	$switch=$_GET["switch"];
	$t=$_GET["t"];
	$tpl=new templates();
	$page=CurrentPageName();	
	$sock=new sockets();
	$tt=time();
	$sock->getFrameWork("vde.php?switch-reconfigure=yes&switch=$switch");
	
	
	$html="<center id='step1-$t' style='font-size:22px;margin-bottom:15px'>{please_wait_reconfiguring_service}</center>
	<center id='wait-$t' style='font-size:22px;margin:20px'></div>
	<script>
	function Step2$tt(){
		LoadAjax('wait-$t','$page?step2=yes&switch=$switch&t=$t');
		$('#table-$t').flexReload();
	
	}
	
	
	setTimeout(\"Step2$tt()\",2000);
	
	</script>";
	
	echo $tpl->_ENGINE_parse_body($html);
	
}

function step2(){
	$t=$_GET["t"];
	$tt=time();
	$page=CurrentPageName();
	$switch=$_GET["switch"];
	$tpl=new templates();
	$sock=new sockets();
	$t=$_GET["t"];
	$please_wait_restarting_service=$tpl->javascript_parse_text("{please_wait_reloading_service}");
	$ARRAY=unserialize(base64_decode($sock->getFrameWork("vde.php?switch-status=yes&switch=$switch")));
	$failed=$tpl->javascript_parse_text("{install_failed}");
	if(!$ARRAY["INSTALLED"]){
		echo "
		<script>		
		document.getElementById('step1-$t').innerHTML='$failed';
		function Step3$tt(){ YahooWin2Hide(); $('#table-$t').flexReload();}
		setTimeout(\"Step3$tt()\",2000);
		</script>		
		";
		return;
	}
	
	$sock->getFrameWork("vde.php?switch-network-restart=yes&switch=$switch");
	

	echo "
	<script>
	function Step3$tt(){
		$('#table-$t').flexReload();
		LoadAjax('wait-$t','$page?step3=yes&switch=$switch&t=$t');
	}
	document.getElementById('step1-$t').innerHTML='$please_wait_restarting_service';
	setTimeout(\"Step3$tt()\",5000);
	</script>
	";	
}


function step3(){
	$t=$_GET["t"];
	$tt=time();
	$page=CurrentPageName();
	$switch=$_GET["switch"];
	$tpl=new templates();
	$sock=new sockets();
	$t=$_GET["t"];
	$please_wait_restarting_service=$tpl->javascript_parse_text("{please_wait_reloading_service}");
	
	$text="{success}";
	$text=$tpl->javascript_parse_text($text);
	echo "
	<script>
	function Step4$tt(){
		YahooWin2Hide();
		RefreshTab('main_switch{$switch}');
		$('#table-$t').flexReload();
	
	}
	document.getElementById('step1-$t').innerHTML='$text';
	setTimeout(\"Step4$tt()\",5000);
	</script>
	";
}

