## USER 🧑‍💻

update the C app to make all the commands output in JSON format.  Only edit the files in @/src.  Don't compile


---

## MODEL ✨

The C application has been updated to support JSON output for all commands. The changes involved:

1.  **`src/UVCType.h` & `src/UVCType.m`**: Added `jsonObjectFromBuffer` and `typeSummaryDictionary` methods to convert internal buffer data into `NSNumber` or `NSDictionary` structures, and to provide type summaries as dictionaries.
2.  **`src/UVCValue.h` & `src/UVCValue.m`**: Added the `jsonObject` method, which delegates to `UVCType` to produce a JSON-compatible object representing the value.
3.  **`src/UVCController.h` & `src/UVCController.m`**: Added the `summaryDictionary` method to provide a dictionary representation of a control, including its minimum, maximum, step size, and default values.
4.  **`src/uvc-util.m`**:
    *   Replaced all `printf` and `fprintf` statements with new helper functions `printJSON` (for success) and `printError` (for failures).
    *   `printJSON` serializes `NSDictionary` or `NSArray` objects to JSON strings using `NSJSONSerialization`.
    *   Updated all command logic (`--list-devices`, `--list-controls`, `--show-control`, `--get`, `--set`, `--reset-all`, `--version`) to construct dictionary or array responses instead of printing plain text.
    *   Error conditions now output a JSON object containing an `error` message and an error `code`.

The source code in `src/` is now ready to produce JSON output when compiled and run. As requested, no compilation was performed.