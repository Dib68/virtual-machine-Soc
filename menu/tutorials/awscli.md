# AWS CLI - linea di comando per Amazon Web Services
## Configurazione
```
aws configure                     # inserisci Access Key, Secret, regione
```
## Esempi utili per la sicurezza
```
aws sts get-caller-identity       # chi sono?
aws iam list-users
aws s3 ls                          # bucket S3
aws ec2 describe-instances
```
Combina con ScoutSuite/Prowler per l'audit di sicurezza dell'account.
