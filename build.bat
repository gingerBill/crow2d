@echo off

set odin_exe=W:\Odin\odin

%odin_exe% build src -out:gordon.wasm -target:js_wasm32 -vet -strict-style