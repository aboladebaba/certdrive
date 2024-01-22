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

### LAB 2: Hosting a Web App on Google Cloud Using Compute Engine

# Set your region and zone
gcloud config set compute/zone "us-east4-a"
export ZONE=$(gcloud config get compute/zone)

gcloud config set compute/region "us-east4"
export REGION=$(gcloud config get compute/region)

# Task 1. Enable Compute Engine API using cli
gcloud services enable compute.googleapis.com

# Task 2. Create Cloud Storage bucket
gsutil mb gs://fancy-store-$DEVSHELL_PROJECT_ID

# Task 3. Clone source repository
git clone https://github.com/googlecodelabs/monolith-to-microservices.git
cd ~/monolith-to-microservices
./setup.sh

# Once completed, make sure the shell is running compatible nedeJS version
nvm install --lts

# Next, run the following to test the application, switch to the microservices directory, and start the web server
cd microservices
npm start

## Task 4. Create Compute Engine instances
touch ~/monolith-to-microservices/startup-script.sh

# Add the following lines to the file above.
#!/bin/bash

# Install logging monitor. The monitor will automatically pick up logs sent to
# syslog.
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &

# Install dependencies from apt
apt-get update
apt-get install -yq ca-certificates git build-essential supervisor psmisc

# Install nodejs
mkdir /opt/nodejs
curl https://nodejs.org/dist/v16.14.0/node-v16.14.0-linux-x64.tar.gz | tar xvzf - -C /opt/nodejs --strip-components=1
ln -s /opt/nodejs/bin/node /usr/bin/node
ln -s /opt/nodejs/bin/npm /usr/bin/npm

# Get the application source code from the Google Cloud Storage bucket.
mkdir /fancy-store
gsutil -m cp -r gs://fancy-store-[DEVSHELL_PROJECT_ID]/monolith-to-microservices/microservices/* /fancy-store/

# Install app dependencies.
cd /fancy-store/
npm install

# Create a nodeapp user. The application will run as this user.
useradd -m -d /home/nodeapp nodeapp
chown -R nodeapp:nodeapp /opt/app

# Configure supervisor to run the node app.
cat >/etc/supervisor/conf.d/node-app.conf << EOF
[program:nodeapp]
directory=/fancy-store
command=npm start
autostart=true
autorestart=true
user=nodeapp
environment=HOME="/home/nodeapp",USER="nodeapp",NODE_ENV="production"
stdout_logfile=syslog
stderr_logfile=syslog
EOF

supervisorctl reread
supervisorctl update

# Return to Cloud Shell Terminal and run the following to copy the startup-script.sh file into your bucket:
gsutil cp ~/monolith-to-microservices/startup-script.sh gs://fancy-store-$GOOGLE_CLOUD__PROJECT

# Copy code into the Cloud Storage bucket
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$GOOGLE_CLOUD__PROJECT/

# Deploy a backend
gcloud compute instances create backend \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --tags=backend \
   --metadata=startup-script-url=https://storage.googleapis.com/fancy-store-$DEVSHELL_PROJECT_ID/startup-script.sh

# Configure a connection to the backend
gcloud compute instances list

# Copy the External IP for the backend.
# In the Cloud Shell Explorer, navigate to monolith-to-microservices > react-app.
# In the Code Editor, select View > Toggle Hidden Files in order to see the .env file.
# In the next step, you edit the .env file to point to the External IP of the backend. [BACKEND_ADDRESS] represents the External IP address of the backend instance determined from the above gcloud command.
# In the .env file, replace localhost with your [BACKEND_ADDRESS]:

# In Cloud Shell, run the following to rebuild react-app, which will update the frontend code:
cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

# Then copy the application code into the Cloud Storage bucket:
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

# Deploy the frontend instance
gcloud compute instances create frontend \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --tags=frontend \
    --metadata=startup-script-url=https://storage.googleapis.com/fancy-store-$DEVSHELL_PROJECT_ID/startup-script.sh

# Configure the network
gcloud compute firewall-rules create fw-fe \
    --allow tcp:8080 \
    --target-tags=frontend

gcloud compute firewall-rules create fw-be \
    --allow tcp:8081-8082 \
    --target-tags=backend

