#!/bin/sh
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_AWS_1
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_AWS_2
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_AWS_3
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_GRAPH_1
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_GRAPH_2
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_GRAPH_3
checkov -d ../infra --external-checks-dir ./custom_checks --check CUSTOM_GRAPH_4