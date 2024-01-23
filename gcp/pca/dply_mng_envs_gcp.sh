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

# LAB 3: Orchestrating the Cloud with Kubernetes

# Set Zone
gcloud config set compute/zone us-east4-b

# Create / Start up a cluster
gcloud container clusters create io

# Task 2. Quick Kubernetes Demo

# Use it to launch a single instance of the nginx container:
kubectl create deployment nginx --image=nginx:1.10.0

# Use the kubectl get pods command to view the running nginx container:
kubectl get pods

# Once the containers are running, us the ccommanbelow to expose it outside of Kubernetes
kubectl expose deployment nginx --port 80 --type LoadBalancer

# List Services running
kubectl get services

## Pods represent and hold a collection of one or more containers. Generally, if you have multiple containers with a hard dependency on each other, you package the containers inside a single pod.

# Task 4. Creating pods

# Create a monolith pod using the yaml file
kubectl create -f pods/monolith.yaml
kubectl describe pods monolith

# Task 5. Interacting with pods
# By default, pods are allocated a private IP address and cannot be reached outside of the cluster. Use the kubectl port-forward command to map a local port to a port inside the monolith pod.
kubectl port-forward monolith 10080:80

# This will work:
curl http://127.0.0.1:10080

# This will not when you tried a secure endpoint
curl http://127.0.0.1:10080/secure