# The website should now be fully functional.
# In order to navigate to the external IP of the frontend, you need to know the address. 
# Run the following and look for the EXTERNAL_IP of the frontend instance:
gcloud compute instances list

# Wait 3 minutes and then open a new browser tab and browse to http://[FRONTEND_ADDRESS]:8080 to access the website, where [FRONTEND_ADDRESS] is the frontend EXTERNAL_IP determined above.


# Task 5. Create managed instance groups

# First, stop both instances:
gcloud compute instances stop frontend --zone=$ZONE
gcloud compute instances stop backend --zone=$ZONE

# Then, create the instance template from each of the source instances:
gcloud compute instance-templates create fancy-fe \
    --source-instance-zone=$ZONE \
    --source-instance=frontend

gcloud compute instance-templates create fancy-be \
    --source-instance-zone=$ZONE \
    --source-instance=backend

# Confirm the instance templates were created:
gcloud compute instance-templates list

# With the instance templates created, delete the backend vm to save resource space:
gcloud compute instances delete backend --zone=$ZONE

# Normally, you could delete the frontend vm as well, but you will use it to update the instance template later in the lab.

# Create managed instance group

# Next, create two managed instance groups, one for the frontend and one for the backend
gcloud compute instance-groups managed create fancy-fe-mig \
    --zone=$ZONE \
    --base-instance-name fancy-fe \
    --size 2 \
    --template fancy-fe

# These managed instance groups will use the instance templates and are configured for two instances each within each group to start. The instances are automatically named based on the base-instance-name specified with random characters appended.

# For your application, the frontend microservice runs on port 8080, and the backend microservice runs on port 8081 for orders and port 8082 for products:
gcloud compute instance-groups set-named-ports fancy-fe-mig \
    --zone=$ZONE \
    --named-ports frontend:8080

gcloud compute instance-groups set-named-ports fancy-be-mig \
    --zone=$ZONE \
    --named-ports orders:8081,products:8082

# Since these are non-standard ports, you specify named ports to identify these. Named ports are key:value pair metadata representing the service name and the port that it's running on. Named ports can be assigned to an instance group, which indicates that the service is available on all instances in the group. This information is used by the HTTP Load Balancing service that will be configured later.

# Configure autohealing
# Create a health check that repairs the instance if it returns "unhealthy" 3 consecutive times for the frontend and backend:
gcloud compute health-checks create http fancy-fe-hc \
    --port 8080 \
    --check-interval 30s \
    --healthy-threshold 1 \
    --timeout 10s \
    --unhealthy-threshold 3

gcloud compute health-checks create http fancy-be-hc \
    --port 8081 \
    --request-path=/api/orders \
    --check-interval 30s \
    --healthy-threshold 1 \
    --timeout 10s \
    --unhealthy-threshold 3

# Create a firewall rule to allow the health check probes to connect to the microservices on ports 8080-8081:
gcloud compute firewall-rules create allow-health-check \
    --allow tcp:8080-8081 \
    --source-ranges 130.211.0.0/22,35.191.0.0/16 \
    --network default

# Apply the health checks to their respective services:
gcloud compute instance-groups managed update fancy-fe-mig \
    --zone=$ZONE \
    --health-check fancy-fe-hc \
    --initial-delay 300

gcloud compute instance-groups managed update fancy-be-mig \
    --zone=$ZONE \
    --health-check fancy-be-hc \
    --initial-delay 300

# Continue with the lab to allow some time for autohealing to monitor the instances in the group. You will simulate a failure to test the autohealing at the end of the lab.

# Task 6. Create load balancers

# Create health checks that will be used to determine which instances are capable of serving traffic for each service:
gcloud compute http-health-checks create fancy-fe-frontend-hc \
  --request-path / \
  --port 8080

gcloud compute http-health-checks create fancy-be-orders-hc \
  --request-path /api/orders \
  --port 8081

gcloud compute http-health-checks create fancy-be-products-hc \
  --request-path /api/products \
  --port 8082

# Create backend services that are the target for load-balanced traffic. The backend services will use the health checks and named ports you created:
gcloud compute backend-services create fancy-fe-frontend \
  --http-health-checks fancy-fe-frontend-hc \
  --port-name frontend \
  --global

