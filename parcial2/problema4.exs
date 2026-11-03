defmodule Parentesis do
  # Stream recursivo y PEREZOSO de cadenas balanceadas con `n` pares y profundidad <= `p`.
  # No calcula nada: solo describe cómo obtener las cadenas cuando alguien las consuma.
  def generar(n, p), do: construir(n, 0, p, "")

  # Cuenta consumiendo el Stream, sin guardar las cadenas en una lista
  def contar(n, p), do: n |> generar(p) |> Enum.count()

  # por_abrir: "(" que faltan | abiertos: "(" sin cerrar | prefijo: cadena construida
  defp construir(0, 0, _p, prefijo), do: [prefijo]

  # Cada rama es una función: la recursión solo se ejecuta si se consume (pereza).
  # Primero se intenta "(" y luego ")".
  defp construir(por_abrir, abiertos, p, prefijo) do
    [
      {por_abrir > 0 and abiertos < p,
       fn -> construir(por_abrir - 1, abiertos + 1, p, prefijo <> "(") end},
      {abiertos > 0, fn -> construir(por_abrir, abiertos - 1, p, prefijo <> ")") end}
    ]
    |> Stream.flat_map(fn {posible, rama} -> if posible, do: rama.(), else: [] end)
  end
end

defmodule VerificadorParentesis do
  # Validación 100 % recursiva: no usa Enum ni Stream.
  # Revisa cada línea "n;p;cadena", escribe el resultado y retorna {válidas, inválidas}.
  def revisar([], _archivo, cuenta), do: cuenta

  def revisar([{linea, texto} | resto], archivo, {validas, invalidas}) do
    motivos = :lists.reverse(motivos(texto))

    IO.puts(
      archivo,
      "Línea #{linea} | #{texto} | #{if motivos == [], do: "VÁLIDA", else: "INVÁLIDA"}"
    )

    escribir(motivos, archivo)

    if motivos == [],
      do: revisar(resto, archivo, {validas + 1, invalidas}),
      else: revisar(resto, archivo, {validas, invalidas + 1})
  end

  defp escribir([], _archivo), do: :ok

  defp escribir([{_clave, texto} | resto], archivo) do
    IO.puts(archivo, "    - #{texto}")
    escribir(resto, archivo)
  end

  defp motivos(texto) do
    with [n, p, cadena] <- String.split(texto, ";"),
         {n, ""} when n >= 1 <- Integer.parse(String.trim(n)),
         {p, ""} when p >= 1 <- Integer.parse(String.trim(p)) do
      cadena = String.trim(cadena)
      recorrer(cadena, cadena, 1, 0, 0, {n, p}, [])
    else
      _ -> [{:formato, "se esperaba n;p;cadena con n >= 1 y p >= 1"}]
    end
  end

  # Caso base: se acabó la cadena
  defp recorrer("", _cadena, pos, balance, _max, {n, _p}, motivos) do
    motivos
    |> agregar(:longitud, pos - 1 != 2 * n, "longitud #{pos - 1}, se esperaba 2n = #{2 * n}")
    |> agregar(:balance, balance != 0, "balance final #{balance}, debe ser 0")
  end

  # "(" : sube el balance; se revisa la profundidad máxima p
  defp recorrer("(" <> resto, cadena, pos, balance, max, {_n, p} = np, motivos) do
    prefijo = String.slice(cadena, 0, pos)

    texto =
      "excede p = #{p}: primer prefijo \"#{prefijo}\" (posición #{pos}, profundidad #{balance + 1})"

    motivos = agregar(motivos, :exceso, balance + 1 > p, texto)
    recorrer(resto, cadena, pos + 1, balance + 1, max(max, balance + 1), np, motivos)
  end

  # ")" : baja el balance; se revisa que no se cierre más de lo abierto
  defp recorrer(")" <> resto, cadena, pos, balance, max, np, motivos) do
    prefijo = String.slice(cadena, 0, pos)

    texto =
      "cierra más de lo abierto: primer prefijo \"#{prefijo}\" (posición #{pos}, profundidad máxima alcanzada #{max})"

    motivos = agregar(motivos, :cierre, balance - 1 < 0, texto)
    recorrer(resto, cadena, pos + 1, balance - 1, max, np, motivos)
  end

  # Cualquier otro carácter no es válido
  defp recorrer(<<caracter::utf8, resto::binary>>, cadena, pos, balance, max, np, motivos) do
    texto = "carácter '#{<<caracter::utf8>>}' en la posición #{pos} (solo se permiten '(' y ')')"
    recorrer(resto, cadena, pos + 1, balance, max, np, agregar(motivos, :caracter, true, texto))
  end

  # Solo se guarda el PRIMER motivo de cada clase
  defp agregar(motivos, clave, true, texto) do
    if :lists.keymember(clave, 1, motivos), do: motivos, else: [{clave, texto} | motivos]
  end

  defp agregar(motivos, _clave, false, _texto), do: motivos
