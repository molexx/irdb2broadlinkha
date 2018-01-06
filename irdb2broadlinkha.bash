#!/bin/bash

#
# Requires pronto2broadlink.py from:  https://gist.githubusercontent.com/appden/42d5272bf128125b019c45bc2ed3311f/raw/bdede927b231933df0c1d6d47dcd140d466d9484/pronto2broadlink.py
#
#
#


WORKDIR="irdb2broadlinkha-work"
TEMP_CSV_FILENAME="current.csv"

PRONTO2BROADLINK_DOWNLOAD="https://gist.githubusercontent.com/appden/42d5272bf128125b019c45bc2ed3311f/raw/bdede927b231933df0c1d6d47dcd140d466d9484/pronto2broadlink.py"
IRPTRANSMORGRIFIER_DOWNLOAD="https://github.com/bengtmartensson/IrpTransmogrifier/releases/download/Version-0.2.0/IrpTransmogrifier-0.2.0-bin.zip"


mkdir -p "${WORKDIR}"
rm -f "${WORKDIR}/${TEMP_CSV_FILENAME}"


function debug() {
  echo "${1}" >&2
  :
}

function error() {
  echo "ERROR: ${1}" >&2
}


# PROTOCOL, DEVICE, SUBDEVICE, FUNCTION
function signalToPronto() {
  local PROTOCOL="$1"
  local DEVICE="$2"
  local SUBDEVICE="$3"
  local FUNCTION="$4"

  local SIGNAL="${PROTOCOL}+${DEVICE}+${SUBDEVICE}+${FUNCTION}"

  PRONTO=""
  debug "signalToPronto: ${SIGNAL}..."
  PRONTO=$(curl --data "signal=${SIGNAL}" "http://irdb.tk/encode/" -s -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Content-Type: application/x-www-form-urlencoded" | grep "=\"sendPronto" |  sed -r -e "s/.*sendPronto\(([^\)]*).*/\1/g" | tr -d "'")
  debug "signalToPronto: ${SIGNAL}, pronto hex: ${PRONTO}"
}

# PRONTO
function prontoToBroadlinkHex() {
  local PRONTO="${1}"
  BROADLINKHEX=$(python2 "${P2BL}" "${PRONTO}")
}



function prontoToYaml() {
  local INDENT="${1}"
  local NAME="${2}"
  local PRONTO="${3}"

  prontoToBroadlinkHex "${PRONTO}"
  debug "BroadlinkHex: ${BROADLINKHEX}"
  local BROADLINKB64=$(echo -e "${BROADLINKHEX}" | xxd -r -p | base64 --wrap=0)
  broadlinkB64ToYaml "${INDENT}" "${NAME_PREFIX}${fnname}" "${BROADLINKB64}"
}


#IRDB_CSV_PATH
function downloadIrdbCsv() {
  local URL="https://cdn.rawgit.com/probonopd/irdb/master/codes/${1}"
  local TARGET="${WORKDIR}/${TEMP_CSV_FILENAME}"

  debug "downloading '${URL}' to '${TARGET}'..."
  curl -s "${URL}" -o "${TARGET}"
}


