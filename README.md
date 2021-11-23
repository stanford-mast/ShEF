# ShEF
ShEF is a end-to-end framework to enable a secure Trusted Execution Environment (TEE) for cloud-based reconfigurable accelerators.
ShEF runs on current cloud FPGAs, such as AWS F1 instances, without reliance on CPU TEEs.

For more information about ShEF, please refer to our ASPLOS'22 paper.
- Mark Zhao, Mingyu Gao, and Christos Kozyrakis. *ShEF: Shielded Enclaves for Cloud FPGAs*. In Proceedings of the Twenty-Seventh International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS), 2022.

# Getting Started
ShEF consists of two main components: a Secure Boot and Remote Attestation process and a Shield module.

The Secure Boot and Remote Attestation process requires physical access and permanent key programming on an FPGA.
Because this process is performed by the FPGA Manufacturer and Cloud Provider as specified by the ShEF workflow, Secure Boot and Remote Attestation is not currently available on cloud FPGAs.

The ShEF Shield assumes successful attestation and provides isolated execution, and can thus be implemented on current AWS F1 instances.
The remainder of this document details setting up and running the ShEF Shield on an AWS F1 instance.
For details on implementing the Secure Boot and Remote Attestation process on a dedicated FPGA, please see [Secure Boot and Remote Attestation Setup](ATTESTATION_SETUP).

