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

# how to compose the widget string: join("",[each.value, "-dev", var.location, var.platform])
# from https://stackoverflow.com/questions/67897315/can-terraform-concatenate-variables-fed-from-a-for-each-loop-with-a-string
# no, don't think this works
# need to perform a mapping, something like this? https://stackoverflow.com/questions/59381410/how-can-i-convert-a-list-to-a-string-in-terraform
# some kind of super cursed format() use inside a list comprehension? only need to make the metric list which can go into the jsonencode() where appropriate

locals {
  read_iops = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeReadOps", "VolumeId", "${volume.id}", { "id" : "readOps_${replace(volume.availability_zone, "-", "_")}", "stat" : "Sum", "visible" : false }]
  ]
  write_iops = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeWriteOps", "VolumeId", "${volume.id}", { "id" : "writeOps_${replace(volume.availability_zone, "-", "_")}", "stat" : "Sum", "visible" : false }]
  ]
  throughput = [for volume in aws_ebs_volume.marklogic_data_volumes :
    [{
      "expression" : "(readOps_${replace(volume.availability_zone, "-", "_")} + writeOps_${replace(volume.availability_zone, "-", "_")})/PERIOD(readOps_${replace(volume.availability_zone, "-", "_")})",
      "label" : "${volume.availability_zone}",
      "id" : "throughput_${replace(volume.availability_zone, "-", "_")}"
    }]
  ]
  read_iops_visible = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeReadOps", "VolumeId", "${volume.id}", { "id" : "readOps_${replace(volume.availability_zone, "-", "_")}", "stat" : "Sum" }]
  ]
  write_iops_visible = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeWriteOps", "VolumeId", "${volume.id}", { "id" : "writeOps_${replace(volume.availability_zone, "-", "_")}", "stat" : "Sum" }]
  ]
  queue_length = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeQueueLength", "VolumeId", "${volume.id}", { "region" : data.aws_region.current.name, "label" : "${volume.availability_zone}" }]
  ]
  idle_time = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeIdleTime", "VolumeId", "${volume.id}", { "region" : data.aws_region.current.name, "label" : "${volume.availability_zone}" }]
  ]
  read_latency = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeTotalReadTime", "VolumeId", "${volume.id}", { "stat" : "Average", "region" : data.aws_region.current.name, "label" : "${volume.availability_zone}" }]
  ]
  write_latency = [for volume in aws_ebs_volume.marklogic_data_volumes :
    ["AWS/EBS", "VolumeTotalWriteTime", "VolumeId", "${volume.id}", { "stat" : "Average", "region" : data.aws_region.current.name, "label" : "${volume.availability_zone}" }]
  ]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-marklogic"
  dashboard_body = jsonencode(
    {
      "widgets" : [
        {
          "height" : 3,
          "width" : 24,
          "y" : 0,
          "x" : 0,
          "type" : "alarm",
          "properties" : {
            "title" : "",
            "alarms" : [
              aws_cloudwatch_metric_alarm.cpu_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.memory_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.memory_utilisation_high_sustained.arn,
              aws_cloudwatch_metric_alarm.system_disk_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.data_disk_utilisation_high.arn,
              aws_cloudwatch_metric_alarm.data_disk_utilisation_high_sustained.arn,
              aws_cloudwatch_metric_alarm.healthy_host_low.arn,
              aws_cloudwatch_metric_alarm.unhealthy_host_high.arn,
            ]
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 9,
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
            "region" : data.aws_region.current.name,
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
          "y" : 3,
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
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "period" : 300,
            "setPeriodToTimeRange" : false,
            "sparkline" : true,
            "trend" : true,
            "title" : "System drive disk usage",
            "yAxis" : {
              "left" : {
                "max" : 100,
                "min" : 0
              }
            }
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 3,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              [aws_cloudwatch_log_metric_filter.taskserver_errorlog_all.metric_transformation[0].namespace,
              aws_cloudwatch_log_metric_filter.taskserver_errorlog_all.metric_transformation[0].name]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "period" : 900,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 9,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              [aws_cloudwatch_log_metric_filter.taskserver_errorlog_error.metric_transformation[0].namespace,
              aws_cloudwatch_log_metric_filter.taskserver_errorlog_error.metric_transformation[0].name]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "period" : 900,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 15,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              [aws_cloudwatch_log_metric_filter.taskserver_errorlog_warning.metric_transformation[0].namespace,
              aws_cloudwatch_log_metric_filter.taskserver_errorlog_warning.metric_transformation[0].name]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "period" : 900,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 3,
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
            "region" : data.aws_region.current.name,
            "period" : 300,
            "stat" : "Average"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 9,
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
            "region" : data.aws_region.current.name
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 3,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_reads"],
              [".", "diskio_writes"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "period" : 300,
            "stat" : "Sum"
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 9,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_write_bytes"],
              [".", "diskio_read_bytes"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 21,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["${var.environment}/MarkLogic", "diskio_iops_in_progress"]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Maximum",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 15,
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
            "region" : data.aws_region.current.name,
            "stat" : "Sum",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 15,
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
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "period" : 300
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 21,
          "x" : 0,
          "type" : "metric",
          "properties" : {
            "metrics" : [
              ["AWS/NetworkELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.ml["8001"].arn_suffix, "LoadBalancer", aws_lb.ml_lb.arn_suffix],
              ["AWS/NetworkELB", "UnHealthyHostCount", "TargetGroup", aws_lb_target_group.ml["8001"].arn_suffix, "LoadBalancer", aws_lb.ml_lb.arn_suffix, { stat : "Maximum" }]
            ],
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Minimum",
            "period" : 300
          }
        },
        {
          "height" : 5,
          "width" : 24,
          "y" : 27,
          "x" : 0,
          "type" : "log",
          "properties" : {
            "query" : "SOURCE '${local.taskserver_error_log_group_name}' | fields @timestamp, @message, @logStream, @log\n| filter @message like /Error/\n| sort @timestamp desc\n| limit 5",
            "region" : data.aws_region.current.name,
            "stacked" : false,
            "title" : "Recent Error log group entries: ${local.taskserver_error_log_group_name}",
            "view" : "table"
          }
        },
        {
          "height" : 5,
          "width" : 24,
          "y" : 3,
          "x" : 0,
          "type" : "log",
          "properties" : {
            "query" : "SOURCE '${local.taskserver_error_log_group_name}' | fields @timestamp, @message, @logStream, @log\n| filter @message like /Warning/\n| sort @timestamp desc\n| limit 5",
            "region" : data.aws_region.current.name,
            "stacked" : false,
            "title" : "Recent Warning log group entries: ${local.taskserver_error_log_group_name}",
            "view" : "table"
          }
        },
        {
          "height" : 5,
          "width" : 24,
          "y" : 37,
          "x" : 0,
          "type" : "log",
          "properties" : {
            "query" : "SOURCE '${local.taskserver_error_log_group_name}' | fields @timestamp, @message, @logStream, @log\n| sort @timestamp desc\n| limit 5",
            "region" : data.aws_region.current.name,
            "stacked" : false,
            "title" : "Recent log group entries: ${local.taskserver_error_log_group_name}",
            "view" : "table"
          }
        },
        {
          "height" : 24,
          "width" : 24,
          "y" : 42,
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
                "value" : local.stack_name
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
            "region" : data.aws_region.current.name
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 48,
          "x" : 0,
          "type" : "metric",
          "properties" : {
            "metrics" : concat(local.read_iops, local.write_iops, local.throughput),
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume throughput",
            "period" : 300,
            "yAxis" : {
                "left": {
                    "label": "IOPS/300s",
                    "showUnits": false
                }
            },
                "annotations": {
                "horizontal": [
                    {
                        "label": "IOPS limit",
                        "value": var.data_volume.iops
                    }
                ]
            }
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 48,
          "x" : 6,
          "type" : "metric",
          "properties" : {
            "metrics" : local.read_iops_visible,
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume read IOPS",
            "period" : 300,
            "yAxis" : {
              "left" : {
                "label" : "IOPS/300s",
                "showUnits" : false
              }
            },
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 48,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : local.write_iops_visible,
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume write IOPS",
            "period" : 300,
            "yAxis" : {
              "left" : {
                "label" : "IOPS/300s",
                "showUnits" : false
              }
            },
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 48,
          "x" : 18,
          "type" : "metric",
          "properties" : {
            "metrics" : local.idle_time,
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume idle time",
            "period" : 300,
            "yAxis" : {
              "left" : {
                "label" : "Idle time"
              }
            }
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 54,
          "x" : 0,
          "type" : "metric",
          "properties" : {
            "metrics" : local.queue_length,
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume queue length",
            "period" : 300,
            "yAxis" : {
              "left" : {
                "label" : "Queue length",
                "showUnits" : false
              }
            }
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 54,
          "x" : 6,
          "type" : "metric",
          "properties" : {
            "metrics" : local.read_latency,
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume read latency",
            "period" : 300,
            "yAxis" : {
              "left" : {
                "label" : "Read latency"
              }
            }
          }
        },
        {
          "height" : 6,
          "width" : 6,
          "y" : 54,
          "x" : 12,
          "type" : "metric",
          "properties" : {
            "metrics" : local.write_latency,
            "view" : "timeSeries",
            "stacked" : false,
            "region" : data.aws_region.current.name,
            "stat" : "Average",
            "title" : "EBS volume write latency",
            "period" : 300,
            "yAxis" : {
              "left" : {
                "label" : "Write latency"
              }
            }
          }
        }
      ]
    }
  )
}
