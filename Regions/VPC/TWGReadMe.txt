/*
 * Terraform Multi-Region Transit Gateway Configuration
 * ====================================================
 * This configuration dynamically creates Transit Gateways, Route Tables, and propagates routes across multiple regions,
 * directing all traffic to a central region for secure syslog data storage. Follow these steps to update the template:
 *
 * Manual Changes Required:
 * ------------------------
 * 1. **Central Region**:
 *    - Update the `central_region` variable with the region that will act as the data sink (e.g., "us-east-1").
 *
 * 2. **Regions to Deploy**:
 *    - Update the `regions` variable with a list of all regions where Transit Gateways and VPCs are deployed.
 *      Example: ["us-east-1", "us-west-2", "eu-central-1", "ap-southeast-1"].
 *
 * 3. **VPC Attachments**:
 *    - Populate the `vpc_attachments` variable with a map of VPC attachment IDs for each region and environment.
 *    - Ensure the central region includes a `security` VPC for syslog storage.
 *      Example:
 *      "us-east-1" = {
 *        "dev"      = "vpc-attachment-id-dev",
 *        "security" = "vpc-attachment-id-security" // Central region VPC for data storage
 *      }
 *
 * 4. **Central Region CIDR Block**:
 *    - Update the `destination_cidr_block` in the `central_region_routing` resource to match the CIDR block
 *      of the central region's security zone VPC.
 *
 * 5. **AWS Providers**:
 *    - Ensure your AWS credentials and profiles are configured for the regions specified in the `regions` variable.
 *    - The `provider "aws"` block dynamically handles region-specific deployments using aliases.
 *
 * 6. **Tags**:
 *    - Update the `tags` variable to match your organization's tagging standards.
 *
 * Validation Steps:
 * -----------------
 * - Run `terraform validate` to check for syntax errors.
 * - Run `terraform plan` to ensure all resources are configured correctly and dependencies are resolved.
 *
 * Notes:
 * ------
 * - All data flow is restricted to the central region. Inter-region communication between non-central regions is blocked.
 * - Ensure the central region VPC has sufficient capacity for syslog data storage and processing.
 * - Review and adjust security group and IAM role policies as needed for access control.
 */
