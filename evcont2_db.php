<?php

$timer_start_total = microtime(true);
$timer_db = 0;
$mod_action = "none";
$body = "";

#include_once('PATHS.inc.php');
#include_once(DIR_HOME . '/functions.inc.php');
#include_once(DIR_HOME . '/db_functions.inc.php');
#include_once(DIR_HOME . '/header_account.inc.php');

    //$db = databaseConnect();
    //print $argc . "\n";

    // evcont_db.php 110515-080001_centro_retrieve.sum configuracion tiempo_ejecucion ruta_y_nombre_summary_report.asc


    if ($argc<2) {
	print "error, necesito mínimo una ruta en la que buscar el fichero 'Retrieve.sum'\n"; exit;
    }

    $filename = $argv[1];
    
    if ($argc>=3) {
	$conf_name = $argv[2];
    } else {
	$pos_ini = strpos($filename, '_');
	if ($pos_ini === FALSE) {
	    $conf_name = "Unknown";
	} else {
	    if ( ($pos_fin = strpos($filename, '_', $pos_ini + 1)) === FALSE )
		$conf_name = "Unknown";
	    else
		$conf_name = substr($filename, $pos_ini + 1, $pos_fin - ($pos_ini + 1) );
	}
    }
    if ($argc>=4) {
	$duration = $argv[3];
    } else {
	$duration = 0;
    }
    
    if ($argc>=5) {
	$summary_filename = $argv[4];
    } else {
	$summary_filename = "";
    }

    if ( !file_exists($filename) ||
	($summary = file($filename)) === FALSE || count($summary)==0 ) {
	print "error, no existe >${filename}< o no contiene informacion valida.\n"; exit;
    }

    $dateSQL = $timeSQLStart = $timeSQLStop = "";
    $list_sql_radar = $list_sql_summary = $list_radar = $list_column = array();
    $sql_insert = array();
    $sql_create = "";

    for($i=0;$i<count($summary);$i++) {

	$line = trim($summary[$i]);
	if ($line[0] != 'X') continue;
	$lineArr = explode(' ', $line);

	if (count($lineArr)==5) {
	    //X OC Procentage_chained 99.378018 11/05/02_08:00:01_08:27:38.00
	    list($nada1, $module, $column, $value, $date ) = $lineArr;
	    $radar = ""; $filters = "";
	} elseif (count($lineArr)==6) { //linea sin filtro aplicado
	    //X RASTA Tot_Ant_Turns 333 11/05/02_08:00:03_08:27:39 alcolea   
	    list($nada1, $module, $column, $value, $date, $radar) = $lineArr;
	    $filters="";
	} elseif (count($lineArr)==7) { // linea con filtro aplicado
	    //X TABULAR_PDF Correct_Mode_C 99.79 11/05/02_08:00:01_08:27:38.00 aspontes CHse_civil_5.fltsql
	    list($nada1, $module, $column, $value, $date, $radar, $filters) = $lineArr;
	}
	if ( ($rc = preg_match('@(\d+)/(\d+)/(\d+)_(\d+):(\d+):(\d+)_(\d+):(\d+):(\d+)@', $date, $m))>0 ) {
	    $dateSQL = $m[1]."-".$m[2]."-".$m[3];
	    $timeSQLStart = $m[4].":" . $m[5].":".$m[6]; $timeSQLStop = $m[7].":".$m[8].":".$m[9];
	} else {
	    print "--- couldn't find date with preg_match in string >$date<\n";
	    exit;
	}
	$column = trim($column);$value = trim($value); $date = trim($date); $radar = trim($radar);
	$list_column[] = $module."_".$column;

	if ($radar=="") {
	    $list_sql_summary[] = $module."_".$column."=".$value;
	} else {
	    if ($value=="nan") // safety (aparece nan en evaluaciones de asturiaswam)
	        $value="NULL";
	    $list_radar[] = $radar;
	    if (!isset($list_sql_radar[$radar])) $list_sql_radar[$radar]=array();
	    if ($filters=="") {
		$list_sql_radar[$radar][] = "`" . $module."_".$column."`=".$value;
	    } else {
		$list_sql_radar[$radar][] = "`" . $module."_".$column."`=".$value.",`".$module."_".$column."_f`='".$filters."'";
	    }
	    //print ">$column<  >$value< >$dateSQL< >$timeSQLStart< >$timeSQLStop< >$radar<\n";
	}
    }

    $list_column = array_values(array_unique($list_column));
    $list_radar = array_values(array_unique($list_radar));
    /* print_r($list_column); print_r($list_radar); print_r($list_sql_radar); exit; */


    //$version = (isset($_ENV['RASS_VERSION_NO']) ? $_ENV['RASS_VERSION_NO'] : "NA") . (isset($_ENV['RASS_PATCH_VERSION']) ? "+" . ($_ENV['RASS_PATCH_VERSION']) : "");

    $version = getenv('RASS_VERSION_NO') . "+" . getenv('RASS_PATCH_VERSION');

    //print_r($_ENV); print $version . "\n"; exit;

    $list_sql_summary[] = "summary_filename='$summary_filename'";
    $list_sql_summary[] = "version='$version'";
    $list_sql_summary[] = "start_date='$dateSQL $timeSQLStart'";
    $list_sql_summary[] = "end_date='$dateSQL $timeSQLStop'";
    $list_sql_summary[] = "insert_date=now()";
    $list_sql_summary[] = "conf_name='$conf_name'";
    $list_sql_summary[] = "duration='$duration'";
    $sql_insert_summary = "INSERT INTO summaries SET " . implode(',
        ', $list_sql_summary) . ";";

    //asegurar que esta grabacion no se ha metido antes (solo se puede hacer si tenemos summary_filename)
    // a lo mejor lo podriamos hacer en lugar de con filename con fechas de inicio, fin y region
    if ($summary_filename!="") {
	$delete = "DELETE s,r FROM summaries s LEFT JOIN radars r ON s.id=r.summary_id " .
	    "WHERE s.summary_filename='$summary_filename';";
	print $delete . "\n";
    }
    $delete = "DELETE s,r FROM summaries s LEFT JOIN radars r ON s.id=r.summary_id " .
        "WHERE start_date='$dateSQL $timeSQLStart' AND end_date='$dateSQL $timeSQLStop' AND conf_name='$conf_name';";
    print $delete . "\n";

    print $sql_insert_summary . "\n";
    print "SET @LASTID = LAST_INSERT_ID();\n";

    $sql_create = "DROP TABLE IF EXISTS radars; CREATE TABLE radars (\n" .
"        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, summary_id INT NOT NULL,\n" .
"        insert_date DATETIME, radar varchar(64) NOT NULL,\n";
    for($i=0;$i<count($list_column);$i++) {
	$sql_create .= "        `" . $list_column[$i] . "` float NULL default NULL, " .
	    "`" . $list_column[$i] . "_f` varchar(64) NULL default NULL,\n";
    }
    $sql_create = substr($sql_create, 0, -2);
    $sql_create .= "\n);";

    //print $sql_create . "\n";

    foreach($list_radar as $r) {
	$sql_insert[$r] = "INSERT INTO radars SET summary_id=@LASTID,insert_date=now(),radar='$r'," .
	    implode(',',$list_sql_radar[$r]) . ";";
	print $sql_insert[$r] . "\n";
    }
    //print_r($sql_insert);

exit;
