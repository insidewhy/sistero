# Sistero

sistero is a profile based tool to manage a digital ocean cluster.

## Installation

```gem install sistero```

## Configuration

The configuration file lives at `.config/sistero`, an example looks like this:

```
defaults:
  vm_name: default-vm
  ssh_keys:
    - 1234567
  ssh_options: -D1080 -A
  access_token: f788fffffffffffff8ffffffffffffffffffffff8fffffffffffffffffffffff
  vm_size: 512mb
  vm_region: nyc3
  vm_image: ubuntu-14-04-x64
profiles:
  -
    vm_name: london-vm
    vm_region: lon1
  -
    vm_name: london-bigger-vm
    vm_region: lon1
    vm_size: 1gb
```

Any values not specified in a profile are taken from `defaults`. If the `defaults` entry specifies a `vm_name` then it becomes the default VM for the `create`, `ssh` and `destroy` commands.

The `ssh_keys` is a list of ID numbers (rather than names) of ssh keys, these can be found by running `sistero ssh-keys`.

The valid options for `region`, `vm_size` and `vm_image` can be found by running `sistero regions`, `sistero sizes` and `sistero images` respectively.

## Running

Assuming the previous config file, to create a VM in new york called default-vm:
```
sistero create
```

Or to create a VM called `london-vm` in london:
```
sistero create london-vm
```
