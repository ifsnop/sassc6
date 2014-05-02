#!/bin/sh
#fecha ultima modificacion
#120426 1015
#set -x

#asterix_file="/home/eval/datos/espana/centro/100419_080001_5mb.ast"
radar_set_path="/home/eval/%rassv6%/pass.rct"
temp_path="/tmp/s"

echo =======================================================================================================
echo "`date +'%Y/%m/%d %H:%M:%S'` pid ($$) $0 $*"
echo =======================================================================================================

echo -ne "\n"

mkdir -p $temp_path 2> /dev/null

function install_ue_stderr_reader_ascii
{
    if [[ ! -d "$RQMRUN_DIR/tmp" ]] ; then
        echo "Creating dir $RQMRUN_DIR/tmp"
        mkdir -p $RQMRUN_DIR/tmp
    fi
    export PATH=$RQMRUN_DIR/tmp:$PATH
    # echo "Extending PATH: $PATH"
    if [[ -e "$RQMRUN_DIR/tmp/ue_stderr_reader" ]] ; then
        echo "Cleaning up $RQMRUN_DIR/tmp/ue_stderr_reader"
        rm $RQMRUN_DIR/tmp/ue_stderr_reader
    fi
    echo "Copying ue_stderr_reader_ascii to $RQMRUN_DIR/tmp"
    cp $(which ue_stderr_reader_ascii) $RQMRUN_DIR/tmp/ue_stderr_reader
}

function gen_radarset_dat_file
{
    RADAR_SET_DAT_FILE=$1
    ORIG_RECORD_DETAILS=${RADAR_SET_DAT_FILE%/*}/recording_details.par
    cat $ORIG_RECORD_DETAILS | grep "RADAR_DATAFILE_NAME" | 
    while read RADAR_LINE; do
    	LINE=${RADAR_LINE#RADAR_DATAFILE_NAME}
    	echo $LINE
    done |
    awk '{if ( $2) print $2 " " $1}' > $RADAR_SET_DAT_FILE
}

function record_plotfile
{
    RADARSET_PAR=$1
    if [[ $RECORDING_DONE == 0 ]]; then
# --- Cleanup --- #
	if [ -s "$RADARSET_PAR/%if_file.if" ] ; then
	    echo "Cleaning up file $RADARSET_PAR/%if_file.if"
	    rm $RADARSET_PAR/%if_file.if
	fi
	RECORD_DEBUG_MODE=0

	echo "Start recording ..."
	time_start_recording="00:00" 
	
#	echo "Before RecordOnly.sh"
	echo ./RecordOnly.sh $RADARSET_PAR -checkeof 
	RecordOnly.sh $RADARSET_PAR -checkeof 
#	WAIT_TIME=$((TIME_DURATION*60))
#	echo "After RecordOnly.sh"
    	time_stop_recording="23:59"
	RECORDING_DONE=1

	PLOTFILENAME=$RADARSET_PAR/%if_file.if
	echo " PLOTFILENAME: >${PLOTFILENAME}<"
    else
	echo "Recording was already done ..."
	echo " PLOTFILENAME: >${PLOTFILENAME}<"
    fi
}

function report_pid
{
	if [[ "$1" -eq "start" ]] ; then
		echo $$ > $RQMTASK_DIR/PID_RUNNING
	fi
	if [[ "$1" -eq "end" ]] ; then
		rm $RQMTASK_DIR/PID_RUNNING
	fi
}

#usage="Usage:\n$0 <rqmtask_dir> <rqmrun_dir> <duration>\n\t<data_dir>\tthe rqmtask directory where to store the settings\n\tthe rqmrun directory where to store the results\n\n"
usage="Usage:\n$0 <recording_file> <YY> <MM> <DD> <HHMMSS> <CFG1> <CFG2..>\n";

RQMTASK_DIR=$radar_set_path

asterix_file="/home/eval/datos/incoming/${1}"
date_start_recording="${4}/${3}/${2}"
timestamp="${2}${3}${4}-${5}"
fecha="${2}${3}${4}"
destination_dir="${2}${3}"
#120207 dtgallardo: como el nombre del fichero ya incluye la fecha (120207-bal-040002.ast) sobra  "${2}${3}${4}"
#RQMRUN_DIR="${temp_path}/${2}${3}${4}_${1}"
RQMRUN_DIR="${temp_path}/${1}"

export REGION="${7}"
export RQM_MODE="YES"   # this disables gd file generation in RunOC.sh and sf_update

echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) RQMTASK_DIR: >${RQMTASK_DIR}<"
echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) RQMRUN_DIR:  >${RQMRUN_DIR}<"

if ( test $# -lt 6 ) then
    echo -e $usage
    exit 1
fi

report_pid start

if [[ -z $RASSP_HOME ]] ; then
    . $HOME/.bashrc

    if [[ -z $RASSP_HOME ]] ; then
        echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) no se han encontrado variables de entorno. abortando"
        exit
    fi
else 
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) RASSP_HOME: >${RASSP_HOME}<"
fi

#Environment variables
. $RASSP_HOME/data/sassc_env

# Adding ORACLE libraries in the LD_LIBRARY_PATH.

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$RASSP_HOME/lib

# --- Recording flag, make sure we only record once --- #
RECORDING_DONE=0

RQMTASK=${RQMTASK_DIR##*/}
RQMTASK=${RQMTASK%.*}

echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) RQMTASK: >${RQMTASK}<"

