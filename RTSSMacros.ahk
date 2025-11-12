#NoEnv
#SingleInstance Force
#Persistent
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#MaxThreadsBuffer On
#KeyHistory 0
#Include RTSSReader.ahk
global runningGTA := processExist("GTA5_Enhanced.exe") ? "GTA5_Enhanced.exe" : "GTA5.exe"
#If WinActive("ahk_exe " runningGTA)

    SetBatchLines, -1
    SetKeyDelay, -1, -1
    SetMouseDelay, -1
    SetWinDelay, -1
    SetControlDelay, -1
    SetDefaultMouseSpeed, 0
    ListLines Off
    SendMode Input

    Process, Priority, , High
    Process, Priority, GTA5.exe, High

    DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution)
    try {
        global RTSSListener := new RTSSReader(runningGTA)
    } catch e {
        MsgBox, 16, Error, % "Failed to initialize RTSS reader.`n`n" e.Message
        ExitApp
    }
    global stdout := FileOpen("log.txt","w")

    Hotkey, *§, BST
    Hotkey, *F2, Ammo
    return

    BST:
        ; InputManager.sendInputs(["enter downR","m","enter up","down","enter downR","down 3","enter up","down down","enter downR","down up","enter up"])
        InputManager.sendInputs(["m","enter","down 4","enter","down","enter"])
    Return

    Ammo:
        InputManager.sendInputs(["enter downR","m","down 4","enter up","enter","sleep","enter","enter downR","down","enter up","m"])
    Return

    class InputManager {
        static inputSanitizerPattern := "O)(\w+)\s?(down|up|\d+)?(R)?"
        static numberCheckPattern = "^\d+$"

        ; The Parameter is an array of keys; doesn't support raw strings cause I was lazy and that is a lot of effort for no gain. You can also type in "sleep" to wait for appromximately 1 frame, or sleep multiple times.
        sendInputs(inputs) {
            if (RTSSListener.measuringFrametime) {
                sanitizedInputs := this._sanitizeInputs(inputs)
                sentStr := []
                for index, input in sanitizedInputs {
                    if (input.sleep) {
                        this._queueInput("{Blind}{f24 up}", true)
                    } else if (input.single) {
                        this._queueInput("{Blind}" . input.rawInput, input.recursive)
                    } else {
                        this._queueInput("{Blind}" input.rawInput . " down}", input.recursive)
                        this._queueInput("{Blind}" input.rawInput . " up}", input.recursive)
                    }
                }

            }
        }

        _queueInput(input, recursive) {
            funcObj := ObjBindMethod(this, "_sendInput", input)
            RTSSListener.queueTask(0, funcObj, recursive)
        }

        _sendInput(input) {
            Send %input%
            ; stdout.WriteLine(RTSSListener._getTimeSinceStart() " " input)
        }

        _sanitizeInputs(inputs) {
            sanitizedData := []
            for index, input in inputs {
                if (RegExMatch(input, this.inputSanitizerPattern, inputMatch)) {
                    inputName := inputMatch[1]
                    secondArgMatch := inputMatch[2]
                    isRecursive := inputMatch[3] != ""

                    sanitizedInput := {}
                    if (inputName = "sleep") {
                        sanitizedInput.sleep := true
                    } else if (secondArgMatch == "" || this._isNumber(secondArgMatch)) {
                        sanitizedInput.rawInput := "{" inputName
                        sanitizedInput.single := false
                        sanitizedInput.sleep := false
                    } else {
                        sanitizedInput.rawInput := "{" inputName " " secondArgMatch "}"
                        sanitizedInput.single := true
                        sanitizedInput.sleep := false
                    }
                    sanitizedInput.recursive := isRecursive
                    amount := this._isNumber(secondArgMatch) ? secondArgMatch : 1
                    Loop %amount% {
                        sanitizedData.Push(sanitizedInput)
                    }
                }
            }
            return sanitizedData
        }

        _isNumber(str) {
            return RegExMatch(str, this.numberCheckPattern)
        }
    }

    Sleep(ms)
    {
        DllCall("QueryPerformanceFrequency", "Int64*", freq)
        DllCall("QueryPerformanceCounter", "Int64*", CounterBefore)

        While (((counterAfter - CounterBefore) / freq * 1000) < ms) {
            RTSSListener._updateFrameTimes()
            DllCall("QueryPerformanceCounter", "Int64*", CounterAfter)
        }

        RTSSListener._updateFrameTimes()
        return ((counterAfter - CounterBefore) / freq * 1000)
    }

    StartCounting() {
        DllCall("QueryPerformanceFrequency", "Int64*", frequency)
        DllCall("QueryPerformanceCounter", "Int64*", CounterBefore)
        return CounterBefore / frequency
    }

    stopCounting(startTime) {
        DllCall("QueryPerformanceFrequency", "Int64*", frequency)
        DllCall("QueryPerformanceCounter", "Int64*", CounterAfter)
        return (CounterAfter / frequency - startTime) * 1000
    }

    processExist(name) {
        Process, Exist, %name%
        return ErrorLevel
    }