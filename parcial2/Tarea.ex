defmodule Tarea do
  defstruct id: "", duracion: 0, plazo: 0, dependencias: []

  def crear(id, duracion, plazo, dependencias) do
    %Tarea{id: id, duracion: duracion, plazo: plazo, dependencias: dependencias}
  end
end
