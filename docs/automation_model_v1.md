# Modelo de automatizacion Semilla Xaman v1

## Pregunta

Como automatizar el trabajo para que el operador no tenga que venir continuamente a aceptar cada paso.

## Respuesta corta

Si. Se puede automatizar gran parte del ciclo, pero no todo debe quedar sin control.

El modelo correcto es autonomia por niveles:

1. Nivel automatico seguro.
2. Nivel supervision diferida.
3. Nivel permiso humano obligatorio.

## Nivel 1 · Automatico seguro

Puede ejecutarse sin pedir permiso en cada ciclo:

- leer repositorios publicos,
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
- no mover archivos criticos,
- no ejecutar comandos externos peligrosos,
- no instalar paquetes,
- no tocar secretos,
- no hacer cambios destructivos.

## Nivel 2 · Supervision diferida

Puede avanzar y luego pedir revision agrupada:

- mejoras de documentacion,
- refactors no destructivos,
- propuestas de arquitectura,
- planes de instalacion,
- comparativas de herramientas,
- cambios en modulos nuevos aislados,
- pruebas en sandbox.

Condiciones:

- diff claro,
- evidencia,
- rollback posible,
- resumen para operador.

## Nivel 3 · Permiso humano obligatorio

Debe pedir aprobacion antes de actuar:

- instalar software,
- conectar APIs o credenciales,
- modificar configuraciones del sistema,
- borrar datos,
- cambiar permisos,
- ejecutar comandos con riesgo,
- hacer deploy publico,
- activar costes,
- tocar repos de produccion,
- integrar herramientas externas con acceso amplio.

## Ciclo automatico propuesto

1. Xaman crea tarea en GitHub.
2. Watcher local hace pull.
3. Qwen procesa tarea.
4. Quality score evalua respuesta.
5. Dataset builder guarda episodio.
6. Xaman lee salida.
7. Si es seguro, crea siguiente tarea automaticamente.
8. Si hay riesgo, bloquea y pide permiso.

## Objetivo

Reducir al minimo la intervencion del operador sin perder seguridad.

El operador no debe aprobar cada microtarea segura.
El operador si debe aprobar cambios con riesgo real.

## Implementacion futura

Crear:

- tools/semilla_watch.ps1
- tools/semilla_autopilot.py
- tools/semilla_permission_gate.py
- data/permission_policy.json
- runtime/inbox
- runtime/outbox
- runtime/status
- evidence/

## Regla final

Automatizar lo repetible.
Bloquear lo peligroso.
Resumir lo importante.
