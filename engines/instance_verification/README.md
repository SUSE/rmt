# InstanceVerification

This plugin implements a framework for additional client validation.
It hooks into the API endpoints:

* `Api::Connect::V3::Subscriptions::SystemsController#announce_system`
  (initial storing of provided system instance data)
* `Api::Connect::V3::Systems::ProductsController#activate`,
  `Api::Connect::V3::Systems::ProductsController#upgrade`
  (verify that the system has access to the product during product activation)

After successful verification, the cache key for that system is added to a Rails cache
for a fixed amount of time which varies depending on whether the system is PAYG, BYOS or HYBRID.
This cache is also used by the `zypper_auth` engine.

How to verify the instance data is provider-specific, see `lib/instance_verification/providers/example.rb` for an example implementation.

## Instance metadata

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
    "signature": {
	  "licenseType":"license",
	  "nonce":"1234",
	  "plan": {
	    "name":"",
		"product":"",
		"publisher":""
	  },
	  "sku":"sku",
	  "subscriptionId":
	  "1234",
	  "timeStamp": {
	    "createdOn":"yyyy-mm-ddThh:mm:ssZ",
		"expiresOn":"yyyy-mm-ddThh:mm:ssZ"
	  },
	  "vmId":"1234"
	}
  },
  "subscriptionId": "some-subscription"
}
```
or
```
{
  "instance_creation_timestamp"=>1234,
  "instance_id"=>"1234",
  "instance_name"=>"foo",
  "project_id"=>"some_name",
  "project_number"=>1234,
  "zone"=>"zone_name"
}
```
for more info check [AWS IMDS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html) 
[Azure IMDS](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/instance-metadata-service?tabs=linux)
or [GCE IMDS](https://cloud.google.com/compute/docs/metadata/querying-metadata)

The value from that info to use as a `system_token` is `instance_id` or `vmId`,
depending on CSP.