# --- Use ascii ue_stderr_reader --- #
install_ue_stderr_reader_ascii


    base=`echo "$asterix_file" | sed 's/\.[^\.]*$//'`
    extension=`echo "$asterix_file" | sed 's/^.*\.//'`
    filename=`basename $base`
    erase_recording=false

    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) base($base) filename($filename) extension($extension)"

    mkdir -p /home/eval/pass/logs/${destination_dir} 2> /dev/null
    mkdir -p /home/eval/pass/summaries/${destination_dir} 2> /dev/null


    if [[ "${extension}A" = "gpsA" ]]; then
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) file is ${extension}, converting to asterix"
	/usr/local/bin/cleanast $asterix_file /tmp/${filename}.ast 2200 0 10
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) processing radar delays"
	#echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) /usr/local/bin/reader_rrd $asterix_file `date --utc --date \"${fecha}\" \"+%s\"`"
	#/usr/local/bin/reader_rrd $asterix_file `date --utc --date "${fecha}" "+%s"` > /home/eval/cocir/logs/${destination_dir}/${timestamp}_${REGION}_rrd.log 2>&1
	#echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) /usr/local/bin/reader_rrd3 -s $asterix_file -t `date --utc --date \"${fecha}\" \"+%s\"` -r ${REGION} -d /var/www/lighttpd/cocirv41/rrds3"
	#/usr/local/bin/reader_rrd3 -s $asterix_file -t `date --utc --date "${fecha}" "+%s"` -r ${REGION} -d /var/www/lighttpd/cocirv41/rrds3 > /home/eval/cocir/logs/${destination_dir}/${timestamp}_${REGION}_rrd.log 2>&1
     
	#asterix_file=${base}.ast
	asterix_file=/tmp/${filename}.ast
	erase_recording=true
    fi

#
# make automatic rass evaluation
#

if [ -d "$RQMRUN_DIR" ]; then
    #echo "Emptying directory $RQMRUN_DIR"
    rm -rf $RQMRUN_DIR
fi
if [ ! -d "$RQMRUN_DIR" ]; then
    #echo "Creating directory $RQMRUN_DIR"
    mkdir -p $RQMRUN_DIR
fi


while [ "$#" -gt 5 ]; do
    cfg=$6
    shift

    echo =======================================================================================================
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) CONFIGURATION: >${cfg}<"

    DIRECTORY="${radar_set_path}/${cfg}.rds"

    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) directory: >${DIRECTORY}<"

    if [ ! -d $DIRECTORY ]; then
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) error, >${DIRECTORY}< doesn't exists."
	continue
    fi

    
    r=${DIRECTORY##*/}
    RADARSET=${r%.*}

    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) Radarset: >${RADARSET}<"

# --- For RQM, recording will need to be done in the <time_start_time_stop> 
# --- subdirectory which does not exist right now ... 
# --- This should be set up in the recording phase, maybe based on file recording_details.par 
    RASS_DIR=$RQMRUN_DIR/$RQMTASK/$RADARSET
