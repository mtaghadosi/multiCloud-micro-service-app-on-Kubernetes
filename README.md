# Trivago's case study implementation guide
#### This file contains all the necessary information’s and actions about my decisions regarding to Trivago case study implementation and also information about how to prepare the environment. 
* #### As you are seeing in below gif, this will deploy two type of deployment into a k3d Kubernetes local cloud. one using `Istio-Gateway` ingress along side with another (as plus) an internal service feeding by a simple busybox deployment. (More demonstration info in meda folder)

* #### Both Deployment demonstrations have traffic shaping configuration in a way that 70% goes to Golang version and another 30% goes to Java version.

#### Answers by [Mohammad Taghadosi](https://linkedin.com/in/mtaghadosi) 
![Alt Text](infra/media/demonstration.gif)
---
### Preparing environment:
1. Ubuntu Linux or Mac with [x86_64 arch](https://www.techtarget.com/whatis/definition/x86-64)
2. A working Docker engine
   - On Linux install [Docker](https://docs.docker.com/engine/install/ubuntu/)
   - On Mac install [Docker Desktop for Mac with Intel chip](https://docs.docker.com/desktop/install/mac-install/)
   - With current user part of gocker group: `sudo usermod -aG docker $USER` 
   - If you just did above step then reboot your system for changes to take effect (sometimes logoff and log back in will work) you should be able to run `docker ps` without sudo. This is critical for script installation.
3. A working kubectl client
    - On [linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
    - On [Mac](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)
    - Verify to have proper config in: `~/.kube/config`
    - `kubectl version --client`
4. A working k3d environment 
   - Can be installed from [here](https://k3d.io/v5.6.0/#installation)
---
### Deploying:
There is two methodes for deploying this on k3d cluster: 
1. First one is by using `install.sh` in the project root directory.
2. Second way is to install and deploy app using Helm chart.
3. Third way is to install by istioctl `install --set meshConfig.enableTracing=true`

#### 1. Using `install.sh` script
1. Copy and extract project folder in `HOME` directory. Navigate inside the project directory.
2. Ensure that you are in root of the project directory with `pwd` command. You should see: `home/$USER/trivago-case-study`
3. Run `chmod +x install.sh`
4. Deploy application by running `./install.sh`
5. During the script installation please wait while the cluster will be up and running do not close the script. It usually takes arround five minutes to finish please be patient during installation.
6. Please enter sudo password if you asked for it.
7. If you want to run the script again first run `uninstall.sh` then run `install.sh`
#### 2. Using Helm chart
Simply copy and paste all below commands one by one. Avoid changing image and/or other components's names.
1. Nagivate to project root. 
2. Create a local image registry: 
   - `k3d registry create trivago-local-registry --port 34281 --volume $SCRIPT_DIR/image-registry-data/:/var/lib/registry`

3. Create a k3d cluster using k3d-config.yaml file in infra folder and provide the local registry to it:
   - `k3d cluster create --config infra/k3d-config.yaml --registry-use k3d-trivago-local-registry:34281`

4. Install Istio by simply applying below yamls in order:
   - `kubectl apply -f infra/istio+addons/istio-init.yaml`
   - `kubectl apply -f infra/istio+addons/istio-install.yaml`
   - `kubectl apply -f infra/istio+addons/kiali-secret.yaml`
   - `kubectl apply -f infra/istio+addons/label-default-namespace.yaml`

5. Build and push Application docker images:
   - `cd apps/java-webserver`
   - `docker build -t localhost:34281/trivago-java:latest .`
   - `docker push localhost:34281/trivago-java:latest`
   - `cd .. && cd .. && cd apps/golang-webserver`
   - `docker build -t localhost:34281/trivago-go:latest .`
   - `docker push localhost:34281/trivago-go:latest`
   - `cd .. && cd .. `

6. Check if you are in project's root directory then Install Trivago app via Helm package: 
   - `helm install trivaago-helm trivago-helm-0.1.0.tgz`

7. Wait for the Pods to come online:
   - `kubectl get pods`

8. Get the cluster IP with one of below ommands (sometimes one can return NULL then used alternative provided command):
   - `echo $(kubectl get services -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')`
   - `echo $(kubectl get services -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')`
9. Run 100 request againist / path: (be carefull about crashing the cluster)
   - `for ((i=1; i<=100; i++)); do curl http://$LB_IP:31380/; sleep 0.1; done`
10. Acces the application and other components like below where the <CLUSTER_IP> is the ip you gathered in 8th stage:
   - Trivago Deployment: http://<CLUSTER_IP>:31380/
   - Kiali: http://<CLUSTER_IP>:31000/
   - Jaeger: http://<CLUSTER_IP>.3:31001/
   - Grafana: http://<CLUSTER_IP>:31002/

