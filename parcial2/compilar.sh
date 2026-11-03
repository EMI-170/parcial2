#!/usr/bin/env bash

rm -f Elixir.*.beam
elixirc Util2.ex Util3.ex Tarea.ex Plan.ex
