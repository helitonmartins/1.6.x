<?php
include_once('ressources/class.templates.inc');
include_once('ressources/class.ldap.inc');
include_once('ressources/class.users.menus.inc');
include_once('ressources/class.mysql.inc');
include_once('ressources/class.ini.inc');


if(isset($_GET["js"])){js();exit;}
if(isset($_GET["events-table"])){events_table();exit;}
if(isset($_GET["ShowID"])){ShowID();exit;}
if(isset($_GET["ShowID-js"])){ShowID_js();exit;}
if(isset($_POST["empty-table"])){empty_table();exit;}
popup();


function js(){
	header("content-type: application/x-javascript");
	$tpl=new templates();
	$title=$tpl->_ENGINE_parse_body("{events}");
	$page=CurrentPageName();
	if($_GET["uuid"]<>null){
		$meta=new mysql_meta();
		$hostname=$meta->uuid_to_host($_GET["uuid"]);
	}
	echo "YahooWin3('1100','$page?uuid=".urlencode($_GET["uuid"])."','$title $hostname')";
}


function ShowID_js(){
	header("content-type: application/x-javascript");
	$id=$_GET["ShowID-js"];
	if(!is_numeric($id)){
		
		return;
	
	}$tpl=new templates();
	header("content-type: application/x-javascript");
	$page=CurrentPageName();
	$sql="SELECT subject FROM meta_admin_mysql WHERE ID=$id";
	$q=new mysql();
	$ligne=@mysql_fetch_array($q->QUERY_SQL($sql,"artica_events"));
	
	$subject=$tpl->javascript_parse_text($ligne["subject"]);
	echo "YahooWin6('550','$page?ShowID=$id','$subject')";
	
}
function ShowID(){

$tpl=new templates();
$sql="SELECT content FROM meta_admin_mysql WHERE ID={$_GET["ShowID"]}";
$q=new mysql();
$ligne=@mysql_fetch_array($q->QUERY_SQL($sql,"artica_events"));

$content=$tpl->_ENGINE_parse_body($ligne["content"]);
$content=nl2br($content);
echo "<p style='font-size:18px'>$content</p>";
}

function empty_table(){
	$q=new mysql();
	$q->QUERY_SQL("TRUNCATE TABLE meta_admin_mysql","artica_events");
}

