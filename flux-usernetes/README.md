# Flux Tofu Usernetes

Terraform module to create Amazon Machine Images (AMI) for Flux Framework HashiCorp Packer and AWS CodeBuild.
We are mirroring functionality from [GoogleCloudPlatform/scientific-computing-examples](https://github.com/GoogleCloudPlatform/scientific-computing-examples/tree/openmpi/fluxfw-gcp). Thank you Google, we love you!

## Usage

### Build Images

Note that we previously built with packer. That no longer seems to work ([maybe this issue](https://github.com/hashicorp/packer/issues/8180))
Instead we are going to run the commands there manually and save the AMI. The previous instruction was to export AWS credentials, cd into build-images,
and `make`. For the manual build, you'll need to create an m5.large instance in the web UI, ubuntu 22.04, and manually run the contents of each
of [build-images/shared/install-flux.sh](build-images/shared/install-flux.sh) and [build-images/node/startup-script.sh](build-images/node/startup-script.sh). This generated:


- flux-ubuntu-usernetes: `ami-08c12e6130ca21962`


### Deploy with Terraform

Once you have images, choose a directory under [examples](examples) to deploy from:

```bash
$ cd examples/autoscale
```

And then init and build:

```bash
$ make init
$ make fmt
$ make validate
$ make build
```

And they all can be run with `make`:

```bash
$ make
```

You can then shell into any node, and check the status of Flux. I usually grab the instance
name via "Connect" in the portal, but you could likely use the AWS client for this too.

```bash
$ ssh -o 'IdentitiesOnly yes' -i "mykey.pem" ubuntu@ec2-xx-xxx-xx-xxx.compute-1.amazonaws.com
```

#### Check Flux

Check the cluster status, the overlay status, and try running a job:

```bash
$ flux resource list
     STATE NNODES   NCORES NODELIST
      free      2        2 i-012fe4a110e14da1b,i-0354d878a3fd6b017
 allocated      0        0 
      down      0        0 
```
```bash
$ flux run -N 2 hostname
i-012fe4a110e14da1b.ec2.internal
i-0354d878a3fd6b017.ec2.internal
```

You can look at the startup script logs like this if you need to debug.

```bash
$ cat /var/log/cloud-init-output.log
```

That's it. Enjoy!

#### Start Usernetes

This is currently manual, and we need a better approach to automate it.

##### Control Plane

Let's first bring up the control plane, and we will copy the `join-command` to each node.
In the index 0 broker (the first in the broker.toml that you shelled into):

```bash
cd ~/usernetes
./start-control-plane.sh
```

Then with flux running, send to the other nodes.

```bash
flux filemap map -C /home/ubuntu/usernetes join-command
flux exec -x 0 -r all flux filemap get -C /home/ubuntu/usernetes
```

##### Worker Nodes

```bash
cd ~/usernetes
./start-worker.sh
```

Check (from the first node) that usernetes is running:

```
kubectl get pods
```

## License

HPCIC DevTools is distributed under the terms of the MIT license.
All new contributions must be made under this license.

See [LICENSE](https://github.com/converged-computing/cloud-select/blob/main/LICENSE),
[COPYRIGHT](https://github.com/converged-computing/cloud-select/blob/main/COPYRIGHT), and
[NOTICE](https://github.com/converged-computing/cloud-select/blob/main/NOTICE) for details.

SPDX-License-Identifier: (MIT)

LLNL-CODE- 842614