# Since Cloud Shell does not handle copying long strings well, create an environment variable for the token.
TOKEN=$(curl http://127.0.0.1:10080/login -u user|jq -r '.token')

# Now this will work:
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:10080/secure

# You can also get some logs with :
kubectl logs monolith

# Use the kubectl exec command to run an interactive shell inside the Monolith Pod. This can come in handy when you want to troubleshoot from within a container:
kubectl exec monolith --stdin --tty -c monolith -- /bin/sh


# Task 6. Services
# Pods aren't meant to be persistent. They can be stopped or started for many reasons - like failed liveness or readiness checks - and this leads to a problem:
# What happens if you want to communicate with a set of Pods? When they get restarted they might have a different IP address.
# That's where Services come in. Services provide stable endpoints for Pods.


# Task 7. Creating a service

# Create the secure-monolith pods and their configuration data:
kubectl create secret generic tls-certs --from-file tls/
# secret/tls-certs created
kubectl create configmap nginx-proxy-conf --from-file nginx/proxy.conf
# configmap/nginx-proxy-conf created
kubectl create -f pods/secure-monolith.yaml
# pod/secure-monolith created

# create the monolith service from the monolith service configuration file:
kubectl create -f services/monolith.yaml
# service/monolith created

# Use the gcloud compute firewall-rules command to allow traffic to the monolith service on the exposed nodeport:
gcloud compute firewall-rules create allow-monolith-nodeport \
  --allow=tcp:31000

# get an external IP address for one of the nodes.
gcloud compute instances list

# Now try hitting the secure-monolith service using curl:
curl -k https://35.199.38.163:31000
### Error encountered.

# Use the following commands to get answers to why you got the error above
  # Questions:
  # Why are you unable to get a response from the monolith service? No labels were assigned
  # How many endpoints does the monolith service have? 
  # What labels must a Pod have to be picked up by the monolith service?

kubectl get services monolith
# NAME       TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
# monolith   NodePort   10.96.2.142   <none>        443:31000/TCP   4m12s

kubectl describe services monolith
# Name:                     monolith
# Namespace:                default
# Labels:                   <none>
# Annotations:              cloud.google.com/neg: {"ingress":true}
# Selector:                 app=monolith,secure=enabled
# Type:                     NodePort
# IP Family Policy:         SingleStack
# IP Families:              IPv4
# IP:                       10.96.2.142
# IPs:                      10.96.2.142
# Port:                     <unset>  443/TCP
# TargetPort:               443/TCP
# NodePort:                 <unset>  31000/TCP
# Endpoints:                <none>
# Session Affinity:         None
# External Traffic Policy:  Cluster
# Events:                   <none>

# Check how many pods you have running with the label "app=monolith": 3 pods 1 monolith, 2 ngnix
kubectl get pods -l "app=monolith"
# NAME              READY   STATUS    RESTARTS   AGE
# monolith          1/1     Running   0          23m
# secure-monolith   2/2     Running   0          11m

# Check how many has secure-enabled ?
kubectl get pods -l "app=monolith,secure=enabled" # yield no result

# Use the kubectl label command to add the missing secure=enabled label to the secure-monolith Pod
kubectl label pods secure-monolith 'secure=enabled'
# pod/secure-monolith labeled

# now query for secured label
kubectl get pods secure-monolith --show-labels
# NAME              READY   STATUS    RESTARTS   AGE   LABELS
# secure-monolith   2/2     Running   0          16m   app=monolith,secure=enabled

# Now that your pods are correctly labeled, view the list of endpoints on the monolith service:
kubectl describe services monolith | grep Endpoints
# Endpoints:                10.92.0.6:443

# List for External Ip
gcloud compute instances list
NAME: gke-io-default-pool-9c5f891b-07hh
ZONE: us-east4-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.150.0.4
EXTERNAL_IP: 35.199.45.118
STATUS: RUNNING

NAME: gke-io-default-pool-9c5f891b-94tp
ZONE: us-east4-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.150.0.5
EXTERNAL_IP: 35.199.38.163
STATUS: RUNNING

NAME: gke-io-default-pool-9c5f891b-gzh0
ZONE: us-east4-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.150.0.3
EXTERNAL_IP: 34.145.167.243
STATUS: RUNNING

# Test this out by hitting one of our nodes again.
curl -k https://34.145.167.243:31000 


# Task 9. Deploying applications with Kubernetes
# Deployments are a declarative way to ensure that the number of Pods running is equal to the desired number of Pods, specified by the user.
# The main benefit of Deployments is in abstracting away the low level details of managing Pods. Behind the scenes Deployments use Replica Sets to manage starting and stopping the Pods. If Pods need to be updated or scaled, the Deployment will handle that. Deployment also handles restarting Pods if they happen to go down for some reason.

# Task 10. Creating deployments
# You're going to break the monolith app into three separate pieces:
  # auth - Generates JWT tokens for authenticated users.
  # hello - Greet authenticated users.
  # frontend - Routes traffic to the auth and hello services.

# Create your deployment object:
kubectl create -f deployments/auth.yaml
    #deployment.apps/auth created

# Create the auth service:
kubectl create -f services/auth.yaml
    # service/auth created

# Now do the same thing to create and expose the hello deployment:
kubectl create -f deployments/hello.yaml
    # deployment.apps/hello created
kubectl create -f services/hello.yaml
    # service/hello created

# Add one more deployment to create and expose the frontend Deployment.
kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf
    # configmap/nginx-frontend-conf created
kubectl create -f deployments/frontend.yaml
    # deployment.apps/frontend created
kubectl create -f services/frontend.yaml
    # service/frontend created

# kubectl get services frontend
    # NAME       TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
    # frontend   LoadBalancer   10.96.12.247   34.48.38.83   443:31880/TCP   73s

# Test with the external IP
curl -k https://34.48.38.83
    # {"message":"Hello"}

# LAB 4: Networking 101


# Task 4. Create custom network with Cloud Shell
# To create the custom network:
gcloud compute networks create taw-custom-network --subnet-mode custom
    # Created [https://www.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-2e0530fb5fbb/global/networks/taw-custom-network].
    # NAME: taw-custom-network
    # SUBNET_MODE: CUSTOM
    # BGP_ROUTING_MODE: REGIONAL
    # IPV4_RANGE: 
    # GATEWAY_IPV4: 
    # Instances on this network will not be reachable until firewall rules
    # are created. As an example, you can allow all internal traffic between
    # instances as well as SSH, RDP, and ICMP by running:
    # $ gcloud compute firewall-rules create <FIREWALL_NAME> --network taw-custom-network --allow tcp,udp,icmp --source-ranges <IP_RANGE>
    # $ gcloud compute firewall-rules create <FIREWALL_NAME> --network taw-custom-network --allow tcp:22,tcp:3389,icmp

# Create 3 Subnets
gcloud compute networks subnets create subnet-us-east1 \
   --network taw-custom-network \
   --region us-east1 \
   --range 10.0.0.0/16
    # Created [https://www.googleapis.com/compute/v1/projects/qwiklabs-gcp-02-2e0530fb5fbb/regions/us-east1/subnetworks/subnet-us-east1].
    # NAME: subnet-us-east1
    # REGION: us-east1
    # NETWORK: taw-custom-network
    # RANGE: 10.0.0.0/16
    # STACK_TYPE: IPV4_ONLY
    # IPV6_ACCESS_TYPE: 
    # INTERNAL_IPV6_PREFIX: 
    # EXTERNAL_IPV6_PREFIX:

gcloud compute networks subnets create subnet-europe-west1 \
   --network taw-custom-network \
   --region europe-west1 \
   --range 10.1.0.0/16

gcloud compute networks subnets create subnet-us-east4 \
   --network taw-custom-network \
   --region us-east4 \
   --range 10.2.0.0/16

# List your networks:
gcloud compute networks subnets list \
   --network taw-custom-network

# Task 5. Adding firewall rules

# Add firewall rules using Cloud Shell
gcloud compute firewall-rules create nw101-allow-http \
    --allow tcp:80 \
    --network taw-custom-network \
    --source-ranges 0.0.0.0/0 \
    --target-tags http

gcloud compute firewall-rules create "nw101-allow-icmp" \
    --allow icmp \
    --network "taw-custom-network" \
    --target-tags rules

gcloud compute firewall-rules create "nw101-allow-internal" --allow tcp:0-65535,udp:0-65535,icmp --network "taw-custom-network" --source-ranges "10.0.0.0/16","10.2.0.0/16","10.1.0.0/16"

gcloud compute firewall-rules create "nw101-allow-ssh" --allow tcp:22 --network "taw-custom-network" --target-tags "ssh"

gcloud compute firewall-rules create "nw101-allow-rdp" --allow tcp:3389 --network "taw-custom-network"


# Task 6. Connecting to your lab VMs and checking latency

# Step 1: create an instance named us-test-01 in the subnet-us-east1 subnet:
gcloud compute instances create us-test-01 \
    --subnet subnet-us-east1 \
    --zone us-east1-b \
    --machine-type e2-standard-2 \
    --tags ssh,http,rules

# Step 2: Now make the us-test-02 and us-test-03 VMs in their correlated subnets:
gcloud compute instances create us-test-02 \
--subnet subnet-europe-west1 \
--zone europe-west1-d \
--machine-type e2-standard-2 \
--tags ssh,http,rules

gcloud compute instances create us-test-03 \
--subnet subnet-us-east4 \
--zone us-east4-b \
--machine-type e2-standard-2 \
--tags ssh,http,rules

# ping -c 3 <us-test-02-external-ip-address>
ping -c 3 104.199.82.189

# ping -c 3 <us-test-03-external-ip-address>
ping -c 3 34.85.187.189

ping -c 3 34.73.47.21

# Use ping to measure latency

# To observe the latency from the US Central region to the Europe West region, 
# run the following command after opening an SSH window on the us-test-01:
ping -c 3 us-test-02.europe-west1-d


# Task 7. Traceroute and Performance testing
# Traceroute is a tool to trace the path between two hosts. A traceroute can be a helpful first step to uncovering many different types of network problems.
# For this step go back to using the us-test-01 VM and us-test-02 VM and SSH into both of them.
# Install these performance tools in the SSH window for us-test-01:
sudo apt-get update
sudo apt-get -y install traceroute mtr tcpdump iperf whois host dnsutils siege

# Task 8. Use iperf to test performance
# Between two hosts
# SSH into us-test-02 and install the performance tools:
sudo apt-get update
sudo apt-get -y install traceroute mtr tcpdump iperf whois host dnsutils siege

# SSH into us-test-01 and run:
iperf -s #run in server mode

# On us-test-02 SSH run this iperf:
iperf -c us-test-01.us-east1-b #run in client mode

# iperf -c us-test-01.us-east1-b #run in client mode
# Between VMs within a region

# In Cloud Shell, create us-test-04:
gcloud compute instances create us-test-04 \
--subnet subnet-us-east1 \
--zone us-east1-c \
--tags ssh,http

# On us-test-02 SSH run:
iperf -s -u #iperf server side

# On us-test-01 SSH run:
iperf -c us-test-02.europe-west1-d -u -b 2G #iperf client side - send 2 Gbits/s

# In the SSH window for us-test-01 run:
iperf -s

# In the SSH window for us-test-02 run:
iperf -c us-test-01.us-east1-b -P 20


# LAB 5: Cloud Logging to Analyze BigQuery Usage
# Console walkthrough for BigQuery.















# Step 1: 
# Step 1: 
# Step 1: 
# Step 1: 
# Step 1: 
# Step 1: 
# Step 1: 
# Step 1: 
# Step 1: 


























