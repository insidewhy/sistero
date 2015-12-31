# Sistero

sistero is a profile based tool to manage a digital ocean cluster.

## Installation

```gem install sistero```

## Usage

Create a config file at `.config/sistero` with something like:

```
---
defaults:
  vm_name: my_default_vm_name
  ssh_keys:
    - 1234567
  ssh_options: -D1080 -A
  access_token: f788fffffffffffff8ffffffffffffffffffffff8fffffffffffffffffffffff
  vm_size: 512mb
  vm_region: nyc3
  vm_image: ubuntu-14-04-x64
london:
  vm_name: my_london_vm_name
  vm_region: lon1
```

The `ssh_keys` is a list of the ID numbers of your ssh keys.

Then to create a VM in new york:
```
sistero create
```

Or to create a VM configured the same only in London:
```
sistero -p london create
```
