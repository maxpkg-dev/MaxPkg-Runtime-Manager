-- Verifies that the reusable Runtime result dialog compiles and loads.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local runtimeRoot = getFilenamePath (getFilenamePath (getSourceFileName()))
    local resultDialogModule = fileIn (runtimeRoot + @"ui\common\result-dialog.ms")
    if (resultDialogModule == undefined) do throw "RESULT_DIALOG_LOAD_FAILED"
    if (not (doesFileExist (runtimeRoot + @"ui\common\result-dialog.html"))) do throw "RESULT_DIALOG_HTML_MISSING"
    if (not (doesFileExist (runtimeRoot + @"ui\common\result-dialog.css"))) do throw "RESULT_DIALOG_STYLES_MISSING"
    if (not (doesFileExist (runtimeRoot + @"ui\common\result-dialog.js"))) do throw "RESULT_DIALOG_SCRIPT_MISSING"
    format "RESULT_DIALOG_LOAD_OK\n"
    true
)
