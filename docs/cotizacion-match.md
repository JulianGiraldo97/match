# Cotización PDF de Match

Implementada y desplegada en `matchdev` el 5 de octubre de 2026.

Actualización del 6 de octubre: [PDF nativo de Quote y preparación del correo](cotizacion-envio-nativo.md). La verificación del compositor está pendiente de autorizar el correo del sandbox.

## Uso

1. Guardar los servicios y los valores de la oportunidad.
2. En el encabezado de la oportunidad, seleccionar **Generar cotización**.
3. Esperar la vista previa y seleccionar **Abrir archivo** para descargar, o **Enviar por correo** para preparar el compositor estándar cuando el email esté habilitado.

Cada ejecución crea un registro estándar **Quote**, sus **QuoteLineItem** y un PDF independiente, incluso si los datos no cambian. El mismo archivo queda en **Archivos** de la oportunidad y de Quote. Durante una generación, la acción ignora invocaciones repetidas. Sin servicios, muestra “Agrega servicios a la oportunidad antes de generar la cotización” y no crea archivos.

El permission set **Generar cotización Match** (`Mat_Generar_Cotizacion`) quedó asignado al usuario actual de `matchdev`. Asignarlo a los demás usuarios que deban generar cotizaciones. También necesitan acceso al registro de oportunidad y a sus servicios, acceso a la lista de precios y permisos habituales de Salesforce Files para crear archivos vinculados; el permission set no amplía el acceso compartido a registros.

## Datos y diseño

| Elemento | Fuente |
| --- | --- |
| Cliente y oportunidad | `Opportunity.Account.Name`, `Opportunity.Name` |
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

- `matGenerateQuote`: acción rápida LWC sin modal, bloqueo durante la solicitud, notificaciones, refresco y navegación a la acción `Quote.Mat_VerCotizacion`; desde allí se abre `filePreview` con el `ContentDocumentId`.
- `MatQuoteData`: consultas con `WITH USER_MODE` y acceso compartido; validación de oportunidad y servicios.
- `MatQuotePdfController`: controlador de lectura y formato del PDF.
- `MatOpportunityQuote`: página Visualforce de solo lectura.
- `MatQuoteService`: renderiza con `getContentAsPDF()` antes de cualquier DML o savepoint. Después crea Quote y líneas estándar e inserta `QuoteDocument.Document`; Salesforce crea el archivo y su vínculo a Quote. `MatQuotePdfFileWriter` agrega el vínculo a oportunidad. Un fallo revierte todas las escrituras, incluidos productos y entradas de precios recién creados.
- `Mat_Generar_Cotizacion`: acceso a las clases y página, lectura del origen, creación de Quote/líneas/productos y edición de listas de precios para registrar entradas faltantes. No concede eliminación ni acceso a todos los registros.
- Acción `Opportunity.Mat_Generar_cotizacion`: primera acción del `platformActionList` del layout `Opportunity-Opportunity Layout`.

Los errores se muestran en español y permiten reintentar. Los renderizadores y escritores sustituibles son privados y accesibles solamente a pruebas con `@TestVisible`; la ruta normal siempre usa Visualforce y Salesforce Files.

Nombre solicitado: `Cotizacion_<oportunidad saneada>_<yyyyMMdd_HHmmss_SSS>.pdf`. La creación nativa de `QuoteDocument` añade el sufijo `_V1` al archivo. Se sustituyen caracteres incompatibles y se limita la longitud del nombre.

## Validación realizada

- Despliegue: **22 componentes**, éxito, ID `0AfWI00000KtOuD0AV`; después se desplegó únicamente la página para ajustar el espaciado y repetir la moneda.
- Apex: **18 métodos de prueba aprobados**. Selección de servicios, producto frente a talento/catálogo, duplicados, más de 200 filas, resumen guardado, descuentos distintos, referencias y valores vacíos, permisos insuficientes, oportunidad vacía o inválida, guardado/vínculo, renderizado antes del DML, archivos independientes y rollback de una escritura parcial.
- Cobertura: `MatQuoteData` **100 %**, `MatQuotePdfController` **100 %**, `MatQuoteService` **89,3 %**; conjunto **95,2 %**. Ejecución independiente posterior aprobada, ID `707WI0000PcdUrz`.
- LWC: **5 pruebas Jest aprobadas**, cobertura **100 %** de líneas, ramas, funciones y sentencias. Incluyen navegación, bloqueo de clics repetidos, errores, reintento y fallos del refresco posterior. ESLint aprobado.
- Salesforce Code Analyzer / PMD Recommended: **0 severidad 1**, **0 severidad 2**. Permanecen 3 advertencias de severidad 3 (complejidad y parámetros del factory) y 46 de severidad 4 (documentación y estilo de pruebas).
- PDF real: **65 servicios, 6 páginas A4**, inspección visual de todas las páginas. Logo, caracteres españoles, nombres largos, moneda y encabezados repetidos, condiciones en tres líneas. Resumen comprobado frente a oportunidad: **8.580.000 COP**, **7.309.600 COP**, **14,81 %**. No aparece el talento.
- Prueba real del botón: abre la vista previa nativa con descarga. Se comprobaron tres documentos independientes conservados antes de retirar la fixture. La oportunidad sin servicios muestra el mensaje esperado y mantiene **Archivos (0)**.
- Limpieza: cuenta, talento, catálogo, dos productos, dos oportunidades, 65 servicios y tres documentos sintéticos retirados de `matchdev`. Permission set temporal de escritura retirado y eliminado. No se purgó la papelera. Se conserva localmente el PDF de ejemplo en `output/pdf/cotizacion-match-ejemplo.pdf`.

Durante la comprobación, el flujo existente `Mat_Selecciona Servicios Oportunidad` mostró un fallo no gestionado en los registros sintéticos. La cotización funcionó correctamente; ese flujo no forma parte de este cambio.

## Despliegue y comprobaciones repetibles

Usar únicamente el manifiesto de esta funcionalidad; el manifiesto general contiene metadata adicional del ambiente.

```sh
sf project deploy start --dry-run --manifest manifest/package-cotizacion.xml --target-org matchdev --test-level RunSpecifiedTests --tests MatQuoteDataTest --tests MatQuotePdfControllerTest --tests MatQuoteServiceTest --tests MatQuoteRecordWriterTest --wait 15 --json
sf project deploy start --manifest manifest/package-cotizacion.xml --target-org matchdev --test-level RunSpecifiedTests --tests MatQuoteDataTest --tests MatQuotePdfControllerTest --tests MatQuoteServiceTest --tests MatQuoteRecordWriterTest --wait 15 --json
sf org assign permset --name Mat_Generar_Cotizacion --target-org matchdev --json
npx sfdx-lwc-jest -- --runInBand --coverage --testPathPattern matGenerateQuote
npx eslint force-app/main/default/lwc/matGenerateQuote
sf code-analyzer run --workspace force-app/main/default --target 'force-app/main/default/classes/MatQuote*.cls' --rule-selector pmd:Recommended --severity-threshold 2 --output-file .sf/cotizacion/code-analyzer-results.json
```

Las pruebas generan fixtures dentro de transacciones de prueba y no dejan datos comerciales. En API 68, su creación usa explícitamente modo sistema; las consultas y escrituras de producción usan modo usuario.

Referencias oficiales: [renderizar PDF desde Apex](https://developer.salesforce.com/docs/platform/salesforce-pages-developers-guide/guide/pages-output-pdf-render-in-apex.html) y [vista previa de archivos desde LWC](https://developer.salesforce.com/docs/platform/lwc/guide/use-open-files.html).
