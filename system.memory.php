<?php
	include_once('ressources/class.templates.inc');
	include_once('ressources/class.ldap.inc');
	include_once('ressources/class.users.menus.inc');
	include_once('ressources/class.main_cf.inc');
	
	$usersmenus=new usersMenus();
	if($usersmenus->AsArticaAdministrator==false){header('location:users.index.php');exit;}


if(isset($_GET["js"])){echo js();exit;}
if(isset($_GET["popup"])){popup();exit;}
if(isset($_POST["SwapEnabled"])){SaveSwapAuto();exit;}


function js(){
	$page=CurrentPageName();
	$tpl=new templates();
	$title=$tpl->_ENGINE_parse_body('{memory_info}');
	$html="
	 YahooWin5('650','$page?popup=yes','$title');
	 
	
	
	";
	
	echo $html;
}

function SaveSwapAuto(){
	$sock=new sockets();
	
	$SwapOffOn=unserialize(base64_decode($sock->GET_INFO("SwapOffOn")));
	$sock->SET_INFO("DisableSWAPP", $_POST["DisableSWAPP"]);
	while (list ($num, $line) = each ($_POST) ){
		$SwapOffOn[$num]=$line;
	}
	
	if(!is_numeric($SwapOffOn["SwapEnabled"])){$SwapOffOn["SwapEnabled"]=1;}
	if(!is_numeric($SwapOffOn["SwapMaxPourc"])){$SwapOffOn["SwapMaxPourc"]=20;}
	if(!is_numeric($SwapOffOn["SwapMaxMB"])){$SwapOffOn["SwapMaxMB"]=0;}	
	if(!is_numeric($SwapOffOn["SwapTimeOut"])){$SwapOffOn["SwapTimeOut"]=60;}
	$sock->SaveConfigFile(base64_encode(serialize($SwapOffOn)),"SwapOffOn");
	$sock->getFrameWork("cmd.php?restart-artica-status=yes");
	$sock->getFrameWork("system.php?swap-init=yes");
	
	
}

function popup(){
	$table_memory=table_memory();
	$page=CurrentPageName();
	$sock=new sockets();
	
	$SwapOffOn=unserialize(base64_decode($sock->GET_INFO("SwapOffOn")));
	$DisableSWAPP=$sock->GET_INFO("DisableSWAPP");
	if(!is_numeric($SwapOffOn["SwapEnabled"])){$SwapOffOn["SwapEnabled"]=1;}
	if(!is_numeric($SwapOffOn["SwapMaxPourc"])){$SwapOffOn["SwapMaxPourc"]=20;}
	if(!is_numeric($SwapOffOn["SwapMaxMB"])){$SwapOffOn["SwapMaxMB"]=0;}
	if(!is_numeric($DisableSWAPP)){$DisableSWAPP=0;}
	if(!is_numeric($SwapOffOn["SwapTimeOut"])){$SwapOffOn["SwapTimeOut"]=60;}
	$table_swap="
	
	
	<div style='font-size:24px'>{automatic_swap_cleaning}</div>
	<div class=explain style='font-size:14px'>{automatic_swap_cleaning_explain}</div>
	<div id='AutoSwapDiv'>
	<table style='width:99%' class=form>
	<tr>
		<td class=legend>{DisableSWAPP}:</td>
		<td>". Field_checkbox("DisableSWAPP",1,$DisableSWAPP,"CheckSwap()")."</td>
	</tr>			
	<tr>
		<td class=legend>{enable}:</td>
		<td>". Field_checkbox("SwapEnabled",1,$SwapOffOn["SwapEnabled"],"CheckSwap()")."</td>
	</tr>
	<tr>
		<td class=legend>{xtimeout}:</td>
		<td style='font-size:13px;'>". Field_text("SwapTimeOut",$SwapOffOn["SwapTimeOut"],"font-size:13px;padding:3px;width:30px")."&nbsp;Mn</td>
	</tr>				
	<tr>
		<td class=legend>{MaxDiskUsage}:</td>
		<td>". Field_text("SwapMaxPourc",$SwapOffOn["SwapMaxPourc"],"font-size:13px;padding:3px;width:30px")."</td>
	</tr>
	<tr>
		<td class=legend>{maxsize}:</td>
		<td>". Field_text("SwapMaxMB",$SwapOffOn["SwapMaxMB"],"font-size:13px;padding:3px;width:60px")."&nbsp;<strong style='font-size:13px'>MB</td>
	</tr>		
	<tr>
		<td colspan=2 align='right'><hr>". button("{apply}","SaveSwapAuto()",16)."</td>
	</tr>
	</table>
	</div>";	
	
	$html="
	
	<table style='width:100%'>
	<tr>
		<td valign='top' width=1%><img src='img/bg_memory-250.png'><br>$table_memory</td>
		<td valign='top'>$table_swap</td>
	</tr>
	</table>
	<script>
	
	
	var x_SaveSwapAuto= function (obj) {
		var results=obj.responseText;
		if(results.length>0){alert(results);}
		Loadjs('$page?js=yes');
		
	}		
	
	function SaveSwapAuto(){
		var XHR=XHRParseElements('AutoSwapDiv');
		DisableSWAPP=0;
		SwapEnabled=0;
		if(document.getElementById('SwapEnabled').checked){SwapEnabled=1;}
		if(document.getElementById('DisableSWAPP').checked){DisableSWAPP=1;}
		var XHR = new XHRConnection();
		XHR.appendData('SwapMaxPourc',document.getElementById('SwapMaxPourc').value);
		XHR.appendData('SwapMaxMB',document.getElementById('SwapMaxMB').value);
		XHR.appendData('SwapTimeOut',document.getElementById('SwapTimeOut').value);
		XHR.appendData('SwapEnabled',SwapEnabled);
		XHR.appendData('DisableSWAPP',DisableSWAPP);
		AnimateDiv('AutoSwapDiv');
		XHR.sendAndLoad('$page', 'POST',x_SaveSwapAuto);	
		
	}
	
	function CheckSwap(){
		document.getElementById('SwapEnabled').disabled=true;
		document.getElementById('SwapMaxPourc').disabled=true;
		document.getElementById('SwapMaxMB').disabled=true;
		document.getElementById('SwapTimeOut').disabled=true;
		
		
		if(document.getElementById('DisableSWAPP').checked){return;}
		document.getElementById('SwapEnabled').disabled=false;
		if(!document.getElementById('SwapEnabled').checked){return;}
		document.getElementById('SwapMaxPourc').disabled=false;
		document.getElementById('SwapTimeOut').disabled=false;
		document.getElementById('SwapMaxMB').disabled=false;		
	
	}
	
	CheckSwap();
	</script>";
	
	$tpl=new templates();
	echo $tpl->_ENGINE_parse_body($html);
	
}


