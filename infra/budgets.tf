resource "aws_budgets_budget" "monthly_cost" {
  name              = "monthly-prod-budget"
  budget_type       = "COST"
  time_unit         = "MONTHLY"

  limit_amount      = "50"
  limit_unit        = "USD"

  cost_types {
    include_credit             = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"
    subscriber_email_addresses = ["kostia.shiian@gmail.com"]
  }
}