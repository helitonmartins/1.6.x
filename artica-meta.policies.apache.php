<?php
include_once('ressources/class.templates.inc');
include_once('ressources/class.mysql-meta.inc');
include_once('ressources/class.system.network.inc');
include_once('ressources/class.system.nics.inc');


$users=new usersMenus();
if(!$users->AsArticaMetaAdmin){
	$tpl=new templates();
	echo "alert('".$tpl->javascript_parse_text("{ERROR_NO_PRIVS}")."');";die();

}
if(isset($_POST["policy-id"])){Save();exit;}

page();



function page(){
	$q=new mysql_meta();
	$ID=$_GET["policy-id"];
	$EnableFreeWeb=intval($q->GET("EnableFreeWeb",$ID));
	$EnableNginx=intval($q->GET("EnableNginx",$ID));
	$tpl=new templates();
	$page=CurrentPageName();
	$t=time();
	
	$p=Paragraphe_switch_img("{enable_freeweb}","{enable_freeweb_text}",
			"EnableFreeWeb-$t",$EnableFreeWeb,null,600);	
	
	$p1=Paragraphe_switch_img("{enable_reverse_proxy_service}", "{enable_reverse_proxy_service_explain}",
			"EnableNginx-$t",$EnableNginx,null,600);
	
	$html="
<div style='width:98%' class=form>
	$p
	<br>
	$p1
	<div style='text-align:right;margin-top:20px'>". button("{apply}","Save$t()",26)."</div>
</div>
<script>
	var xSave$t= function (obj) {
	var tempvalue=obj.responseText;
	if(tempvalue.length>3){alert(tempvalue);return;};
	RefreshTab('meta-policy-$ID');
}
	
function Save$t(){
	var XHR = new XHRConnection();
	XHR.appendData('EnableFreeWeb',document.getElementById('EnableFreeWeb-$t').value);
	XHR.appendData('EnableNginx',document.getElementById('EnableNginx-$t').value);
	XHR.appendData('policy-id','$ID');
	XHR.sendAndLoad('$page', 'POST',xSave$t);
}
</script>
					";
	echo $tpl->_ENGINE_parse_body($html);
}

function Save(){
$policy_id=$_POST["policy-id"];
unset($_POST["policy-id"]);
$q=new mysql_meta();
while (list ($key, $val) = each ($_POST)){
	if(!$q->SET($key, $val, $policy_id)){echo $q->mysql_error;return;}
}

$sock=new sockets();
$sock->getFrameWork("artica.php?apply-policy=yes&policy-id=$policy_id");
}

