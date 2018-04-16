composeTemplatesFolder="docker-compose-templates"
artifactsTemplatesFolder="artifact-templates"
: ${CTI_HOME:=$PWD}
: ${TEMPLATES_ARTIFACTS_FOLDER:=$CTI_HOME/$artifactsTemplatesFolder}
: ${TEMPLATES_DOCKER_COMPOSE_FOLDER:=$CTI_HOME/$composeTemplatesFolder}
: ${GENERATED_ARTIFACTS_FOLDER:=./artifacts}
: ${GENERATED_DOCKER_COMPOSE_FOLDER:=./dockercompose}
: ${DOMAIN:="cti.com"}
: ${ORG1:="a"}
: ${ORG2:="b"}
: ${ORG3:="c"}
: ${ORG4:="d"}
DEFAULT_ORDERER_PORT=7050
DEFAULT_WWW_PORT=8080
DEFAULT_API_PORT=4000
DEFAULT_CA_PORT=7054
DEFAULT_PEER0_PORT=7051
DEFAULT_PEER0_EVENT_PORT=7053
DEFAULT_PEER1_PORT=7056
DEFAULT_PEER1_EVENT_PORT=7058
GID=$(id -g)
WGET_OPTS="--verbose -N"
CHAINCODE_COMMON_NAME=reference
CHAINCODE_BILATERAL_NAME=relationship
CHAINCODE_COMMON_INIT='{"Args":["init","a","100","b","100"]}'
CHAINCODE_BILATERAL_INIT='{"Args":["init","a","100","b","100"]}'

function info() {
    echo "=============  info()  ===================="
    echo 
    echo "$1"
    echo 
}

function dockerComposeUp() {
  compose_file="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-$1.yaml"
  echo "starting docker instances from $compose_file"
  TIMEOUT=${CLI_TIMEOUT} docker-compose -f ${compose_file} up -d 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    logs ${1}
    exit 1
  fi
}

function installChaincode() {
  org=$1
  n=$2
  v=$3
  f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-${org}.yaml"
  p=${n}
  l=golang
  echo "installing chaincode $n to peers of $org from ./chaincode/go/$p $v using $f"
  echo "docker-compose --file ${f} run --rm \"cli.$org.$DOMAIN\" bash -c \"CORE_PEER_ADDRESS=peer0.$org.$DOMAIN:7051 peer chaincode install -n $n -v $v -p $p -l $l "
  echo " && CORE_PEER_ADDRESS=peer1.$org.$DOMAIN:7051 peer chaincode install -n $n -v $v -p $p -l $l\""
  docker-compose --file ${f} run --rm "cli.$org.$DOMAIN" bash -c "CORE_PEER_ADDRESS=peer0.$org.$DOMAIN:7051 peer chaincode install -n $n -v $v -p $p -l $l \
  && CORE_PEER_ADDRESS=peer1.$org.$DOMAIN:7051 peer chaincode install -n $n -v $v -p $p -l $l"
}

function installAll() {
  org=$1
  sleep 2
  for chaincode_name in ${CHAINCODE_COMMON_NAME} ${CHAINCODE_BILATERAL_NAME}
  do
    installChaincode ${org} ${chaincode_name} "1.0"
  done
}

function createChannel() {
    org=$1
    channel_name=$2
    f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-${org}.yaml"
    info "creating channel $channel_name by $org using $f"
    echo "docker-compose --file ${f} run --rm \"cli.$org.$DOMAIN\" bash -c \"peer channel create -o orderer.$DOMAIN:7050 -c $channel_name -f /etc/hyperledger/artifacts/channel/$channel_name.tx --tls --cafile /etc/hyperledger/crypto/orderer/tls/ca.crt\""
    docker-compose --file ${f} run --rm "cli.$org.$DOMAIN" bash -c "peer channel create -o orderer.$DOMAIN:7050 -c $channel_name -f /etc/hyperledger/artifacts/channel/$channel_name.tx --tls --cafile /etc/hyperledger/crypto/orderer/tls/ca.crt"
    echo "changing ownership of channel block files"
    docker-compose --file ${f} run --rm "cli.$DOMAIN" bash -c "chown -R $UID:$GID ."
    d="$GENERATED_ARTIFACTS_FOLDER"
    echo "copying channel block file from ${d} to be served by www.$org.$DOMAIN"
    cp "${d}/$channel_name.block" "www/${d}"
}