#    RASS_DIR=$RASS_DIR/${time_start_recording%:*}${time_start_recording#*:}_${time_stop_recording%:*}${time_stop_recording#*:}
    RASS_DIR=$RASS_DIR
    
#    # in case of debugging mode, still create a unique RASS_DIR
#    if [[ $RECORD_DEBUG_MODE == 1 ]] ; then
#            DTG=`date +%Y%m_%b_%d_%a_%T`                # append YYYYMMM_mmm_DD_ddd_HH:MM:SS
#            RASS_DIR=$RASS_DIR"_debug_"$DTG"_"$$        # append ps id
#    fi
#    RASS_DIR=$RASS_DIR/%rass%


    # inserta el nombre de la grabacion que vamos a usar
    #recording_file=$RQMTASK_DIR/$RADARSET.rds/recording_details.par
    #awk -v filename="$asterix_file" '{if ($1=="DISC_FILENAME") printf("%s\t%s\n",$1,filename); else print $0}' $recording_file > /tmp/recording_details.$$
    #mv -f /tmp/recording_details.$$ $recording_file
    time_start_recording="00:00" 
    time_stop_recording="23:59" 
    PLOTFILENAME="$asterix_file"

# --- At this point $DIRECTORY/$RADARSET.dat does not yet exist. 
# --- It needs to be generated.
    gen_radarset_dat_file ${DIRECTORY}/${RADARSET}.dat
