# PDF nativo de Quote y preparación del correo

Desplegado en `matchdev` el 6 de octubre de 2026. La integración está implementada; la comprobación final del compositor de correo queda pendiente de habilitar el email del sandbox.

## Uso

1. Guardar los servicios de la oportunidad y seleccionar **Generar cotización**.
2. Se crea una Quote con sus líneas estándar y un PDF nativo. Se abre **Cotización Match**, con **Abrir archivo** y **Enviar por correo**.
3. **Enviar por correo** solicita abrir y completar la acción estándar existente `Quote.SendEmail`, con el archivo guardado como adjunto y asunto **Cotización Match**. Usa `lightning:quickActionAPI.setActionFieldValues`, con `submitOnSuccess: false`. El usuario debe escoger el destinatario, revisar el contenido y enviar desde Salesforce.
4. Para consultar una cotización anterior, abrir Quote y seleccionar **Ver PDF y enviar**. Se usa su último PDF guardado; no se vuelve a consultar ni renderizar la oportunidad.

No se enviaron correos en las pruebas.

## Bloqueo comprobado en el ambiente

En Configuración → Capacidad de entrega, `matchdev` tiene **Solamente emails del sistema**. El flujo nativo de Salesforce **PDF de email** muestra “El email no está configurado aún. Haga contacto con su administrador para obtener ayuda”. La nueva acción también devuelve un mensaje comprensible y permite reintentar conservando el PDF.

Está pendiente la autorización solicitada para cambiar a **Todos los emails**. Es una configuración global que habilita correo para usuarios y automatizaciones existentes. No se cambió este ajuste. Por este bloqueo aún no se confirmó en la interfaz que el compositor abra con el adjunto cargado; debe comprobarse después de habilitar el correo, sin enviar mensajes de prueba.

La llamada a Quick Action API requiere que `Quote.SendEmail` sea una acción visible y disponible en la página de Quote. La navegación completa desde oportunidad usa `window.open(url, "_self")` con la URL de la acción comprobada en Salesforce; el servicio de navegación sustituía el contexto por oportunidad. La URL establece explícitamente Quote como contexto de fondo para que la acción estándar pueda operar sobre esa cotización. Después de habilitar correo, verificar el compositor tanto desde la generación como al abrir **Ver PDF y enviar** desde Quote.

## Persistencia y componentes

`MatQuoteService.generateQuoteForPreview` devuelve `quoteId`, `quoteDocumentId`, `contentVersionId` y `contentDocumentId`. El método anterior `generateQuote` conserva su contrato de devolver `ContentDocumentId`.

El renderizado Visualforce ocurre antes de DML y savepoint. Después se crean catálogo faltante, Quote y líneas; `MatQuotePdfFileWriter` inserta `QuoteDocument.Document`. Salesforce crea automáticamente un solo `ContentVersion`, su `ContentDocument` y el vínculo a Quote. El escritor vincula el mismo documento a oportunidad. Un fallo revierte toda la transacción, incluidos los archivos nativos. Insertar únicamente `ContentVersionDocumentId` no funciona en este org; insertar ambos campos crea otro archivo, por lo que no se utiliza esa ruta.

Salesforce añade `_V1` al nombre nativo del PDF, construido desde el nombre saneado de Quote. Cada generación conserva una Quote y archivo independientes.

`matGenerateQuote` abre la acción `Quote.Mat_VerCotizacion`. El contenedor Aura `MatQuotePreviewAndEmail` conecta el LWC `matQuotePreview` con la API estándar de correo. Al abrir el compositor no dispara un evento de cierre que pudiera cerrarlo; al volver permite abrir el correo nuevamente. La vista previa incluye el PDF guardado y acceso al visor nativo de Files para descarga. En el navegador integrado de Codex, el iframe PDF no se mostró, pero **Abrir archivo** mostró correctamente el PDF mediante la vista previa nativa de Salesforce. El iframe del visor nativo de Quote se había comprobado en Chrome.

Las consultas y escrituras usan modo usuario y acceso compartido. El permission set `Mat_Generar_Cotizacion` agrega acceso al escritor y permisos `EmailSingle` y su dependencia `EditTask`. El layout Quote conserva la acción estándar `Quote.SendEmail` y añade **Ver PDF y enviar**. No se modificaron las fórmulas de origen, ni el layout de oportunidad en esta ampliación.

## Validación

