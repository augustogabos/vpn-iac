# VPN BETWEEN GCP AND AZURE
This code was mainly for study porpuses, the challenge was to create VPN between GCP and Azure clouds.
The goal of challenge was to create GCP side of VPN with Terraform, and Azure side with Bicep.
I include the Azure DevOps step to pass GCP gateway IP to be use in tunnel to automate the task to passing this value as variable.

The code also include the creation of VMs to make ping tests.
Points to consider and evolve, this project wasn't configured varibles groups with key vault.