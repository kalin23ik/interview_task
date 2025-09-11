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

- Set up a local kind cluster

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

After installation of kind, next step is to create and configure a Kubernetes cluster.
Kind uses **Docker (prerequisite for kind)** as platform for running of the cluster nodes, as one kind cluster node actually is one running Docker container. The minimal setup of K8S cluster with kind is with only one control-plane node, which functions as worker node. In our case we have as requirement the mentioned above pod affinity, set at the Deployment level, which will manage the spreading of application pods across minimum of 3 (three) Kubernetes cluster nodes. So, we will need a kind configuration with at least 2 (two) worker nodes, additionally to the control-plane node, and this should be our minimal setup. A simple kind configuration file (`kind/kind-config.yaml)`, that can be used to create such cluster can be (that’s I have used in my local setup for the task):

```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  # Optional: port mapping of local system port 80 to a NodePort 30100, that eventually will be configured further as the Kubernetes service resource
  # extraPortMappings:
  # - containerPort: 30100
  #  hostPort: 80
  #  listenAddress: "0.0.0.0" # Optional, defaults to "0.0.0.0"
  #  protocol: tcp # Optional, defaults to tcp
- role: worker
  
- role: worker

```
   
The optional port mapping is not actually used in the solution, it’s just a kind of a prerequisite for eventual exposing (externally) of the application on K8S node level, with a NodePort service type.

Create the so configured kind cluster with:

```
kind create cluster --config kind/kind-config.yaml --name task

# To check for created nodes
kind get nodes -n task
```


- Install the chart for both dev and prod (installation of [Helm](https://helm.sh/docs/intro/install/) is prerequisite)
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


6. ## Kustomize setup

### Description of the concrete solution
[Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) is a configuration management tool for Kubernetes that allows customisation of Kubernetes manifests without modifying the original manifests. Kustomize provides a declarative approach to managing Kubernetes configurations, making it easy to manage complex configurations.
By its nature, Helm allows customisation of Kubernetes manifests through setting different than default values in values.yaml files, thereby doing every Helm chart release specific for a given environment or infrastructure. Kustomise can do the completely same thing through its mechanism of patching (“Kustomization”)  of YAML files. So, in this very simple usecase -  customisation through variables of a base set of YAML manifests for K8S resources - both tools are doing the same task.   
Still, Helm and Kustomize are complementary tools that can be used together to manage Kubernetes manifests. Helm can be used to manage the release cycle of the applications and Kustomize can be used to customise the Kubernetes manifests. Even more - there are several usecases that can only benefit of together use of these two tools, as otherwise the solutions can be a much more complex (below is cited from this [article](https://trstringer.com/helm-kustomize/)):

“
- You don’t have control over the Helm chart
One of the benefits of Helm is that it’s considered the “package manager of Kubernetes”. It’s quite common to pull and use a Helm chart somebody else published in a Helm repository. What if you want to modify something in the manifests, *(or even - to add new files, that are not defined in chart )*- ? Kustomize makes this simple.
- You don’t want your secrets in a Helm chart (but you might want them patched in by Kustomize)
When working with Secret and ConfigMap resources, you might not want them baked into your Helm charts (or set through values). Having Kustomize create the resources after Helm has inflated the charts is a better way to inject this sensitive data in the cluster.
- Cross-cutting fields
In certain instances, you may want to force all (or a subset of) resources to a namespace, or apply a label to these resources. Typically you wouldn’t want to have that in your Helm charts, but Kustomize can easily overlay this configuration on your resources.
“

The two main (mutually exclusive) ways to use them together are:
1) `helm template` generates the manifest and dumps it into a file, and then run `kubectl kustomize`. Similar to this is the way to use Kustomize field `helmCharts` (or the generator of such field - *HelmChartInflationGenerator*) to inflate the Helm chart manifests directly  through `kustomize build`. The downside is that **Helm doesn’t manage any release**.
2) `helm install` (or `helm upgrade --install`) and specifying a custom [post-renderer](https://helm.sh/docs/topics/advanced/#post-rendering) that runs `kubectl kustomize`. The benefit is that **Helm manages the release** and its full lifecycle.

Trying to be more comprehensive in my solution, I decided to present both options, although I personally think that the first option would not be suitable in a real case of a complex Kubernetes infrastructure, which is (almost) entirely based on using Helm charts for deployment (and in general this option may make the use of Kustomize meaningless).

**First variant 1)** is placed under both directories: `gitops/base/` and `gitops/overlays/`.  
Directory `gitops/base/` is dedicated for definitions of the resources or presenting of variable values, that are common for both environments. As described above, the Metrics Server is a service that is required for use of HPA(HorizontalPodAutoscaler) in a Kubernetes Deployment level, so it is a real candidate for a Kustomize Component, that would be necessary to be **reused** (not duplicated) in both the environments.   
Directory `gitops/overlays/` contains Kustomize-related code for the two environments (sub-dirs `dev/` and `prod/`) that are differentiated only by the Helm chart value “prod” (“true”/“false”).  In the subdirectory `common/` of every environment directory is the `kustomization.yaml` file for use of the components for deployment of metrics-server Helm chart (as common for the both envs) . And, in subdirectory `internal-service/` of every  environment directory are located: `namespace.yaml` for creation of environment-specific namespace that the web app pod and its hpa will be placed, as well as the `kustomization.yaml` that is inflating also the manifests of the locally-sourced `internal-service` Helm chart, and that are customised through the use of `patch-env.yaml` file in the *additionalValuesFiles* attribute of helmCharts field.
Implementation of the two environments in this variant 1) can be done by rendering through Kustomize (“kustomisation”) of the all Kubernetes resources definitions as YAML manifests, and applying them through kubectl apply, as this can be done in two steps: first - rendering and storing the manifests, and second - applying them (if this the actual goal of the task), or in one pass, containing  the both steps.

- Dev environment (being in `gitops/` dir):

```
kustomize build ./overlays/dev --enable-helm \ 
--load-restrictor LoadRestrictionsNone > overlays/dev/resources.yaml

kubectl apply -f overlays/dev/resources.yaml
```

In one pass, directly applying in cluster:

```
kustomize build ./overlays/dev --enable-helm \ 
--load-restrictor LoadRestrictionsNone | kubectl apply -f -
```

- Prod environment (being in `gitops/` dir):

```
kustomize build ./overlays/prod --enable-helm \ 
--load-restrictor LoadRestrictionsNone > overlays/prod/resources.yaml

kubectl apply -f overlays/prod/resources.yaml
```

```
kustomize build ./overlays/prod --enable-helm \ 
--load-restrictor LoadRestrictionsNone | kubectl apply -f -
```

**Second variant 2)** implements an example of use of Helm [post-renderer](https://gist.github.com/neoakris/edc0642a088be2cdc4f5ffe8d90ef5ca), running Kustomize,  in Helm release install/upgrade, in order to be able to track and maintain the whole deployed infrastructure in Helm. In my opinion, even if this solution seems advanced, it is more effective and justifies using both tools together. 
The solution is placed inside the `gitops/helm-post-renderer/` directory,. Every one of the environment-dedicated sub-directories (`dev/` and `prod/`) contains:
 
* `kustomize.sh` (the actual script, acting as post-renderer, which function is described in comments inside the script);
* `kustomiziation.yaml` (doing the “kustomization” of the generated through Helm YAML manifests and stored into a temporary file by the post-renderer script, which then executes `kustomize build`, making use of this file);
* `depl-patch`.yaml (contains only the patch of the generated Deployment resource with the specific PROD env. variable value)

Implementation:

**Dev** (as being in `gitops/helm-post-renderer/dev/` dir):

```
helm upgrade --install internal-service-dev -n dev \
-f ../../../chart/internal-service/values.yaml \
../../../chart/internal-service --set-string hub="kkrast" \
--create-namespace \
--post-renderer ./kustomize.sh
```

**Prod** (as being in `gitops/helm-post-renderer/prod/`):

```
helm upgrade --install internal-service-prod -n prod \
-f ../../../chart/internal-service/values.yaml \
../../../chart/internal-service --set-string hub="kkrast" \
--create-namespace \
--post-renderer ./kustomize.sh
```

Note: metrics-server Helm chart is not managed by this part of the solution, so it can be installed separately, through Helm, as described above.

Then, it can be seen that the Helm releases for both the dev and prod environments are manage-able through regular `helm` commands:

```
helm list -A
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
internal-service-dev    dev             1               2025-09-11 23:38:32.736999 +0300 EEST   deployed        internal-service-0.1.1  1.0        
internal-service-prod   prod            1               2025-09-11 23:42:41.72347 +0300 EEST    deployed        internal-service-0.1.1  1.0        
metrics-server          kube-system     1               2025-09-10 01:41:35.646951 +0300 EEST   deployed        metrics-server-3.13.0   0.8.0
```
. 

   