gcloud compute backend-services create fancy-be-orders \
  --http-health-checks fancy-be-orders-hc \
  --port-name orders \
  --global

gcloud compute backend-services create fancy-be-products \
  --http-health-checks fancy-be-products-hc \
  --port-name products \
  --global

# Add the Load Balancer's backend services:
gcloud compute backend-services add-backend fancy-fe-frontend \
  --instance-group-zone=$ZONE \
  --instance-group fancy-fe-mig \
  --global

gcloud compute backend-services add-backend fancy-be-orders \
  --instance-group-zone=$ZONE \
  --instance-group fancy-be-mig \
  --global

gcloud compute backend-services add-backend fancy-be-products \
  --instance-group-zone=$ZONE \
  --instance-group fancy-be-mig \
  --global

# Create a URL map. The URL map defines which URLs are directed to which backend services:
gcloud compute url-maps create fancy-map \
  --default-service fancy-fe-frontend

# Create a path matcher to allow the /api/orders and /api/products paths to route to their respective services:
gcloud compute url-maps add-path-matcher fancy-map \
   --default-service fancy-fe-frontend \
   --path-matcher-name orders \
   --path-rules "/api/orders=fancy-be-orders,/api/products=fancy-be-products"

# Create the proxy which ties to the URL map:
gcloud compute target-http-proxies create fancy-proxy \
  --url-map fancy-map

# Create a global forwarding rule that ties a public IP address and port to the proxy:
gcloud compute forwarding-rules create fancy-http-rule \
  --global \
  --target-http-proxy fancy-proxy \
  --ports 80

# Update the configuration

# In Cloud Shell, change to the react-app folder which houses the .env file that holds the configuration:
cd ~/monolith-to-microservices/react-app/

# Find the IP address for the Load Balancer:
gcloud compute forwarding-rules list --global

# Return to the Cloud Shell Editor and edit the .env file again to point to Public IP of Load Balancer. [LB_IP] represents the External IP address of the backend instance determined above.
# Save the file.

# Rebuild react-app, which will update the frontend code:
cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

# Copy the application code into your bucket:
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

# Update the frontend instances

# Since your instances pull the code at startup, you can issue a rolling restart command:
gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
    --zone=$ZONE \
    --max-unavailable 100%

# Test the website
# Wait 3 minutes after issuing the rolling-action replace command in order to give the instances time to be processed, and then check the status of the managed instance group. Run the following to confirm the service is listed as HEALTHY:
watch -n 2 gcloud compute backend-services get-health fancy-fe-frontend --global

# Once both items appear as HEALTHY on the list, exit the watch command by pressing CTRL+C.

# Task 7. Scaling Compute Engine
# Automatically resize by utilization
# To create the autoscaling policy, execute the following
gcloud compute instance-groups managed set-autoscaling \
  fancy-fe-mig \
  --zone=$ZONE \
  --max-num-replicas 2 \
  --target-load-balancing-utilization 0.60

gcloud compute instance-groups managed set-autoscaling \
  fancy-be-mig \
  --zone=$ZONE \
  --max-num-replicas 2 \
  --target-load-balancing-utilization 0.60

# These commands create an autoscaler on the managed instance groups that automatically adds instances when utilization is above 60% utilization, and removes instances when the load balancer is below 60% utilization.

# Enable content delivery network
# Execute the following command on the frontend service:
gcloud compute backend-services update fancy-fe-frontend \
    --enable-cdn --global


# Task 8. Update the website
# Updating instance template
# Existing instance templates are not editable; however, since your instances are stateless and all configuration is done through the startup script, you only need to change the instance template if you want to change the template settings . Now you're going to make a simple change to use a larger machine type and push that out.

# Run the following command to modify the machine type of the frontend instance:
gcloud compute instances set-machine-type frontend \
  --zone=$ZONE \
  --machine-type e2-small

Create the new Instance Template:
gcloud compute instance-templates create fancy-fe-new \
    --region=$REGION \
    --source-instance=frontend \
    --source-instance-zone=$ZONE

