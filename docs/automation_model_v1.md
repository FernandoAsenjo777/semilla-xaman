# Modelo de automatización Semilla Xaman v1

## Objetivo

Reducir al mínimo la intervención del operador sin perder seguridad.

## Nivel 1 · Automático seguro

Puede ejecutarse sin pedir permiso en cada ciclo:

- leer repositorios públicos,
- crear fichas de fuentes,
- crear microtareas para Qwen,
- procesar respuestas de Qwen,
- calcular score,
- guardar dataset,
- generar evidencias,
- actualizar memoria no destructiva,
- crear documentos nuevos,
- hacer commits de artefactos seguros,
- hacer push de resultados no peligrosos.

Condiciones:

- no borrar,
- no mover archivos críticos,
- no ejecutar comandos externos peligrosos,
- no instalar paquetes,
- no tocar secretos,
- no hacer cambios destructivos.

## Nivel 2 · Supervisión diferida

Puede avanzar y luego pedir revisión agrupada:

- mejoras de documentación,
- refactors no destructivos,
- propuestas de arquitectura,
- planes de instalación,
- comparativas de herramientas,
- cambios en módulos nuevos aislados,
- pruebas en sandbox.

## Nivel 3 · Permiso humano obligatorio

Debe pedir aprobación antes de actuar:

- instalar software,
- conectar APIs o credenciales,
- modificar configuraciones del sistema,
- borrar datos,
- cambiar permisos,
- ejecutar comandos con riesgo,
- hacer deploy público,
- activar costes,
- tocar repos de producción,
- integrar herramientas externas con acceso amplio.

## Regla final

Automatizar lo repetible.
Bloquear lo peligroso.
Resumir lo importante.