function joinChannel() {
  org=$1
  channel_name=$2
  f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-${org}.yaml"
  echo "joining channel $channel_name by all peers of $org using $f"
  docker-compose --file ${f} run --rm "cli.$org.$DOMAIN" bash -c "CORE_PEER_ADDRESS=peer0.$org.$DOMAIN:7051 peer channel join -b $channel_name.block"
  docker-compose --file ${f} run --rm "cli.$org.$DOMAIN" bash -c "CORE_PEER_ADDRESS=peer1.$org.$DOMAIN:7051 peer channel join -b $channel_name.block"
}

function instantiateChaincode() {
  org=$1
  channel_names=($2)
  n=$3
  i=$4
  f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-${org}.yaml"
  for channel_name in ${channel_names[@]}; do
    echo "instantiating chaincode $n on $channel_name by $org using $f with $i"
    c="CORE_PEER_ADDRESS=peer0.$org.$DOMAIN:7051 peer chaincode instantiate -n $n -v 1.0 -c '$i' -o orderer.$DOMAIN:7050 -C $channel_name --tls --cafile /etc/hyperledger/crypto/orderer/tls/ca.crt"
    d="cli.$org.$DOMAIN"
    echo "instantiating with $d by $c"
    docker-compose --file ${f} run --rm ${d} bash -c "${c}"
  done
}

function createJoinInstantiateWarmUp() {
  org=${1}
  channel_name=${2}
  chaincode_name=${3}
  chaincode_init=${4}
  createChannel ${org} ${channel_name}
  joinChannel ${org} ${channel_name}
  instantiateChaincode ${org} ${channel_name} ${chaincode_name} ${chaincode_init}
}

function joinWarmUp() {
  org=$1
  channel_name=$2
  chaincode_name=$3
  joinChannel ${org} ${channel_name}
}

for org in ${DOMAIN} ${ORG1} ${ORG2} ${ORG3} ${ORG4}
  do
    dockerComposeUp ${org}
  done

for org in ${ORG1} ${ORG2} ${ORG3} ${ORG4}
  do
    installAll ${org}
  done

# all-chan
createJoinInstantiateWarmUp a all-chan ${CHAINCODE_COMMON_NAME} ${CHAINCODE_COMMON_INIT}
joinWarmUp b all-chan ${CHAINCODE_COMMON_NAME}
joinWarmUp c all-chan ${CHAINCODE_COMMON_NAME}
joinWarmUp d all-chan ${CHAINCODE_COMMON_NAME}

# csirt-chan
createJoinInstantiateWarmUp a csirt-chan ${CHAINCODE_BILATERAL_NAME} ${CHAINCODE_BILATERAL_INIT}
joinWarmUp b csirt-chan ${CHAINCODE_BILATERAL_NAME}
joinWarmUp c csirt-chan ${CHAINCODE_BILATERAL_NAME}

# eu-chan
createJoinInstantiateWarmUp a eu-chan ${CHAINCODE_BILATERAL_NAME} ${CHAINCODE_BILATERAL_INIT}
joinWarmUp b eu-chan ${CHAINCODE_BILATERAL_NAME}
joinWarmUp c eu-chan ${CHAINCODE_BILATERAL_NAME}

# ie-chan
createJoinInstantiateWarmUp a ie-chan ${CHAINCODE_BILATERAL_NAME} ${CHAINCODE_BILATERAL_INIT}
joinWarmUp d ie-chan ${CHAINCODE_BILATERAL_NAME}