- Despliegue limitado a **12 componentes**, ID `0AfWI00000Ku4La0AJ`, estado **Succeeded**, **33 métodos Apex aprobados**, cero fallos.
- Ajuste posterior de navegación y regreso del compositor: **3 componentes de interfaz**, despliegue `0AfWI00000Ktx2N0AR`, estado **Succeeded**; 12 pruebas Jest y ESLint aprobados.
- Navegación intermedia: despliegue de `matGenerateQuote` `0AfWI00000KuHc90AF`, estado **Succeeded**.
- Navegación completa final: despliegue de `matGenerateQuote` `0AfWI00000KuHnR0AV`, estado **Succeeded**; 12 pruebas Jest y ESLint aprobados.
- Validación previa `0AfWI00000KuGGH0A3`: 33 métodos aprobados. Cobertura del escritor **94,44 %** y servicio **90,91 %**.
- La ejecución independiente paralela `707WI0000Pcn4hd` produjo `UNABLE_TO_LOCK_ROW` en el setup del controlador al actualizar la lista estándar de precios; las otras tres clases aprobaron. Se repitió solamente `MatQuotePdfControllerTest` de forma síncrona: **4 métodos aprobados**, cero fallos. No se alteró código de producción por este bloqueo de pruebas.
- **12 pruebas Jest aprobadas**, dos suites. Cobertura total **100 %** de líneas, funciones y sentencias; **88,23 %** de ramas. ESLint aprobado para los componentes modificados.
- PMD Recommended, resultado `.sf/cotizacion/email-native/code-analyzer-results-20261006-0854.json`, resumen del parser oficial:

```json
{"total":17,"sev1":0,"sev2":0,"sev3":1,"sev4":16,"sev5":0}
```

El aviso moderado corresponde a complejidad del servicio; los bajos corresponden a documentación y uso de `runAs` en pruebas. El nuevo escritor no tiene hallazgos.

Prueba real conservada:

| Caso | Quote | PDF nativo | Archivo |
| --- | --- | --- | --- |
| Servicio Apex | `0Q0WI000004s9op0AA` / 00000005 | `0QDWI0000003qwX4AQ` | `069WI00000EaZYnYAN` |
| Botón en oportunidad | `0Q0WI000004sCMr0AM` / 00000006 | `0QDWI0000003qzl4AA` | `069WI00000EaeGkYAJ` |

Las cotizaciones 00000005 y 00000006 tienen **5 líneas**, tarifa guardada **6.000.000 COP**, tarifa negociada **5.070.000 COP**, descuento **15,50 %** y `GrandTotal` **5.070.000**. Cada una tiene un PDF nativo independiente. Se verificaron el logo, los nombres y descuentos por fila, el resumen, condiciones con saltos de línea y la descarga en la vista previa nativa. Se conservaron las cotizaciones anteriores. La cotización 00000007 (`0Q0WI000004sCgD0AU`) también se conserva como prueba de navegación; su PDF nativo es `0QDWI0000003r1N4AQ`.

Captura de la vista previa: `.sf/cotizacion/email-native/preview-real.jpg`. Datos y limpieza manual no ejecutada: `docs/datos-prueba-cotizacion-20261005.json` y `scripts/apex/limpiar-datos-prueba-cotizacion-20261005.apex`.

## Despliegue repetible

```sh
sf project deploy start --manifest manifest/package-cotizacion-email.xml --target-org matchdev --test-level RunSpecifiedTests --tests MatQuoteDataTest --tests MatQuotePdfControllerTest --tests MatQuoteServiceTest --tests MatQuoteRecordWriterTest --wait 15 --json
```

El manifiesto completo `manifest/package-cotizacion.xml` también incorpora los nuevos componentes.

Referencias oficiales: [API de acciones rápidas](https://developer.salesforce.com/docs/platform/lightning-component-reference/guide/aura-quick-action-api.html), [acciones que la API puede controlar](https://developer.salesforce.com/docs/platform/case-feed-dev-guide/guide/quickaction-api-considerations.html), [vista previa de Files](https://developer.salesforce.com/docs/platform/lwc/guide/use-open-files.html).

Las cotizaciones 00000007, 00000008 y 00000009 se conservaron durante la comprobación de las alternativas de navegación. Los IDs están en el registro de datos de prueba.

La URL con contexto de Quote abrió correctamente la acción al navegar directamente. La sesión de interfaz usada durante los despliegues continuó mostrando el contexto anterior de oportunidad al generar; la navegación completa final debe volver a verificarse en una sesión que cargue el componente actualizado. No se considera comprobado aún el flujo completo hasta abrir el compositor nativo y confirmar el adjunto.

Se recuperó el LWC final desde `matchdev` y se comprobó que su JavaScript coincide con el local, salvo el salto de línea final, incluida la navegación completa. La discrepancia observada en la sesión de UI es compatible con una definición anterior en caché; debe verificarse de nuevo al cargar el componente actualizado.
