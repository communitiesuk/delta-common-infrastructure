To use this module you need to manually create two AWS secrets:

* `ml-license-${var.environment}` with a value of the form `{"licensee":"foo","license_key":"bar"}`
* `ml-admin-user-${var.environment}` with a value of the form `{"username":"foo","password":"bar"}`