defmodule ValidacionTareas do
  # Validación 100 % recursiva: no usa Enum ni Stream.
  # Cada error es {linea, mensaje}; un ciclo se reporta como {linea, [ids]}.
  def validar(registros) do
    {vistos, errores} = revisar_registros(registros, %{}, [])
    errores = revisar_dependencias(registros, vistos, errores)
    :lists.reverse(buscar_ciclos(:lists.sort(Map.keys(vistos)), vistos, errores))
  end

  # vistos: mapa id => {línea, dependencias sin repetir}
  defp revisar_registros([], vistos, errores), do: {vistos, errores}

  defp revisar_registros([{linea, [id, duracion, plazo, deps]} | resto], vistos, errores) do
    {primera, _deps} = Map.get(vistos, id, {0, []})

    errores =
      agregar(linea, errores, [
        {id == "" or String.contains?(id, "|"), "id vacío o con '|'"},
        {primera > 0, "id duplicado '#{id}' (ya definido en la línea #{primera})"},
        {not entero?(duracion, 1), "duración '#{duracion}' no es un entero positivo"},
        {not entero?(plazo, 0), "plazo '#{plazo}' no es un entero no negativo"}
      ])

    revisar_registros(resto, Map.put_new(vistos, id, {linea, :lists.usort(deps)}), errores)
  end

  defp revisar_registros([{linea, campos} | resto], vistos, errores) do
    mensaje = "se esperaban 4 campos y se encontraron #{length(campos)}"
    revisar_registros(resto, vistos, [{linea, mensaje} | errores])
  end

  defp revisar_dependencias([], _vistos, errores), do: errores

  defp revisar_dependencias([{linea, [id, _, _, deps]} | resto], vistos, errores) do
    revisar_dependencias(resto, vistos, revisar_lista(linea, id, deps, [], vistos, errores))
  end

  # Registro mal formado: ya se reportó en la primera pasada
  defp revisar_dependencias([_ | resto], vistos, errores) do
    revisar_dependencias(resto, vistos, errores)
  end

  # vistas: dependencias ya revisadas de esta tarea (para detectar repetidas)
  defp revisar_lista(_linea, _id, [], _vistas, _vistos, errores), do: errores

  defp revisar_lista(linea, id, [dep | resto], vistas, vistos, errores) do
    errores =
      agregar(linea, errores, [
        {dep == "", "dependencia vacía en '#{id}' (use '-' si no tiene)"},
        {dep == id, "la tarea '#{id}' depende de sí misma"},
        {dep != "" and :lists.member(dep, vistas), "dependencia repetida '#{dep}' en '#{id}'"},
        {dep != "" and not Map.has_key?(vistos, dep),
         "'#{id}' depende de '#{dep}', que no existe"}
      ])

    revisar_lista(linea, id, resto, [dep | vistas], vistos, errores)
  end

  # Para cada id se buscan los ciclos que empiezan en él pasando solo por ids
  # MAYORES: así cada ciclo sale una vez (sin rotaciones repetidas).
  defp buscar_ciclos([], _vistos, ciclos), do: ciclos

  defp buscar_ciclos([inicio | resto], vistos, ciclos) do
    buscar_ciclos(resto, vistos, explorar(inicio, [inicio], vistos, ciclos))
  end

  # camino: ids recorridos (el actual primero)
  defp explorar(inicio, [actual | _] = camino, vistos, ciclos) do
    {_linea, deps} = Map.get(vistos, actual, {0, []})
    recorrer(deps, inicio, camino, vistos, ciclos)
  end

  defp recorrer([], _inicio, _camino, _vistos, ciclos), do: ciclos

  defp recorrer([dep | otras], inicio, camino, vistos, ciclos) do
    ciclos =
      cond do
        # Volvimos al inicio: ciclo completo (la autodependencia ya se reportó aparte)
        dep == inicio and length(camino) > 1 ->
          {linea, _deps} = vistos[inicio]
          [{linea, :lists.reverse(camino, [inicio])} | ciclos]

        dep > inicio and not :lists.member(dep, camino) ->
          explorar(inicio, [dep | camino], vistos, ciclos)

        true ->
          ciclos
      end

    recorrer(otras, inicio, camino, vistos, ciclos)
  end

  # Agrega un error por cada condición verdadera de la lista
  defp agregar(_linea, errores, []), do: errores

  defp agregar(linea, errores, [{true, mensaje} | resto]) do
    agregar(linea, [{linea, mensaje} | errores], resto)
  end

  defp agregar(linea, errores, [_ | resto]), do: agregar(linea, errores, resto)

  defp entero?(texto, minimo), do: match?({n, ""} when n >= minimo, Integer.parse(texto))
end

