# Recuperación de metadata de matchdev

Fecha: 5 de octubre de 2026. Ambiente: `matchdev` (sandbox). API: `68.0`.

Salesforce devolvió el estado `Succeeded` para la operación `09SWI00000hpIYR2A2`. Se recuperaron 2.995 componentes únicos en 3.120 archivos dentro de `force-app/main/default`. Se verificó la sintaxis de los 3.037 archivos XML de metadata, sin errores de parseo.

## Manifiestos

- `manifest/package.xml`: generado desde los archivos recuperados, para futuras recuperaciones de la metadata local.
- `manifest/package-inventory.xml`: inventario original del ambiente, incluyendo paquetes administrados y desbloqueados: 1.509 entradas de 70 tipos. Incluye entradas que la API lista pero no permite recuperar.
- `manifest/retrieve-unavailable.json`: detalle íntegro de los 113 diagnósticos de entradas rechazadas por Salesforce y los mensajes de la API.

El inventario enumera componentes padres; la recuperación también trae sus componentes hijos, por lo que los conteos del inventario y del código local difieren.

## Limitaciones reportadas por Salesforce

La recuperación no es una copia absoluta de toda la configuración interna del ambiente. La API rechazó campos de histórico (`__hd`), vistas de lista, `UiViewDefinition`, algunos reportes y dashboards de ejemplo, miembros del canal `ActivityEngagementVirtualChannel` y la aplicación conectada `CPQIntegrationUserApp`. También rechazó cuatro entradas `WorkflowFlowAutomation` por nombres sin el delimitador requerido; los cuatro flujos correspondientes sí se recuperaron en `flows/` junto con sus `FlowDefinition`.

Los archivos protegidos de paquetes instalados y la configuración sin soporte de Metadata API no se pueden considerar respaldados por esta recuperación. El detalle de rechazos se conserva para revisión; no se modificó metadata del ambiente.

## Volver a recuperar

Desde la raíz del proyecto:

```sh
sf project retrieve start --manifest manifest/package.xml --target-org matchdev --api-version 68.0 --wait 60 --json
```

Para volver a descubrir componentes nuevos del ambiente:

```sh
sf project generate manifest --from-org matchdev --include-packages managed unlocked --api-version 68.0 --output-dir manifest --name package-inventory --json
sf project retrieve start --manifest manifest/package-inventory.xml --target-org matchdev --api-version 68.0 --wait 60 --json
```

El ambiente predeterminado local ya era `matchdev`. `sfdx-project.json` se actualizó de API 67.0 a 68.0 para coincidir con el sandbox. Los resultados completos del CLI están en `.sf/retrieve-matchdev/`, una carpeta excluida por `.gitignore`.
