#!/bin/bash
# ANSI color codes
ORANGE='\033[0;33m'
PINK='\033[38;5;206m'
NC='\033[0m' # No Color
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Checking if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${ORANGE}Error: Docker is not installed. Please install Docker before running this script.${NC}"
    exit 1
fi

# Creating a local image registry
registry_output=$(k3d registry ls)
if echo "$registry_output" | grep -q "k3d-trivago-local-registry"; then
    echo "k3d-trivago-local-registry already exists. Skipping installation."
else
    if k3d registry create trivago-local-registry --port 34281 --volume $SCRIPT_DIR/image-registry-data/:/var/lib/registry; then
        echo -e "${ORANGE}Trivago local image registry was created successfully!${NC}"
    else
        echo -e "${ORANGE}Error: Failed to create Trivago image registry! Is the registry already exists? ${NC}"
        exit 1
    fi
fi


echo
echo -e "${ORANGE}---------------------------------------"
# Creating K3d cluster
cluster_output=$(k3d cluster ls)
if echo "$cluster_output" | grep -q "trivago-cluster-tinta"; then
        echo "trivago-cluster-tinta is already exists. Deletting it..."
        k3d cluster delete trivago-cluster-tinta
fi
if k3d cluster create --config $SCRIPT_DIR/infra/k3d-config.yaml --registry-use k3d-trivago-local-registry:34281; then
    echo -e "${ORANGE}Cluster created successfully!${NC}"
else
    echo -e "${ORANGE}Error: Failed to create Trivago cluster. Check above logs.${NC}"
    exit 1
fi


echo -e "${ORANGE}Please wait this could take a while...${NC}"
sleep 2
while true; do
    # I am running 'kubectl get pods -A' to making sure that cluster is up and running before continueing 
    # I reached to this point that if all pads of kube-system not being in running more and script 
    # deploys the microservices sometimes it leads to microservices behave oddly! => mTaghadosi
    pod_status=$(kubectl get pods -A)

    # Check if all kube-system pods are "Running" except helm ones!
    if echo "$pod_status" | grep -v "helm" | grep -q " 0/"; then
        echo -e "${ORANGE}Waiting for Cluster: trivago-cluster-tinta...${NC}"
        sleep 3  # Adjust the sleep duration as needed
    else
        echo -e "${ORANGE}DONE. All pods are up!${NC}"
        break  # Exit the loop when all pods are in the Running state
    fi
done

echo
echo -e "${ORANGE}---------------------------------------"
echo -e "${ORANGE}Building Java microservice...${NC}"
cd $SCRIPT_DIR/apps/java-webserver
docker build -t localhost:34281/trivago-java:latest .
sleep 2 #why wait? this is for the delay between build and push sometime file-system can act tricky when pulling images instantly after pushing them.
echo -e "${ORANGE}Pushing Java microservice to local image repository...${NC}"
docker push localhost:34281/trivago-java:latest

echo -e "${ORANGE}Building Golang microservice...${NC}"
cd $SCRIPT_DIR/apps/golang-webserver
docker build -t localhost:34281/trivago-go:latest .
sleep 2
echo -e "${ORANGE}Pushing Golang microservice to local image repository...${NC}"
docker push localhost:34281/trivago-go:latest


echo
echo -e "${ORANGE}---------------------------------------${NC}"
echo -e "${ORANGE}Installing helm into the cluster...${NC}"
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor > helm.gpg
sudo mv helm.gpg /usr/share/keyrings/helm.gpg
sudo apt-get install apt-transport-https -y
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# echo
# echo -e "${ORANGE}---------------------------------------${NC}"
# echo -e "${ORANGE}Installing Istio...${NC}"
# curl -sL https://istio.io/downloadIstioctl | sh -
# export PATH=$HOME/.istioctl/bin:$PATH
# istioctl install -y
# echo -e "${ORANGE}Done.${NC}"


echo
echo -e "${ORANGE}---------------------------------------${NC}"
echo -e "${ORANGE}Deploying manifests...${NC}"
cd $SCRIPT_DIR
kubectl apply -f $SCRIPT_DIR/infra/istio+addons/istio-init.yaml
kubectl apply -f $SCRIPT_DIR/infra/istio+addons/istio-install.yaml
kubectl apply -f $SCRIPT_DIR/infra/istio+addons/kiali-secret.yaml  # no needed for new versions
kubectl apply -f $SCRIPT_DIR/infra/istio+addons/label-default-namespace.yaml
kubectl apply -f $SCRIPT_DIR/infra/canary-auto-load-70-30.yaml
kubectl apply -f $SCRIPT_DIR/infra/canary-istio-gateway.yaml

echo -e "${ORANGE}Please wait this could take a while...${NC}"
echo -e "${ORANGE}Maybe two to three minutes, want to grap a cofffe?${NC}"
sleep 2


while true; do
    # waiting for all pods to be up! => mTaghadosi
    pod_status=$(kubectl get pods -A)

    # Check if all kube-system pods are "Running" except helm ones!
    if echo "$pod_status" | grep -v "helm" | grep -v "Pending" | grep -q " 0/"; then
        echo -e "${ORANGE}Waiting for Cluster: trivago-cluster-tinta...${NC}"
        sleep 3  # Adjust the sleep duration as needed
    else
        echo -e "${ORANGE}DONE. All pods are up!${NC}"
        break  # Exit the loop when all pods are in the Running state
    fi
done


echo
LB_IP=$(kubectl get services -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# Check if LB_IP is null or not. Sometimes it's a bit tricky!!! if NULL then use istio loadbalancer IP instead => mTaghadosi
if [ -z "$LB_IP" ]; then
    LB_IP=$(kubectl get services -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

echo -e "${ORANGE}+ Done, All Pods are up!${NC}"
echo
echo -e "${ORANGE}--------------------------------------${NC}"
echo -e "${ORANGE}------------ CLUSTER INFO ------------${NC}"
echo -e "${ORANGE}--------------------------------------${NC}"
echo
echo -e "${ORANGE}+ Cluster external IP: ${PINK}$LB_IP${NC}"
echo -e "${ORANGE}+ Trivago Deployment: ${PINK}http://$LB_IP:31380/${NC}"
echo -e "${ORANGE}+ Kiali: ${PINK}http://$LB_IP:31000/${NC}"
echo -e "${ORANGE}+ Jaeger: ${PINK}http://$LB_IP:31001/${NC}"
echo -e "${ORANGE}+ Grafana: ${PINK}http://$LB_IP:31002/${NC}"
echo
echo -e "${ORANGE}--------------------------------------${NC}"
echo -e "${ORANGE}--------------------------------------${NC}"
echo
echo -e "${ORANGE}+ Sending 100 traffic to generate the mesh graphs...${NC}"
echo -e "${ORANGE}+ After this please open Kiali and see the graphs.${NC}"
for ((i=1; i<=100; i++)); do
    curl -sS http://$LB_IP:31380/health > /dev/null
    echo -e -ne "${ORANGE}+ Sent: $i\r${NC}"
    sleep 0.1
done
echo -e "${ORANGE}+ ALL DONE.${NC}"