#CSVPATH, NAME_PREFIX, INDENT
function loopAroundCsv() {
  local LOCAL_CSV_PATH="${1}"
  local REMOTE_CSV_PATH="${2}"
  local NAME_PREFIX="${3}"
  local INDENT="${4}"
  local FUNCTION_PATTERN="${5}"

  [ ! -f "${LOCAL_CSV_PATH}" ] && { echo "${LOCAL_CSV_PATH} file not found"; exit 99; }

  local NUM_LINES=$(wc -l <"${LOCAL_CSV_PATH}")
  #debug "file '${LOCAL_CSV_PATH}' has `wc -l ${LOCAL_CSV_PATH}` lines..."
  debug "file '${REMOTE_CSV_PATH}' has ${NUM_LINES} lines, looking for functions matching '${FUNCTION_PATTERN}'..."

  #skip header line
  sed 1d "${LOCAL_CSV_PATH}" |
  while IFS=, read fnname protocol device subdevice fn
  do
    if [[ "${fnname}" != "" ]] ; then
      #debug "fnname $fnname, protocol: $protocol, device: $device, subdevice: $subdevice, fn: $fn"
      shopt -s nocasematch
      if [[ "${FUNCTION_PATTERN}" == "" ]] || [[ "${fnname}" =~ "${FUNCTION_PATTERN}" ]] ; then
        if [[ "${FUNCTION_PATTERN}" != "" ]] ; then
          debug "fnname '${fnname}' matches pattern '${FUNCTION_PATTERN}'..."
        fi

#        signalToBroadlinkB64 "$protocol" "$device" "$subdevice" "$fn"
#        #debug "${fnname}: ${BROADLINKB64}"
#        if [[  "${BROADLINKB64}" != "" ]] ; then
#          broadlinkB64ToYaml "${INDENT}" "${NAME_PREFIX}${fnname}" "${BROADLINKB64}"
#        else
#          error "signalToBroadlinkB64 returned empty for '$fnname': '$protocol' '$device' '$subdevice' '$fn'"
#        fi
        signalToPronto "$protocol" "$device" "$subdevice" "$fn"
        if [[  "${PRONTO}" != "" ]] && [[  "${PRONTO}" != "None" ]] ; then
          prontoToYaml "${INDENT}" "${NAME_PREFIX}${fnname}" "${PRONTO}"
        else
          error "signalToPronto '${protocol}' '${device}' '${subdevice}' '${fn}' returned no pronto code. Check that the pronto code is available on http://irdb.tk."
        fi
        debug ""
      else
        #debug "fnname '${fnname}' does not match pattern '${FUNCTION_PATTERN}', skipping"
       :
      fi
      shopt -u nocasematch
    else
      error "${NAME_PREFIX}: first column empty, ignoring line."
    fi
  done
}


arr=()

function broadlinkB64ToYaml() {
  local INDENT="${1}"
  #local NAME_PREFIX="${2}"
  local NAME="${2}"
  local CODEB64="${3}"

 #sky_0:
 #       friendly_name: "Sky 0"
 #       command_on:  'JgA0AFcdDg4ODg4dDh0dDg4ODg4ODg4ODg4ODg4OHQ4OHQ4ODg4ODg4ODg4ODg4ODg4ODg4ADM8NBQAA'
 #       command_off: 'JgA0AFcdDg4ODg4dDh0dDg4ODg4ODg4ODg4ODg4OHQ4OHQ4ODg4ODg4ODg4ODg4ODg4ODg4ADM8NBQAA'


  #sanitize NAME for use as a key
  local sname="${NAME,,}"     #lowercase
  sname="${sname// /_}"       #remove spaces
  sname="${sname////_}"       #remove forward slashes
  sname="${sname//+/_plus}"    #remove plus
  sname="${sname//-/_}"       #remove hyphen/minus
  sname="${sname//./_}"       #remove periods
  sname="${sname//,/_}"       #remove commas
  sname="${sname//:/_}"       #remove colons
  sname="${sname//(/_}"       #remove open bracket
  sname="${sname//)/_}"       #remove close bracket
  sname="${sname//^/_up}"       #remove hat

  local suffix=""

  count=1
  while [[ " ${arr[*]} " == *" $sname$suffix "* ]]; do
    debug "key '$sname$suffix' already used..."
    ((count++))
    suffix="_${count}"
  done

  sname="${sname}${suffix}"
  arr+=("${sname}")

  debug "writing yaml entry for '${NAME}' (sanitized: '${sname}')..."

  echo "${INDENT}'${sname}':"
  echo "${INDENT}  friendly_name: \"${NAME}${suffix}\""
  echo "${INDENT}  command_on: '${CODEB64}'"
  echo "${INDENT}  "
}





