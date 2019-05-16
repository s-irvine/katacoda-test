Harbor is a CNCF project that combines the Docker Registry, Notary and Clair. This gives you image hosting, signing and scanning out of the box. We won't focus on Harbor too much as we have limited time but you can find out more [here](https://github.com/goharbor/harbor/blob/master/README.md).

It's likely you may be using a hosted registry service that already supports vulnerability scanning and image signing that builds on top of the same open source software and therefore provides the same functionality. For example, IBM Cloud Container Registry and Azure Container Registry both provide Notary as a service as part of their Container Registry as a service offerings. To keep it local and consistent however, we will be using Harbor to provide this functionality.

## Install Harbor

We've provided you with the YAML for Kubernetes to install Harbor.

(Optional) Feel free to `cat harbor.yaml`{{execute}} and have a look at the deployments and components of harbor. (Optional)

This YAML was generated with the help of the [harbor-helm](https://github.com/goharbor/harbor-helm/tree/1.0.0) project.

1. Apply the YAML to the cluster and wait for the pods to become ready (don't worry if there a couple restarts, the deployment will stabilise):
`kubectl apply -f harbor.yaml`{{execute}}
1. Run `kubectl get pods -w` and wait until all the pods show "Running".
1. Once all of the pods are ready, click the 'Harbor' tab at the top of your terminal. This will open a new browser tab/window with the dashboard of your harbor deployment. Login to the dashboard with the following credentials:

    ```creds
    user: admin
    password: kubecon1234
    ```

Harbor is now installed! Feel free to take a moment to have a look around the UI, and then return to the homepage for the next step.
