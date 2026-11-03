# Parcial 2 – Programación III – Problemas 2 y 4

Misma organización de la carpeta de la asignatura: todo en una sola carpeta.

| Archivo | Contenido |
|---|---|
| `Util2.ex` | Código base de la asignatura (`mostrar`, `ordenar`, `convertir_coleccion_mensaje`) |
| `Util3.ex` | `lineas_utiles/1` (File.stream! perezoso con línea física), `si_existe/2`, `escapar_xml/1` |
| `Tarea.ex`, `Plan.ex` | Structs del Problema 2 (`crear/…` y `String.Chars`, como `Cliente.ex`) |
| `problema2.exs` | Tareas con dependencias: validación, backtracking y Gantt SVG |
| `problema4.exs` | Paréntesis balanceados: generador perezoso, verificación y Stream infinito |
| `tareas.csv`, `parametros.csv`, `propuestas.txt` | Entradas por defecto |
| `pruebas/` | Casos inválidos y límite |

## Ejecución

```bash
./compilar.sh                 # (compilar.bat en Windows) compila Util2, Util3, Tarea y Plan
elixir problema2.exs          # lee tareas.csv
elixir problema4.exs          # lee parametros.csv y propuestas.txt
```

Las salidas se escriben en la carpeta actual.

## Pruebas

```bash
elixir problema2.exs pruebas/tareas_invalidas.csv   # 9 errores con línea, sin planes
elixir problema2.exs pruebas/tareas_ciclo.csv       # 4 ciclos sin rotaciones
elixir problema2.exs pruebas/tareas_vacio.csv       # proyecto vacío
elixir problema2.exs pruebas/tareas_empate.csv      # 24 planes empatados (el SVG dibuja el primero)
elixir problema2.exs pruebas/tareas_una.csv         # una sola tarea
elixir problema4.exs pruebas/parametros_invalidos.csv pruebas/propuestas.txt
```

## Notas para la sustentación

- **Validación recursiva** (`ValidacionTareas`, `VerificadorParentesis`): sin `Enum` ni `Stream`; usan `:lists` de Erlang para invertir, ordenar y buscar.
- **Ciclos sin rotaciones:** para cada id se buscan caminos que vuelvan a él pasando solo por ids mayores.
- **Backtracking:** en `Planificador.explorar/6`, al volver de la recursión el estado anterior (inmutable) sigue intacto.
- **Generador perezoso:** cada rama de `Parentesis.construir/4` es una función; solo se ejecuta si se consume el Stream.
- **`reduce_while`** detiene el Stream infinito al recibir n=8 sin pedir n=9.
- El separador del orden en `planes.csv` es `-`; se cambia en `Plan.ex`.
