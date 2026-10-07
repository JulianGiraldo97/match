# Cotización PDF de Match

Implementada en `matchdev` y desplegada en **`matchprod` el 7 de octubre de 2026**, con API **67.0**. La prueba E2E de generación, vista previa, descarga y preparación de correo nativo está aprobada.

Actualización del 7 de octubre: el PDF incluye **Talento** debajo de Oportunidad, desde `Opportunity.Mat_Talento__r.Name`. El permission set concede lectura de `Opportunity.Mat_Talento__c`. Delta: `manifest/package-cotizacion-talento.xml`, desplegado como `0AfWI00000Kvp8j0AB` con 41 pruebas Apex aprobadas y cobertura 100 % del lector/controlador. Se revisó un PDF real.

Actualización del 6 de octubre: [PDF nativo de Quote y preparación del correo](cotizacion-envio-nativo.md). El compositor y el adjunto fueron comprobados en producción, sin enviar correos.

La funcionalidad y todos sus manifiestos usan **API 67.0**, compatible con producción. El redespliegue de versiones utiliza `manifest/package-cotizacion-api67.xml`; este delta contiene únicamente los 15 componentes versionados y requiere que los campos, permisos y demás dependencias de la funcionalidad ya existan. Para una instalación completa usar `manifest/package-cotizacion.xml`. Redespliegue en `matchdev`: `0AfWI00000Kw1D70AJ`, 15 componentes, 41 pruebas Apex y 12 pruebas LWC aprobadas; versión 67 verificada en el org y PDF real validado. Quote de comprobación: `0Q0WI000004tZFl0AM`.

## Uso

1. Guardar los servicios y los valores de la oportunidad.
2. En el encabezado de la oportunidad, seleccionar **Generar cotización**.
3. Esperar la vista previa y seleccionar **Abrir archivo** para descargar, o **Enviar por correo** para preparar el compositor estándar cuando el email esté habilitado.

Cada ejecución crea un registro estándar **Quote**, sus **QuoteLineItem** y un PDF independiente, incluso si los datos no cambian. El mismo archivo queda en **Archivos** de la oportunidad y de Quote. Durante una generación, la acción ignora invocaciones repetidas. Sin servicios, muestra “Agrega servicios a la oportunidad antes de generar la cotización” y no crea archivos.

El permission set **Generar cotización Match** (`Mat_Generar_Cotizacion`) está asignado al usuario actual en `matchdev` y `matchprod`. Asignarlo a los demás usuarios que deban generar cotizaciones. También necesitan acceso al registro de oportunidad y a sus servicios, acceso a la lista de precios y permisos habituales de Salesforce Files para crear archivos vinculados; el permission set no amplía el acceso compartido a registros.

## Datos y diseño

| Elemento | Fuente |
| --- | --- |
| Cliente y oportunidad | `Opportunity.Account.Name`, `Opportunity.Name` |
| Talento del encabezado | `Opportunity.Mat_Talento__r.Name`, debajo de Oportunidad; **—** si está vacío |
| Moneda | `Opportunity.Mat_Moneda__c` |
| Servicio, sin talento | `Mat_Servicios_de_oportunidad__c.Mat_Servicio_de_talento__r.Servicio__r.Name` |
| Tarifa, descuento y tarifa negociada por fila | `Mat_Tarifa__c`, `Mat_Descuento__c`, `Mat_Tarifa_negociada__c` del servicio de oportunidad |
| Resumen | Los tres campos financieros guardados de `Opportunity` |
| Condiciones comerciales | `Opportunity.Condiciones_comerciales__c`, si tiene contenido |
| Logo | `Mat_LogoCotizacion`, copia del PNG existente `Diseno_sin_titulo3` |

Se consultan exclusivamente los servicios vinculados por `Mat_Oportunidad__c`. Se mantienen filas duplicadas, ordenadas por nombre del producto, fecha de creación e ID como desempate. La consulta separada soporta más de 200 servicios. Sin producto se conserva la fila como **Servicio sin nombre**; valores numéricos nulos se presentan con **—**.

Formato A4 en español, fondo blanco, acentos amarillos, encabezados repetidos y numeración de páginas. Importes con puntos para miles, de acuerdo con la escala de cero decimales de los campos existentes; descuentos con coma y dos decimales. La moneda se repite en los encabezados de tarifas y en el resumen. La fecha usa la zona horaria del usuario.

