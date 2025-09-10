## FFlag "parser"
## Copyright (C) 2024 Trayambak Rai
import std/[json, tables, logging, strutils]
import ./[sober_config, config]

type FFlagParseError* = object of ValueError

proc parseFFlags*(config: Config, fflags: var SoberFFlags) =
  if config.client.fflags.len > 0:
    for flag in config.client.fflags.split('\n'):
      let splitted = flag.split('=')

      if splitted.len < 2:
        if flag.len > 0:
          error "verm: error whilst parsing FFlag (" & flag &
            "): only got key, no value to complete the pair was found."
          raise newException(
            FFlagParseError,
            "Error whilst parsing FFlag (" & flag &
              "). Only got key, no value to complete the pair was found.",
          )
        else:
          continue

      if splitted.len > 2:
        error "verm: error whilst parsing FFlag (" & flag &
          "): got more than two splits, key and value were already found."
        raise newException(
          FFlagParseError,
          "Error whilst parsing FFlag (" & flag &
            "). Got more than two splits, key and value were already found!",
        )

      let
        key = splitted[0]
        val = splitted[1]

      if val.startsWith('"') and val.endsWith('"') or
          val.startsWith('\'') and val.endsWith('\''):
        fflags[key] = newJString(val)
      elif val in ["true", "false"]:
        fflags[key] = newJBool(parseBool(val))
      else:
        var allInt = false

        for c in val:
          if c in {'0' .. '9'}:
            allInt = true
          else:
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
