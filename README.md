# Installing Jenkins-X on IBM Cloud

## Pre-Requisites

* a **IKS cluster** v1.15.X, can be provisioned [here](https://cloud.ibm.com/kubernetes/clusters)
* the **[IBM Cloud CLI](https://cloud.ibm.com/docs/cli/reference/ibmcloud/download_cli.html#install_use)** installed on your machine
* **[Helm CLI](https://github.com/helm/helm)** installed on your machine and on the cluster
* tiller service account for Helm, [see here](https://github.com/helm/helm/issues/5100)
* the **[jx CLI](https://jenkins-x.io/docs/getting-started/setup/install/)** installed on your machine

## Pre installation steps

1. Connect to your IKS cluster (here: jx-15)
    ```sh
    $ ic ks cluster config --cluster jx-15
    ```

1. Verify that you're connected to your cluster
    ```sh
    $ kubectl config current-context
    jx-15/bpt0sbsf0jcnu0julbdg
    ```
    
1. Retreive information about the Ingress Subdomain of your cluster (`iks-cluster-ingress-subdomain` below)
      ```sh
      $ ibmcloud ks cluster get --cluster jx-15 --json | grep ingressHostname | tr -d '":,' | awk '{print $2}'
      jx-15-44f776XXXXXXXXXXXXXXXXXbd46cec-0000.eu-de.containers.appdomain.cloud
      ```
1. Have on hand your GitHub account, displayed in the "Your profile" page (`username` below)

1. Download locally the file [jx-requirements-iks-template.yml](https://github.com/lionelmace/jenkins-x-iks/blob/master/jx-requirements-iks-template.yml)

1. Edit the file and replace the values <> such as the cluster name, the github user name, the ingress subdomain with your own value. Change also the registry if you need
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
    ```

## Jenkins-X Boot

1. Run the `jx boot` command with the requirements file which will overwrite the default requirements file
    ```sh
    jx boot --requirements=./jx-requirements-iks-template.yml
    ```

1. Jenkins-X works on IKS so just validate when being asked 
    ```When being asked jx boot has only been validated on GKE and EKS, we'd love feedback and contributions for other Kubernetes providers```

1. Answer some remaining questions, e.g., for your Git/GitHub user.
    ```

1. Once the installation is complete, you should see a message similar to this:

    ```
    Installation is currently looking: GOOD
    Using namespace 'jx' from context named 'jxcluster/boumltjf0rljb7kbmbu0' on server 'https://c2.eu-de.containers.cloud.ibm.com:25118'.
    ```

## Activate the IBM Cloud Container Registry

1. Create a namespace in the IBM Cloud Container Registry Service that matches your GitHub organization name. If the names do not match, then Jenkins-X cannot use the Container Registry.
    
    ```
    ibmcloud cr namespace-add <your-github-org>
    ```

1. While Jenkins-X is installing, create an API key to authorize Jenkins-X to push to the Container Registry. For production environments, create a Service ID API Key with Container Registry write permissions.

    ```
    ibmcloud iam api-key-create <key-name> -d "Jenkins X API Key" --file <filename>
    ```

1. After Jenkins-X has installed, use jx create docker auth command to update the registry authorization.

    ```
    jx create docker auth --host "de.icr.io" --user "iamapikey" --secret "<IAMAPIKEY>" --email "a@b.c"
    ```

1. Copy and rename the default secret to any environment namespaces that you are using. These steps update the secret for the jx-staging and jx-production namespaces.

    OK
    ```sh
    kubectl get secret default-de-icr-io -o yaml -n default | sed 's/default/jx-staging/g' | kubectl -n jx-staging create -f -
    ```
    Output:
    secret/jx-staging-de-icr-io created

    NOK
    ```sh
    kubectl get secret default-de-icr-io -o yaml -n default | sed 's/default/jx-production/g' | kubectl -n jx-production create -f -
    ```
    Output:
    Error from server (NotFound): error when creating "STDIN": namespaces "jx-production" not found

1. Patch the ServiceAccounts to use the pull secret in the new namespaces

    ```
    kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "jx-staging-de-icr-io"}]}' -n jx-staging
    ```
    Output:
    serviceaccount/default patched

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

    APPLICATION      STAGING PODS URL
    myfirstjxproject 0.0.1   1/1  http://myfirstjxproject-jx-staging.jxcluster-483cccd2f0d38128dd40d2b711142ba9-0000.eu-de.containers.appdomain.cloud

1. Open the app running in IKS 

    ![](./images/jx-iks-app.png)
