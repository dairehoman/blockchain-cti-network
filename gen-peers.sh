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

function genPeerArtifacts() { 
    org=$1
    api_port=$2
    www_port=$3
    ca_port=$4
    peer0_port=$5
    peer0_event_port=$6
    peer1_port=$7
    peer1_event_port=$8
    : ${api_port:=${DEFAULT_API_PORT}}
    : ${www_port:=${DEFAULT_WWW_PORT}}
    : ${ca_port:=${DEFAULT_CA_PORT}}
    : ${peer0_port:=${DEFAULT_PEER0_PORT}}
    : ${peer0_event_port:=${DEFAULT_PEER0_EVENT_PORT}}
    : ${peer1_port:=${DEFAULT_PEER1_PORT}}
    : ${peer1_event_port:=${DEFAULT_PEER1_EVENT_PORT}}
    echo "Creating peer $DOMAIN, $org, $api_port, $www_port, $ca_port, $peer0_port, $peer0_event_port, $peer1_port, $peer1_event_port"
    compose_template=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-composetemplate-peer.yaml
    f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-$org.yaml"
    sed -e "s/DOMAIN/$DOMAIN/g" -e "s/ORG/$org/g" $TEMPLATES_ARTIFACTS_FOLDER/cryptogentemplate-peer.yaml > $GENERATED_ARTIFACTS_FOLDER/"cryptogen-$org.yaml"
    sed -e "s/PEER_EXTRA_HOSTS/$peer_extra_hosts/g" -e "s/CLI_EXTRA_HOSTS/$cli_extra_hosts/g" -e "s/API_EXTRA_HOSTS/$api_extra_hosts/g" -e "s/DOMAIN/$DOMAIN/g" -e "s/\([^ ]\)ORG/\1$org/g" -e "s/API_PORT/$api_port/g" -e "s/WWW_PORT/$www_port/g" -e "s/CA_PORT/$ca_port/g" -e "s/PEER0_PORT/$peer0_port/g" -e "s/PEER0_EVENT_PORT/$peer0_event_port/g" -e "s/PEER1_PORT/$peer1_port/g" -e "s/PEER1_EVENT_PORT/$peer1_event_port/g" ${compose_template} | awk '{gsub(/\[newline\]/, "\n")}1' > ${f}
    sed -e "s/ORG/$org/g" $TEMPLATES_ARTIFACTS_FOLDER/fabric-ca-server-configtemplate.yaml > $GENERATED_ARTIFACTS_FOLDER/"fabric-ca-server-config-$org.yaml"
    mkdir -p $GENERATED_ARTIFACTS_FOLDER/hosts/${org}
    cp $TEMPLATES_ARTIFACTS_FOLDER/default_hosts $GENERATED_ARTIFACTS_FOLDER/hosts/${org}/api_hosts
    cp $TEMPLATES_ARTIFACTS_FOLDER/default_hosts $GENERATED_ARTIFACTS_FOLDER/hosts/${org}/cli_hosts
    echo "Generating crypto material"
    echo "docker-compose --file ${f} run --rm \"cliNoCryptoVolume.$org.$DOMAIN\" bash -c \"cryptogen generate --config=cryptogen-$org.yaml\""
    docker-compose --file ${f} run --rm "cliNoCryptoVolume.$org.$DOMAIN" bash -c "sleep 2 && cryptogen generate --config=cryptogen-$org.yaml"
    echo "Changing artifacts ownership"
    docker-compose --file ${f} run --rm "cliNoCryptoVolume.$org.$DOMAIN" bash -c "chown -R $UID:$GID ."
    echo "Adding generated CA private keys filenames to $f"
    ca_private_key=$(basename `ls -t $GENERATED_ARTIFACTS_FOLDER/crypto-config/peerOrganizations/"$org.$DOMAIN"/ca/*_sk`)
    [[ -z  ${ca_private_key}  ]] && echo "empty CA private key" && exit 1
    sed -i -e "s/CA_PRIVATE_KEY/${ca_private_key}/g" ${f}
    sed -e "s/DOMAIN/$DOMAIN/g" -e "s/ORG/$org/g" $TEMPLATES_ARTIFACTS_FOLDER/configtx-orgtemplate.yaml > $GENERATED_ARTIFACTS_FOLDER/configtx.yaml
    echo "Generating ${org}Config.json"
    echo "docker-compose --file ${f} run --rm \"cliNoCryptoVolume.$org.$DOMAIN\" bash -c \"FABRIC_CFG_PATH=./ configtxgen  -printOrg ${org}MSP > ${org}Config.json\""
    docker-compose --file ${f} run --rm "cliNoCryptoVolume.$org.$DOMAIN" bash -c "FABRIC_CFG_PATH=./ configtxgen  -printOrg ${org}MSP > ${org}Config.json"
}
genPeerArtifacts ${ORG1} 4000 8081 7054 7051 7053 7056 7058
genPeerArtifacts ${ORG2} 4001 8082 8054 8051 8053 8056 8058
genPeerArtifacts ${ORG3} 4002 8083 9054 9051 9053 9056 9058
genPeerArtifacts ${ORG4} 4003 8084 1054 1051 1053 1056 1058