function popup(){

	$page=CurrentPageName();
	$tpl=new templates();
	$date=$tpl->javascript_parse_text("{zDate}");
	$description=$tpl->javascript_parse_text("{description}");
	$context=$tpl->javascript_parse_text("{context}");
	$events=$tpl->javascript_parse_text("{events}");
	$empty=$tpl->javascript_parse_text("{empty}");
	$daemon=$tpl->javascript_parse_text("{daemon}");
	$hostname=$tpl->javascript_parse_text("{hostname}");
	$settings=$tpl->javascript_parse_text("{watchdog_squid_settings}");
	$empty_events_text_ask=$tpl->javascript_parse_text("{empty_events_text_ask}");
	$TB_HEIGHT=450;
	$TB_WIDTH=927;
	$TB2_WIDTH=551;
	$all=$tpl->javascript_parse_text("{all}");
	$t=time();

	$buttons="
	buttons : [
	{name: '$empty', bclass: 'Delz', onpress : EmptyEvents},
	{name: 'Warn', bclass: 'Warn', onpress :  Warn$t},
	{name: 'Info', bclass: 'Help', onpress :  info$t},
	{name: 'Crit.', bclass: 'Err', onpress :  Err$t},
	{name: '$all', bclass: 'Statok', onpress :  All$t},
	
	

	],	";
	$html="
<table class='events-table-$t' style='display: none' id='events-table-$t' style='width:99%'></table>
	<script>

function BuildTable$t(){
	$('#events-table-$t').flexigrid({
		url: '$page?events-table=yes&text-filter={$_GET["text-filter"]}&hostname=".urlencode($_GET["hostname"])."&uuid={$_GET["uuid"]}',
		dataType: 'json',
		colModel : [
		{display: '', name : 'severity', width :31, sortable : true, align: 'center'},
		{display: '$date', name : 'zDate', width :127, sortable : true, align: 'left'},
		{display: '$events', name : 'subject', width : $TB2_WIDTH, sortable : false, align: 'left'},
		{display: '$daemon', name : 'filename', width :145, sortable : true, align: 'left'},
		{display: '$hostname', name : 'hostname', width :145, sortable : true, align: 'left'},
		
		],
		$buttons
	
		searchitems : [
		{display: '$events', name : 'subject'},
		{display: '$hostname', name : 'hostname'},
		
		],
		sortname: 'zDate',
		sortorder: 'desc',
		usepager: true,
		title: '',
		useRp: true,
		rp: 50,
		showTableToggleBtn: false,
		width: '99%',
		height: $TB_HEIGHT,
		singleSelect: true,
		rpOptions: [10, 20, 30, 50,100,200,500]

	});
}

function articaShowEvent(ID){
	YahooWin6('750','$page?ShowID='+ID,'$title::'+ID);
}

var x_EmptyEvents= function (obj) {
	var results=obj.responseText;
	if(results.length>3){alert(results);return;}
	$('#events-table-$t').flexReload();
	//$('#grid_list').flexOptions({url: 'newurl/'}).flexReload();
	// $('#fgAllPatients').flexOptions({ query: 'blah=qweqweqwe' }).flexReload();

}

function Warn$t(){
	$('#events-table-$t').flexOptions({url: '$page?events-table=yes&critical=1&hostname=".urlencode($_GET["hostname"])."'}).flexReload(); 
}
function info$t(){
	$('#events-table-$t').flexOptions({url: '$page?events-table=yes&critical=2&hostname=".urlencode($_GET["hostname"])."'}).flexReload(); 
}
function Err$t(){
	$('#events-table-$t').flexOptions({url: '$page?events-table=yes&critical=0&hostname=".urlencode($_GET["hostname"])."'}).flexReload(); 
}
function All$t(){
	$('#events-table-$t').flexOptions({url: '$page?events-table=yes&hostname=".urlencode($_GET["hostname"])."'}).flexReload(); 
}

function EmptyEvents(){
	if(!confirm('$empty_events_text_ask')){return;}
	var XHR = new XHRConnection();
	XHR.appendData('empty-table','yes');
	XHR.sendAndLoad('$page', 'POST',x_EmptyEvents);
}
setTimeout(\" BuildTable$t()\",800);
</script>";

echo $html;

}

function events_table(){
	$tpl=new templates();
	$MyPage=CurrentPageName();
	$q=new mysql();

	$FORCE=1;
	
	
	
	$search='%';
	$table="meta_admin_mysql";
	$page=1;
	$ORDER="ORDER BY zDate DESC";
	if(is_numeric($_GET["critical"])){
		$FORCE="severity={$_GET["critical"]}";
	}
	
	if($_GET["text-filter"]<>null){
		$FORCE=" subject LIKE '%{$_GET["text-filter"]}%'";
		if(is_numeric($_GET["critical"])){
			$FORCE=$FORCE." AND severity={$_GET["critical"]}";
		}
	}
	
	if($_GET["hostname"]<>null){
		$FORCE=$FORCE." AND hostname='{$_GET["hostname"]}'";
	}
	if($_GET["uuid"]<>null){
		$FORCE=$FORCE." AND uuid='{$_GET["uuid"]}'";
	}

	$total=0;
	if($q->COUNT_ROWS($table,"artica_events")==0){json_error_show("no data",3);}
	if(isset($_POST["sortname"])){if($_POST["sortname"]<>null){$ORDER="ORDER BY {$_POST["sortname"]} {$_POST["sortorder"]}";}}
	if(isset($_POST['page'])) {$page = $_POST['page'];}

	$severity[0]="22-red.png";
	$severity[1]="22-warn.png";
	$severity[2]="22-infos.png";
	$currentdate=date("Y-m-d");

	$searchstring=string_to_flexquery();
	
	if($searchstring<>null){
		
		
		$sql="SELECT COUNT(*) as TCOUNT FROM `$table` WHERE $FORCE $searchstring";
		$ligne=mysql_fetch_array($q->QUERY_SQL($sql,"artica_events"));
		if(!$q->ok){ if(preg_match("#marked as crashed#", $q->mysql_error)){ $q->QUERY_SQL("DROP TABLE `$table`","artica_events"); } }
		
		$total = $ligne["TCOUNT"];

	}else{
		if(strlen($FORCE)>2){
			$sql="SELECT COUNT(*) as TCOUNT FROM `$table` WHERE $FORCE";
			$ligne=mysql_fetch_array($q->QUERY_SQL($sql,"artica_events"));
			if(!$q->ok){ if(preg_match("#marked as crashed#", $q->mysql_error)){ $q->QUERY_SQL("DROP TABLE `$table`","artica_events"); } }
			$total = $ligne["TCOUNT"];
		}else{
			$total = $q->COUNT_ROWS($table, "artica_events");
		}
	}

	if (isset($_POST['rp'])) {$rp = $_POST['rp'];}



	$pageStart = ($page-1)*$rp;
	$limitSql = "LIMIT $pageStart, $rp";
	
	$sql="SELECT *  FROM `$table` WHERE $FORCE $searchstring $ORDER $limitSql";
	writelogs($sql,__FUNCTION__,__FILE__,__LINE__);
	$results = $q->QUERY_SQL($sql,"artica_events");
	if(!$q->ok){ if(preg_match("#marked as crashed#", $q->mysql_error)){ $q->QUERY_SQL("DROP TABLE `$table`","artica_events"); } }
	if(!$q->ok){json_error_show($q->mysql_error,3);}

	$data = array();
	$data['page'] = $page;
	$data['total'] = $total;
	$data['rows'] = array();

	$CurrentPage=CurrentPageName();

	if(mysql_num_rows($results)==0){json_error_show("no data $sql",3);}

	while ($ligne = mysql_fetch_assoc($results)) {
		
		$hostname=$ligne["hostname"];
		$ligne["zDate"]=str_replace($currentdate, "", $ligne["zDate"]);
		$severity_icon=$severity[$ligne["severity"]];
		$link="<a href=\"javascript:blur();\" OnClick=\"javascript:Loadjs('$CurrentPage?ShowID-js={$ligne["ID"]}')\" style='text-decoration:underline'>";
		$text=$link.$tpl->_ENGINE_parse_body($ligne["subject"]."</a><div style='font-size:10px'>{host}:$hostname {function}:{$ligne["function"]}, {line}:{$ligne["line"]}</div>");
		
		
		$data['rows'][] = array(
				'id' => $ligne['ID'],
				'cell' => array(
						"<img src='img/$severity_icon'>",
						
						$ligne["zDate"],$text,$ligne["filename"],$ligne["hostname"] )
		);
	}


	echo json_encode($data);

}