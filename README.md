# Installing Jenkins-X on IBM Cloud

This tutorial describes how to install Jenkins-X on an existing IKS cluster and deploy applications using the IBM Cloud registry.

## Pre-Requisites

This tutorial was tested with the following versions:

| Package Name     | Version           |
| ------------- |:-------------|
| jx                                    | v2.0.1249 |
| IKS cluster                    | v1.15.11+IKS      |
| kubectl                               | v1.14.3 & v1.16.3 |
| git                                   | v2.20.1 (Apple Git-117) |
| OS                                    | Mac OS X 10.14.6 build 18G3020   |
| IBM Cloud CLI                         | v0.22.1   |
| IBM Cloud plugins container-registry  | v0.1.454  |
| IBM Cloud plugins kubernetes-service  | v1.0.15   |
| Helm Client & Server                  | v2.12.3   |

Download the package from here:
* **IKS cluster**, can be provisioned [here](https://cloud.ibm.com/kubernetes/clusters)
* **[IBM Cloud CLI](https://cloud.ibm.com/docs/cli/reference/ibmcloud/download_cli.html#install_use)** installed on your machine
* **[kubectl CLI](https://kubernetes.io/fr/docs/tasks/tools/install-kubectl)** installed on your machine
* **[Helm CLI](https://github.com/helm/helm)** installed on your machine and on the cluster
* **[jx CLI](https://jenkins-x.io/docs/getting-started/setup/install/)** installed on your machine

Supported versions for jx: https://github.com/jenkins-x/jenkins-x-versions/tree/master/packages


## Set up the Jenkins-X requirements with your cluster info

1. Connect to your IKS cluster
    ```sh
    ibmcloud ks cluster config --cluster <iks-cluster-name>
    ```

1. Verify that you're connected to your cluster
    ```sh
    kubectl config current-context
    ```
    Output:
    ```
    jx-15/bpt0sbsf0jcnu0julbdg
    ```
    
1. Retrieve and copy the Ingress Subdomain of your cluster
    ```sh
    ibmcloud ks cluster get --cluster <iks-cluster-name> --json | jq ".ingressHostname" | tr -d '":,'
    ```
    Output:
    ```
    jx-15-44f776XXXXXXXXXXXXXXXXXbd46cec-0000.eu-de.containers.appdomain.cloud
    ```

1. Have on hand your `GitHub account` (displayed in the "Your profile" page) or your GitHub Organisation name (`username` below)

1. Download locally the file [jx-requirements-iks-template.yml](https://github.com/lionelmace/jenkins-x-iks/blob/master/jx-requirements-iks-template.yml)

1. Edit the file and replace the values <...> such as the cluster name, the github user name, the ingress subdomain with your own value. Change also the registry if you need
    ```yml
    cluster:
      clusterName: <iks-cluster-name>
      devEnvApprovers:
      - <username>
      provider: kubernetes
      environmentGitOwner: <username>
      environmentGitPublic: true
      registry: de.icr.io
    environments:
    - ingress:
        domain: <iks-cluster-ingress-subdomain>
      key: dev
    - ingress:
        domain: <iks-cluster-ingress-subdomain>
      key: staging
    - ingress:
        domain: <iks-cluster-ingress-subdomain>
      key: production
    ingress:
      domain: <iks-cluster-ingress-subdomain>
    secretStorage: local
    ```

## Configure Helm for new cluster

Helm Tiller with a service account must be configured for new cluster. See this [issue](https://github.com/helm/helm/issues/5100)

1. Install tiller on the cluster
    ```
    helm init
    ```

1. Configure Service Account and Cluster Role Binding by running the following 3 commands:
    ```
    kubectl create serviceaccount -n kube-system tiller
    ```
    ```
    kubectl create clusterrolebinding tiller-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    ```
    ```
    kubectl --namespace kube-system patch deploy tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}
    ```

## Installing Jenkins-X with `jx boot`

1. Run the `jx boot` command with the requirements file which will overwrite the default requirements file
    ```sh
    jx boot --requirements=./jx-requirements-iks-template.yml
    ```

1. Jenkins-X works on IKS so just validate when being asked 
    ```
    When being asked jx boot has only been validated on GKE and EKS, we'd love feedback and contributions for other Kubernetes providers```

1. Answer some remaining questions, e.g. Git/GitHub user.
    ```
    ? Jenkins X Admin Username *****
    ? Jenkins X Admin Password [? for help] *****
    ? Pipeline bot Git username *****
    ? Pipeline bot Git email address *****
    ? Pipeline bot Git token [? for help] ****************************************
    Generated token XXXXXXXXXXXXXXX, to use it press enter.
    This is the only time you will be shown it so remember to save it
    ? HMAC token, used to validate incoming webhooks. Press enter to use the generated token [? for help]
    Do you want to configure an external Docker Registry? No
    ```
    
    > Make sure to answer **No** to the question **Do you want to configure an external Docker Registry?**

1. Once the installation is complete, you should see a message similar to this:

    ```
    Installation is currently looking: GOOD
    Using namespace 'jx' from context named 'jxcluster/boumltjf0rljb7kbmbu0' on server 'https://c2.eu-de.containers.cloud.ibm.com:25118'.
    ```

## Using the IBM Cloud Container Registry (after Jenkins-X has installed)

1. Create a namespace in the IBM Cloud Container Registry Service that matches your GitHub organization name or your GitHub username. If the names do not match, then Jenkins-X cannot use the Container Registry.
    ```
    ibmcloud cr namespace-add <your-github-org>
    ```
    
1. Create an API key which will be used to authorize Jenkins-X to push to the IBM Container Registry. (For production environments, create a Service ID API Key with Container Registry write permissions)
    ```
    ibmcloud iam api-key-create <key-name> -d "Jenkins X API Key" --file <filename>
    ```

1. Go into the `jx` namespace created during the installation
    ```
    jx ns jx
    ```
    
1. Use `jx create docker auth command` to update the registry authorization with your own API key
    ```
    jx create docker auth --host "de.icr.io" --user "iamapikey" --secret "<YOURAPIKEY>" --email "a@b.c"
    ```

1. Create the following 3 kubernetes namespaces
    ```
    kubectl create namespace jx-dev
    kubectl create namespace jx-staging
    kubectl create namespace jx-production
    ```

1. Copy and rename the default secret to any environment namespaces that you are using with jx (here: dev, staging, production). These steps update the secret for the jx-dev, jx-staging and jx-production namespaces.
    ```sh
    kubectl get secret default-de-icr-io -o yaml -n default | sed 's/default/jx-dev/g' | kubectl -n jx-dev create -f -
    kubectl get secret default-de-icr-io -o yaml -n default | sed 's/default/jx-staging/g' | kubectl -n jx-staging create -f -
    kubectl get secret default-de-icr-io -o yaml -n default | sed 's/default/jx-production/g' | kubectl -n jx-production create -f -
    ```

1. Patch the ServiceAccounts to use the pull secrets in the new namespaces

    ```
    kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "jx-dev-de-icr-io"}]}' -n jx-dev
    kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "jx-staging-de-icr-io"}]}' -n jx-staging
    kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "jx-production-de-icr-io"}]}' -n jx-production
    ```

## Test the project

1. Start a first project
    ```
    jx create quickstart
    ```
    Select node-http

1. Enter the project your created.
    ```
    jx get applications
    ```
    Output:
    APPLICATION STAGING PODS URL
    jx15-qs-1   0.0.5   1/1  http://jx15-qs-1-jx-staging.jx-15-44f776889ff639c7e053e4520bd46cec-0000.eu-de.containers.appdomain.cloud

1. Open the app running in IKS 

    ![](./images/jks-iks-app-2.png)
