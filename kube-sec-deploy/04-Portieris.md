# This section is optional

Portieris is a Kubernetes admission controller, open sourced by IBM. When you create a new workload in Kubernetes, Portieris modifies the image tag in your workload specification to refer to the most recent signed version of the image before the Kubernetes API Server distributes the workload to your cluster workers. Your cluster workers pull the signed version of the image instead of the most recently tagged version, even if they are different. When pods are re-scheduled by your cluster, the new workers also pull the same signed version, rather than the tagged version that may have changed in between creating the workload and re-scheduling the pod.

> Note: This section requires you to use an IBM Cloud account. You can use a free trial account to perform all the steps, but you'll need to create an account if you don't have one already. To create an IBM Cloud account, go to <https://cloud.ibm.com>.

## Setting up IBM Cloud Container Registry

1. Create a namespace.

    1. Open the IBM Cloud dashboard. <https://cloud.ibm.com>.
    1. Once you've logged in, click the menu button in the top-left corner, and then click `Kubernetes`.
    1. In the side bar, click `Registry`.
    1. Make sure that the `Location` field is set to `Dallas`.
    1. Click `Namespaces`.
    1. Click `Create namespace`.
    1. Enter a name for your namespace, and then click `Create`. Remember your namespace, because you'll use that later.
    1. Your namespace appears in the list.

1. Create an IAM API key and grant it access to IBM Cloud Container Registry. IBM Cloud IAM Service IDs allow you to create API keys for your applications and create policies to control their access.

    1. In the top bar of the IBM Cloud dashboard, click `Manage`, then `Access (IAM)`.
    1. In the side bar, click `Service IDs`.
    1. Click `Create`. Enter a name for your service ID, and then click `Create`. Your new service ID appears in the list.
    1. Click on your service ID. The configuration page for your service ID appears.
    1. Create an IAM policy to allow your service ID to access Container Registry.
        1. Click `Access policies`, and then `Assign access`.
        1. Click `Assign access to resources`.
        1. In the `Service` box, select `Container Registry`. You can start typing in the box to filter the list.

            > Tip: Once you select the service, more options appear that allow you to refine the access further. For simplicity, we'll leave these boxes empty to grant access to all images in your account.
        1. In the `Select roles` field, check the `Manager` box.
        1. Click `Assign`. The new `Manager` policy is shown in the list.
    1. Create an API key to allow you to log in to Container Registry.
        1. On the configuration page for your service ID, click on `API keys`.
        1. Click `Create`. Enter a name for your API key, and then click `Create`. A dialog appears containing your new API key.
        1. Use any of the options in the dialog to note down your API key. You'll need it later.

            > Tip: If you dismiss this dialog without taking note of your API key, you can't retrieve that API key later. You can create another API key and use that instead.

1. Create an Image Pull Secret with your API key. Replace `<your_api_key>` with your API key from the previous step.

    ```bash
    kubectl create secret docker-registry icr-us --docker-username=iamapikey --docker-password=<your_api_key> --docker-server=us.icr.io --docker-email=a@b.com
    ```

    Patch your image pull secret into the default service account, so that you don't need to specify it in your pod spec.

    ```bash
    kubectl patch serviceaccount default -p '{"imagePullSecrets":[{"name":"icr-us"}]}'
    ```{{execute}}

1. Log in to Container Registry. Replace `<your_api_key>` with your API key.

    ```bash
    docker login -u iamapikey -p <your_api_key> us.icr.io
    ```

1. Push your vulnerable image into Container Registry, without signing it. Replace `<your_namespace>` with the namespace that you created earlier.

    ```bash
    unset DOCKER_CONTENT_TRUST
    ```{{execute}}

    ```bash
    docker tag 127.0.0.1:30002/library/demo-api:vulnerable us.icr.io/<your_namespace>/demo-api:vulnerable
    ```

    ```bash
    docker push us.icr.io/<your_namespace>/demo-api:vulnerable
    ```

1. Enable content trust for Container Registry.

    ```bash
    export DOCKER_CONTENT_TRUST=1
    export DOCKER_CONTENT_TRUST_SERVER=https://us.icr.io:4443
    ```{{execute}}

1. Push your signed image into Container Registry. You will be prompted to create a new repository key.

    ```bash
    docker tag 127.0.0.1:30002/library/demo-api:signed us.icr.io/<your_namespace>/demo-api:signed
    ```

    ```bash
    docker push us.icr.io/<your_namespace>/demo-api:signed
    ```

## Setting up Portieris

1. Install Portieris.

    1. Deploy Portieris.

        ```bash
        kubectl apply -f portieris.yaml
        ```{{execute}}

    1. Wait for Portieris to start. This might take a couple of minutes.

        ```bash
        kubectl get pods --watch
        ```{{execute}}

        Wait for there to be at least one `portieris` pod running:

        ```bash
        NAME                         READY   STATUS    RESTARTS   AGE
        portieris-84f9cb7746-bxxqm   1/1     Running   0          18s
        ```

    1. Set up the Mutating Admission Webhook for Portieris. This tells Kubernetes to ask Portieris if a given resource is OK to deploy.

        ```bash
        kubectl apply -f webhook.yaml
        ```{{execute}}

    Portieris installs two custom Kubernetes resources for managing it: ImagePolicies and ClusterImagePolicies. If an ImagePolicy exists in the same Kubernetes namespace as your resources, Portieris uses that to decide what rules to enforce on your resources. Otherwise, Portieris uses the ClusterImagePolicy.

