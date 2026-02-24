from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckCategories, CheckResult


class SecurityGroupHasDescription(BaseResourceCheck):
    def __init__(self):
        name = "Ensure every security group has a description"
        id = "CUSTOM_AWS_3"
        supported_resources = ["aws_security_group"]
        categories = [CheckCategories.NETWORKING]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        description = conf.get("description", [None])
        if isinstance(description, list):
            description = description[0] if description else None
        if description and description not in ["", "Managed by Terraform"]:
            return CheckResult.PASSED
        return CheckResult.FAILED


check = SecurityGroupHasDescription()