Los acumulados y fórmulas existentes conservan su funcionamiento. Los campos y fórmulas de oportunidad y servicios conservan sus valores y funcionamiento. El documento refleja los datos guardados al generarlo; no agrega impuestos, conversiones ni envío automático.

## Componentes y seguridad

- `matGenerateQuote`: acción rápida LWC sin modal, bloqueo durante la solicitud, notificaciones y refresco. En una consola, `IsConsoleNavigation` y `openTab({recordId: quoteId, focus: true})` enfocan Quote antes de abrir `Quote.Mat_VerCotizacion`. Esto evita que el compositor conserve el contexto de Opportunity. Desde la vista previa se abre `filePreview` con el `ContentDocumentId`.
- `Quote_Record_Page`: conserva la configuración existente de producción y agrega las acciones dinámicas **Ver PDF y enviar** y **Email**, junto a la acción de aprobación existente. Los tres layouts se combinaron con las versiones de producción para conservar sus campos y listas relacionadas.
- `MatQuoteData`: consultas con `WITH USER_MODE` y acceso compartido; validación de oportunidad y servicios.
- `MatQuotePdfController`: controlador de lectura y formato del PDF.
- `MatOpportunityQuote`: página Visualforce de solo lectura.
- `MatQuoteService`: renderiza con `getContentAsPDF()` antes de cualquier DML o savepoint. Después crea Quote y líneas estándar e inserta `QuoteDocument.Document`; Salesforce crea el archivo y su vínculo a Quote. `MatQuotePdfFileWriter` agrega el vínculo a oportunidad. Un fallo revierte todas las escrituras, incluidos productos y entradas de precios recién creados.
- `Mat_Generar_Cotizacion`: acceso a las clases y página, lectura del origen, creación de Quote/líneas/productos y edición de listas de precios para registrar entradas faltantes. No concede eliminación ni acceso a todos los registros.
- Acción `Opportunity.Mat_Generar_cotizacion`: primera acción del `platformActionList` del layout `Opportunity-Opportunity Layout`.

Los errores se muestran en español y permiten reintentar. Los renderizadores y escritores sustituibles son privados y accesibles solamente a pruebas con `@TestVisible`; la ruta normal siempre usa Visualforce y Salesforce Files.

Nombre solicitado: `Cotizacion_<oportunidad saneada>_<yyyyMMdd_HHmmss_SSS>.pdf`. La creación nativa de `QuoteDocument` añade el sufijo `_V1` al archivo. Se sustituyen caracteres incompatibles y se limita la longitud del nombre.

## Validación en producción — 7 de octubre de 2026

- Despliegue principal: `0AfbV000001pj5lSAA`, **55 componentes**, validación `0AfbV000001pj2XSAQ` con **43 pruebas Apex aprobadas**; cobertura conjunta **94,82 %**. Todas las clases, Visualforce, LWC y Aura usan API 67.
- Página activa de Quote: `0AfbV000001pjKHSAY`; navegación de consola: `0AfbV000001pk1pSAA`. **13 pruebas Jest** y ESLint aprobados. Validación final del manifiesto local, `0AfbV000001pkY5SAI`: 56 componentes y 43/43 pruebas, cero errores.
- PMD Recommended: cero hallazgos de severidad 1 o 2; 9 de severidad 3 y 80 de severidad 4 por complejidad, documentación y patrones de pruebas.
- E2E desde el botón: Quote y líneas estándar, PDF vinculado a Quote y Opportunity, logo, talento, filas duplicadas, descuentos distintos, condiciones y tarifas extranjeras. Caso USD: **2.800.000 COP**, **2.450.000 COP**, **12,50 %**, **700 USD / 613 USD**.
- Caso multipágina: **65 líneas, seis páginas A4**, encabezados repetidos y nombres largos; **8.580.000 COP / 7.309.600 COP / 14,81 %**. Se inspeccionaron las seis páginas.
- Vista previa nativa y descarga aprobadas; el PDF descargado desde el navegador coincide con el archivo recuperado por API. El compositor nativo abrió con **un solo adjunto** y asunto **Cotización Match**, desde Quote y desde la generación en consola. No se enviaron mensajes.
- Dos generaciones USD conservaron dos Quotes y archivos distintos. La oportunidad vacía mostró el mensaje esperado y mantuvo cero Quotes/archivos.
- Limpieza verificada: tres Quotes, 71 líneas, tres PDFs, 68 servicios y sus cuentas, oportunidades, talento, productos y catálogo sintéticos retirados. No se purgó la papelera. Evidencia local: `.sf/cotizacion/matchprod-20261007/report.md`; PDFs en `output/pdf/matchprod-e2e-cotizacion-*.pdf`.