function lircFileToYaml() {
  local CONF_PATH="${1}"
  local NAME_PREFIX="${2}"
  local MATCH_PATTERN="${3}"

  #downloadIrdbCsv "${IRDB_CSV_PATH}"
  local URL="https://sourceforge.net/p/lirc-remotes/code/ci/master/tree/remotes/${CONF_PATH}?format=raw"
  local LIRC_CONF="${WORKDIR}/lircd.conf"
  debug "downloading lirc config from '${URL}' to '${LIRC_CONF}'..."
  curl --fail -s "${URL}" -o "${LIRC_CONF}"
  if [[ $? != 0 ]] ; then
    error "failed to download lirc config '${URL}'"
    exit 5
  fi

  debug "downloaded lirc config to '${LIRC_CONF}'."

  local IRP="${WORKDIR}/irp"
  local IRP_SED="${WORKDIR}/irp.sed"
  #"${WORKDIR}/iptransmorgifier/irptransmogrifier.sh"
  debug "converting lirc config to irp using irptransmogrifier..."
  "${IRPTM}" lirc "${LIRC_CONF}" >"${IRP}"
  cat "${IRP}" | sed -e s/^[^:]\*:// >"${IRP_SED}"
  debug "irp created."

  local BUTTON_CODES="${WORKDIR}/buttons"
  awk '/begin codes/{flag=1;next}/end codes/{flag=0}flag' "${LIRC_CONF}" >"${BUTTON_CODES}"

  cat "${BUTTON_CODES}" | while read fnname code comment
  do
    debug "function: '$fnname', code: '$code', comment: '${comment}'."
    #"${IRPTM}" render -p -i `cat "${IRP_SED}"` -n F=0xc738
    debug "running irptransmogrifier for '$fnname', code: '$code'..."
    local PRONTO="$("${IRPTM}" render -p -i `cat "${IRP_SED}"` -n F=${code})"
    debug "pronto: $PRONTO"
    prontoToYaml "" "${NAME_PREFIX}${fnname}" "${PRONTO}"
  done

  debug "done looping around buttons."

  #"${WORKDIR/iptransmorgifier/irptransmogrifier.sh"

  #loopAroundCsv "${WORKDIR}/${TEMP_CSV_FILENAME}" "${IRDB_CSV_PATH}" "${NAME_PREFIX}" "" "${MATCH_PATTERN}"
}



function irdbFileToYaml() {
  local IRDB_CSV_PATH="${1}"
  local NAME_PREFIX="${2}"
  local MATCH_PATTERN="${3}"

  downloadIrdbCsv "${IRDB_CSV_PATH}"

  loopAroundCsv "${WORKDIR}/${TEMP_CSV_FILENAME}" "${IRDB_CSV_PATH}" "${NAME_PREFIX}" "" "${MATCH_PATTERN}"
}



function irdbDirToYaml() {
  local IRDB_PATH="${1}"
  local NAME_PREFIX="${2}"
  local MATCH_PATTERN="${3}"

  curl -s "https://api.github.com/repos/probonopd/irdb/contents/codes/${IRDB_PATH}" | jq -r ".[] | .name" | while read f
  do
    downloadIrdbCsv "${IRDB_PATH}/${f}"
    loopAroundCsv "${WORKDIR}/${TEMP_CSV_FILENAME}" "${IRDB_PATH}/${f}" "${NAME_PREFIX}_${f}_" "" "${MATCH_PATTERN}"
  done
}

function downloadIrpTransmogrifier() {
  #local URL="https://github.com/bengtmartensson/IrpTransmogrifier/releases/download/Version-0.2.0/IrpTransmogrifier-0.2.0-bin.zip"
  local URL="${IRPTRANSMORGRIFIER_DOWNLOAD}"
  local TARGET="${WORKDIR}/IrpTransmogrifier-bin.zip"
  debug "downloading IrpTransmogrifier from '${URL}' to '${TARGET}'..."
  curl --fail -L "${URL}" -o "${TARGET}"
  local CURL_RC=$?
  debug "download of IrpTransmogrifier returned: $CURL_RC"
  if [[ $CURL_RC != 0 ]] ; then
    error "failed to download IrpTransmogrifier from '${URL}'"
    exit 5
  fi

  cd "${WORKDIR}"
  mkdir irptransmogrifier
  cd irptransmogrifier
  unzip ../IrpTransmogrifier-bin.zip >/dev/null
  local UNZIP_RC=$?
  debug "unzip of IrpTransmogrifier returned: $UNZIP_RC"
  cd ..
  if [[ ${UNZIP_RC} == 0 ]] ; then
    rm IrpTransmogrifier-bin.zip
  else
    rmdir irptransmogrifier
    cd ..
    error "failed to unzip '${WORKDIR}/IrpTransmogrifier-bin.zip', IrpTransmogrifier not installed."
    exit 5
  fi
  cd ..
}

