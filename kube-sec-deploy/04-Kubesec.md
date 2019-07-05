Kubesec identifies security risks in your Kubernetes configuration and quantifies them with risk scores.

## Install Kubesec

1. Clone <https://github.com/stefanprodan/kubesec-webhook>  
`git clone https://github.com/stefanprodan/kubesec-webhook`{{execute}}  
`cd kubesec-webhook`{{execute}}
1. Generate the certificates for the webhook, deploy it, and label the `default` namespace so the admission controllers knows to validate its pods:  
`make certs && make deploy`{{execute}}  
`kubectl label namespaces default kubesec-validation=enabled`{{execute}}  
This deploys a `kubesec-webhook` pod in the `kubesec` namespace, a webhook admission controller configuration for the API server, and the secrets for secure communication.
1. Examine the webhook admission controller that's just been deployed:  
`less deploy/webhook-registration.yaml`{{execute}}
1. Find the `namespaceSelector` that corresponds to the label applied to the `default` namespace above. This is the only link between the admission controller and a namespace.  
Notice a CA bundle is required. This is because pod manifests may contain secrets in environment variables, or sensitive information about itself or other services. To ensure that the Kubernetes API trusts the admission controller, the CA bundle of the HTTPS endpoint that the API server POSTs to must be declared to establish a trust relationship between them.  
The secrets that are mounted into the admission controller are in `webhook-certs.yaml`, and the actual pod that's deployed is in `webhook.yaml`.

## Block a Deployment

1. Try to deploy an insecure deployment:  
`kubectl apply -f ./test/deployment.yaml`{{execute}}  
We should receive:  
```bash
Error from server (InternalError): error when creating "./test/deployment.yaml": Internal error occurred: admission webhook "deployment.admission.kubesc.io" denied the request: deployment-test score is -30, deployment minimum accepted score is 0
```
1. The deployment is insecure. Let's check why. Create a Bash function to POST YAML to <https://kubesec.io.>  
```bash
kubesec() {
local FILE="${1:-}";
[[ ! -f "${FILE}" ]] && {
  echo "kubesec: ${FILE}: No such file" >&2;
  return 1
};
curl --silent \
--compressed \
--connect-timeout 5 \
-F file=@"${FILE}" \
https://kubesec.io/
}
kubesec ./test/deployment.yaml
```{{copy}}
> all sensitive configuration should live in `secrets` -  never leak configuration to a remote service.
1. The problem is `containers[] .securityContext .privileged == true` - running a privileged pod.  
Although this is dangerous, perhaps we have an "urgent business requirement" (:facepalm:). Let's edit the admission controller to allow an insecure deployment:  
`sed -i 's,-min-score=.*,-min-score=-100,' deploy/webhook.yaml`{{execute}}
`kubectl delete -f deploy/webhook.yaml`{{execute}}
`kubectl create -f deploy/webhook.yaml`{{execute}}
1. Now anything with a score above `-100` will be allowed into the cluster! This is a bad thing. Let's test it:  
`kubectl apply -f ./test/deployment.yaml`  
Our deployment has just been created despite failing the checks.
1. Now that we've deployed an insecure pod, let's change the admission controller risk threshold back to `0`.  
`sed -i 's,-min-score=.*,-min-score=0,' deploy/webhook.yaml`
`kubectl delete -f deploy/webhook.yaml`{{execute}}
`kubectl create -f deploy/webhook.yaml`{{execute}}
`kubectl get pods --selector=app=nginx`{{execute}}
Notice that the existing deployment is not affected - admission controllers are only called when an pod is "admitted" to the API server.
