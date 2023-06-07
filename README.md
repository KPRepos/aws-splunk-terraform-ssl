### Install and configure Demo/Lab Splunk with SSL certs for quick testing using LetsEncrypt, this also applies SSL for HEC 

This is a combination of changes that worked for version 9.x of splunk, Terraform will install SPlunk and enables AWS SSM to login. Once installed, Create a DNS Record for Splunk with public IP attached as EIP to Splunk.

### Install using terraform 

Change lab-variables.auto.tfvars as required  and run `terraform init && terraform apply`

The very first time this runs, the SPLUNk marketplace subscription need to be accepted, This is using BYOL so no software charges, but please validate before subscribing or hardcode a known AMI-ID


Login to splunk using aws Session Manger and follow Post Install scripts below. Lets encrypt require port 80 for Auto domain validation  and 8088 and 8443 are made Public, and can be removed from Security Groups


```
sudo letsencrypt certonly --standalone -d splunk-1.lab.kprepos.com --register-unsafely-without-email --agree-tos

sudo mkdir /opt/splunk/etc/auth/sloccerts

sudo cp /etc/letsencrypt/live/splunk-1.lab.kprepos.com/privkey.pem /opt/splunk/etc/auth/sloccerts/

sudo cp /etc/letsencrypt/live/splunk-1.lab.kprepos.com/fullchain.pem /opt/splunk/etc/auth/sloccerts/

sudo cp /etc/letsencrypt/live/splunk-1.lab.kprepos.com/cert.pem /opt/splunk/etc/auth/sloccerts/

sudo cp /etc/letsencrypt/live/splunk-1.lab.kprepos.com/chain.pem /opt/splunk/etc/auth/sloccerts/

sudo su - splunk

cd /opt/splunk/etc/auth/sloccerts/

cat cert.pem privkey.pem chain.pem > combined-cert.pem

sudo chown -R splunk:splunk /opt/splunk/etc/auth/sloccerts/
```

#### Create new file web.conf anf update new cert info

```
[settings]
enableSplunkWebSSL = true
httpport = 8443
serverCert = /opt/splunk/etc/auth/sloccerts/combined-cert.pem
privKeyPath = /opt/splunk/etc/auth/sloccerts/privkey.pem
```

#### Update inputs.conf file - Specially for HEC

/opt/splunk/etc/system/local/inputs.conf

```
[splunktcp://9997]
disabled = 0

[default]
host = splunk-1.lab.kprepos.com

[http]
disabled = 0
index = main
enableSSL = 1
serverCert = /opt/splunk/etc/auth/sloccerts/combined-cert.pem
sslPassword =
crossOriginSharingPolicy = \*

```

#### Add/update below content to /opt/splunk/etc/system/local/server.conf, There will be additional auto generated content which we can keep as is and just add below lines.

```
[general]
serverName = splunk-1.lab.kprepos.com
[sslConfig]
enableSplunkdSSL = true
sslRootCAPath = /opt/splunk/etc/auth/sloccerts/cert.pem

```

#### Now restart to apply changes and (reboot server just in case, if needed)

sudo /opt/splunk/bin/splunk restart splunkd

#### Now open Splunk DNS in port 8443

#### Test HEC

#### create a token and test using curl

curl https://splunk-1.lab.kprepos.com:8088/services/collector/event -H "Authorization: Splunk 1dfa654b-xxxx-cccc-dddd-eeeeeeeee" -d '{"event": "hello world"}'

#### Refernces used for this repo

1. https://docs.splunk.com/Documentation/Splunk/9.0.4/Security/HowtoprepareyoursignedcertificatesforSplunk
2. https://www.splunk.com/en_us/blog/tips-and-tricks/secure-splunk-web-in-five-minutes-using-lets-encrypt.html?locale=en_us
3. https://community.splunk.com/t5/All-Apps-and-Add-ons/How-do-I-secure-the-event-collector-port-8088-with-an-ssl/m-p/243885
4. https://nicovibert.com/2021/12/10/terraform-and-splunk-part-1-building-a-splunk-instance-in-aws/
