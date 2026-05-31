# Customer Data Protection Policy

Update packages must never overwrite these customer-owned paths:

```text
license/
uploads/
backups/
logs/
app/application.properties
database customer data
```

Application updates may replace:

```text
app/jig-management-system.jar
package-owned launcher scripts
package-owned documentation templates
```

Database migrations must be explicit in release notes. A release must say whether migration is required and how the customer should run it.
