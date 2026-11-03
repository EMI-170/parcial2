defmodule Util3 do
  # Líneas útiles de un archivo, de forma perezosa: {número de línea física, texto}.
  # Se numera ANTES de filtrar para conservar la línea física de cada registro.
  def lineas_utiles(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {texto, linea} -> {linea, String.trim(texto)} end)
    |> Stream.reject(fn {_linea, texto} -> texto == "" or String.starts_with?(texto, "#") end)
  end

  # Ejecuta la función solo si el archivo existe; si no, muestra un aviso
  def si_existe(ruta, funcion) do
    if File.exists?(ruta),
      do: funcion.(),
      else: Util2.mostrar("No existe el archivo #{ruta}", :error)
  end

  def escapar_xml(texto) do
    [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {"\"", "&quot;"}]
    |> Enum.reduce(to_string(texto), fn {de, a}, resto -> String.replace(resto, de, a) end)
  end
end
