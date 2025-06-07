# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands
- **Run all tests:** `busted -p '^test_.*%.lua$' --helper tests/helper.lua tests`

## Code Style Guidelines
- **Indentation:** 2-space indent
- **Naming:** snake_case for functions, variables, files; UPPER_SNAKE_CASE for constants
- **Module structure:** Each file returns a table with public functions
- **Imports:** Use `dofile(minetest.get_modpath("moon") .. "/path/to/file.lua")` pattern
- **Error handling:** Return `false/nil` + error message string for failures, `true` + result for success
- **No globals:** Avoid global variable writes outside the `moon` namespace
- **Documentation:** File headers describe purpose; document any new flags or solver behaviors
- **Testing:** New features must include or update tests
- **Philosophy:** Everything is data-driven; extend via new material flags, bond/port types, or solver passes

# OBJECTIVE:
Your objective is to fix all the easiest issues where tests are currently failing. Once you fix something and it fails, give up quickly and move on to another task. DO NOT USE GIT. 

This code has a number of inconsistencies between the files - often function calls are placed to functions which don't exist, or variable names are not correct. This will be especially pronounced between different files in the codebase - they were created mostly independently.