#    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) mv -f /tmp/recording_details.$$ ${RASS_DIR}/ae_${RADARSET}.eva/recording_details.par"
#    mkdir -p ${RASS_DIR}/ae_${RADARSET}.eva 2> /dev/null
#    mv -f /tmp/recording_details.$$ ${RASS_DIR}/ae_${RADARSET}.eva/recording_details.par
#    ${DIRECTORY}/${RADARSET}.dat /recording_details.par

    secs=$RANDOM
    let "secs %= 50"
    let "secs += 60"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) waiting random ${secs} seconds"
    sleep $secs
    
    date_start=`date +%s` 
    
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) date_start_recording: >${date_start_recording}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) time_start_recording: >${time_start_recording}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) time_stop_recording: >${time_stop_recording}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) plotfilename: >${PLOTFILENAME}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) directory: >${DIRECTORY}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) radarset: >${RADARSET}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) rass_dir: >${RASS_DIR}<"
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) rqmtask_dir: >${RQMTASK_DIR}<"
    
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) ./auto_rass_eval.ksh $date_start_recording $time_start_recording $time_stop_recording $PLOTFILENAME $DIRECTORY/$RADARSET.dat $RASS_DIR $RQMTASK_DIR"
    auto_rass_eval.ksh "$date_start_recording" "$time_start_recording" "$time_stop_recording" "$PLOTFILENAME" "$DIRECTORY/$RADARSET.dat" "$RASS_DIR" "$RQMTASK_DIR"
    ret=$?
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) return code from auto_rass_eval.ksh: >$ret<"
    date_stop=`date +%s` 
    
    date_diff=$(( $date_stop - $date_start ))
    processlog_size=$(stat -c%s ${RASS_DIR}/ae_${RADARSET}.eva/Process.log)
    #si error al ejecutar stat, garantizamos no insertar
    if [[ $? -ne 0 ]]; then
	processlog_size=5000001
    fi
    #comprobamos que existe un fichero con resultados (retrieve.sum) y que no haya errores de inserción en bbdd durante la ejecución del sassc
    #en caso de errores, el process.log crece muchísimo
    if [ -f ${RASS_DIR}/ae_${RADARSET}.eva/Retrieve.sum ] && [ $processlog_size -lt 5000000 ]; then
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) copiando los resultados al directorio final"
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) cp ${RASS_DIR}/ae_${RADARSET}.eva/Retrieve.sum /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_retrieve.sum"
	cp ${RASS_DIR}/ae_${RADARSET}.eva/Retrieve.sum /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_retrieve.sum
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) cp ${RASS_DIR}/ae_${RADARSET}.eva/Summary_report.asc /home/eval/pass/summaries/${destination_dir}/${timestamp}_${cfg}_summary_report.asc"
	cp ${RASS_DIR}/ae_${RADARSET}.eva/Summary_report.asc /home/eval/pass/summaries/${destination_dir}/${timestamp}_${cfg}_summary_report.asc
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) cp ${RASS_DIR}/ae_${RADARSET}.eva/Process.log /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_process.log"
	cp ${RASS_DIR}/ae_${RADARSET}.eva/Process.log /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_process.log
	#echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) insertando en bbdd" 
	#echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) /usr/bin/php /software/sassc6.6/scripts/evcont_db.php /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_retrieve.sum ${cfg} $date_diff /home/eval/cocir/summaries/${destination_dir}/${timestamp}_${cfg}_summary_report.asc > /home/eval/cocir/logs/${destination_dir}/${timestamp}_${cfg}_insert.sql"
	#/usr/bin/php /software/sassc6.6/scripts/evcont_db.php /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_retrieve.sum ${cfg} $date_diff /home/eval/pass/summaries/${destination_dir}/${timestamp}_${cfg}_summary_report.asc > /home/eval/pass/logs/${destination_dir}/${timestamp}_${cfg}_insert.sql
	#/usr/bin/mysql -u root -D cocir < /home/eval/cocir/logs/${destination_dir}/${timestamp}_${cfg}_insert.sql >> /home/eval/cocir/logs/${destination_dir}/${timestamp}_${cfg}_process.log
	
	#if [[ ${RADARSET} != *tma* ]]; then 
	#    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) no es una evaluación de TMA, populando hits para kml coverage" 
	#    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) /usr/bin/php /software/sassc6.6/scripts/export/populate_hits_table_threadedv2.php ${RASS_DIR}/ae_${RADARSET}.eva"
	#    /usr/bin/php /software/sassc6.6/scripts/export/populate_hits_table_threadedv2.php ${RASS_DIR}/ae_${RADARSET}.eva
	#fi
	if [[ ${RADARSET} = *tma* ]]; then
	    rm -rf ${RASS_DIR}
	else
            echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) enabling cockpit (${RASS_DIR}/cockpit.sh)"
            echo "S_Cockpit ${RASS_DIR}/ae_${RADARSET}.eva" > ${RASS_DIR}/cockpit.sh
            chmod 755 ${RASS_DIR}/cockpit.sh
	fi
    else
	echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) error durante la ejecucion del sass-c, NO insertando en bbdd: logsize($processlog_size)"
    fi

    # chmod 755 ${RASS_DIR}/ae_${RADARSET}.eva/multi.sh
    # echo "so_display MultiRadar ${RASS_DIR}/ae_${RADARSET}.eva/CHse.ocs" > ${RASS_DIR}/multi.sh
    # $fpa=`find ${RASS_DIR}/ae_${RADARSET}.eva/CHse.ocs -type d -name "false*.fpa"`
    # echo "sf_display FPFinal $fpa" > ${RASS_DIR}/false.sh
    # /tmp/s/120212-este-160001.gps/cocir/este/ae_este.eva
    # so_display MultiRadar $1
    # $1 = home/eval/%rassv6%/user.RASS/spain.tsk/centro.cmp/a120202_2000.eva/CHse.ocs
    # clean everything
    # rm -r $RQMRUN_DIR 2> /dev/null

done
# --- FOR LOOP ENDS HERE !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! --- #

report_pid end

echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) cleaning old files"
find $temp_path -mtime +2 -exec rm -rf '{}' \; 2> /dev/null

cuenta=`ps ax |grep CleanOrphan|grep delete | wc -l`
if [ $cuenta -eq 0 ]; then
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) removing orphaned databases"
    CleanOrphanDb.sh --delete 
else 
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) already removing orphaned databases"
fi

# --- Finally, remove the ascii ue_stderr_reader --- #
rm -rf $RQMRUN_DIR/tmp/ue_stderr_reader       

if [[ "${erase_recording}" = "true" ]]; then
    echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) erasing >$asterix_file<"
    rm -f $asterix_file
fi

chown -R eval.eval $RQMRUN_DIR

echo "`date +'%Y/%m/%d %H:%M:%S'` ($$) done >$0<"

exit 0
