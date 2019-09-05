#!/bin/sh

# usage: ./cmd [-v]
# connect with Shock to retrieve list of files to be moved to location


# send data items in Shock output to a TSM instance
# the Shockoutput will be of the form
  # ---snip---
  # /dpool/mgrast/shock/data/00/01/a9/0001a988-f2a2-4c55-a42e-dd28d42d0344/0001a988-f2a2-4c55-a42e-dd28d42d0344.data
  # /dpool/mgrast/shock/data/00/01/c1/0001c1ed-58a3-44ca-8be5-f05a5d37da5b/0001c1ed-58a3-44ca-8be5-f05a5d37da5b.data
  # /dpool/mgrast/shock/data/00/01/c1/0001c1ed-58a3-44ca-8be5-f05a5d37da5b/0001c1ed-58a3-44ca-8be5-f05a5d37da5b.idx.zip
  # /dpool/mgrast/shock/data/00/01/d2/0001d251-e1f2-4336-9088-ab7d91063260/0001d251-e1f2-4336-9088-ab7d91063260.data
  # /dpool/mgrast/shock/data/00/01/d2/0001d251-e1f2-4336-9088-ab7d91063260/0001d251-e1f2-4336-9088-ab7d91063260.idx.zip
  # /dpool/mgrast/shock/data/00/01/e0/0001e095-0c3e-42f7-bb79-f1bd65091df8/0001e095-0c3e-42f7-bb79-f1bd65091df8.data
# ---snip---

# config of TSM is via the run time environment (e.g. the dsmc utilities and the server side config)


### ################################################################################
### ################################################################################
### ################################################################################
### Config variables start here

# config variables
# URL to server
SHOCK_SERVER_URL="https://shock.mg-rast.org"
# the DATA directory of the shock server
SHOCK_DATA_PATH="/dpool/mgrast/shock/data"
# name of the location defined in locations.yaml
LOCATION_NAME="anltsm"
# name of the dump file for TSM data
TSM_DUMP=${SHOCK_DATA_PATH/backends/${LOCATION_NAME}}
# NOTE: we assume authentication bits to be contain in the AUTH env variable
WCOPY=${SHOCK_DATA_PATH}/$(basename $0)_wcopy.$$.txt
OUTCOPY=${SHOCK_DATA_PATH}/$(basename $0)_output.$$.txt

### no more config
### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

### return the age of a file in hours
function fileage() {
if [ ! -f $1 ]; then
  echo "file $1 does not exist"
        exit 1
fi
MAXAGE=$(bc <<< '24*60*60') # seconds in 28 hours
# file age in seconds = current_time - file_modification_time.
FILEAGE=$(($(date +%s) - $(stat -c '%Y' "$1")))
test $FILEAGE -lt $MAXAGE && {  # this is a very ugly hack and needs to return the actual hours..
    echo "23"
    exit 0
}
  echo "25"
}

### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

###  extract a list of all items in TSM backup once every day
update_TSM_dump () {

filename=$1
cachefiledate=$(fileage ${filename})

# check if cace
if [ -f $filename ] && [[ ${cachefiledate} -lt 24 ]]
then
  if [ ${verbose} == "1" ] ; then
    echo "using cached nodes file ($filename)"
  fi
else
  # capture nova output in file
  if [ ${verbose} == "1" ] ; then
    echo "creating new DUMP file ($filename)"
  fi
  dsmc q b "${SHOCK_DATA_PATH}/*/*/*/*/*" > $filename
  chmod g+w ${filename} 2>/dev/null

fi
}

### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

### set location with stored == false, indicating that data is in flight to TSM
write_location() {
id=$1

local val=false
local JSON_STRING='{"id":"'"$LOCATION_NAME"'","stored":"'"$val"'"}'

curl -s -X POST -H "$AUTH" "${SHOCK_SERVER_URL}/node/${id}/locations/ -d ${JSON_STRING}"
}

### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

### set Location as verified in Shock, confirming the data for said node is in TSM
verify_location() {
id=$1

local val=true
local JSON_STRING='{"id":"'"$LOCATION_NAME"'","stored":"'"$val"'"}'

curl -s -X POST -H "$AUTH" "${SHOCK_SERVER_URL}/node/${id}/locations/ -d ${JSON_STRING}" > $
}

### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

#### write usage info
usage() {
      echo "script usage: $(basename $0) [-v] [-h] -d <TSM_dumpfile> filename" >&2
      echo "connect with Shock to retrieve list of files to be moved to location" >&2
}

### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

### ################################################################################
### ################################################################################
### ################################################################################
### ################################################################################

## main


#
while getopts 'vfh' OPTION; do
  case "$OPTION" in
    v)
      verbose="1"
      ;;
    f)
      force="1"
      ;;
    h)
      echo "$(basename $0) -h --> display this help" >&1
      usage
      exit 0
      ;;       
    ?)
      usage
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# check if parameter is file
if [ ! -f $1 ] ; then
	usage
	exit 1	
fi

if [[ $verbose == "1" ]] ;then 
  echo "Settings:"
  echo "SHOCK_SERVER_URL:\t\t${SHOCK_SERVER_URL}"
  echo "SHOCK_DATA_PATH:\t${SHOCK_SERVER_URL}" 
  echo "LOCATION_NAME:\t\t${LOCATION_NAME}"
  echo "TSM_DUMP:\t\t${TSM_DUMP}"
fi

# check if the dsmc command is available
if [ ! -x "$(which dsmc)" ] ; then
  echo " [$(basename $0)] requires the IBM TSM dsmc command to be installed, configured and available in PATH"
  exit 1
fi

if [ ! "${force}x" -eq "x" ] ; then 
  if [ -x ${WCOPY} ] || [ -x ${OUTCOPY} ] ; then
     echo " [$(basename $0)] Can't connect to "
    exit 1
  fi
fi
 

# download the file from SHOCK

curl -s -X POST -H "$AUTH" "${SHOCK_SERVER_URL}/location/nodes/" > WCOPY

if [ $? != 0 ] ; then 
  echo " [$(basename $0)] Can't connect to ${SHOCK_SERVER_URL}"
  exit 1
fi


## read a file dumped by shock
writecount=0
verifycount=0
missingcount=0

while read line; do 
    id=$(echo $line)  
    if [[ $verbose == "1" ]] ; then 
	    echo "working on $id"
    fi

    # add the data files and the idx directory to the request file
    DATAFILE="${SHOCK_DATA_PATH}/*/*/*/*/${id}.data"
    INDEX="${SHOCK_DATA_PATH}/*/*/*/*/${id}/idx"


    # check if all data and index are in the backup already
    if [ fgrep -q ${DATAFILE} DSMCDB ] && [ fgrep -q ${INDEXFILE} DSMCDB ] ; then
      if [[ $verbose == "1" ]] ; then 
	      echo "$id already found in TSM"
      fi
      JSON=$(verify_location ${id} )
      if echo ${JSON} |  grep -q 200  ; then 
        verifycount=`expr $verifycount + 1`
      elif echo ${JSON}| grep -q "Node not found" ; then
        missingcount=`expr $missingcount + 1`
      else
        echo "$(basename $0) can't write to ${SHOCK_SERVER_URL}; exiting (node: ${id})" >&2
        echo "RAW JSON: \n${JSON}\n"
        exit 1
     fi 

    else  # add data and index to request file
      if [[ $verbose == "1" ]] ; then 
	      echo "${id} NOT found in TSM"
      fi
      # write names to request file
      echo "${DATAFILE}" >> ${OUTCOPY}
      echo "${INDEXFILE" >> ${OUTCOPY}

      JSON=$(write_location ${id} )

      if echo ${JSON} |  grep -q 200  ; then 
        writecount=`expr $writecount + 1`
      elif echo ${JSON}| grep -q "Node not found" ; then
        missingcount=`expr $missingcount + 1`
      else
        echo " [$(basename $0)] can't write to ${SHOCK_SERVER_URL}; exiting (node: ${id})" >&2
        echo "RAW JSON: \n${JSON}\n"
        exit 1
      fi 

    fi
done <$1

if [[ ${verbose == "1" } ]] ; then
  echo "found $writecount items to add to TSM"
  echo "found $verifycount items to confirm as in TSM"
  echo "found ${missingcount} nodes missing in MongoDB)"
fi

# run the command to request archiving
dsmc command ..


# clean up
rm -f ${WCOPY} ${OUTCOPY} 
