#!/bin/bash

#
# Requires pronto2broadlink.py from:  https://gist.githubusercontent.com/appden/42d5272bf128125b019c45bc2ed3311f/raw/bdede927b231933df0c1d6d47dcd140d466d9484/pronto2broadlink.py
#
#
#


WORKDIR="work"

mkdir -p "${WORKDIR}"


function debug() {
  echo "${1}" >&2
  :
}

# PROTOCOL, DEVICE, SUBDEVICE, FUNCTION
function signalToPronto() {
  PROTOCOL="$1"
  DEVICE="$2"
  SUBDEVICE="$3"
  FUNCTION="$4"

  debug "signalToPronto: ${PROTOCOL}+${DEVICE}+${SUBDEVICE}+${FUNCTION}..."
  PRONTO=$(curl --data "signal=${PROTOCOL}+${DEVICE}+${SUBDEVICE}+${FUNCTION}" "http://irdb.tk/encode/" -s -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" -H "Content-Type: application/x-www-form-urlencoded" | grep "=\"sendPronto" |  sed -r -e "s/.*sendPronto\(([^\)]*).*/\1/g" | tr -d "'")
  debug "signalToPronto: ${PROTOCOL}+${DEVICE}+${SUBDEVICE}+${FUNCTION}, pronto hex: $PRONTO"
}

# PRONTO
function prontoToBroadlinkHex() {
  PRONTO="${1}"
  BROADLINKHEX=$(python2 pronto2broadlink.py "${PRONTO}")
}


# PROTOCOL, DEVICE, SUBDEVICE, FUNCTION
function signalToBroadlinkB64() {
  PROTOCOL="${1}"
  DEVICE="${2}"
  SUBDEVICE="${3}"
  FUNCTION="${4}"

  signalToPronto "${PROTOCOL}" "${DEVICE}" "${SUBDEVICE}" "${FUNCTION}"
  prontoToBroadlinkHex "${PRONTO}"
  debug "BroadlinkHex: ${BROADLINKHEX}"
  BROADLINKB64=$(echo -e "${BROADLINKHEX}" | xxd -r -p | base64 --wrap=0)
}


#IRDB_CSV_PATH
function downloadIrdbCsv() {
  curl -s "http://cdn.rawgit.com/probonopd/irdb/master/codes/${1}" -o "${WORKDIR}/current.csv"
}


#CSVPATH, NAME_PREFIX, INDENT
function loopAroundCsv() {
  LOCAL_CSV_PATH="${1}"
  NAME_PREFIX="${2}"
  INDENT="${3}"

  [ ! -f "${LOCAL_CSV_PATH}" ] && { echo "${LOCAL_CSV_PATH} file not found"; exit 99; }

  debug "file '${LOCAL_CSV_PATH}' has `wc -l ${LOCAL_CSV_PATH}` lines..."

  #skip header line
  sed 1d "${LOCAL_CSV_PATH}" |
  while IFS=, read fnname protocol device subdevice fn
  do
    debug "fnname $fnname, protocol: $protocol, device: $device, subdevice: $subdevice, fn: $fn"
    signalToBroadlinkB64 "$protocol" "$device" "$subdevice" "$fn"
    #debug "${fnname}: ${BROADLINKB64}"
    broadlinkB64ToYaml "${INDENT}" "${NAME_PREFIX}${fnname}" "${BROADLINKB64}"
    debug ""
  done
}


broadlinkB64ToYaml() {
  INDENT="${1}"
  #NAME_PREFIX="${2}"
  NAME="${2}"
  CODEB64="${3}"

 #sky_0:
 #       friendly_name: "Sky 0"
 #       command_on:  'JgA0AFcdDg4ODg4dDh0dDg4ODg4ODg4ODg4ODg4OHQ4OHQ4ODg4ODg4ODg4ODg4ODg4ODg4ADM8NBQAA'
 #       command_off: 'JgA0AFcdDg4ODg4dDh0dDg4ODg4ODg4ODg4ODg4OHQ4OHQ4ODg4ODg4ODg4ODg4ODg4ODg4ADM8NBQAA'

  NAME="${NAME,,}"
  NAME="${NAME// /_}"
  NAME="${NAME////_}"
  NAME="${NAME//+/plus}"
  NAME="${NAME//-/minus}"
  NAME="${NAME//./_}"


  echo "${INDENT}'${NAME}':"
  echo "${INDENT}  friendly_name: \"${NAME}\""
  echo "${INDENT}  command_on: '${CODEB64}'"
  echo "${INDENT}  "
}


IRDB_CSV_PATH="${1}"
NAME_PREFIX="${2}"


downloadIrdbCsv "${IRDB_CSV_PATH}"
loopAroundCsv "${WORKDIR}/current.csv" "${NAME_PREFIX}" ""
