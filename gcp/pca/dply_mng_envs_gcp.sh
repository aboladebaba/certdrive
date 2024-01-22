##

# Check the version of gcloud installed
gcloud --version

# Set Region and Zone for the current interactions
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-c

# Create vm instance
gcloud compute instances create lab-1 
    --zone us-central1-c 
    --machine-type=e2-standard-2

# Check your current gcloud configuration
Check your current gcloud configuration

# You can change other settings using the gcloud config set command. 
# Those changes are permanent; they are written to your home directory.
# The default configuration is stored in ~/.config/gcloud/configurations/config_default.
cat ~/.config/gcloud/configurations/config_default

# Task 2. Create and switch between multiple IAM configurations

# Create a new IAM configuration
gcloud init --no-launch-browser

# follow the prompts, give the new config a name, select new user acct option
# go to auth url, enter user password, follow the prompts, accept the options
# copy the auth code and enter in your current session. 

# List compute instances
gcloud compute instances list

# switch between configurations 
gcloud config configurations activate #<default/new config you saved>

# Task 3. Identify and assign correct IAM permissions

# Examine roles and permissions
gcloud iam roles describe roles/compute.instanceAdmin

# Set the 2nd project id. Note this was being done in SSH envs
echo "export PROJECTID2=<the-project-id>" >> ~/.bashrc

# Set the context to the project ID
. ~/.bashrc
gcloud config set project $PROJECTID2

. ~/.bashrc
gcloud projects add-iam-policy-binding <$PROJECTID2> 
    --member user:<$USERID2> 
    --role=roles/viewer


# Create a new role with permissions
gcloud iam roles create devops --project $PROJECTID2 
    --permissions "compute.instances.create,compute.instances.delete,\
    compute.instances.start,compute.instances.stop,compute.instances.update,\
    compute.disks.create,compute.subnetworks.use,compute.subnetworks.useExternalIp,\
    compute.instances.setMetadata,compute.instances.setServiceAccount"

# Bind the role to the second account to both projects
gcloud projects add-iam-policy-binding $PROJECTID2 --member user:$USERID2 --role=roles/iam.serviceAccountUser


# Bind the custom role "devops" to a given user
gcloud projects add-iam-policy-binding $PROJECTID2 
    --member user:$USERID2 
    --role=projects/$PROJECTID2/roles/devops

# Create a service account
gcloud iam service-accounts create devops --display-name <devops>

# Get the service account email address
gcloud iam service-accounts list  --filter "displayName=devops"

# Put the email address into a local variable called SA
SA=$(gcloud iam service-accounts list --format="value(email)" --filter "displayName=devops")

# Give the service account the role of iam.serviceAccountUser
gcloud projects add-iam-policy-binding $PROJECTID2 
    --member serviceAccount:$SA 
    --role=roles/iam.serviceAccountUser

# Give the service account the role of compute.instanceAdmin
gcloud projects add-iam-policy-binding $PROJECTID2 
    --member serviceAccount:$SA 
    --role=roles/compute.instanceAdmin
