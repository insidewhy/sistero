# Sistero

sistero is a profile based tool to manage a digital ocean cluster.

## Installation

```gem install sistero```

## Configuration

First sistero looks for a file called `sistero.yaml` in the current directory or a parent of the current directory. If it is not found the default configuration is loaded from `.config/sistero`. Here is an example:

```
defaults:
  name: default-vm
  ssh_keys:
    - 1234567
  ssh_options: -D1080 -A
  access_token: f788fffffffffffff8ffffffffffffffffffffff8fffffffffffffffffffffff
  size: 512mb
  region: nyc3
  image: ubuntu-14-04-x64
vms:
  -
    name: default-vm
  -
    name: london-vm
    region: lon1
  -
    name: london-bigger-vm
    region: lon1
    size: 1gb
```

Any values not specified in a profile are taken from `defaults`. If the `defaults` entry specifies a `name` then it becomes the default VM for the `create`, `ssh` and `destroy` commands but is not inherited by vm configuration items.

The `ssh_keys` is a list of ID numbers (rather than names) of ssh keys, these can be found by running `sistero ssh-keys`.

The valid options for `region`, `size` and `image` can be found by running `sistero regions`, `sistero sizes` and `sistero images` respectively.

## Running

Assuming the previous config file, to create a VM in new york called default-vm:
```
sistero create
```

Or to create a VM called `london-vm` in london:
```
sistero create london-vm
```

The command `sistero create-all` can be used to create all VMs listed in the configuration file.

## More advanced configurations

This config that shows how to create a CoreOS cluster:

```
defaults:
  ssh_user: core
  ssh_keys:
    - 1234567
    - 1234568
  ssh_options: -D1080 -A
  access_token:
    file: ./secrets/digital-ocean.access-token
  region: lon1
  image: coreos-stable
  name: vm1
  private_networking: true
  user_data: |
    #cloud-config
    coreos:
      etcd2:
        # y$@" :r !curl -s -w "\n" "https://discovery.etcd.io/new?size=2"
        discovery: https://discovery.etcd.io/af66d811fc9b5b9b0989009f849cc37a
        # use $public_ipv4 for multi-cloud/region:
        advertise-client-urls: http://$private_ipv4:2379
        initial-advertise-peer-urls: http://$private_ipv4:2380
        listen-client-urls: http://0.0.0.0:2379
        listen-peer-urls: http://$private_ipv4:2380
      fleet:
        public-ip: $private_ipv4   # used for fleetctl ssh command
        metadata: "size=#{size},name=#{name}"
      units:
        - name: etcd2.service
          command: start
        - name: fleet.service
          command: start
vms:
  -
    name: vm1
    size: 1gb
  -
    name: vm2
    size: 512mb
  -
    name: vm3
    size: 512mb
```

This demonstrates a few more things:

1. The config can be split over multiple files using `file:`, in this config file the digital ocean access token is specified in a different file.
2. In `user_data` vm configuration variables can be substituted, see `#{size}` and `#{name}` in the metadata.
