find ./artifacts/ \! -name '.gitkeep' -delete
rm -rf ./dockercompose/ && mkdir ./dockercompose/
rm -rf ./www/
cp ./docker-compose-templates/base-intercept.yaml ./dockercompose/
cp ./docker-compose-templates/base.yaml ./dockercompose/
docker kill $(docker ps -q)
docker rm -f $(docker ps -aq)
docker volume rm $(docker volume ls -q -f "name=dockercompose_*")
docker volume prune -f
docker ps -a