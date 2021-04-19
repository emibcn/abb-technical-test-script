#!/bin/bash -e

# Determine which type of output we'll do
# As we only accept one option, we don't really need getopt
OUTPUT_TYPE="influx"
if [ "${1}" = '--human' ]
then
    OUTPUT_TYPE="HUMAN"
fi

ERROR=""
TIMESTAMP="$(date +%s%N)"
MEASUREMENT="example"

print_value() {
    local FIELD="${1}"
    local VALUE="${2}"
    if [ "${OUTPUT_TYPE}" = 'HUMAN' ]
    then
        # Pretty print variable name
        local CAPITALIZED="${FIELD^}"
        echo "${CAPITALIZED//_/ }: ${VALUE}"
    else
        echo "${MEASUREMENT} ${FIELD}=${VALUE} ${TIMESTAMP}"
    fi
}

# Wrap influx text values with quotes
print_text_value() {
    if [ "${OUTPUT_TYPE}" = 'HUMAN' ]
    then
        print_value "${1}" "${2}"
    else
        print_value "${1}" "\"${2}\""
    fi
}

# Show error:
# - If there is no error, show "OK"
# - For influx, if there is an error message, add "ERROR" at
#   the beginning, so Grafana shows it RED
print_error() {
    local ERR_MSG="${@}"

    if [ "${ERR_MSG}" = "" ]
    then
        ERR_MSG="OK"
    elif [ "${OUTPUT_TYPE}" != 'HUMAN' ]
    then
        ERR_MSG="ERROR: ${ERR_MSG}"
    fi

    print_text_value "error" "${ERR_MSG}"
}

# Get default router information and extract its IP
ROUTER="$(ip route show default | sed -e 's/.* via \([^ ]*\) .*/\1/')"

# If no IP could be extracted
if [ "${ROUTER}" = "" ]
then
    ERROR="No default router found"
else
    print_text_value "router" "${ROUTER}"
fi

if [ "${ERROR}" = "" ]
then
    # Try to ping the router. Fail fast:
    # - c1: Only one ping
    # - W1: One second timeout
    TIME="$(ping -c1 -W1 "${ROUTER}" | grep 'bytes from' | sed -e 's/.* time=\([^ ]*\) .*/\1/')"
    if [ "$TIME" = "" ]
    then
        ERROR="Default router ${ROUTER} could not be reached"
    else
        print_value "time_to_router" "${TIME}"
    fi
fi

if [ "${ERROR}" = "" ]
then
    # Get own public IP from public service icanhazip
    PUBLIC_IP="$(curl -s https://icanhazip.com)"
    
    # Reverse resolve public IP using dig (and remove leading dot)
    RESOLVED_HOST="$(dig +short -x "${PUBLIC_IP}" | sed -e 's/\.$//')"

    print_text_value "public_ip" "${PUBLIC_IP}"
    print_text_value "resolved_host" "${RESOLVED_HOST}"
fi

print_error "${ERROR}"
