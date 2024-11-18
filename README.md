# Hashicat Compute
The compute portion for a demo featuring the Hashicat app. A VM that will run an Apache2 server with the Hashicat app.

## Inputs:
- `prefix`: a memorable prefix to be included in the name of most resources. E.g. 'ricardo'
- `resource_group_name`: resource group created in the `networking` module.
- `vm_subnet_id`: subnet id for the VM, created in the `networking` module.
- `security_group_id`: id of the SG to allow SSH access. 

## Outputs:
- `vm_ips`: private IP addresses of the VMs created to configure the backend in the `app-gateway` module.

## Resources created:
- Public IP for the provisioner to connect through SSH.
- Network interface for the VM
- VM: Ubuntu machine.
- (Null resource for the provisioner)