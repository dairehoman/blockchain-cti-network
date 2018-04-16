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

function generateOrdererDockerCompose() {
    mainOrg=$1
    echo "Creating orderer docker compose yaml file with $DOMAIN, $ORG1, $ORG2, $ORG3, $ORG4 $DEFAULT_ORDERER_PORT, $DEFAULT_WWW_PORT"
    compose_template=$TEMPLATES_DOCKER_COMPOSE_FOLDER/docker-composetemplate-orderer.yaml
    f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-$DOMAIN.yaml"
    cli_extra_hosts=${DEFAULT_CLI_EXTRA_HOSTS}
    sed -e "s/DOMAIN/$DOMAIN/g" -e "s/MAIN_ORG/$mainOrg/g" -e "s/CLI_EXTRA_HOSTS/$cli_extra_hosts/g" -e "s/ORDERER_PORT/$DEFAULT_ORDERER_PORT/g" -e "s/WWW_PORT/$DEFAULT_WWW_PORT/g" -e "s/ORG1/$ORG1/g" -e "s/ORG2/$ORG2/g" -e "s/ORG3/$ORG3/g" -e "s/ORG4/$ORG4/g"  ${compose_template} | awk '{gsub(/\[newline\]/, "\n")}1' > ${f}
}

function generateNetworkConfig() {
  orgs=${@}
  echo "Generating network-config.json for $orgs, ${orgs[0]}"
  networkConfigTemplate=$TEMPLATES_ARTIFACTS_FOLDER/network-config-template.json
  if [ -f ./$artifactsTemplatesFolder/network-config-template.json ]; then
    networkConfigTemplate=./$artifactsTemplatesFolder/network-config-template.json
  fi
  out=`sed -e "s/DOMAIN/$DOMAIN/g" -e "s/ORG1/${orgs[0]}/g" -e "s/^\s*\/\/.*$//g" $networkConfigTemplate`
  placeholder=",}}"
  for org in ${orgs}
    do
      snippet=`sed -e "s/DOMAIN/$DOMAIN/g" -e "s/ORG/$org/g" $TEMPLATES_ARTIFACTS_FOLDER/network-config-orgsnippet.json`
      out="${out//$placeholder/,$snippet}"
    done
  eof="}}"
  out="${out//$placeholder/${eof}}"
  echo ${out} > $GENERATED_ARTIFACTS_FOLDER/network-config.json
}

function generateOrdererArtifacts() {
    mkdir ./artifatcs/channel
    org=$1
    echo "Creating orderer yaml files with $DOMAIN, $ORG1, $ORG2, $ORG3, $ORG4, $DEFAULT_ORDERER_PORT, $DEFAULT_WWW_PORT"
    f="$GENERATED_DOCKER_COMPOSE_FOLDER/docker-compose-$DOMAIN.yaml"
    mkdir -p "$GENERATED_ARTIFACTS_FOLDER/channel"
    generateNetworkConfig ${ORG1} ${ORG2} ${ORG3} ${ORG4}
    sed -e "s/DOMAIN/$DOMAIN/g" -e "s/ORG1/$ORG1/g" -e "s/ORG2/$ORG2/g" -e "s/ORG3/$ORG3/g" -e "s/ORG4/$ORG4/g" $TEMPLATES_ARTIFACTS_FOLDER/configtxtemplate.yaml > $GENERATED_ARTIFACTS_FOLDER/configtx.yaml
    createChannels=("all-chan" "csirt-chan" "eu-chan" "ie-chan")    
    for channel_name in ${createChannels[@]}
    do
        echo "Generating channel config transaction for $channel_name"
        docker-compose --file ${f} run --rm -e FABRIC_CFG_PATH=/etc/hyperledger/artifacts "cli.$DOMAIN" configtxgen -profile "$channel_name" -outputCreateChannelTx "./channel/$channel_name.tx" -channelID "$channel_name"
    done
    sed -e "s/DOMAIN/$DOMAIN/g" $TEMPLATES_ARTIFACTS_FOLDER/cryptogentemplate-orderer.yaml > "$GENERATED_ARTIFACTS_FOLDER/cryptogen-$DOMAIN.yaml"
    echo "Generating crypto material with cryptogen"
    echo "docker-compose --file ${f} run --rm \"cli.$DOMAIN\" bash -c \"sleep 2 && cryptogen generate --config=cryptogen-$DOMAIN.yaml\""
    docker-compose --file ${f} run --rm "cli.$DOMAIN" bash -c "sleep 2 && cryptogen generate --config=cryptogen-$DOMAIN.yaml"
    echo "Generating orderer genesis block with configtxgen"
    docker-compose --file ${f} run --rm -e FABRIC_CFG_PATH=/etc/hyperledger/artifacts "cli.$DOMAIN" configtxgen -profile OrdererGenesis -outputBlock ./channel/genesis.block
    echo "Changing artifacts file ownership"
    docker-compose --file ${f} run --rm "cli.$DOMAIN" bash -c "chown -R $UID:$GID ."
}
generateOrdererDockerCompose ${ORG1}
generateOrdererArtifacts