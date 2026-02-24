from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckCategories, CheckResult


class EC2InPrivateSubnet(BaseResourceCheck):
    def __init__(self):
        name = "Ensure EC2 instance is deployed in a private subnet"
        id = "CUSTOM_AWS_2"
        supported_resources = ["aws_instance"]
        categories = [CheckCategories.NETWORKING]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        subnet_id = conf.get("subnet_id", [])
        if isinstance(subnet_id, list):
            subnet_id = subnet_id[0] if subnet_id else ""
        if "private" in str(subnet_id):
            return CheckResult.PASSED
        return CheckResult.FAILED


check = EC2InPrivateSubnet()
