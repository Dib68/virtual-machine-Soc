# Trivy - scanner di vulnerabilita' (container, IaC, filesystem, segreti)
## Uso base
```
trivy image nginx:latest          # vulnerabilita' in un'immagine Docker
trivy fs .                         # scansiona il filesystem/progetto
trivy config .                     # misconfig in Terraform/K8s/Dockerfile
trivy repo URL_GIT                 # scansiona un repository
```
Uno dei tool DevSecOps piu' richiesti.
