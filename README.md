#### Event driven functions with Google Cloud Functions (GCF) and Cloud Pub/Sub

_Scalability of your applictaions also depend upon the "degree" of coupling that exists between it's components. We are pretty used to building synchronous systems, where a caller will invoke an endpoint and then wait for the response to come back before it can do anything meaningful for the end users, your systems may require such design and it's not sin to have modern microservices to make HTTP calls and wait for response before they proceed, with the advent of async I/O and reactive programming styles, it's much more easier to code resource efficient and highly responsive applications while working with HTTP._

_However, in a distributed world, sometimes you need events for your systems to communicate, these systems are often separated by their domain functions but yet require to exchange vital set of information between them, for example an order acceptance app and analytical database, they are completely different systems, one is internet facing app, other is an internal business facing analytical system, yet the analytical system needs to reliably capture each order transaction so as to do accurate reporting, thus indirectly there exist a coupling. Architecturally, you would keep such systems decoupled and yet ensure that the order acceptance app can transmit what it should without necessarily having to worry about location, availability, performance and other SLA of the analytical system, that's a sound, loosely coupled design._

_Google Cloud Functions is a serverless compute platform which provides developers an easy way to deploy granular, task-focused and lightweight functions in a varierty of runtimes, Python, Java, Node.js, Go etc. Cloud Functions are ideal for building and deploying code which must be invoked when responding to a certain event and must go to rest afterwards, even better, yield the resources and scale-in to "zero" when there are no events._
 _On the other hand, Google Cloud Pub/Sub is a fully managed event broker from Google Cloud which helps you ingest and consume massive amount of event data at scale and is often an ideal choice for building "event driven" flows on Google Cloud, Pub/Sub acts as a glue between the systems willing to emit/consme events, yet keeping them loosely coupled and largely unware of each other._
 
 _In this simple tutorial we will deploy a couple of Cloud Functions, one a HTTP trigger which responds to HTTP requests it recieves and another one, which is a Pub/Sub trigger (a push subscription) which is invoked automatically when an event is published in the Pub/Sub topic. This way the two functions despite of having an intent to exchange data, remain decoupled from each other and work independently, though the set-up is really simple, one extrapolate this to many real-world scenarios where apps need to communicate yet remain independent and decoupled. In systems where eventual consistency is far more than just acceptable (like microservices) this can be a really powerful pattern. Let's get started:_
 
_Tools needed:_
1. _A Linux shell_
2. _Terraform_
3. _Google Cloud CLI or gcloud as it is popularly known as_
4. _Installed curl utility_
5. _Git CLI_

_Every artifact that this tutorial needs is in the repo including the archives that will be used by your Cloud Functions. However, you will need a Google Cloud Project and an account to work with, for the sake of this tutorial and convinience I would suggest using an account which has "Project Owner" role assigned to it, however for production, please remember to follow the principle of least priviliges and do not use over permissive accounts._

_Go to the Linux shell you have access to and first clone the repository locally:_
```
git clone https://github.com/rmishgoog/cloud-functions-with-pubsub.git
```
_Go the root directory and then into terraform-automation directory:_
```
cd cloud-functions-with-pubsub/terraform-automation
```
_First thing first, let's authenticate the gcloud SDK before executing any of the code/configuration:_
```
gcloud auth login
```
_Make sure you see the right account when you issue the following command, this should be the same account you decided to use as project owner:_
```
gcloud auth list
```
_Next verify the configurations:_
```
gcloud config list
```
_Check the project set on gcloud SDK currently, if it is not the same as the project you wish to work with, you can set the project id by:_
```
gcloud config set project <your-correct-project-id>
```
_Next, update the Application Default Credentials or ADC, this will be automatically used by the Terraform Google Cloud provider:_
```
gcloud auth application-default login
```
_Follow the instructions and you shall have the ADCs updated, ADCs will provide credentials and project context to Google Cloud APIs. The above command has no impact on login operation performed by "gcloud auth login", essentially auth application-default will use the token for the account you first logged in with and the project that is set on gcloud as verified by gcloud config list, however gcloud auth application-default login is versatile command and can rather let you authenticate as a different entity such as a service account and change the project context in the scope ADC which is purely for the purpose of using with Google Cloud API calls._

_If you run into challenegs because you do not have a browser on the machine you are working from, use the below command instead._
```
gcloud auth login --activate --no-launch-browser -quiet --update-adc
```
_That should be it. Next, create a file with name terraform.tfvars in this directory and supply the following values:_
```
project                    = "<your project>"
region                     = "<preferred region where functions should be deployed"
invoker                    = "<email of your project owner account"
service_account_http_fn    = "http-go-fn-publisher" 
service_account_trigger_fn = "trigger-go-fn-reciever"
```
_After you have provided these values, let's execute Terraform code:_
```
terraform init
```
```
terraform plan
```
```
terraform apply -auto-approve
```
_Once Terraform has finished provisioning your infrastructure, you shall have the required infrastructure:_
1. _HTTP triggered cloud function_
2. _Pub/Sub triggered cloud function (push subscription is automatically created)_
3. _A Pub/Sub topic_
4. _Other infrastructure components like a GCS bucket where archives are stored, service accounts etc._

```
export PROJECT_ID=<your project id>
```
```
export REGION=<your choosen region>
```
  

_Let's test the code:_
```
curl -X POST -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://${REGION}-${PROJECT_ID}.cloudfunctions.net/go-http-function -d '{"name":"Rohit", "vote":"Yes"}'
```
_You shall see the response:_
```
Hello, Rohit!, we have recieved your vote
```
_What actually happened? The HTTP function was invoked, it accepted the payload and published to the Pub/Sub topic and then returned a response back to the caller, without waiting for how this event/payload it just published is processed. But at the same time, the Pub/Sub trigger function was invoked automatically and recieved this event, let's verify from it's logs:_
```
gcloud functions logs read go-trigger-function
```
```
LEVEL  NAME                 EXECUTION_ID  TIME_UTC                 LOG
D      go-trigger-function  k5jm5aaim33x  2022-05-20 21:59:33.382  Function execution took 321 ms, finished with status: 'ok'
       go-trigger-function  k5jm5aaim33x  2022-05-20 21:59:33.381
       go-trigger-function  k5jm5aaim33x  2022-05-20 21:59:33.381
       go-trigger-function  k5jm5aaim33x  2022-05-20 21:59:33.381  2022/05/20 21:59:33 Recieved: The message recieved from Pub/Sub topic, {"name":"Rohit","vote":"Yes"}!
D      go-trigger-function  k5jm5aaim33x  2022-05-20 21:59:33.063  Function execution started
D      go-trigger-function  q6pi8y5k5r5z  2022-05-20 20:33:35.366  Function execution took 27 ms, finished with status: 'ok'
       go-trigger-function  q6pi8y5k5r5z  2022-05-20 20:33:35.365
       go-trigger-function  q6pi8y5k5r5z  2022-05-20 20:33:35.365
       go-trigger-function  q6pi8y5k5r5z  2022-05-20 20:33:35.365  2022/05/20 20:33:35 Recieved: The message recieved from Pub/Sub topic, {"name":"Rohit","vote":"Yes"}!
D      go-trigger-function  q6pi8y5k5r5z  2022-05-20 20:33:35.341  Function execution started
```
_As we can see, the function has successfully recieved the payload when it was auto-triggered, this is called a "Push" subscription model. Terraform code also demonstrates other IAM related stuff that you will need for example, granting invoker role to your developer account so you can test._

_Finally,let's reclaim the infrastructure:_
```
terraform destroy -auto-approve
```



