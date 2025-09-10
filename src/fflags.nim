## FFlag "parser"
## Copyright (C) 2024 Trayambak Rai
import std/[json, tables, logging, strutils]
import ./[sober_config, config]

type FFlagParseError* = object of ValueError

proc parseFFlags*(config: Config, fflags: var SoberFFlags) =
  if config.client.fflags.len > 0:
    for flag in config.client.fflags.split('\n'):
      let trimmedFlag = flag.strip()
      if trimmedFlag.len == 0:
        continue

      # Only split on the first '=' to allow '=' in values
      let splitted = trimmedFlag.split('=', maxsplit=1)

      if splitted.len < 2:
        if trimmedFlag.len > 0:
          error "verm: error whilst parsing FFlag (" & trimmedFlag &
            "): only got key, no value to complete the pair was found."
          raise newException(
            FFlagParseError,
            "Error whilst parsing FFlag (" & trimmedFlag &
              "). Only got key, no value to complete the pair was found.",
          )
        else:
          continue

      let
        key = splitted[0].strip()
        val = splitted[1].strip()

      if val.len == 0:
        error "verm: error whilst parsing FFlag (" & trimmedFlag &
          "): value is empty."
        raise newException(
          FFlagParseError,
          "Error whilst parsing FFlag (" & trimmedFlag &
            "). Value is empty.",
        )

      if (val.startsWith('"') and val.endsWith('"')) or
         (val.startsWith('\'') and val.endsWith('\'')):
        fflags[key] = newJString(val)
      elif val in ["true", "false"]:
        fflags[key] = newJBool(parseBool(val))
      else:
        var allInt = true
        for c in val:
          if c notin {'0' .. '9'}:
            allInt = false
            break

        if allInt:
          fflags[key] = newJInt(parseInt(val))
        else:
          raise newException(
            FFlagParseError,
            "Cannot handle FFlag pair of key (" & key & ") and value (" & val &
              "); did you mean " & key & '=' & '\'' & val & "'?",
          )
