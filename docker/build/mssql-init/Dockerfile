# escape=`

ARG PARENT_IMAGE
ARG SPE_IMAGE
ARG HEADLESS_SERVICES_IMAGE

FROM ${SPE_IMAGE} AS spe
FROM ${HEADLESS_SERVICES_IMAGE} AS headless_services
FROM ${PARENT_IMAGE}

COPY .\StartInit.ps1 c:\StartInit.ps1
COPY .\DeployDatabases.ps1 c:\DeployDatabases.ps1
COPY .\SetSitecoreAdminPassword.ps1 c:\SetSitecoreAdminPassword.ps1

# Copy and init the JSS / Headless Services Module
COPY --from=headless_services C:\module\db C:\jss_data

# Add SPE module
COPY --from=spe C:\module\db C:\resources\spe