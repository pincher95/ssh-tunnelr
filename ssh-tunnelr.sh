#!/bin/bash

####################
# ssh-tunnelr v2.0 #
####################

DST_FIRST_PORT=40000
DRY_MODE=0

show_help () {
  echo "Usage: ssh-tunnelr [OPTIONS] HOST[S] RANGE [RANGE...]"
  echo ""
  echo "Hosts:                 Hosts separate by ',' e.g. host.domain.com,172.16.1.8,user@10.1.8.1:2222"
  echo "                       An host is defined by [user@]host[:ssh_port] where user and ssh_port are optional"
  echo "Range(s)               Ports to forward to endpoint. This can be a single port e.g. 80 or a range e.g. 80:82."
  echo "                       You also can specify output port range with a third port number e.g. 7000:7002:80."
  echo "                       So port 7000 will be forwarded on port 80 of the endpoint, 7001 on 81 and 7002 on 82."
  echo "                       For single port combined with output port scpecified, you have to write 7000:7000:80."
  echo "                       Several ranges are allowed and must be separated by spaces  e.g 10000:10008 7000:7002:80 3306."
  echo "Options:"
  echo "  -d, --dry            Dry mode, for test. With this option, ssh command is not launched, it's only shown."
  echo "  --help               Show help"
  echo ""
  echo "Example:               ssh-tunnelr foo@host.domain.com,172.16.1.11,bar@10.5.1.10:2222 7000:7008"
  echo ""
}

while :; do
  case $1 in
	-d|--dry)
	  DRY_MODE=1
	  ;;
	--help)
	  show_help
  	  exit
	  ;;
	-?*)
	  printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
	  ;;
	*)
	  break
  esac
  shift
done

HOSTS="$1"
shift

for arg in "$@"; do
  RANGES="$RANGES $arg"
done

echo $HOSTS
echo $RANGES

MAX_PORT_NUMBER=65535

throw_error () {
  MSG=$1
  EXIT=$2

  STD_MSG="Command stopped"

  printf "\033[0;31m$MSG\033[0m\n"
  echo "$STD_MSG"
  if $EXIT ; then
  	exit 1
  fi
}

# unserialize data
IFS=',' read -r -a HSTS <<< "$HOSTS"
IFS=' ' read -r -a PRS  <<< "$RANGES"

# checks
if (( "${#HSTS[@]}" == 0 )); then
  throw_error "Please specify at least one host"
fi
if (( "${#PRS[@]}" == 0 )); then
  throw_error "Please specify at least one port range"
fi

# construct ssh command
CMD=""
# for each host
for ((i=0; i<${#HSTS[@]}; ++i)); do
  HST=${HSTS[$i]}
  SSH_USER=""
  SSH_PORT=""
  # if ssh user specified
  if [[ "$HST" =~ ^(.+)@(.+)$ ]]; then
    SSH_USER="${BASH_REMATCH[1]}@"
    HST=${BASH_REMATCH[2]}
  fi
  # if ssh port specified
  if [[ "$HST" =~ ^(.+):([0-9]+)$ ]]; then
    HST=${BASH_REMATCH[1]}
    SSH_PORT="-p ${BASH_REMATCH[2]}"
  fi
  CMD="$CMD\nssh $SSH_PORT $SSH_USER$HST\n"

  # for each range in ports ranges
  for ((j=0; j<${#PRS[@]}; ++j)); do
    # unserialize range
    IFS=':' read -r -a PR <<< "${PRS[$j]}"

    # if single port specified
    if (( "${#PR[@]}" == 1 )); then
      PR[1]=${PR[0]}
      PR[2]=${PR[0]}
    # if simple range port specified
    #elif (( "${#PR[@]}" == 2 )); then
      #PR[2]=${PR[1]}
    fi

    SRC_PORT=${PR[0]}
    DST_PORT=${PR[0]}
  
  	# if last host AND out ports range specified
    if [[ "$(( i + 1 ))" -eq "${#HSTS[@]}" && "${#PR[@]}" -eq "3" ]]; then
	  DST_PORT=${PR[2]}
	fi

	# checks
	if (( $SRC_PORT < 1 )) || (( $DST_PORT < 1 )); then
	  throw_error "Ports numbers  must be greater than 1"
	fi
	if (( ${PR[0]} > ${PR[1]} )); then
	  throw_error "First port in range must be less than last port"
	fi

	# for each port in range
	for ((k=${PR[0]}; k<=${PR[1]}; ++k)); do
	  if (( $SRC_PORT > $MAX_PORT_NUMBER )) || (( $DST_PORT > $MAX_PORT_NUMBER )); then
		throw_error "Ports numbers  must be less than $MAX_PORT_NUMBER - $DST_PORT"
	  fi
	  CMD="$CMD-L $SRC_PORT:localhost:$DST_PORT\n"
	  (( SRC_PORT++ ))
	  (( DST_PORT++ ))
    done
  done
done

echo -e $CMD
CMD="$(echo -e $CMD)"
if [ "$DRY_MODE" -eq "0" ]; then
  $CMD
fi

#TODO:
#- Prendre en charge des options ssh (-X, -t)
#- username facultative