1. Out of the box, Portieris installs ImagePolicies into the `kube-system` and `ibm-system` namespaces, and a ClusterImagePolicy. Let's have a look at what's created.
    1. List your ClusterImagePolicies.

        ```bash
        kubectl get ClusterImagePolicies
        ```{{execute}}

        One ClusterImagePolicy is shown: `portieris-default-cluster-image-policy`.

    2. Edit the `portieris-default-cluster-image-policy` policy.

        ```bash
        kubectl edit ClusterImagePolicy portieris-default-cluster-image-policy
        ```{{execute}}

        Look at the `spec` section, and the `repositories` subsection inside it. One image is shown, with `name: "*"` and `policy: trust: enabled: true`. `*` is a wildcard character, so this policy matches any image.

        Change `enabled: true` to `enabled: false`.

        When the policy is not enabled, we don't apply any trust requirement. Essentially, Portieris doesn't do anything at this point. Let's prove that.

    3. Try to deploy your unsigned image to the cluster. Edit the image name in `demo-api.yaml` to your image in Container Registry, and then deploy it to your cluster.

        ```bash
        vi demo-api.yaml
        ```

        > Tip: Your unsigned image name in Container Registry looks like `us.icr.io/<your_namespace>/demo-api:vulnerable`. Replace `<your_namespace>` with your Container Registry namespace.

        ```bash
        kubectl apply -f demo-api.yaml
        ```{{execute}}

        Portieris doesn't do anything with the deployment, so it's allowed to be deployed.

    4. Let's enable trust enforcement for our image. Create a new element in the `repositories` list, after the `*`:

        ```bash
        kubectl edit ClusterImagePolicy portieris-default-cluster-image-policy
        ```{{execute}}

        ```yaml
        repositories:
            - name: "us.icr.io/*"
              policy:
                trust:
                  enabled: true
        ```

        Then save and close the file.

    5. Delete your deployment and then try to deploy your unsigned image again.

        ```bash
        kubectl delete deployment demo-api
        kubectl apply -f demo-api.yaml
        ```{{execute}}

        The deployment is rejected because it isn't signed.

        ```text
        admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request: Deny, failed to get content trust information: No valid trust data for vulnerable
        ```

        Because your new deployment was rejected, the deployment in the cluster stays the same.

    6. Portieris doesn't prevent pods from restarting, even if the pod no longer satisfies your policy. This prevents you from getting an outage if your pods crash but they don't match your policy.

        Delete the pods in your deployment, and then watch as they are re-created.

        ```bash
        kubectl delete pods -l app=demo-api
        kubectl get pods -l app=demo-api --watch
        ```{{execute}}

    7. Try to deploy your signed image. Change the image in demo-api.yaml to our signed image: `us.icr.io/<your_namespace>/demo-api:signed`

        ```bash
        vi demo-api.yaml
        ```

        Then deploy it:

        ```bash
        kubectl apply -f demo-api.yaml
        ```{{execute}}

        This deployment should now be allowed.

You have signed your image and configured Portieris to require image signatures. You have seen that when it enforces content trust, Portieris modifies the image name to the digest of the signed image.

## Using named signers with Portieris

Portieris can verify the signatures from named signers, and only allow the deployment of an image once it has a valid signature from each one.

1. Edit the ClusterImagePolicy to enforce your particular signer.

    1. Create a secret for the public key.

        ```bash
        kubectl create secret generic portierisdemo --from-literal=name=portierisdemo --from-file=publicKey=portierisdemo.pub
        ```{{execute}}

    2. Edit the ClusterImagePolicy to enforce it.

        ```bash
        kubectl edit clusterimagepolicy portieris-default-cluster-image-policy
        ```{{execute}}

        Add the signer secret as a required key for our demo-api repository:

        ```yaml
        repositories:
            - name: "us.icr.io/*"
            policy:
                trust:
                enabled: true
                signerSecrets:
                - name: portierisdemo
        ```

2. Try to deploy your signed image again. This time, the deployment is rejected. Your image is signed, but not by the `portierisdemo` signer.

    ```text
    admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request: Deny, no signature found for role portierisdemo
    ```

3. Sign the image using your `portierisdemo` key. Docker automatically signs images using all the keys that you have, so running the sign command again adds a signature for your newly created key.

    ```bash
    docker trust sign us.icr.io/<your_namespace>/demo-api:signed
    ```

4. Try to deploy your signed image once more. This time, the deployment is allowed.

You have created a signing key and configured Portieris to require images in your namespace to be signed using it. You can use the same signing key in multiple repositories to require a common root of trust.
