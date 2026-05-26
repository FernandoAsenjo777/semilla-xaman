# Semilla Xaman

Semilla Xaman es el proyecto para convertir a Qwen local en una IA cada vez mas capaz, medible y util mediante una capa externa de aprendizaje, memoria, evaluacion, algoritmos, feedback y herramientas controladas.

## Objetivo principal

Qwen es el objeto destino.

ChatGPT/Xaman actua como mentor, arquitecto y auditor durante la construccion.
Qwen debe evolucionar desde modelo local que responde tareas hacia Qwen Semilla: una IA local con metodo, memoria, criterio, evaluacion y capacidad de mejora progresiva.

## Idea central

No se espera que Qwen mejore solo por magia ni por reentrenamiento inmediato.
Se construye una escuela alrededor de Qwen:

- tareas pequenas,
- contexto controlado,
- memoria,
- RAG,
- evaluacion,
- feedback,
- dataset,
- algoritmos,
- calidad de codigo,
- creatividad,
- supervision humana.

## Dos piernas de aprendizaje

### Pierna 1 · Tecnica-operativa

Para que Qwen aprenda a pensar, programar, estructurar, validar, usar herramientas y resolver problemas.

### Pierna 2 · Interpretativa-creativa

Para que Qwen aprenda a entender prompts, leer intencion, interpretar estilo, diseno, narrativa, marca y creatividad aplicada.

## Primera arquitectura objetivo

source_map -> learning_harness -> qwen_task -> qwen_output -> quality_score -> xaman_review -> dataset_builder -> memory -> next_task

## Regla de seguridad

Qwen no ejecuta acciones peligrosas directamente.
Toda accion con riesgo debe pasar por control humano, evidencias, validacion y rollback cuando proceda.

## Estado

Repositorio inicializado como base limpia para la Escuela de Qwen Semilla.