## ShEF Shield Setup
The ShEF Shield runs on AWS F1 instances. 
For further information on setting up AWS F1 instances, please refer to the [F1 Development Kit](https://github.com/aws/aws-fpga).

### AWS Setup
There are a few one-time steps required to setup the necessary AWS infrastructure to run on F1 instances.
1. Create an [AWS Account](https://aws.amazon.com/) if you do not already have one.
    1. Ensure that your user and IAM role has policies for *AmazonEC2FullAccess* and *AmazonS3FullAccess*.
    2. Also enable IAM permissions for *CreateFpgaImage* and *DescribeFpgaImages* for EC2.
    2. Be sure to save your *AWS Access Key ID* and *AWS Secret Access Key* for future use.
2. Generate an EC2 Key Pair.
    1. Using the [AWS Management Console](https://console.aws.amazon.com/), navigate to the EC2 page and select *Key Pairs* from the *NETWORK & SECURITY* menu.
    2. Create a Key Pair, which will automatically download a .pem file to your local machine.
    3. Move the key file to your `~/.ssh/` folder.
3. Create an S3 Bucket
    1. Return to the [AWS Management Console](https://console.aws.amazon.com/) and navigate to the S3 page.
    2. Create a new S3 bucket, and provide a unique name.
    3. Place your bucket in a region that you will launch F1 instances in - US East, US West, or EU.
    4. Create two directories in the S3 bucket, one that will be used for logs, and one for design checkpoints.
4. Request access to EC2 F1 Instances. 
    1. Open the [Service Limit Increase](http://aws.amazon.com/contact-us/ec2-request) form.
    2. Create a Service Limit Increase for EC2 Instances, and select a `f1.2xlarge` instance as the primary instance type.
    3. Select the region where you created your bucket above.
    4. Set the 'New Limit Value' to 1 or more.
    5. Fill out the remainder of the form and submit. Requests should be processed within 1-2 days.


### Developer Instance Setup
1. Create a developer instance using the [AWS FPGA Development AMI](\url{https://aws.amazon.com/marketplace/pp/prodview-gimv3gqbpe57k?ref=cns_1clkPro}).
    1. We use version 1.8.1 of this AMI on a z1d.2xlarnge instance, although our workflow should be compatible with future AMI versions and comparable EC2 instances.
2. SSH into the development instance using the key you generated above.
    1. On your local host `ssh -i ~/.ssh/<your-key.pem> centos@<instance address>`.
3. Setup necessary enviroment variables.
    1. In your `.bashrc`, add the following lines.
    ```
    export AWS_FPGA_REPO_DIR=/home/centos/src/project_data/aws-fpga
    export LC_ALL="C"
    export LD_LIBRARY_PATH="$LD_LIBARY_PATH:/usr/local/lib"
    export SHEF_DIR=/home/centos/src/project_data/shef
    ```
    2. `source ~/.bashrc`
3. Clone this project.
    ```
    git clone https://github.com/stanford-mast/ShEF.git $SHEF_DIR
    ```
4. Clone the AWS F1 Development Kit.
    ```
    git clone https://github.com/aws/aws-fpga.git $AWS_FPGA_REPO_DIR
    cd $AWS_FPGA_REPO_DIR
    git checkout tags/v1.4.14
    ```
    - In certain applications, a compilation error may arise when using the SDK Runtime. To fix this, we need to patch two files.
        - In `$AWS_FPGA_REPO_DIR/sdk/userspace/fpga_libs/fpga_dma/fpga_dma_utils.c`, remove `static` from Line 91.
        - In `$AWS_FPGA_REPO_DIR/sdk/userspace/include/fpga_dma.h`, remove `static` from Line 73.
5. Configure your AWS credentials
    ```
        $ aws configure # to set your credentials (found in your console.aws.amazon.com page) and instance region (us-east-1, us-west-2, eu-west-1 or us-gov-west-1)
    ```

### Runtime Instance Setup
We use a separate F1 instance to run the actual accelerator bitstream, as F1 instances are more expensive to develop on.
Repeat the same steps from [Developer Instance Setup](#developer-instance-setup), except use a `f1.2xlarge` instance.


# Using ShEF
ShEF's project structure is organized as follows.
- `apps/`: Benchmark applications built using the Hardware Development Kit (pure RTL).
- `hdk/`: Source code for the ShEF Shield.

## Example Workflow using DNNWeaver
Next, we walk through how to build and run an accelerator using DNNWeaver, with Shield enabled, as an example.
Detailed instructions for building a bitstream can be found at https://github.com/aws/aws-fpga/tree/master/hdk#simcl.

### Building the Custom Logic
The Hardware Development Kit reliees on a `CL_DIR` enviroment variable to be set to the appropriate root directory for the application.
For the DNNWeaver (with Shield), this can be found at `$SHEF_DIR/apps/dnnweaver_shield`.

```
cd $SHEF_DIR/apps/dnnweaver_shield
export CL_DIR=$(pwd)
```

Next, we need to setup the HDK build environment.
```
source $AWS_FPGA_REPO_DIR/hdk_setup.sh
```

To build the accelerator bitstream, simply run the following.
```
./aws_build_dcp_from_cl.sh -foreground
```
Note that this process will take multiple hours. Either run in a persistent session (e.g. `tmux`) or omit `foreground` to use a `nohup` context so that terminated SSH sessions do not terminate the build.

### Submit the DCP to AWS
The build script aboe will generate a design checkpoint `.dcp` file. However, this is not the final bitstream.
You must submit the DCP file to AWS, who will in turn build the final bitstream.

First, upload the DCP tarball to the S3 bucket you created earlier.
```
$ aws s3 cp $CL_DIR/build/checkpoints/to_aws/*.Developer_CL.tar \       # Upload the file to S3
             s3://<bucket-name>/<dcp-folder-name>/
```

Then, use the AWS CLI to create the final bitstream (AFI).
```
$ aws ec2 create-fpga-image \
    --region <region> \
    --name <afi-name> \
    --description <afi-description> \
    --input-storage-location Bucket=<dcp-bucket-name>,Key=<path-to-tarball> \
    --logs-storage-location Bucket=<logs-bucket-name>,Key=<path-to-logs> \
[ --client-token <value> ] \
[ --dry-run | --no-dry-run ]

NOTE: <path-to-tarball> is <dcp-folder-name>/<tar-file-name>
      <path-to-logs> is <logs-folder-name>
```

The command outputs two identifiers to your AFI, an *AFI ID* and an *AGFI ID*. Save both.

You can check the status of your AFI by running 
```
$ aws ec2 describe-fpga-images --fpga-image-ids <your-afi-id>
```

Once the above command has the state set to `available`, your AFI is ready to run. 
This process typically takes under an hour.

### Run your AFI
Finally, you are ready to load and run your accelerator.
SSH into your F1 runtime instance.

First, setup the necessary runtime enviroment.
```
$ sudo su
$ cd $AWS_FPGA_REPO_DIR
$ source sdk_setup.sh
```

Next, make sure that you clear the FPGA, and then load your AFI instance into the FPGA.
```
$ fpga-clear-local-image  -S 0
$ fpga-load-local-image -S 0 -I <your-agfi-id>  # Use the AGFI, not AFI.
```

You can confirm that your instance is properly loaded via the following.

```
$ fpga-describe-local-image -S 0 -R -H
```

Finally, build and run the executable to test your accelerator. `$CL_DIR` is the same root directory that you set above for the development instance.
```
$ cd $CL_DIR/software
$ make
$ ./test_lenet
```

## Customizing ShEF


