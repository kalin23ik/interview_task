# interview_task


# The Task:
[Platform_DevOps_Homework Assignment_ Helm-based GitOps-Friendly Deployment for Internal Services-180725-073637](https://drive.google.com/file/d/1esEqRPTYc45jn2E-GjnpUkviFn0nIMEd/view?usp=sharing)<!-- {"preview":"true"} -->


# The Solution

1. ## Simple Web Application

It is a really simple web application. It’s written on Python, using the [Flask](https://palletsprojects.com/projects/flask/) web framework,  which is designed to make getting started quick and easy, with the ability to scale up to complex applications. 
The application does only one thing - to print as JSON the output of `os.environ` function, actually displaying the environment variables of the OS, where it is executed.
The code is in the file `app/app.py` 

*Note:* The task requires such a simple functionality of the application, without specifying how exactly to achieve it. My research (considering that I’m not a professional web developer) showed, that this functionality, certainly, can be achieved by use of many other programming (scripting) languages, or frameworks, as: Node.JS with Express, Rust with ActixWeb, Go language, even static HTML + shell CGI. The Python with Flask was chosen just because of my sympathy for this programming language.

2. ## Dockerfile

The simple web application is “dockerized” through use of the `app/Dockerfile` which builds a Docker image based on *python:3.11-slim* image.
The image is tagged as `envapp:v1` and pushed to the Dockerhub repository called [kkrast/envapp](https://hub.docker.com/repository/docker/kkrast/envapp/general)for public access 

3. ## Helm Chart

The source code of the Helm chart, purposed for deploying the proposed application on Kubernetes, is inside the `chart/internal-servce/` sub-directory.
It defines several Kubernetes resources, forming the application by a minimalistic way, just providing the task requirements:

- `templates/deployments.yaml`

  Deployment resource specification contains the mentioned as requirements features:
		
  * Replicated deployment (min 3 pods) (`replicas: 3`)
  * Pod anti-affinity (to spread pods across nodes -through `affinity` block), as it is including even control-plane node in scheduling of pods (through `tolerations` block)
  * Pod SecurityContext with (some of) best practices (as per this [article](https://www.jit.io/resources/devsecops/8-steps-to-configure-and-define-kubernetes-security-context) ): 

```
	securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 2000

		allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
            drop: ["ALL"]
```

 	   Additionally, to provide with the required functionality for environments setup, the 	Deployment template has ability to add container environment variable `prod=“true”\”false”` (as only distinction of the two environments *dev* and *prod*), as well as ability to be added additional so called extra environment variable(s)

- `templates/service.yaml`

  Kubernetes service exposes the application just internally inside the cluster (through usage of `ClusterIP` service type), as it is explicitly mentioned in the task that the service is internal (and there is no need of ingress).  Still, to see the produced web page can be used `kubectl port-forwarding` functionality, to forward the service port (80) to a local system port.

- `templates/hpa.yaml`

  This manifest template configures *HoriziontalPodAutoscaler* (HPA), as it is required in the task.
  HPA resource is configured with `minReplicas: 3` and `maxReplicas:10`, which should ensure at least 3 pods (spread across 3 cluster nodes) as minimum, and scaling out to maximum 10 pods (which also can be spread across the respective number of nodes). 
  HPA **requires** [metrics-server](https://github.com/kubernetes-sigs/metrics-server) service to be installed  in the Kubernetes cluster, (not mentioned in the task!) so this is considered in the deployment of all the structure (through Kustomise, as will be described further)

Helm chart *internal-service* has a `values.yaml` file with the default configuration values, as required: `hub`, `image`, `tag`, `prod`, `env`, `resources` . Some comments have been added to the helm templates, through which the use of some additional variables can be added (marked as optional in `values.yaml`)

4. ## Environment Support

As mentioned in the task, the only distinction of dev and prod environment must be the value of the environment variable `PROD=“true”/“false”`, which is controlled by the Helm chart value called *prod*. 
No ingress resource configured in the chart, also there is no any persistent volume setup.
5. ## Run on [kind](https://kind.sigs.k8s.io/)

- #### Set up a local kind cluster

As described in kind [quick-start](https://kind.sigs.k8s.io/docs/user/quick-start) page, it can be installed simply from release binaries, for instance

On Linux
```
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

On Mac
```
# For Intel Macs
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-darwin-amd64
# For M1 / ARM Macs
[ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-darwin-arm64
chmod +x ./kind
mv ./kind /some-dir-in-your-PATH/kind
```

- #### Install the chart for both dev and prod (installation of [Helm](https://helm.sh/docs/intro/install/) is prerequisite)
1) install metrics-server, required for HPA
```
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-	server/

helm install metrics-server metrics-server/metrics-server -n kube-system 	\
	--set args[0]='--kubelet-insecure-tls' \
	--set args[1]='--kubelet-preferred-address-	types=InternalIP\,Hostname\,InternalDNS\,ExternalDNS\,ExternalIP'
```
  
2) install the Helm chart for internal-service (make sure you are in the root repository directory)
For dev environment:

```
helm install internal-service-dev -n dev \
-f ./chart/internal-service/values.yaml ./chart/internal-service \ 
--set-string hub='kkrast' \ 
--set-string prod='false' \
--create-namespace
```

For prod environment:

```
helm install internal-service-prod -n prod \
-f ./chart/internal-service/values.yaml ./chart/internal-service \ 
--set-string hub='kkrast' \ 
--set-string prod='true' \
--create-namespace
```


6. 
   
7. 