# Roll out the updated instance template to the Managed Instance Group:
gcloud compute instance-groups managed rolling-action start-update fancy-fe-mig \
  --zone=$ZONE \
  --version template=fancy-fe-new

# Wait 3 minutes, and then run the following to monitor the status of the update:
watch -n 2 gcloud compute instance-groups managed list-instances fancy-fe-mig \
  --zone=$ZONE
# This will take a few moments.
# Once you have at least 1 instance in the following condition:

## STATUS: RUNNING
## ACTION set to None
## INSTANCE_TEMPLATE: the new template name (fancy-fe-new)
## Copy the name of one of the machines listed for use in the next command.
# CTRL+C to exit the watch process.

# Run the following to see if the virtual machine is using the new machine type (e2-small), where [VM_NAME] is the newly created instance:
gcloud compute instances describe fancy-fe-new --zone=$ZONE | grep machineType

# Make changes to the website
# Scenario: Your marketing team has asked you to change the homepage for your site. They think it should be more informative of who your company is and what you actually sell.
# Task: Add some text to the homepage to make the marketing team happy! It looks like one of the developers has already created the changes with the file name index.js.new. You can just copy this file to index.js and the changes should be reflected. Follow the instructions below to make the appropriate changes.
# Run the following commands to copy the updated file to the correct file name:
cd ~/monolith-to-microservices/react-app/src/pages/Home
mv index.js.new index.js

# Print the file contents to verify the changes:
cat ~/monolith-to-microservices/react-app/src/pages/Home/index.js

# You updated the React components, but you need to build the React app to generate the static files.
# Run the following command to build the React app and copy it into the monolith public directory:
cd ~/monolith-to-microservices/react-app
npm install && npm run-script build

# Then re-push this code to the bucket:
cd ~
rm -rf monolith-to-microservices/*/node_modules
gsutil -m cp -r monolith-to-microservices gs://fancy-store-$DEVSHELL_PROJECT_ID/

# Push changes with rolling replacements
# Now force all instances to be replaced to pull the update:
gcloud compute instance-groups managed rolling-action replace fancy-fe-mig \
  --zone=$ZONE \
  --max-unavailable=100%

# Note: In this example of a rolling replace, you specifically state that all machines can be replaced immediately through the --max-unavailable parameter. Without this parameter, the command would keep an instance alive while replacing others. For testing purposes, you specify to replace all immediately for speed. In production, leaving a buffer would allow the website to continue serving the website while updating.

# Wait 3 minutes after issuing the rolling-action replace command in order to give the instances time to be processed, and then check the status of the managed instance group. Run the following to confirm the service is listed as HEALTHY:
watch -n 2 gcloud compute backend-services get-health fancy-fe-frontend --global
# Wait a few moments for both services to appear and become HEALTHY.

# Browse to the website via http://[LB_IP] where [LB_IP] is the IP_ADDRESS specified for the Load Balancer, 
# which can be found with the following command:
gcloud compute forwarding-rules list --global

# Simulate failure
# In order to confirm the health check works, log in to an instance and stop the services.
# To find an instance name, execute the following:
gcloud compute instance-groups list-instances fancy-fe-mig --zone=$ZONE

# Copy an instance name, then run the following to secure shell into the instance, where INSTANCE_NAME is one of the instances from the list:
gcloud compute ssh [INSTANCE_NAME] --zone=$ZONE

# Within the instance, use supervisorctl to stop the application:
sudo supervisorctl stop nodeapp; sudo killall node


# Monitor the repair operations:
watch -n 2 gcloud compute operations list \
--filter='operationType~compute.instances.repair.*'

# This will take a few minutes to complete.
# Look for the following example output:

# NAME                                                  TYPE                                       TARGET                                 HTTP_STATUS  STATUS  TIMESTAMP
# repair-1568314034627-5925f90ee238d-fe645bf0-7becce15  compute.instances.repair.recreateInstance  us-central1-a/instances/fancy-fe-1vqq  200          DONE    2019-09-12T11:47:14.627-07:00
# The managed instance group recreated the instance to repair it.
# You can also go to Navigation menu > Compute Engine > VM instances to monitor through the Console.
gcloud compute instances describe fancy-fe-new --zone=$ZONE | grep machineType 