# InstanceVerification
This plugin implements a framework for additional checks during product activation. The checks themselves are provider-specific, see `lib/instance_verification/providers/example.rb` for an example implementation.

# Instance metadata
Depending on the CSP the metadata can look more or less like this

```json
{
  "accountId" : "1234",
  "architecture" : "some-arch",
  "availabilityZone" : "some-zone",
  "billingProducts" : [ "billing-info" ],
  "devpayProductCodes" : null,
  "marketplaceProductCodes" : null,
  "imageId" : "ami-1234",
  "instanceId" : "i-1234",
  "instanceType" : "instance-type",
  "kernelId" : null,
  "pendingTime" : "yyyy-mm-ddThh:mm:ssZ",
  "privateIp" : "some-ip",
  "ramdiskId" : null,
  "region" : "some-region",
  "version" : "2017-09-30"
}
```
 or
```json
{
  "billingTag": "some-billing-tag", 
  "attestedData": {
    "signature": "signature"
  }, 
  "subscriptionId": "some-subscription"
}
```
for more info check [AWS IMDS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html) 
[Azure IMDS](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/instance-metadata-service?tabs=linux)
or [GCE IMDS](https://cloud.google.com/compute/docs/metadata/querying-metadata)
