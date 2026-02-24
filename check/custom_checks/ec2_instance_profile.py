from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckCategories, CheckResult


class EC2InstanceProfile(BaseResourceCheck):
    def __init__(self):
        name = "Ensure EC2 instance has an IAM instance profile attached"
        id = "CUSTOM_AWS_1"
        supported_resources = ["aws_instance"]
        categories = [CheckCategories.IAM]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        iam_profile = conf.get("iam_instance_profile")
        if iam_profile and iam_profile not in [None, [""], ""]:
            return CheckResult.PASSED
        return CheckResult.FAILED


check = EC2InstanceProfile()
