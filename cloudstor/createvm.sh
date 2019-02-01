#!/bin/bash 

rgName='logservertestrg'
vmName='logservertra'
vmUser='tranise'
vmLocation='westeurope'
vmOpenPort=80 
storageAccountName="tralogstorage12312"
storogeAccountFileShareName="logs"
#https://www.web2generators.com/apache-tools/htpasswd-generator
passwordHash='tranise:$apr1$4t5rn1oy$G7uJ/ujh9ujVXiPlstSVB1'

echo write the basic auth credentials in nginx file
echo $passwordHash > ./log_server/nginx/.htpasswd

create_AzureVm(){
 echo -- create the resource group
 az group create --name $rgName --location $vmLocation

 echo -- create the vm
 az vm create --resource-group $rgName --name $vmName --public-ip-address-dns-name $vmName --image UbuntuLTS --admin-username $vmUser --generate-ssh-keys

 echo -- open port $vmOpenPort on the vm
 az vm open-port --port $vmOpenPort --resource-group $rgName --name $vmName
}

install_DockerTools (){
 echo install dependencies docker, docker compose and start docker service
 #install Docker
 az vm run-command invoke -g $rgName -n $vmName --command-id RunShellScript --scripts "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' && sudo apt-get update && apt-cache policy docker-ce && sudo apt-get install -y docker-ce"
 #install Docker Compose
 az vm run-command invoke -g $rgName -n $vmName --command-id RunShellScript --scripts "sudo curl -L https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
 #start Docker service
 az vm run-command invoke -g $rgName -n $vmName --command-id RunShellScript --scripts "sudo service docker start"
}

install_CloudstorePlugin (){
 echo install cloudstor plugin
 az vm run-command invoke -g $rgName -n $vmName --command-id RunShellScript --scripts "sudo docker plugin install docker4x/cloudstor:17.05.0-ce-azure2 --grant-all-permissions --alias cloudstor:azure CLOUD_PLATFORM=AZURE AZURE_STORAGE_ACCOUNT="$storageAccountName" AZURE_STORAGE_ACCOUNT_KEY="$storagePrimaryKey""
}

create_AzureStorageAndFileShare(){
 echo -- create the storage account
 az storage account create -n $storageAccountName -g $rgName -l $vmLocation --sku Standard_LRS
 storageConnexionString=$(az storage account show-connection-string -n $storageAccountName -g $rgName --query 'connectionString' -o tsv)
 storagePrimaryKey=$(az storage account keys list --resource-group $rgName --account-name $storageAccountName --query "[0].value" | tr -d '"')

 echo -- create the file share
 az storage share create --name $storogeAccountFileShareName --connection-string $storageConnexionString
}

run_LogServer(){
 echo copy 'log_server' folder content in the remote vm
 scp -o StrictHostKeyChecking=no -r ./log_server $vmUser@$vmName.$vmLocation.cloudapp.azure.com:/home/$vmUser/log_server

 echo run 'docker-compose' file
 az vm run-command invoke --debug -g $rgName -n $vmName --command-id RunShellScript --scripts "cd /home/"$vmUser"/log_server && sudo docker-compose up -d"
}

create_AzureVm
install_DockerTools
create_AzureStorageAndFileShare
install_CloudstorePlugin
run_LogServer

echo log server available on $vmName.$vmLocation.cloudapp.azure.com

#clear [.htpasswd] file
echo "" > ./log_server/nginx/.htpasswd