defmodule Planificador do
  # Backtracking: se prueba cada tarea habilitada (en orden alfabético) y, al volver
  # de la recursión, el estado anterior sigue intacto para probar la siguiente.
  # acumulador = {total de planes, mejores planes [{numero, plan}] con el último primero}
  def buscar(tareas, csv), do: explorar(tareas, [], 0, 0, {0, []}, csv)

  # Caso base: no quedan tareas pendientes, el plan está completo
  defp explorar([], fins, tiempo, penalizacion, {total, mejores}, csv) do
    plan = Plan.crear(Enum.reverse(fins), penalizacion)
    IO.puts(csv, "#{total + 1};#{plan};#{tiempo};#{penalizacion}")
    {total + 1, mejorar(mejores, {total + 1, plan})}
  end

  # Caso recursivo: probar cada tarea cuyas dependencias ya terminaron
  defp explorar(pendientes, fins, tiempo, penalizacion, acumulador, csv) do
    pendientes
    |> Enum.filter(fn tarea -> Enum.all?(tarea.dependencias, &List.keymember?(fins, &1, 0)) end)
    |> Enum.reduce(acumulador, fn tarea, acumulado ->
      fin = tiempo + tarea.duracion
      retraso = max(0, fin - tarea.plazo)
      resto = List.delete(pendientes, tarea)
      explorar(resto, [{tarea.id, fin} | fins], fin, penalizacion + retraso, acumulado, csv)
    end)
  end

  defp mejorar([], nuevo), do: [nuevo]

  defp mejorar([{_, %Plan{penalizacion: minima}} | _] = mejores, {_, plan} = nuevo) do
    cond do
      plan.penalizacion < minima -> [nuevo]
      plan.penalizacion == minima -> [nuevo | mejores]
      true -> mejores
    end
  end
end

