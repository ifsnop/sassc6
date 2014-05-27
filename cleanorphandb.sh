#!/bin/sh

set -u

function db2str {
    db=$1
    if [[ ${db:0:3} == "rqm" ]]; then
	#rqm_eval_cocir_133733576145
	number=${db:15}
	length=${#number}
	let length=$length-2
	number=${number:0:$length}
    else
	#ce_db_1335779130
	#fp_db_1335783706
	#pradb_1335784146
	number=${db:6}
	length=${#number}
	let length=$length
	number=${number:0:$length}
    fi
    db_date=`date -u -d @$number`
    echo $db_date
}

#db2str rqm_eval_cocir_133733576145
#db2str ce_db_1335779130
#db2str fp_db_1335783706
#db2str pradb_1335784146

#
# Process arguments
#

# No argument provided => display help message
if [ $# = 0 ]
then
   echo "Bad argument(s)."
   echo "cleanOrphanDb.sh {--list|--delete} [SEARCH_DIRECTORY ... SEARCH_DIRECTORY]"
   echo "Maximum 10 search directories."
   echo "/home && /tmp/s used if no search directory provided."
   exit 0
fi

# Find out which option is used
optionFlag=0

if [ $1 = "--list" ]
then
   optionFlag=1
fi

if [ $1 = "--delete" ]
then
   optionFlag=2
fi

# If no legal option => display help message
if [ $optionFlag = 0 ]
then
   echo "Bad argument(s)."
   echo "$0 {--list|--delete} [SEARCH_DIRECTORY ... SEARCH_DIRECTORY]"
   echo "Maximum 10 search directories."
   echo "/home && /tmp/s used if no search directory provided."
   exit 0
fi

# If no directory is provided, search in /home directory
if [ $# = 1 ]
then
   searchPath="/tmp/s /home/eval/%rassv6%"
else
   searchPath="/tmp/s /home/eval/%rassv6% $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11}"
fi

echo "Search path =" $searchPath

echo [STEP 0]

#
# Evaluation DBs
#

# extrae el dato de todas las bases de datos existentes en mysql
listOfDb=`mysql -u root -e "SHOW DATABASES" | grep -v "^Database$"`
listOfDbi=`echo $listOfDb | tr [:upper:] [:lower:]`

# extrae el nombre de todas las bases de datos usadas por las evaluaciones
listOfUsedDb=""
listOfUsedDbFile=`find $searchPath -name databaseName.my 2>/dev/null`
for dbFile in $listOfUsedDbFile
do
    listOfUsedDb="$listOfUsedDb `cat $dbFile 2> /dev/null`"
done
listOfUsedDbi=`echo $listOfUsedDb | tr [:upper:] [:lower:]`

# delete all databases with table generalInfo
echo [STEP 1]

for dbi in $listOfDbi
do
   evaDbFlag=`mysql -u root $dbi -e "SHOW TABLES" | grep -i generalinfo`
   if [[ -n "$evaDbFlag" ]]
   then
      #
      echo "checking $dbi" > /dev/null
      echo -n .
      isUsedFlag=0
      #
      for usedDbi in $listOfUsedDbi
      do
         #usedDbi=`echo $usedDb | tr [:upper:] [:lower:]`
         if [[ $dbi = $usedDbi ]]
         then
            echo -n "[$usedDbi]" > /dev/null
            isUsedFlag=1
            break
         fi
      done
      #
      #
      if [[ $isUsedFlag -eq 0 ]]
      then
         dbstr=$(db2str $dbi)
         if [[ $optionFlag -eq 2 ]]
         then
	    echo "$dbi ($dbstr) is orphan => Deleted."
            mysql -u root -e "DROP DATABASE $dbi"
         else
            echo "$dbi ($dbstr) is orphan."
         fi
      #else
           #dbstr=$(db2str $dbi)
           #echo "Found in db $dbi ($dbstr)" > /dev/null
           #mysqlcheck --auto-repair "$dbi" > /dev/null
      fi
   else
     echo "ignoring $dbi, not from sass-c (step 1)" > /dev/null
   fi
done

echo .
echo [STEP 2]

#
# CE, FPA et PRA DBs
#

# listado de las bases de datos en el mysql
listOfDb=`mysql -u root -e "SHOW DATABASES" | grep -i "^ce_db"`
listOfDb="$listOfDb `mysql -u root -e "SHOW DATABASES" | grep -i "^fp_db"`"
listOfDb="$listOfDb `mysql -u root -e "SHOW DATABASES" | grep -i "^pradb"`"
listOfDbi=`echo $listOfDb | tr [:upper:] [:lower:]`

# listado de las bases de datos usadas en las evaluaciones
listOfUsedDb=""
listOfUsedDbFile=`find $searchPath -name ce_db 2>/dev/null`
for dbFile in $listOfUsedDbFile
do
    listOfUsedDb="$listOfUsedDb `cat $dbFile 2> /dev/null`"
done

listOfUsedDbFile=`find $searchPath -name fp_db 2>/dev/null`
for dbFile in $listOfUsedDbFile
do
   listOfUsedDb="$listOfUsedDb `cat $dbFile 2> /dev/null`"
done

listOfUsedDbFile=`find $searchPath -name pradb 2>/dev/null`
for dbFile in $listOfUsedDbFile
do
   listOfUsedDb="$listOfUsedDb `cat $dbFile 2> /dev/null`"
done

listOfUsedDbi=`echo $listOfUsedDb | tr [:upper:] [:lower:]`

for dbi in $listOfDbi
do
   echo -n .
   #mysqlcheck -u root --auto-repair $db
   #dbi=`echo $db | tr [:upper:] [:lower:]`
   echo "checking $dbi" > /dev/null

   isUsedFlag=0
   for usedDbi in $listOfUsedDbi
   do
      if [[ $dbi = $usedDbi ]]; then
         isUsedFlag=1
         break
      fi
   done
   if [[ $isUsedFlag -eq 0 ]]; then
      dbstr=$(db2str $dbi)
      if [[ $optionFlag -eq 2 ]]; then
	 echo "[$dbi ($dbstr) is orphan => Deleted]"
         mysql -u root -e "DROP DATABASE $dbi"
         if [[ $? -ne 0 ]]; then
             #error al hacer el drop, apuntar
             echo "error dropping database $dbi ($dbstr)"
         fi
      else
         echo "[$dbi ($dbstr) is orphan]"
      fi
   #else
      #echo "Found in db $dbi ($dbstr)" > /dev/null
      #mysqlcheck --auto-repair "$db" > /dev/null
   fi
done

echo .

