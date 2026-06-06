# kubectl - gestione di Kubernetes
## Uso base
```
kubectl get nodes
kubectl get pods -A
kubectl describe pod NOME
kubectl get roles,rolebindings -A   # utile per audit RBAC
```
Per la sicurezza dei cluster: vedi anche kube-bench e kube-hunter (Docker).
