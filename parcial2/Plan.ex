defmodule Plan do
  defstruct orden: [], finalizaciones: [], penalizacion: 0

  def crear(finalizaciones, penalizacion) do
    orden = Enum.map(finalizaciones, fn {id, _fin} -> id end)
    %Plan{orden: orden, finalizaciones: finalizaciones, penalizacion: penalizacion}
  end

  # Los ids del orden se separan con "-" (cambie aquí el separador si lo piden distinto)
  defimpl String.Chars, for: Plan do
    def to_string(%Plan{orden: orden}), do: Enum.join(orden, "-")
  end
end
