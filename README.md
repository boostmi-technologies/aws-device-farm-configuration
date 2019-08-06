# aws-device-farm-configuration

This script is super easy to use. Start by copying the two files at the root of your Xcode Project:
* run-ui-tests-on-aws-device-farm.sh
* aws-device-farm-export.plist

Then, go into the `run-ui-tests-on-aws-device-farm.sh` file and modify the first section:

```
# Define configuration variables
application_scheme="MODIFY_THIS"
uitests_scheme="UITests"
aws_device_farm_project_arn="MODIFY_THIS"
aws_device_farm_device_pool_arn="MODIFY_THIS"
```

Then, simply execute the script:

```./run-ui-tests-on-aws-device-farm.sh ```
