# Registros estándar de Quote

Actualización del 6 de octubre: [PDF nativo de Quote y preparación del correo](cotizacion-envio-nativo.md).

Actualización desplegada en `matchdev` el 5 de octubre de 2026. **Generar cotización** ahora crea un Quote y sus líneas estándar, además del PDF. La lista relacionada de Quote añadida por el usuario permite abrir cada generación.

## Información guardada

| Registro | Campo | Contenido |
| --- | --- | --- |
| Quote | `OpportunityId`, `AccountId` | Oportunidad y cliente relacionados; AccountId lo deriva Salesforce |
| Quote | `Mat_Cliente__c`, `Mat_Nombre_oportunidad__c` | Nombres guardados al generar, para conservar el historial |
| Quote | `Mat_Moneda__c`, `Mat_Fecha_generacion__c` | Moneda comercial y fecha de generación |
| Quote | `Mat_Tarifa__c`, `Mat_Tarifa_negociada__c`, `Mat_Descuento__c` | Valores copiados directamente de oportunidad, sin recalcular |
| Quote | `Description` | Condiciones comerciales con sus saltos de línea |
| QuoteLineItem | `QuoteId`, `PricebookEntryId`, `Quantity`, `SortOrder` | Línea estándar, cantidad 1 por registro de servicio y orden del PDF |
| QuoteLineItem | `UnitPrice`, `Discount` | Tarifa y descuento del servicio de oportunidad |
| QuoteLineItem | `Mat_Tarifa__c`, `Mat_Tarifa_negociada__c`, `Mat_Descuento__c` | Valores originales guardados, sin depender de cálculos estándar ni cambios posteriores |
| QuoteLineItem | `Mat_Nombre_servicio__c` | Nombre del producto en el momento de generar; sin talento |
| QuoteLineItem | `Mat_Servicio_de_oportunidad__c` | Registro de servicio que originó esa fila |

Los dos campos de tarifa existentes en Quote se ampliaron a precisión 18 para admitir los mismos importes que el origen. Las filas repetidas se mantienen separadas. Quote queda en **Draft** y no se sincroniza con oportunidad; generar otra versión conserva la anterior. Las fórmulas y valores de oportunidad no cambian.

El layout de Quote muestra la sección **Cotización Match**, sus servicios cotizados y **Archivos**. El layout de QuoteLineItem muestra **Servicio cotizado Match** con los valores originales y la referencia de origen. Este despliegue no modificó el layout ni la página de oportunidad.

## Lista de precios

Se usa la lista ya indicada en `Opportunity.Pricebook2Id`; si está vacío, se usa la **Standard Price Book** existente. Cuando un producto no tiene una entrada, se crea con la tarifa del primer servicio de ese producto en el orden de la cotización. Para listas personalizadas se crean primero los precios estándar que Salesforce exige. Las entradas existentes conservan sus precios.

Cada línea usa su propia tarifa del servicio, aunque la lista de precios tenga otro importe. Productos o entradas inactivos muestran un mensaje para corregirlos; no se activan automáticamente. No se crean listas de precios nuevas ni se cambia `Opportunity.Pricebook2Id`.

Si falta el producto, se mantiene la fila y se usa un producto compartido **Servicio sin nombre**, identificado con `ProductCode = MATCH_QUOTE_UNNAMED_SERVICE`. Los números no disponibles permanecen nulos en los campos de copia; las columnas nativas requeridas utilizan cero. El PDF sigue mostrando **—** para números no disponibles. Descuentos fuera de 0–100 o tarifas negativas se rechazan con un mensaje porque las líneas estándar necesitan importes válidos.

La moneda comercial se conserva en `Mat_Moneda__c` y en el PDF. El ambiente no tiene `CurrencyIsoCode` por registro; esta actualización no habilita multimoneda ni hace conversiones. Los totales estándar de Salesforce se calculan desde las líneas; los campos Match y el PDF conservan los totales guardados de oportunidad como fuente.

## Transacción y acceso

El PDF se renderiza antes de cualquier escritura o savepoint. Después se registran los productos/entradas faltantes, se crea Quote con sus líneas y se guarda el archivo. Se inserta `QuoteDocument.Document`, que crea automáticamente un archivo vinculado a Quote. Un `ContentDocumentLink` adicional vincula el mismo documento a oportunidad. Cualquier fallo revierte todas esas escrituras.

Las consultas y DML usan modo usuario y las clases declaran acceso compartido. Se actualizó el permission set existente **Generar cotización Match**, que ya estaba asignado al usuario actual. Agrega creación/lectura de Quote y QuoteLineItem, edición de Quote y de listas de precios, y creación de productos para el caso sin referencia. No concede eliminación ni acceso global a registros.

## Comprobaciones

- Despliegue `0AfWI00000KtQw10AF`: **27 componentes**, **29 métodos Apex aprobados**.
- Ejecución independiente `707WI0000Pcdxjv`: aprobada, cobertura de ejecución **95 %**. Controlador de persistencia **100 %**, servicio **91,8 %**, catálogo **90,8 %**, lector **100 %**.
- Pruebas LWC: **5 aprobadas**, cobertura **100 %**. ESLint aprobado.
- PMD Recommended: **0 críticos**, **0 altos**; 8 avisos moderados y 62 bajos, incluidos avisos de estilo que no reconocen las aserciones delegadas al helper de pruebas. Resultado: `.sf/cotizacion/quote-record/code-analyzer-results-20261005-160610.json`.
- Pruebas de líneas duplicadas, tarifas independientes de lista de precios, valores guardados tras cambios del origen, producto ausente, números nulos, lista personalizada, datos inactivos/incorrectos y **254 líneas**.
- Prueba real de persistencia y PDF: Quote **00000001**, **5 líneas**, totales **6.000.000 COP / 5.070.000 COP / 15,50 %**; mismo archivo relacionado con Quote y oportunidad. El PDF A4 se inspeccionó y sus cifras coinciden con Quote.
- Prueba real multipágina: Quote **00000002**, **65 líneas**, totales **8.580.000 COP / 7.309.600 COP / 14,81 %**.

Se conservaron los dos Quotes de datos ficticios para pruebas manuales:

- [Quote 00000001](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Quote/0Q0WI000004rQOf0AM/view)
- [Quote 00000002](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Quote/0Q0WI000004rQV70AM/view)

El despliegue de esta ampliación usa `manifest/package-cotizacion-quote.xml`. El manifiesto completo `manifest/package-cotizacion.xml` también incluye los componentes nuevos. Los IDs y el script de limpieza manual se documentan en `docs/datos-prueba-cotizacion.md`; no se ejecutó la limpieza de estos datos.

Referencias oficiales: [Quote](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_quote.htm), [QuoteLineItem](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_quotelineitem.htm), [PricebookEntry](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_pricebookentry.htm).
