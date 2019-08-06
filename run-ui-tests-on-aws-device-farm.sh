#!/bin/sh

#  run-ui-tests-on-aws-device-farm.sh
#  Boostmi
#
#  Created by Etienne Noel on 2019-07-19.

# Define configuration variables
application_scheme="MODIFY_THIS"
uitests_scheme="UITests"
aws_device_farm_project_arn="MODIFY_THIS"
aws_device_farm_device_pool_arn="MODIFY_THIS"

# Create the build directory if it doesn't exist
echo "- Creating the build directory if it doesn't already exist"
rm -rf build
mkdir -p build

# Start by archiving the application
echo "- Archiving the application"
xcodebuild -scheme "$application_scheme" archive -archivePath "build/Archive/$application_scheme.xcarchive" 

# Building the UI Tests scheme
echo "- Build the UITests scheme in the build directory for actual devices"
xcodebuild -scheme "$uitests_scheme" build-for-testing SYMROOT="build" -sdk iphoneos

echo "- Build the UITests scheme in the build directory for simulator"
xcodebuild -scheme "$uitests_scheme" build-for-testing SYMROOT="build" -arch x86_64 -sdk iphonesimulator

echo "- Export the application into an .ipa"
xcodebuild -exportArchive -archivePath "build/Archive/$application_scheme.xcarchive" -exportOptionsPlist aws-device-farm-export.plist -exportPath build/Archive

# Configure the package to upload to AWS Device Farm
echo "- Create a folder inside the build for for AWS Device Farm Deployment"
rm -rf build/aws-device-farm
mkdir -p build/aws-device-farm/Payload

# Copy the runner application inside the Payload directory
echo "- Copying the runner application '${application_scheme}${uitests_scheme}-Runner.app' inside the paylaod directory"
cp -R "build/Debug-iphoneos/${application_scheme}${uitests_scheme}-Runner.app" build/aws-device-farm/Payload

echo "- Compress the the Payload folder"
cd build/aws-device-farm

zip -r "$uitests_scheme.ipa" Payload

# Return to the original folder
cd ../../

# Send the info to DeviceFarm using awscli
echo "- Create the AWS Device Farm upload"
echo "- Upload the $application_scheme.ipa to Device Farm"
upload_response=$(aws devicefarm create-upload --project-arn "$aws_device_farm_project_arn" --name "$application_scheme.ipa" --type "IOS_APP")

echo "Response from AWS: '$upload_response'"
signed_url=$(echo "$upload_response" | jq -r '.upload.url')
app_arn=$(echo "$upload_response" | jq -r '.upload.arn')

echo "- Uploading to the signed URL"
curl -T "build/Archive/$application_scheme.ipa" "$signed_url"

echo "- Verifying upload status for package with arn: '$app_arn'"
for (( ; ; ))
do
get_upload_response=$(aws devicefarm get-upload --arn "$app_arn")
upload_status=$(echo "$get_upload_response" | jq -r '.upload.status')

if [ "$upload_status" == "SUCCEEDED" ]
then
echo "Upload successfully completed."
break
fi

echo "Upload still processing: '$upload_status'"
sleep 1
done


# Upload now the Tests Payload config.
echo "- Upload the $uitests_scheme.ipa to Device Farm"
upload_response=$(aws devicefarm create-upload --project-arn "$aws_device_farm_project_arn" --name "$uitests_scheme.ipa" --type "XCTEST_UI_TEST_PACKAGE")
signed_url=$(echo "$upload_response" | jq -r '.upload.url')
test_package_arn=$(echo "$upload_response" | jq -r '.upload.arn')
curl -T "build/aws-device-farm/$uitests_scheme.ipa" "$signed_url"

echo "- Verifying upload status for package with arn: '$test_package_arn'"
for (( ; ; ))
do
get_upload_response=$(aws devicefarm get-upload --arn "$test_package_arn")
upload_status=$(echo "$get_upload_response" | jq -r '.upload.status')

if [ "$upload_status" == "SUCCEEDED" ]
then
echo "Upload successfully completed."
break
fi

echo "Upload still processing: '$upload_status'"
sleep 1
done

# Schedule a run
echo "Scheduling a run for Upload ARN: '$test_package_arn'"
aws devicefarm schedule-run --project-arn "$aws_device_farm_project_arn" --device-pool-arn "$aws_device_farm_device_pool_arn" --app-arn "$app_arn" --test "type=XCTEST_UI,testPackageArn=$test_package_arn"