applications_Status();	

function applications_Status(){
	$tpl=new templates();
	

	
	
	$html="
	<div class=form>{memory_info_text}</div>
		<h4>{memory_info}</H4>
		<table style='width:100%'>
		<tr>
		<td valign='top' width=1%><img src='img/bg_memory.jpg'></td>
		<td valign='top'>
		".table_memory()."
		
			</td>
		</tr>
	</table>
	";
	$tpl=new template_users('{memory_info}',$html);
	echo $tpl->web_page;
	
}

function table_memory(){
	$sys=new systeminfos();
	$tpl=new templates();
	if($sys->swap_total>0){
		$pourc=round(($sys->swap_used/$sys->swap_total)*100);
	}
	
	if(is_numeric($pourc)){
		$pourc_swap="				<tr>
					<td class=legend style='font-size:14px'>{used}:</strong></td>
					<td style='font-size:14px'>$sys->swap_used Mb ($pourc%)</strong></td>	
				</tr>	";
		
	}
	
	return $tpl->_ENGINE_parse_body("<table  style='width:99%' class=form>
				<tr><td colspan=2><strong style='font-size:14px'>{physical_memory}</strong></td></tr>
				<tr>
					<td class=legend style='font-size:14px'>{total}</strong></td>
					<td style='font-size:14px'>$sys->memory_total Mb</strong></td>	
				</tr>
				<tr>
					<td class=legend style='font-size:14px'>{free}</strong></td>
					<td style='font-size:14px'>$sys->memory_free Mb</strong></td>	
				</tr>	
				<tr>
					<td class=legend style='font-size:14px'>{used}</strong></td>
					<td style='font-size:14px'>$sys->memory_used Mb</strong></td>	
				</tr>					
				<tr>
					<td class=legend style='font-size:14px'>{shared}</strong></td>
					<td style='font-size:14px'>$sys->memory_shared Mb</strong></td>	
				</tr>
				<tr>
					<td class=legend style='font-size:14px'>{cached}</strong></td>
					<td style='font-size:14px'>$sys->memory_cached Mb</strong></td>	
				</tr>	
				<tr><td colspan=2><strong style='font-size:14px'>{swap_memory}</strong></td></tr>				
				<tr>
					<td class=legend style='font-size:14px'>{total}:</strong></td>
					<td style='font-size:14px'>$sys->swap_total Mb</strong></td>	
				</tr>	
				<tr>
					<td class=legend style='font-size:14px'>{free}:</strong></td>
					<td style='font-size:14px'>$sys->swap_free Mb</strong></td>	
				</tr>
				$pourc_swap																				
			</table>");
	
}


function disk(){
$tpl=new templates();
	$sys=new systeminfos();
	$hash=$sys->DiskUsages();	
	if(!is_array($hash)){return null;}
	$img="<img src='img/fw_bold.gif'>";
	$html="<H4>{disks_usage}:</h4>
	<table style='width:600px' align=center>
	<tr style='background-color:#CCCCCC'>
	<td>&nbsp;</td>
	<td class=legend>{Filesystem}:</strong></td>
	<td class=legend>{size}:</strong></td>
	<td class=legend>{used}:</strong></td>
	<td class=legend>{available}:</strong></td>
	<td align='center'><strong>{use%}:</strong></td>
	<td class=legend>{mounted_on}:</strong></td>
	</tr>
	";
	
	 while (list ($num, $ligne) = each ($hash) ){
	 	$html=$html . "<tr " . CellRollOver().">
	 	<td width=1% class=bottom>$img</td>
	 	<td class=bottom>{$ligne[0]}:</td>
	 	<td class=bottom>{$ligne[2]}:</td>
	 	<td class=bottom>{$ligne[3]}:</td>
	 	<td class=bottom>{$ligne[4]}:</td>
	 	<td align='center' class=bottom><strong>{$ligne[5]}:</strong></td>
	 	<td class=bottom>{$ligne[6]}:</td>
	 	</tr>
	 	";
	 	
	 }
	return $html . "</table>";
	
}
	