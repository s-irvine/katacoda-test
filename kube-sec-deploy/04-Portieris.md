# This section is optional

Portieris is a Kubernetes admission controller, open sourced by IBM. When you create a new workload in Kubernetes, Portieris modifies the image tag in your workload specification to refer to the most recent signed version of the image before the Kubernetes API Server distributes the workload to your cluster workers. Your cluster workers pull the signed version of the image instead of the most recently tagged version, even if they are different. When pods are re-scheduled by your cluster, the new workers also pull the same signed version, rather than the tagged version that may have changed in between creating the workload and re-scheduling the pod.

> Note: This section requires you to use an IBM Cloud account. You can use a free trial account to perform all the steps, but you'll need to create an account if you don't have one already. To create an IBM Cloud account, go to <https://cloud.ibm.com>.

## Setting up IBM Cloud Container Registry

TODO

* Create a namespace
* Reconfigure Notary
* Push demo-api
* Create IAM API Key
* Create ImagePullSecret using the API key

TODO below use icr.io image names

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

    3. Try to deploy an unsigned image to the cluster. We've created a deployment definition for you.

        ```bash
        kubectl apply -f demo-api.yaml
        ```{{execute}}

        Portieris doesn't do anything with the deployment, so it's allowed to be deployed.

    4. Let's enable trust enforcement for our image. Create a new element in the `repositories` list, after the `*`:

        ```yaml
        repositories:
            - name: "127.0.0.1:30002/library/*demo-api"
              policy:
                trust:
                  enabled: true
                  trustServer: "https://127.0.0.1:30004"
        ```

        Then save and close the file.

    5. Delete your deployment and then try to deploy your unsigned image again.

        ```bash
        kubectl delete deployment demo-api
        kubectl apply -f demo-api.yaml
        ```{{execute}}

        The deployment is rejected because it isn't signed.

        ```text
        admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request: Deny, failed to get content trust information: No valid trust data for secure
        ```

    6. Portieris doesn't prevent pods from restarting, even if the pod no longer satisfies your policy. This prevents you from getting an outage if your pods crash but they don't match your policy.

        Delete the pods in your deployment, and then watch as they are re-created.

        ```bash
        kubectl delete pods -l app=demo-api
        kubectl get pods -l app=demo-api --watch
        ```{{execute}}

    7. Try to deploy your signed image. Change the image in demo-api.yaml to our signed image: `127.0.0.1:30002/library/signed-demo-api`

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
            - name: "127.0.0.1:30002/library/*demo-api"
            policy:
                trust:
                enabled: true
                trustServer: "https://127.0.0.1:30004"
                signerSecrets:
                - name: portierisdemo
        ```

2. Try to deploy your signed image again. This time, the deployment is rejected. Your image is signed, but not by the `portierisdemo` signer.

    ```text
    admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request: Deny, no signature found for role portierisdemo
    ```

3. Sign the image using your `portierisdemo` key. Docker automatically signs images using all the keys that you have, so running the sign command again adds a signature for your newly created key.

    ```bash
    docker trust sign 127.0.0.1:30002/library/signed-demo-api:latest
    ```{{execute}}

4. Try to deploy your signed image once more. This time, the deployment is allowed.

You have created a signing key and configured Portieris to require images in your namespace to be signed using it. You can use the same signing key in multiple repositories to require a common root of trust.
