resource "aws_cloudwatch_log_metric_filter" "taskserver_errorlog_all" {
  depends_on     = [module.marklogic_log_group.log_group_names]
  log_group_name = local.taskserver_error_log_group_name
  name           = "taskserver-errorlog-count-all-${var.environment}"
  pattern        = ""
  metric_transformation {
    name          = "taskserver-errorlog-count-all-transform-${var.environment}"
    namespace     = "${var.environment}/MarkLogic"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "taskserver_errorlog_warning" {
  depends_on     = [module.marklogic_log_group.log_group_names]
  log_group_name = local.taskserver_error_log_group_name
  name           = "taskserver-errorlog-count-warning-${var.environment}"
  pattern        = "\"Warning:\""
  metric_transformation {
    name          = "taskserver-errorlog-count-warning-transform-${var.environment}"
    namespace     = "${var.environment}/MarkLogic"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "taskserver_errorlog_error" {
  depends_on     = [module.marklogic_log_group.log_group_names]
  log_group_name = local.taskserver_error_log_group_name
  name           = "taskserver-errorlog-count-error-${var.environment}"
  pattern        = "\"Error:\""
  metric_transformation {
    name          = "taskserver-errorlog-count-error-transform-${var.environment}"
    namespace     = "${var.environment}/MarkLogic"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-marklogic"
  dashboard_body = jsonencode(
    {
      "widgets" : [
        {
          "height" : 6,
          "width" : 24,
          "y" : 26,
          "x" : 0,
          "type" : "log",
          "properties" : {
            "query" : "SOURCE '${local.taskserver_error_log_group_name}' | fields @timestamp, @message, @logStream, @log\n| sort @timestamp desc\n| limit 20",
            "region" : "eu-west-1",
            "stacked" : false,
            "title" : "Recent log group entries: ${local.taskserver_error_log_group_name}",
            "view" : "table"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 8,
          "x" : 6,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "disk_used_percent", "path", "/var/opt/MarkLogic", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Average",
            "period" : 300,
            "setPeriodToTimeRange" : false,
            "sparkline" : true,
            "trend" : true,
            "title" : "Data drive disk usage "
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 2,
          "x" : 6,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "disk_used_percent", "path", "/", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Average",
            "period" : 300,
            "setPeriodToTimeRange" : false,
            "sparkline" : true,
            "trend" : true,
            "title" : "System drive disk usage",
            "yAxis" : {
              "left" : {
                "max" : 100,
                "min" : 80
              }
            }
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 2,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              [aws_cloudwatch_log_metric_filter.taskserver_errorlog_all.metric_transformation[0].namespace,
              aws_cloudwatch_log_metric_filter.taskserver_errorlog_all.metric_transformation[0].name]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "period" : 900,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 8,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              [aws_cloudwatch_log_metric_filter.taskserver_errorlog_error.metric_transformation[0].namespace,
              aws_cloudwatch_log_metric_filter.taskserver_errorlog_error.metric_transformation[0].name]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "period" : 900,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 14,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              [aws_cloudwatch_log_metric_filter.taskserver_errorlog_warning.metric_transformation[0].namespace,
              aws_cloudwatch_log_metric_filter.taskserver_errorlog_warning.metric_transformation[0].name]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "period" : 900,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 2,
          "x" : 0,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "cpu_usage_active", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "period" : 300,
            "stat" : "Average"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 8,
          "x" : 0,
          "type" : "metric",
          "properties" : {
            "view" : "timeSeries",
            "stacked" : false,
            "metrics" : [
              ["${var.environment}/MarkLogic", "mem_used_percent", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "region" : "eu-west-1"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 2,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_reads"],
              [".", "diskio_writes"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "period" : 300,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 8,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_write_bytes"],
              [".", "diskio_read_bytes"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 20,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_iops_in_progress"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Maximum",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 14,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_io_time"],
              [".", "diskio_read_time"],
              [".", "diskio_write_time"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 14,
          "x" : 0,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "swap_used_percent", { id : "m1", stat : "Minimum" }],
              ["...", { id : "m2" }],
              ["...", { id : "m3", stat : "Maximum" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : "eu-west-1",
            "stat" : "Maximum",
            "period" : 300
          }
        },
        {
          "height" : 2,
          "width" : 24,
          "y" : 0,
          "x" : 0,
          "type" : "alarm",
          "properties" : {
            "title" : "",
            "alarms" : [
              aws_cloudwatch_metric_alarm.cpu_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.memory_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.system_disk_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.data_disk_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.data_disk_utilisation_high_sustained.arn
            ]
          }
        },
        {
          "height" : 15,
          "width" : 24,
          "y" : 32,
          "x" : 0,
          "type" : "explorer",
          "properties" : {
            "metrics" : [
              {
                "metricName" : "CPUUtilization",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Average"
              },
              {
                "metricName" : "NetworkIn",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Average"
              },
              {
                "metricName" : "NetworkOut",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Average"
              },
              {
                "metricName" : "NetworkPacketsIn",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Average"
              },
              {
                "metricName" : "NetworkPacketsOut",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Average"
              },
              {
                "metricName" : "StatusCheckFailed_Instance",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Sum"
              },
              {
                "metricName" : "StatusCheckFailed_System",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Sum"
              },
              {
                "metricName" : "StatusCheckFailed",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Sum"
              },
              {
                "metricName" : "Memory % Committed Bytes In Use",
                "resourceType" : "AWS::EC2::Instance",
                "stat" : "Average"
              }
            ],
            "aggregateBy" : {
              "key" : "",
              "func" : ""
            },
            "labels" : [
              {
                "key" : "marklogic:stack:name",
                "value" : "marklogic-stack-test"
              }
            ],
            "widgetOptions" : {
              "legend" : {
                "position" : "bottom"
              },
              "view" : "timeSeries",
              "stacked" : false,
              "rowsPerPage" : 50,
              "widgetsPerRow" : 3
            },
            "period" : 300,
            "splitBy" : "",
            "region" : "eu-west-1"
          }
        }
      ]
    }
  )
}