end

defmodule Problema4 do
  def main do
    {parametros, propuestas} =
      case System.argv() do
        [parametros, propuestas] -> {parametros, propuestas}
        _ -> {"parametros.csv", "propuestas.txt"}
      end

    Util3.si_existe(parametros, fn -> procesar_parametros(parametros) end)
    escribir_primera()
    Util3.si_existe(propuestas, fn -> verificar(propuestas) end)
    escribir_secuencia()
  end

  defp procesar_parametros(ruta) do
    ruta
    |> Util3.lineas_utiles()
    |> Enum.each(fn {linea, texto} ->
      case parametros(texto) do
        nil -> Util2.mostrar("Línea #{linea} ignorada: se esperaba n;p con 1 <= p <= n", :error)
        {n, p} -> escribir_soluciones(n, p)
      end
    end)
  end

  defp parametros(texto) do
    with [n, p] <- String.split(texto, ";"),
         {n, ""} <- Integer.parse(String.trim(n)),
         {p, ""} <- Integer.parse(String.trim(p)),
         true <- n >= 1 and p >= 1 and p <= n do
      {n, p}
    else
      _ -> nil
    end
  end

  # Cada cadena se escribe en el archivo en el momento en que el Stream la entrega
  defp escribir_soluciones(n, p) do
    File.open!("parentesis_n#{n}_p#{p}.txt", [:write, :utf8], fn archivo ->
      total =
        n
        |> Parentesis.generar(p)
        |> Stream.each(fn cadena -> IO.puts(archivo, cadena) end)
        |> Enum.count()

      IO.puts(archivo, "Total: #{total}")
      Util2.mostrar("n=#{n}, p=#{p} -> Total: #{total}", :mensaje)
    end)
  end

  defp escribir_primera do
    # PEREZOSO: generar(18, 18) no calcula nada y Enum.take(1) detiene el Stream tras la
    # primera cadena (~36 pasos de recursión). Las otras 477.638.700 soluciones del caso
    # nunca se generan: sus ramas ")" quedan sin ejecutar. Calcularlas todas sería exponencial.
    [primera] = 18 |> Parentesis.generar(18) |> Enum.take(1)
    File.write!("primera_n18_p18.txt", primera <> "\n")
    Util2.mostrar("Primera solución n=18, p=18: #{primera}", :mensaje)
  end

  defp verificar(ruta) do
    registros = ruta |> Util3.lineas_utiles() |> Enum.to_list()

    {validas, invalidas} =
      File.open!("verificacion_parentesis.txt", [:write, :utf8], fn archivo ->
        VerificadorParentesis.revisar(registros, archivo, {0, 0})
      end)

    Util2.mostrar("Propuestas: #{validas} válidas y #{invalidas} inválidas", :mensaje)
  end

  # Stream infinito n = 1, 2, 3, ... con p = n, transformado perezosamente en {n, total}
  defp escribir_secuencia do
    n_final =
      File.open!("secuencia_parentesis.csv", [:write, :utf8], fn archivo ->
        IO.puts(archivo, "n;total")

        1
        |> Stream.iterate(fn n -> n + 1 end)
        |> Stream.map(fn n -> {n, Parentesis.contar(n, n)} end)
        |> Enum.reduce_while(nil, fn {n, total}, _ ->
          IO.puts(archivo, "#{n};#{total}")
          Util2.mostrar("n=#{n}: #{total}", :mensaje)
          # reduce_while se detiene al recibir el primer total >= 1000 sin pedir el siguiente
          # elemento: n = 9 nunca se calcula (take_while sí tendría que calcularlo).
          if total >= 1000, do: {:halt, n}, else: {:cont, nil}
        end)
      end)

    Util2.mostrar("Se detuvo en n=#{n_final}; n=#{n_final + 1} no se calculó", :mensaje)
  end
end

Problema4.main()