function ensureIrpTransmogrifier() {
  which java >/dev/null
  if [[ $? != 0 ]] ; then
    error "java command not available, a JRE is needed by IrpTransmogrifier which is needed to convert lirc config files"
    exit 5
  fi

  if [[ -e "${WORKDIR}/irptransmogrifier" ]] ; then
    debug "irptransmogrifier found at '${WORKDIR}/irptransmogrifier'."
  else
    debug "irptransmogrifier not found at '${WORKDIR}/irptransmogrifier', downloading it..."
    downloadIrpTransmogrifier
  fi
  IRPTM="${WORKDIR}/irptransmogrifier/irptransmogrifier.sh"
}


function downloadPronto2Broadlink() {
  local URL="${PRONTO2BROADLINK_DOWNLOAD}"
  local TARGET="${WORKDIR}/pronto2broadlink.py"
  debug "downloading pronto2broadlink.py from '${URL}' to '${TARGET}'..."
  curl --fail -L "${URL}" -o "${TARGET}"
  local CURL_RC=$?
  debug "download of pronto2broadlink.py returned: $CURL_RC"
  if [[ $CURL_RC != 0 ]] ; then
    error "failed to download pronto2broadlink.py from '${URL}'"
    exit 5
  fi
}

function ensurePronto2Broadlink() {
  which python2 >/dev/null
  if [[ $? != 0 ]] ; then
    error "python2 command not available, it is needed by pronto2broadlink.py which is needed to convert pronto codes to broadlink codes"
    exit 5
  fi

  if [[ -e "${WORKDIR}/pronto2broadlink.py" ]] ; then
    debug "pronto2broadlink.py found at '${WORKDIR}/pronto2broadlink.py'."
  else
    debug "pronto2broadlink.py not found at '${WORKDIR}/pronto2broadlink.py', downloading it..."
    downloadPronto2Broadlink
  fi
  P2BL="${WORKDIR}/pronto2broadlink.py"
}


function usage() {
  error "Usage:"
  error "  $0 \"path to irdb .csv file or directory; or path to lircd.conf file\" \"configured name prefix\" [\"functions matching pattern\"]"
  error "  e.g.:  $0 \"Yamaha/Receiver/120,-1.csv\" \"Amp \"            (irdb)"
  error "         $0 \"Yamaha/Receiver\" \"Amp \" \"POWER\"             (parse all remotes in the irdb directory, only add POWER commands)"
  error "         $0 \"apple/A1294.lircd.conf\" appletv_ >appletv.yaml  (lirc)"
}



IRDB_PATH="${1}"
NAME_PREFIX="${2}"
MATCH_PATTERN="${3}"

if [[ "${IRDB_PATH}" == "" ]] || [[ "${NAME_PREFIX}" == "" ]] || [[ "${4}" != "" ]]  ; then
  usage
  exit 5
fi


ensurePronto2Broadlink

IRDB_PATH_LOWER="${IRDB_PATH,,}"
if [[ "${IRDB_PATH_LOWER%.csv}" != "${IRDB_PATH_LOWER}" ]] ; then
  debug "path '${IRDB_PATH}' ends in .csv, downloading file..."
  irdbFileToYaml "${IRDB_PATH}" "${NAME_PREFIX}" "${MATCH_PATTERN}"
else
  if [[ "${IRDB_PATH_LOWER%.conf}" != "${IRDB_PATH_LOWER}" ]] ; then
    ensureIrpTransmogrifier
    debug "path '${IRDB_PATH}' ends in .conf, assuming a lirc conf, downloading file..."
    lircFileToYaml "${IRDB_PATH}" "${NAME_PREFIX}" "${MATCH_PATTERN}"
  else
    debug "path '${IRDB_PATH}' does not end in .csv, assuming it is a directory, reading contents..."
    irdbDirToYaml "${IRDB_PATH}" "${NAME_PREFIX}" "${MATCH_PATTERN}"
  fi
fi