La validación global inicial encontró además un fallo preexistente de `Mat_SlackOpportunityPublisherTest` por acceso a `Mat_Talentos__c.Mat_Slack_usuario_ID__c`. El despliegue de esta funcionalidad usó sus cinco clases de prueba específicas; no modificó Slack.

## Despliegue y comprobaciones repetibles

Para diagnosticar fallos de persistencia en la validación de un change set, incluir `MatQuotePersistenceDiagnosticTest`. Sus dos métodos invocan directamente los escritores reales de Quote/líneas y PDF/vínculos, conservando el modo usuario y dejando visible la excepción original que `MatQuoteService` sustituye por un mensaje amigable. No cambia el comportamiento de la funcionalidad y sus datos se revierten al terminar las pruebas. Delta de instalación: `manifest/package-cotizacion-diagnostico.xml`, API 67.

Diagnóstico desplegado en `matchdev`: `0AfWI00000Kw2M50AJ`, únicamente la nueva clase, con **43 pruebas Apex aprobadas**. PMD Recommended: sin hallazgos de severidad 1 o 2; un aviso de severidad 3 por aserciones delegadas a un helper y dos de severidad 4 por no envolver cada método en `runAs` (se prueba con el usuario real de validación). En producción, el diagnóstico mostró acceso insuficiente a campos de Quote para el usuario de validación. Se instalaron primero los campos y permisos de objetos/campos, se asignó `Mat_Generar_Cotizacion` al usuario y después se validó/desplegó el paquete completo con éxito. Asignar el permission set antes de ejecutar las pruebas que escriben en modo usuario.

El fallo de producción de `Mat_SlackOpportunityPublisherTest` identifica acceso insuficiente a `Mat_Talentos__c.Mat_Slack_usuario_ID__c`. Es un fallo independiente de la cotización: revisar el acceso efectivo del usuario de esa prueba y el permission set de Slack en producción. No se cambió esa integración.

Usar únicamente el manifiesto de esta funcionalidad; el manifiesto general contiene metadata adicional del ambiente.

```sh
sf project deploy start --dry-run --manifest manifest/package-cotizacion.xml --target-org matchdev --test-level RunSpecifiedTests --tests MatQuoteDataTest --tests MatQuotePdfControllerTest --tests MatQuoteServiceTest --tests MatQuoteRecordWriterTest --tests MatQuotePersistenceDiagnosticTest --wait 15 --json
sf project deploy start --manifest manifest/package-cotizacion.xml --target-org matchdev --test-level RunSpecifiedTests --tests MatQuoteDataTest --tests MatQuotePdfControllerTest --tests MatQuoteServiceTest --tests MatQuoteRecordWriterTest --tests MatQuotePersistenceDiagnosticTest --wait 15 --json
sf org assign permset --name Mat_Generar_Cotizacion --target-org matchdev --json
npx sfdx-lwc-jest -- --runInBand --coverage --testPathPattern matGenerateQuote
npx eslint force-app/main/default/lwc/matGenerateQuote
sf code-analyzer run --workspace force-app/main/default --target 'force-app/main/default/classes/MatQuote*.cls' --rule-selector pmd:Recommended --severity-threshold 2 --output-file .sf/cotizacion/code-analyzer-results.json
```

Las pruebas generan fixtures dentro de transacciones de prueba y no dejan datos comerciales. Los fixtures de prueba usan explícitamente modo sistema; las consultas y escrituras de la funcionalidad usan modo usuario.

Referencias oficiales: [renderizar PDF desde Apex](https://developer.salesforce.com/docs/platform/salesforce-pages-developers-guide/guide/pages-output-pdf-render-in-apex.html) y [vista previa de archivos desde LWC](https://developer.salesforce.com/docs/platform/lwc/guide/use-open-files.html).