defmodule Gantt do
  def dibujar({numero, plan}, tareas, total) do
    escala = max(4, min(60, div(900, total)))
    y_fin = 90 + length(plan.orden) * 44

    [
      [
        ~s[<text x="10" y="26" font-size="16" font-weight="bold">#{Util3.escapar_xml("Gantt del plan óptimo ##{numero}: #{plan}")}</text>],
        ~s[<text x="10" y="46" font-size="13">Duración total: #{total}, penalización: #{plan.penalizacion}</text>]
      ],
      marcas(total, escala, y_fin),
      barras(plan, tareas, escala, total),
      referencias(y_fin + 20)
    ]
    |> Stream.concat()
    |> escribir("mejor_plan.svg", 70 + total * escala + 280, y_fin + 60)
  end

  def leyenda(mensaje) do
    [~s[<text x="20" y="55" font-size="16" fill="#b03a2e">#{Util3.escapar_xml(mensaje)}</text>]]
    |> escribir("mejor_plan.svg", 700, 100)
  end

  # Escritura progresiva: un elemento SVG por línea, nunca un string gigante
  defp escribir(elementos, ruta, ancho, alto) do
    File.open!(ruta, [:write, :utf8], fn svg ->
      IO.puts(svg, ~s[<svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}">])
      IO.puts(svg, ~s[<rect width="100%" height="100%" fill="white"/>])
      Enum.each(elementos, fn elemento -> IO.puts(svg, elemento) end)
      IO.puts(svg, "</svg>")
    end)
  end

  # Eje horizontal: una marca cada `paso` unidades de tiempo
  defp marcas(total, escala, y_fin) do
    Stream.flat_map(0..total//max(1, div(total + 19, 20)), fn t ->
      x = 70 + t * escala

      [
        ~s[<line x1="#{x}" y1="84" x2="#{x}" y2="#{y_fin}" stroke="#cccccc"/>],
        ~s[<text x="#{x}" y="78" font-size="12" text-anchor="middle">#{t}</text>]
      ]
    end)
  end

  # Una barra por tarea; longitud proporcional a la duración; naranja si termina tarde
  defp barras(plan, tareas, escala, total) do
    plan.finalizaciones
    |> Stream.with_index()
    |> Stream.flat_map(fn {{id, fin}, fila} ->
      tarea = tareas[id]
      inicio = fin - tarea.duracion
      retraso = max(0, fin - tarea.plazo)
      {y, x} = {90 + fila * 44, 70 + inicio * escala}
      color = if retraso > 0, do: "#e0572f", else: "#2e9e5b"
      estado = if retraso > 0, do: "tarde +#{retraso}", else: "a tiempo"
      detalle = "inicio #{inicio}, fin #{fin}, plazo #{tarea.plazo} (#{estado})"
      marca = 70 + tarea.plazo * escala

      [
        ~s[<text x="10" y="#{y + 26}" font-size="14" font-weight="bold">#{Util3.escapar_xml(id)}</text>],
        ~s[<rect x="#{x}" y="#{y + 8}" width="#{tarea.duracion * escala}" height="26" fill="#{color}" stroke="#333333"/>],
        ~s[<text x="#{x + tarea.duracion * escala + 8}" y="#{y + 26}" font-size="12">#{Util3.escapar_xml(detalle)}</text>]
      ] ++
        if tarea.plazo <= total,
          do: [
            ~s[<line x1="#{marca}" y1="#{y + 2}" x2="#{marca}" y2="#{y + 40}" stroke="#111111" stroke-width="2" stroke-dasharray="4 2"/>]
          ],
          else: []
    end)
  end

  defp referencias(y) do
    [
      ~s[<rect x="70" y="#{y}" width="18" height="14" fill="#2e9e5b" stroke="#333333"/>],
      ~s[<text x="96" y="#{y + 12}" font-size="12">A tiempo</text>],
      ~s[<rect x="190" y="#{y}" width="18" height="14" fill="#e0572f" stroke="#333333"/>],
      ~s[<text x="216" y="#{y + 12}" font-size="12">Fuera de plazo</text>],
      ~s[<line x1="350" y1="#{y}" x2="350" y2="#{y + 14}" stroke="#111111" stroke-width="2" stroke-dasharray="4 2"/>],
      ~s[<text x="358" y="#{y + 12}" font-size="12">Plazo de la tarea</text>]
    ]
  end
end

defmodule Tareas do
  def main do
    ruta = List.first(System.argv()) || "tareas.csv"
    Util3.si_existe(ruta, fn -> procesar(ruta) end)
  end

  defp procesar(ruta) do
    registros = ruta |> Util3.lineas_utiles() |> Stream.map(&separar/1) |> Enum.to_list()

    errores =
      registros
      |> ValidacionTareas.validar()
      |> Util2.ordenar(:asc, fn {linea, _} -> linea end)

    File.open!("validacion_tareas.txt", [:write, :utf8], fn archivo ->
      IO.puts(archivo, "Errores encontrados: #{length(errores)}")
      Enum.each(errores, fn error -> IO.puts(archivo, mensaje(error)) end)
    end)

    cond do
      errores != [] ->
        errores
        |> Util2.convertir_coleccion_mensaje(fn error -> mensaje(error) <> "\n" end)
        |> Util2.mostrar(:error)

        Gantt.leyenda("Red de tareas inválida: no hay plan (ver validacion_tareas.txt)")

      registros == [] ->
        File.write!("resumen_tareas.txt", "Proyecto vacío: no hay tareas\n")
        Util2.mostrar("Proyecto vacío: no hay tareas", :mensaje)
        Gantt.leyenda("Proyecto vacío: no hay plan")

      true ->
        planificar(registros)
    end
  end

  # Registro = {línea, [id, duración, plazo, [dependencias]]}; '-' significa sin dependencias
  defp separar({linea, texto}) do
    case texto |> String.split(";") |> Enum.map(&String.trim/1) do
      [id, duracion, plazo, deps] -> {linea, [id, duracion, plazo, dependencias(deps)]}
      campos -> {linea, campos}
    end
  end

  defp dependencias("-"), do: []
  defp dependencias(texto), do: texto |> String.split("|") |> Enum.map(&String.trim/1)

  defp mensaje({linea, ciclo}) when is_list(ciclo) do
    "Línea #{linea}: ciclo de dependencias #{Enum.join(ciclo, " -> ")}"
  end

  defp mensaje({linea, texto}), do: "Línea #{linea}: #{texto}"

  defp planificar(registros) do
    tareas =
      registros
      |> Enum.map(fn {_, [id, duracion, plazo, deps]} ->
        Tarea.crear(id, String.to_integer(duracion), String.to_integer(plazo), deps)
      end)
      |> Util2.ordenar(:asc, fn tarea -> tarea.id end)

    # Cada plan se escribe en el CSV en el momento en que la recursión lo produce
    {total, mejores} =
      File.open!("planes.csv", [:write, :utf8], fn csv ->
        IO.puts(csv, "id;orden;duracion_total;penalizacion")
        Planificador.buscar(tareas, csv)
      end)

    mejores = Enum.reverse(mejores)
    duracion = tareas |> Enum.map(fn tarea -> tarea.duracion end) |> Enum.sum()
    {_, primero} = hd(mejores)

    resumen = [
      "Total de planes: #{total}",
      "Tiempo total del proyecto: #{duracion}",
      "Penalización mínima: #{primero.penalizacion}",
      "Planes óptimos (#{length(mejores)}):"
      | Enum.map(mejores, fn {numero, plan} -> "  Plan #{numero}: #{plan}" end)
    ]

    File.open!("resumen_tareas.txt", [:write, :utf8], fn archivo ->
      Enum.each(resumen, fn linea -> IO.puts(archivo, linea) end)
    end)

    resumen |> Enum.take(10) |> Enum.each(fn linea -> Util2.mostrar(linea, :mensaje) end)
    Gantt.dibujar(hd(mejores), Map.new(tareas, fn tarea -> {tarea.id, tarea} end), duracion)
  end
end

Tareas.main()
