# Datos de prueba de cotizaciones

Creados en el sandbox `matchdev` el 5 de octubre de 2026. Permanecen disponibles para pruebas manuales. Todos los registros son ficticios y llevan el prefijo `TEST -`.

| Caso          | Servicios | Tarifa total COP | Tarifa negociada COP | Descuento | Abrir                                                                                                                   |
| ------------- | --------: | ---------------: | -------------------: | --------: | ----------------------------------------------------------------------------------------------------------------------- |
| Básica        |         5 |        6.000.000 |            5.070.000 |   15,50 % | [Oportunidad](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Opportunity/006WI00000RbuLRYAZ/view) |
| Multipágina   |        65 |        8.580.000 |            7.309.600 |   14,81 % | [Oportunidad](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Opportunity/006WI00000RbuLSYAZ/view) |
| Sin servicios |         0 |                0 |                    0 | Sin valor | [Oportunidad](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Opportunity/006WI00000RbuLTYAZ/view) |

La básica contiene dos filas del producto **TEST - Reel para redes sociales** con tarifas y descuentos distintos. Los descuentos por fila son 0 %, 10 %, 15 %, 20 % y 25 %. La multipágina incluye productos repetidos, nombres largos y descuentos de 0 %, 10 %, 20 % y 30 %. Ambas incluyen condiciones comerciales con saltos de línea.

Para probar, abrir una oportunidad y seleccionar **Generar cotización**. Revisar el PDF, descargarlo y volver a generarlo para comprobar que se conserva el anterior. En la oportunidad sin servicios se debe mostrar el mensaje de validación sin crear un archivo.

Se crearon 1 cuenta, 1 talento, 4 productos, 4 servicios de catálogo, 3 oportunidades y 70 servicios de oportunidad. Se verificaron vínculos, cantidades y totales contra las filas guardadas. Los permisos temporales usados para crear datos fueron retirados y eliminados; no se modificó la funcionalidad de cotización. Después de implementar los registros estándar, se generaron dos Quotes y sus PDFs para validar el flujo completo: `00000001` (5 líneas) y `00000002` (65 líneas). Los productos se incorporaron a la lista estándar de precios; cada línea conserva la tarifa de su servicio de oportunidad.

Los IDs exactos están en `docs/datos-prueba-cotizacion-20261005.json`. El script de creación está en `scripts/apex/crear-datos-prueba-cotizacion.apex`; evita duplicar el conjunto si la cuenta de prueba existe y requiere permisos de creación/escritura sobre los objetos y campos usados.

## Limpieza opcional

El script de limpieza está preparado y **no se ha ejecutado**. Cuando ya no se necesiten estos datos, usar una cuenta con permisos de eliminación:

```sh
sf apex run --file scripts/apex/limpiar-datos-prueba-cotizacion-20261005.apex --target-org matchdev --json
```

Elimina únicamente los IDs de este conjunto, los Quotes de sus oportunidades y sus relaciones, junto con cotizaciones generadas en esas tres oportunidades cuyo título empieza por `Cotizacion_TEST - Cotización`. No purga la papelera. No ejecutar hasta terminar las pruebas.

## Pruebas del PDF nativo y correo — 6 de octubre

Se conservaron [Quote 00000005](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Quote/0Q0WI000004s9op0AA/view) y [Quote 00000006](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Quote/0Q0WI000004sCMr0AM/view), cada una con cinco líneas y un PDF nativo independiente. La segunda se generó desde el botón real de oportunidad. En Quote, **Ver PDF y enviar** vuelve a abrir el PDF guardado.

No se enviaron correos. `matchdev` está restringido a **Solamente emails del sistema**; la prueba del compositor requiere autorización para cambiar globalmente a **Todos los emails**. [Detalle y validación](cotizacion-envio-nativo.md).

El script de limpieza también contempla archivos vinculados solamente a los Quotes de prueba, incluida la prueba nativa conservada en Quote 00000001. Sigue sin ejecutarse.

## Pruebas de monedas — 6 de octubre

Se creó una [oportunidad ficticia USD](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Opportunity/006WI00000ReUhNYAV/view) con dos servicios: 50.000.000 COP de tarifa, 40.000.000 COP negociados, descuento 20 % y tasa 3.196,2. Sus fórmulas producen 15.644 USD y 12.515 USD. [Quote 00000012](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Quote/0Q0WI000004slsT0AQ/view) conserva esos valores y el PDF validado.

También se generó [Quote 00000013 COP](https://matchdev--sandboxv01.sandbox.lightning.force.com/lightning/r/Quote/0Q0WI000004slu50AA/view) sobre el fixture básico existente. Los registros anteriores se conservaron. [Detalle de la ampliación](cotizacion-monedas.md).

IDs: `docs/datos-prueba-cotizacion-monedas-20261006.json`. La limpieza de 20261005 no incluye la nueva oportunidad USD: al terminar las pruebas, eliminar manualmente únicamente su Quote/archivo, sus dos servicios y esa oportunidad. Cuenta, talento y productos son compartidos con los fixtures anteriores. No se ejecutó limpieza.
